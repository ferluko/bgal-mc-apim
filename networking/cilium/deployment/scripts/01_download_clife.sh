#!/bin/bash
# =============================================================================
# Descarga y extrae los manifiestos de CLife (Cilium Lifecycle Operator)
# Soporta modo offline usando artifacts/
# Uso: CLUSTER_NAME=paas-arqlab ./01_download_clife.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

echo "=== Preparando CLife v${CLIFE_VERSION} para ${CLUSTER_NAME} ==="

# Crear directorios
mkdir -p "${CLIFE_TMP_DIR}"
mkdir -p "${MANIFESTS_DIR}"

# Buscar CLife en orden de prioridad:
# 1. artifacts/ (modo offline)
# 2. downloads/ (descarga previa)
# 3. Descargar de internet

ARTIFACTS_DIR="${BASE_DIR}/artifacts/clife"
DOWNLOAD_DIR="${BASE_DIR}/downloads"
CLIFE_FILE="clife-v${CLIFE_VERSION}.tar.gz"

if [[ -f "${ARTIFACTS_DIR}/${CLIFE_FILE}" ]]; then
    # Modo offline - usar artifacts
    echo "✓ Usando CLife desde artifacts/ (modo offline)"
    SOURCE_DIR="${ARTIFACTS_DIR}"
elif [[ -f "${DOWNLOAD_DIR}/${CLIFE_FILE}" ]]; then
    # Ya descargado previamente
    echo "✓ Usando CLife desde downloads/"
    SOURCE_DIR="${DOWNLOAD_DIR}"
else
    # Descargar de internet
    echo "Descargando CLife desde internet..."
    mkdir -p "${DOWNLOAD_DIR}"
    cd "${DOWNLOAD_DIR}"
    
    if curl -fSL -o "${CLIFE_FILE}" "${CLIFE_URL}" 2>/dev/null; then
        curl -fSL -o "${CLIFE_FILE}.sha256" "${CLIFE_URL}.sha256" 2>/dev/null || true
        
        # Verificar checksum si existe
        if [[ -f "${CLIFE_FILE}.sha256" ]]; then
            echo "Verificando checksum..."
            if sha256sum -c "${CLIFE_FILE}.sha256"; then
                echo "✓ Checksum válido"
            else
                echo "✗ ERROR: Checksum inválido"
                rm -f "${CLIFE_FILE}"
                exit 1
            fi
        fi
        SOURCE_DIR="${DOWNLOAD_DIR}"
    else
        echo ""
        echo "ERROR: No se pudo descargar CLife y no hay copia local."
        echo ""
        echo "Para modo offline, ejecutar primero en una máquina con internet:"
        echo "  ./00_download_artifacts.sh"
        echo ""
        echo "Luego copiar la carpeta artifacts/ al servidor destino."
        exit 1
    fi
fi

# Extraer al directorio del cluster
echo "Extrayendo a ${CLIFE_TMP_DIR}..."
tar -xzf "${SOURCE_DIR}/${CLIFE_FILE}" -C "${CLIFE_TMP_DIR}" --strip-components=1

# Listar contenido
echo ""
echo "=== Contenido extraído ==="
ls -la "${CLIFE_TMP_DIR}"

echo ""
echo "✓ CLife preparado correctamente"
echo "  Siguiente paso: CLUSTER_NAME=${CLUSTER_NAME} ./02_generate_manifests.sh"
