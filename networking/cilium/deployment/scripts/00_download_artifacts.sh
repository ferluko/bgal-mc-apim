#!/bin/bash
# =============================================================================
# Descarga todos los artefactos necesarios para instalación offline (air-gapped)
# Ejecutar desde una máquina con acceso a internet
#
# Incluye:
#   - CLife (Cilium Lifecycle Operator)
#   - Herramientas CLI: yq, jq, cilium, hubble, skopeo, helm
#   - Imágenes de Cilium (guardadas en tar.gz)
#
# Uso: ./00_download_artifacts.sh [--skip-images]
#
# Opciones:
#   --skip-images   No descargar imágenes de contenedores
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="${BASE_DIR}/artifacts"

# Opciones
SKIP_IMAGES=false
for arg in "$@"; do
    case $arg in
        --skip-images) SKIP_IMAGES=true ;;
    esac
done

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Descargando artefactos para instalación offline ===${NC}"
echo ""

# Crear estructura de directorios
mkdir -p "${ARTIFACTS_DIR}"/{clife,tools,images}

# -----------------------------------------------------------------------------
# 1. CLife (Cilium Lifecycle Operator)
# -----------------------------------------------------------------------------
echo -e "${CYAN}[1/4] Descargando CLife...${NC}"

CLIFE_VERSION="1.18.6"
CLIFE_BASE_URL="https://docs.isovalent.com/v25.11/public/clife"

cd "${ARTIFACTS_DIR}/clife"

if [[ ! -f "clife-v${CLIFE_VERSION}.tar.gz" ]]; then
    curl -fSL -o "clife-v${CLIFE_VERSION}.tar.gz" "${CLIFE_BASE_URL}/clife-v${CLIFE_VERSION}.tar.gz"
    curl -fSL -o "clife-v${CLIFE_VERSION}.tar.gz.sha256" "${CLIFE_BASE_URL}/clife-v${CLIFE_VERSION}.tar.gz.sha256"
    
    if sha256sum -c "clife-v${CLIFE_VERSION}.tar.gz.sha256"; then
        echo -e "${GREEN}✓ CLife v${CLIFE_VERSION} descargado${NC}"
    else
        echo -e "${RED}✗ Error en checksum de CLife${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ CLife v${CLIFE_VERSION} ya existe${NC}"
fi

# -----------------------------------------------------------------------------
# 2. Herramientas CLI
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[2/4] Descargando herramientas CLI...${NC}"

cd "${ARTIFACTS_DIR}/tools"

# yq (para manipular YAML)
YQ_VERSION="4.40.5"
if [[ ! -f "yq_linux_amd64" ]]; then
    echo "Descargando yq v${YQ_VERSION}..."
    curl -fSL -o "yq_linux_amd64" "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64"
    curl -fSL -o "yq_linux_amd64.sha256" "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/checksums_hashes_order" 
    chmod +x yq_linux_amd64
    echo -e "${GREEN}✓ yq v${YQ_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ yq ya existe${NC}"
fi

# jq (para manipular JSON)
JQ_VERSION="1.7.1"
if [[ ! -f "jq-linux-amd64" ]]; then
    echo "Descargando jq v${JQ_VERSION}..."
    curl -fSL -o "jq-linux-amd64" "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64"
    chmod +x jq-linux-amd64
    echo -e "${GREEN}✓ jq v${JQ_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ jq ya existe${NC}"
fi

# cilium CLI
CILIUM_CLI_VERSION="0.16.4"
if [[ ! -f "cilium-linux-amd64.tar.gz" ]]; then
    echo "Descargando cilium CLI v${CILIUM_CLI_VERSION}..."
    curl -fSL -o "cilium-linux-amd64.tar.gz" "https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz"
    curl -fSL -o "cilium-linux-amd64.tar.gz.sha256sum" "https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz.sha256sum"
    echo -e "${GREEN}✓ cilium CLI v${CILIUM_CLI_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ cilium CLI ya existe${NC}"
fi

# hubble CLI
HUBBLE_VERSION="0.13.0"
if [[ ! -f "hubble-linux-amd64.tar.gz" ]]; then
    echo "Descargando hubble CLI v${HUBBLE_VERSION}..."
    curl -fSL -o "hubble-linux-amd64.tar.gz" "https://github.com/cilium/hubble/releases/download/v${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz"
    curl -fSL -o "hubble-linux-amd64.tar.gz.sha256sum" "https://github.com/cilium/hubble/releases/download/v${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz.sha256sum"
    echo -e "${GREEN}✓ hubble CLI v${HUBBLE_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ hubble CLI ya existe${NC}"
fi

# skopeo (binario estático de lework/skopeo-binary)
SKOPEO_VERSION="1.18.0"
if [[ ! -f "skopeo-linux-amd64" ]]; then
    echo "Descargando skopeo v${SKOPEO_VERSION}..."
    curl -fSL -o "skopeo-linux-amd64" "https://github.com/lework/skopeo-binary/releases/download/v${SKOPEO_VERSION}/skopeo-linux-amd64"
    chmod +x skopeo-linux-amd64
    echo -e "${GREEN}✓ skopeo v${SKOPEO_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ skopeo ya existe${NC}"
fi

# helm
HELM_VERSION="3.14.0"
if [[ ! -f "helm-linux-amd64.tar.gz" ]]; then
    echo "Descargando helm v${HELM_VERSION}..."
    curl -fSL -o "helm-linux-amd64.tar.gz" "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz"
    echo -e "${GREEN}✓ helm v${HELM_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ helm ya existe${NC}"
fi

# -----------------------------------------------------------------------------
# 3. Imágenes de Cilium (guardadas como tar.gz)
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[3/5] Descargando imágenes de Cilium...${NC}"

cd "${ARTIFACTS_DIR}/images"

# Lista de imágenes de Cilium/Isovalent para v1.18.6
# Obtenidas con: helm template cilium isovalent/cilium --version 1.18.6 --set hubble.enabled=true ...
# La versión correcta es cee.2 (no cee.1)
CILIUM_IMAGES=(
    "quay.io/isovalent/cilium:v1.18.6-cee.2"
    "quay.io/isovalent/operator-generic:v1.18.6-cee.2"
    "quay.io/isovalent/cilium-envoy:v1.18.6-cee.2"
    "quay.io/isovalent/hubble-relay:v1.18.6-cee.2"
)

# Hubble UI (desde quay.io/cilium, no isovalent)
HUBBLE_IMAGES=(
    "quay.io/cilium/hubble-ui:v0.13.3"
    "quay.io/cilium/hubble-ui-backend:v0.13.3"
)

# Imágenes adicionales para tests
TEST_IMAGES=(
    "docker.io/library/busybox:1.36"
    "docker.io/library/nginx:alpine"
)

# Guardar lista
cat > images-list.txt << EOF
# Imágenes de Cilium/Isovalent para instalación air-gapped
# Generado: $(date -Iseconds)
# Versión CLife: ${CLIFE_VERSION}
#
# Las imágenes se guardan en: cilium-images.tar.gz
# Cargar con: podman load -i cilium-images.tar.gz

# Cilium core images
EOF

for img in "${CILIUM_IMAGES[@]}"; do
    echo "$img" >> images-list.txt
done

echo "" >> images-list.txt
echo "# Hubble UI images (quay.io/cilium)" >> images-list.txt
for img in "${HUBBLE_IMAGES[@]}"; do
    echo "$img" >> images-list.txt
done

echo "" >> images-list.txt
echo "# Test images" >> images-list.txt
for img in "${TEST_IMAGES[@]}"; do
    echo "$img" >> images-list.txt
done

if [[ "${SKIP_IMAGES}" == "true" ]]; then
    echo -e "${YELLOW}⚠ Saltando descarga de imágenes (--skip-images)${NC}"
    echo "  Ejecutar manualmente después:"
    echo "  ./save-images.sh"
else
    # Verificar que tenemos podman o docker
    if command -v podman &>/dev/null; then
        CONTAINER_CMD="podman"
    elif command -v docker &>/dev/null; then
        CONTAINER_CMD="docker"
    else
        echo -e "${YELLOW}⚠ No se encontró podman ni docker${NC}"
        echo "  Las imágenes se descargarán cuando ejecutes ./save-images.sh"
        CONTAINER_CMD=""
    fi

    if [[ -n "${CONTAINER_CMD}" ]]; then
        echo "Usando ${CONTAINER_CMD} para descargar imágenes..."
        
        ALL_IMAGES=("${CILIUM_IMAGES[@]}" "${HUBBLE_IMAGES[@]}" "${TEST_IMAGES[@]}")
        
        # Pull todas las imágenes
        for img in "${ALL_IMAGES[@]}"; do
            echo "  Descargando: ${img}"
            ${CONTAINER_CMD} pull "${img}" || echo -e "${YELLOW}⚠ No se pudo descargar ${img}${NC}"
        done
        
        # Guardar en tar.gz
        echo ""
        echo "Guardando imágenes en cilium-images.tar.gz..."
        ${CONTAINER_CMD} save "${ALL_IMAGES[@]}" | gzip > cilium-images.tar.gz
        
        echo -e "${GREEN}✓ Imágenes guardadas en cilium-images.tar.gz ($(du -h cilium-images.tar.gz | cut -f1))${NC}"
    fi
fi

# -----------------------------------------------------------------------------
# 4. Crear script de instalación de herramientas
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[4/5] Creando scripts de instalación...${NC}"

cat > "${ARTIFACTS_DIR}/install-tools.sh" << 'EOF'
#!/bin/bash
# =============================================================================
# Instala las herramientas CLI en /usr/local/bin
# Ejecutar como root o con sudo
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
INSTALL_DIR="/usr/local/bin"

echo "Instalando herramientas en ${INSTALL_DIR}..."

# yq
if [[ -f "${TOOLS_DIR}/yq_linux_amd64" ]]; then
    cp "${TOOLS_DIR}/yq_linux_amd64" "${INSTALL_DIR}/yq"
    chmod +x "${INSTALL_DIR}/yq"
    echo "✓ yq instalado"
fi

# jq
if [[ -f "${TOOLS_DIR}/jq-linux-amd64" ]]; then
    cp "${TOOLS_DIR}/jq-linux-amd64" "${INSTALL_DIR}/jq"
    chmod +x "${INSTALL_DIR}/jq"
    echo "✓ jq instalado"
fi

# cilium
if [[ -f "${TOOLS_DIR}/cilium-linux-amd64.tar.gz" ]]; then
    tar -xzf "${TOOLS_DIR}/cilium-linux-amd64.tar.gz" -C "${INSTALL_DIR}" cilium
    chmod +x "${INSTALL_DIR}/cilium"
    echo "✓ cilium instalado"
fi

# hubble
if [[ -f "${TOOLS_DIR}/hubble-linux-amd64.tar.gz" ]]; then
    tar -xzf "${TOOLS_DIR}/hubble-linux-amd64.tar.gz" -C "${INSTALL_DIR}" hubble
    chmod +x "${INSTALL_DIR}/hubble"
    echo "✓ hubble instalado"
fi

# skopeo
if [[ -f "${TOOLS_DIR}/skopeo-linux-amd64" ]]; then
    cp "${TOOLS_DIR}/skopeo-linux-amd64" "${INSTALL_DIR}/skopeo"
    chmod +x "${INSTALL_DIR}/skopeo"
    echo "✓ skopeo instalado"
fi

# helm
if [[ -f "${TOOLS_DIR}/helm-linux-amd64.tar.gz" ]]; then
    tar -xzf "${TOOLS_DIR}/helm-linux-amd64.tar.gz" -C /tmp linux-amd64/helm
    mv /tmp/linux-amd64/helm "${INSTALL_DIR}/helm"
    chmod +x "${INSTALL_DIR}/helm"
    rm -rf /tmp/linux-amd64
    echo "✓ helm instalado"
fi

echo ""
echo "Verificando instalación:"
echo "  yq version:     $(yq --version 2>/dev/null || echo 'no instalado')"
echo "  jq version:     $(jq --version 2>/dev/null || echo 'no instalado')"
echo "  cilium version: $(cilium version --client 2>/dev/null || echo 'no instalado')"
echo "  hubble version: $(hubble version 2>/dev/null || echo 'no instalado')"
echo "  skopeo version: $(skopeo --version 2>/dev/null || echo 'no instalado')"
echo "  helm version:   $(helm version --short 2>/dev/null || echo 'no instalado')"
EOF

chmod +x "${ARTIFACTS_DIR}/install-tools.sh"

# -----------------------------------------------------------------------------
# 5. Crear script para registry local con Podman
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[5/5] Creando scripts adicionales...${NC}"

cat > "${ARTIFACTS_DIR}/start-local-registry.sh" << 'REGISTRY_SCRIPT'
#!/bin/bash
# =============================================================================
# Inicia un registry local con Podman para servir imágenes en entorno air-gapped
#
# Uso:
#   ./start-local-registry.sh              # Inicia en puerto 5000
#   ./start-local-registry.sh 5001         # Inicia en puerto específico
#   ./start-local-registry.sh stop         # Detiene el registry
#   ./start-local-registry.sh load         # Carga imágenes desde tar.gz
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_PORT="${1:-5000}"
REGISTRY_NAME="local-registry"
REGISTRY_DATA="${SCRIPT_DIR}/registry-data"
IMAGES_TAR="${SCRIPT_DIR}/images/cilium-images.tar.gz"

# Verificar podman
if ! command -v podman &>/dev/null; then
    echo "ERROR: podman no está instalado"
    exit 1
fi

case "${1:-start}" in
    stop)
        echo "Deteniendo registry..."
        podman stop ${REGISTRY_NAME} 2>/dev/null || true
        podman rm ${REGISTRY_NAME} 2>/dev/null || true
        echo "✓ Registry detenido"
        ;;
    
    load)
        echo "Cargando imágenes desde ${IMAGES_TAR}..."
        if [[ ! -f "${IMAGES_TAR}" ]]; then
            echo "ERROR: No se encontró ${IMAGES_TAR}"
            exit 1
        fi
        
        # Cargar imágenes en podman local
        podman load -i "${IMAGES_TAR}"
        
        # Re-tag y push al registry local
        echo ""
        echo "Subiendo imágenes al registry local (localhost:${REGISTRY_PORT})..."
        
        # Leer lista de imágenes
        while IFS= read -r img; do
            # Saltar comentarios y líneas vacías
            [[ "$img" =~ ^#.*$ ]] && continue
            [[ -z "$img" ]] && continue
            
            # Extraer nombre de imagen sin registry
            IMG_NAME=$(echo "$img" | sed 's|^[^/]*/||')
            LOCAL_TAG="localhost:${REGISTRY_PORT}/${IMG_NAME}"
            
            echo "  ${img} -> ${LOCAL_TAG}"
            podman tag "${img}" "${LOCAL_TAG}" 2>/dev/null || true
            podman push "${LOCAL_TAG}" --tls-verify=false 2>/dev/null || echo "    ⚠ Error al subir"
        done < "${SCRIPT_DIR}/images/images-list.txt"
        
        echo ""
        echo "✓ Imágenes cargadas en localhost:${REGISTRY_PORT}"
        ;;
    
    *)
        # Verificar si ya está corriendo
        if podman ps --format "{{.Names}}" | grep -q "^${REGISTRY_NAME}$"; then
            echo "Registry ya está corriendo en puerto ${REGISTRY_PORT}"
            podman ps --filter name=${REGISTRY_NAME}
            exit 0
        fi
        
        # Crear directorio para datos
        mkdir -p "${REGISTRY_DATA}"
        
        echo "Iniciando registry local en puerto ${REGISTRY_PORT}..."
        
        # Iniciar registry
        podman run -d \
            --name ${REGISTRY_NAME} \
            --restart=always \
            -p ${REGISTRY_PORT}:5000 \
            -v ${REGISTRY_DATA}:/var/lib/registry:Z \
            docker.io/library/registry:2
        
        echo ""
        echo "✓ Registry iniciado"
        echo ""
        echo "URL: http://localhost:${REGISTRY_PORT}"
        echo ""
        echo "Próximo paso: cargar imágenes"
        echo "  ./start-local-registry.sh load"
        echo ""
        echo "Para usar en CiliumConfig:"
        echo "  INTERNAL_REGISTRY=<IP-servidor>:${REGISTRY_PORT}"
        ;;
esac
REGISTRY_SCRIPT

chmod +x "${ARTIFACTS_DIR}/start-local-registry.sh"

# Script para guardar imágenes (si no se hizo durante la descarga)
cat > "${ARTIFACTS_DIR}/save-images.sh" << 'SAVE_SCRIPT'
#!/bin/bash
# =============================================================================
# Guarda las imágenes de Cilium en un archivo tar.gz
# Ejecutar en máquina con acceso a internet
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="${SCRIPT_DIR}/images"
IMAGES_LIST="${IMAGES_DIR}/images-list.txt"
OUTPUT_FILE="${IMAGES_DIR}/cilium-images.tar.gz"

# Verificar podman o docker
if command -v podman &>/dev/null; then
    CMD="podman"
elif command -v docker &>/dev/null; then
    CMD="docker"
else
    echo "ERROR: Se requiere podman o docker"
    exit 1
fi

echo "Usando: ${CMD}"
echo ""

# Leer imágenes de la lista
IMAGES=()
while IFS= read -r line; do
    # Saltar comentarios y líneas vacías
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    IMAGES+=("$line")
done < "${IMAGES_LIST}"

echo "Descargando ${#IMAGES[@]} imágenes..."
for img in "${IMAGES[@]}"; do
    echo "  Pull: ${img}"
    ${CMD} pull "${img}" || echo "  ⚠ Error al descargar ${img}"
done

echo ""
echo "Guardando en ${OUTPUT_FILE}..."
${CMD} save "${IMAGES[@]}" | gzip > "${OUTPUT_FILE}"

echo ""
echo "✓ Imágenes guardadas: ${OUTPUT_FILE}"
echo "  Tamaño: $(du -h ${OUTPUT_FILE} | cut -f1)"
SAVE_SCRIPT

chmod +x "${ARTIFACTS_DIR}/save-images.sh"

# Script para cargar imágenes en el servidor destino
cat > "${ARTIFACTS_DIR}/load-images.sh" << 'LOAD_SCRIPT'
#!/bin/bash
# =============================================================================
# Carga las imágenes de Cilium desde tar.gz y las sube al registry local
#
# Uso:
#   ./load-images.sh                           # Usa localhost:5000
#   ./load-images.sh registry.example.com:5000 # Registry específico
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="${SCRIPT_DIR}/images"
IMAGES_TAR="${IMAGES_DIR}/cilium-images.tar.gz"
IMAGES_LIST="${IMAGES_DIR}/images-list.txt"
REGISTRY="${1:-localhost:5000}"

# Verificar podman
if ! command -v podman &>/dev/null; then
    echo "ERROR: podman no está instalado"
    echo "  Ejecutar: sudo ./install-tools.sh"
    exit 1
fi

if [[ ! -f "${IMAGES_TAR}" ]]; then
    echo "ERROR: No se encontró ${IMAGES_TAR}"
    echo "  Ejecutar primero ./save-images.sh en máquina con internet"
    exit 1
fi

echo "=== Cargando imágenes de Cilium ==="
echo "  Archivo: ${IMAGES_TAR}"
echo "  Registry destino: ${REGISTRY}"
echo ""

# Cargar en podman local
echo "Cargando imágenes en podman local..."
podman load -i "${IMAGES_TAR}"

echo ""
echo "Subiendo imágenes al registry ${REGISTRY}..."

# Re-tag y push
while IFS= read -r img; do
    # Saltar comentarios y líneas vacías
    [[ "$img" =~ ^#.*$ ]] && continue
    [[ -z "$img" ]] && continue
    
    # Extraer nombre sin el registry original
    # quay.io/isovalent/cilium:v1.18.6 -> cilium:v1.18.6
    IMG_PATH=$(echo "$img" | sed 's|^[^/]*/[^/]*/||')
    
    # Nueva tag con registry local
    NEW_TAG="${REGISTRY}/${IMG_PATH}"
    
    echo "  ${img}"
    echo "    -> ${NEW_TAG}"
    
    podman tag "${img}" "${NEW_TAG}" 2>/dev/null || {
        echo "    ⚠ No se pudo taggear (quizás la imagen no se cargó)"
        continue
    }
    
    podman push "${NEW_TAG}" --tls-verify=false 2>/dev/null || {
        echo "    ⚠ Error al subir"
        continue
    }
    echo "    ✓ OK"
done < "${IMAGES_LIST}"

echo ""
echo "=== Resumen ==="
echo "Registry: ${REGISTRY}"
echo ""
echo "Para verificar:"
echo "  curl -s http://${REGISTRY}/v2/_catalog | jq"
echo ""
echo "Para usar en CiliumConfig, agregar:"
echo "  INTERNAL_REGISTRY=${REGISTRY}"
LOAD_SCRIPT

chmod +x "${ARTIFACTS_DIR}/load-images.sh"

# Archivo de versiones
cat > "${ARTIFACTS_DIR}/versions.txt" << EOF
# Versiones de artefactos descargados
# Fecha: $(date -Iseconds)

CLife (Cilium Lifecycle Operator): ${CLIFE_VERSION}
yq: ${YQ_VERSION}
jq: ${JQ_VERSION}
cilium CLI: ${CILIUM_CLI_VERSION}
hubble CLI: ${HUBBLE_VERSION}
skopeo: ${SKOPEO_VERSION}
helm: ${HELM_VERSION}

# URLs de descarga
CLife: ${CLIFE_BASE_URL}/clife-v${CLIFE_VERSION}.tar.gz
yq: https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64
jq: https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64
cilium: https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
hubble: https://github.com/cilium/hubble/releases/download/v${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz
skopeo: https://github.com/lework/skopeo-binary/releases/download/v${SKOPEO_VERSION}/skopeo-linux-amd64
helm: https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz
EOF

# -----------------------------------------------------------------------------
# Resumen
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}=== Descarga completada ===${NC}"
echo ""
echo "Artefactos descargados en: ${ARTIFACTS_DIR}"
echo ""
ls -la "${ARTIFACTS_DIR}"
echo ""
echo "Contenido:"
du -sh "${ARTIFACTS_DIR}"/* 2>/dev/null || true
echo ""
echo -e "${GREEN}=== Pasos siguientes ===${NC}"
echo ""
echo -e "${CYAN}1. Si no se descargaron las imágenes:${NC}"
echo "   cd ${ARTIFACTS_DIR}"
echo "   ./save-images.sh"
echo ""
echo -e "${CYAN}2. Crear paquete para Git/transferencia:${NC}"
echo "   cd $(dirname ${ARTIFACTS_DIR})"
echo "   tar -czvf cilium-deployment-offline.tar.gz artifacts/ clusters/ scripts/ docs/ README.md"
echo ""
echo -e "${CYAN}3. Subir a Git (sin tar.gz grandes):${NC}"
echo "   git add ."
echo "   git commit -m 'Actualizar artefactos offline'"
echo "   git push"
echo ""
echo -e "${CYAN}4. En el servidor air-gapped:${NC}"
echo "   git clone <repo> && cd <repo>"
echo "   # O extraer tar.gz"
echo ""
echo "   # Instalar herramientas"
echo "   sudo ./artifacts/install-tools.sh"
echo ""
echo "   # Iniciar registry local"
echo "   ./artifacts/start-local-registry.sh"
echo ""
echo "   # Cargar imágenes"
echo "   ./artifacts/load-images.sh localhost:5000"
echo ""
echo "   # Desplegar cluster"
echo "   export AIR_GAPPED=true"
echo "   export INTERNAL_REGISTRY=<IP>:5000"
echo "   cd scripts && ./deploy.sh <cluster-name>"
