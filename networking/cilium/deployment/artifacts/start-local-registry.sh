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
