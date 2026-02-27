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
