#!/bin/bash
# =============================================================================
# Obtiene la lista de imágenes de Cilium/Isovalent para instalación air-gapped
# Basado en: https://docs.isovalent.com/ink/install/air-gapped.html
#
# Uso: CLUSTER_NAME=paas-arqlab ./00_get_images.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

echo "=== Obteniendo lista de imágenes de Cilium ${CLIFE_VERSION} ==="

# Verificar herramientas requeridas
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo "ERROR: $1 no está instalado"
        echo "  Instalar con: $2"
        exit 1
    fi
}

check_tool "helm" "brew install helm / dnf install helm"
check_tool "yq" "brew install yq / instalar mikefarah/yq"

# Verificar que es mikefarah/yq
if ! yq --version 2>&1 | grep -q "mikefarah/yq"; then
    echo "ADVERTENCIA: Se requiere mikefarah/yq, no la versión de Python"
    echo "  Versión actual: $(yq --version 2>&1)"
fi

# --- Configurar Helm ---
echo ""
echo "Configurando Helm repository de Isovalent..."
helm repo add isovalent https://helm.isovalent.com 2>/dev/null || true
helm repo update isovalent

# --- Verificar versión disponible ---
echo ""
echo "Versiones disponibles de Cilium:"
helm search repo isovalent/cilium --versions | head -10

# --- Obtener configuración de Cilium del cluster ---
CILIUM_VALUES_FILE="${CLUSTER_DIR}/cilium-values.yaml"

if [[ ! -f "${CILIUM_VALUES_FILE}" ]]; then
    echo ""
    echo "ADVERTENCIA: No existe ${CILIUM_VALUES_FILE}"
    echo "  Usando CiliumConfig del clife-tmp si existe..."
    
    if [[ -f "${CLIFE_TMP_DIR}/ciliumconfig.yaml" ]]; then
        # Extraer spec del CiliumConfig como valores de Helm
        yq '.spec' "${CLIFE_TMP_DIR}/ciliumconfig.yaml" > "${CILIUM_VALUES_FILE}" 2>/dev/null || touch "${CILIUM_VALUES_FILE}"
    else
        echo "  Usando configuración vacía (imágenes base)"
        touch "${CILIUM_VALUES_FILE}"
    fi
fi

# --- Generar lista de imágenes ---
IMAGES_OUTPUT="${CLUSTER_DIR}/images-required.txt"
echo ""
echo "Generando lista de imágenes requeridas..."

helm template cilium isovalent/cilium \
    --version "${CLIFE_VERSION}" \
    --values "${CILIUM_VALUES_FILE}" \
    2>/dev/null | yq -N '.. | .image? | select(.)' | sort -u > "${IMAGES_OUTPUT}"

# Contar imágenes
IMAGE_COUNT=$(wc -l < "${IMAGES_OUTPUT}" | tr -d ' ')

echo ""
echo "=== ${IMAGE_COUNT} imágenes requeridas ==="
cat "${IMAGES_OUTPUT}"

# --- Generar script de mirror ---
MIRROR_SCRIPT="${CLUSTER_DIR}/mirror-images.sh"
echo ""
echo "Generando script de mirror: ${MIRROR_SCRIPT}"

cat > "${MIRROR_SCRIPT}" << 'MIRROR_HEADER'
#!/bin/bash
# =============================================================================
# Script de mirror de imágenes de Cilium para entorno air-gapped
# Generado automáticamente por 00_get_images.sh
#
# Requisitos:
#   - skopeo instalado
#   - Acceso a quay.io/isovalent (o las imágenes ya descargadas)
#   - Acceso al registry interno destino
#
# Uso:
#   export INTERNAL_REGISTRY="registry.internal.example.com"
#   ./mirror-images.sh
# =============================================================================
set -euo pipefail

# Configuración
INTERNAL_REGISTRY="${INTERNAL_REGISTRY:-registry.example}"

# Verificar skopeo
if ! command -v skopeo &>/dev/null; then
    echo "ERROR: skopeo no está instalado"
    echo "  Instalar con: dnf install skopeo"
    exit 1
fi

echo "=== Iniciando mirror de imágenes ==="
echo "  Destino: ${INTERNAL_REGISTRY}"
echo ""

mirror_image() {
    local SOURCE_IMAGE="$1"
    
    # Extraer componentes
    local REGISTRY=$(echo "$SOURCE_IMAGE" | cut -d'/' -f1)
    local IMAGE_PATH=$(echo "$SOURCE_IMAGE" | cut -d'/' -f2-)
    
    # Separar imagen del digest (si existe)
    if [[ "$IMAGE_PATH" == *"@sha256:"* ]]; then
        local IMAGE_NAME=$(echo "$IMAGE_PATH" | cut -d':' -f1 | cut -d'@' -f1)
        local DIGEST=$(echo "$IMAGE_PATH" | grep -o '@sha256:.*')
        # Para skopeo, quitar el tag si hay digest
        SOURCE_IMAGE=$(echo "$SOURCE_IMAGE" | sed 's/:[^@]*@/@/')
        local TARGET_IMAGE="${INTERNAL_REGISTRY}/${IMAGE_NAME}${DIGEST}"
    else
        local IMAGE_NAME=$(echo "$IMAGE_PATH" | cut -d':' -f1)
        local TAG=$(echo "$IMAGE_PATH" | cut -d':' -f2)
        local TARGET_IMAGE="${INTERNAL_REGISTRY}/${IMAGE_NAME}:${TAG}"
    fi
    
    echo "Copiando: ${IMAGE_NAME}"
    echo "  Desde: ${SOURCE_IMAGE}"
    echo "  Hacia: ${TARGET_IMAGE}"
    
    if skopeo copy --all --preserve-digests \
        "docker://${SOURCE_IMAGE}" \
        "docker://${TARGET_IMAGE}"; then
        echo "  ✓ OK"
    else
        echo "  ✗ ERROR"
        return 1
    fi
    echo ""
}

# Lista de imágenes a copiar
IMAGES=(
MIRROR_HEADER

# Agregar cada imagen al script
while IFS= read -r image; do
    echo "    \"${image}\"" >> "${MIRROR_SCRIPT}"
done < "${IMAGES_OUTPUT}"

cat >> "${MIRROR_SCRIPT}" << 'MIRROR_FOOTER'
)

# Procesar imágenes
FAILED=0
for img in "${IMAGES[@]}"; do
    if ! mirror_image "$img"; then
        ((FAILED++))
    fi
done

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo "✓ Todas las imágenes copiadas correctamente"
else
    echo "✗ ${FAILED} imágenes fallaron"
    exit 1
fi
MIRROR_FOOTER

chmod +x "${MIRROR_SCRIPT}"

# --- Generar valores de Helm para registry interno ---
HELM_VALUES_REGISTRY="${CLUSTER_DIR}/helm-values-registry.yaml"
echo ""
echo "Generando valores de Helm para registry interno: ${HELM_VALUES_REGISTRY}"

cat > "${HELM_VALUES_REGISTRY}" << 'EOF'
# Valores de Helm para usar registry interno en instalación air-gapped
# Ajustar INTERNAL_REGISTRY al nombre real de tu registry
#
# Usar con: helm template ... --values helm-values-registry.yaml

image:
  repository: "INTERNAL_REGISTRY/cilium"
  # useDigest: true  # Mantener digests para inmutabilidad

operator:
  image:
    repository: "INTERNAL_REGISTRY/operator"
    # El chart agrega "-generic" automáticamente

envoy:
  image:
    repository: "INTERNAL_REGISTRY/cilium-envoy"

hubble:
  relay:
    image:
      repository: "INTERNAL_REGISTRY/hubble-relay"
  ui:
    frontend:
      image:
        repository: "INTERNAL_REGISTRY/hubble-ui-enterprise"
    backend:
      image:
        repository: "INTERNAL_REGISTRY/hubble-ui-enterprise-backend"
EOF

# También actualizar images-list.txt global
GLOBAL_IMAGES="${BASE_DIR}/artifacts/images/images-list.txt"
echo ""
echo "Actualizando lista global: ${GLOBAL_IMAGES}"

cat > "${GLOBAL_IMAGES}" << EOF
# Imágenes de Cilium/Isovalent para instalación air-gapped
# Generado: $(date -Iseconds)
# Versión CLife: ${CLIFE_VERSION}
#
# Estas imágenes se obtuvieron de:
#   helm template cilium isovalent/cilium --version ${CLIFE_VERSION}
#
# Usar skopeo para copiar a registry interno:
#   skopeo copy --all --preserve-digests \\
#     docker://IMAGEN_ORIGEN docker://REGISTRY_INTERNO/IMAGEN

EOF

cat "${IMAGES_OUTPUT}" >> "${GLOBAL_IMAGES}"

echo ""
echo "=== Resumen ==="
echo "  Lista de imágenes:        ${IMAGES_OUTPUT}"
echo "  Script de mirror:         ${MIRROR_SCRIPT}"
echo "  Valores Helm (registry):  ${HELM_VALUES_REGISTRY}"
echo "  Lista global:             ${GLOBAL_IMAGES}"
echo ""
echo "Próximos pasos para air-gapped:"
echo "  1. Copiar ${MIRROR_SCRIPT} a máquina con acceso a internet y registry interno"
echo "  2. export INTERNAL_REGISTRY=tu-registry.example.com"
echo "  3. ./mirror-images.sh"
echo "  4. Editar ${HELM_VALUES_REGISTRY} con el nombre real del registry"
