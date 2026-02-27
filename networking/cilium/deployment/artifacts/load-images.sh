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
