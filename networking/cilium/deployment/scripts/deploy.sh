#!/bin/bash
# =============================================================================
# Script principal para desplegar un cluster con Cilium
# Uso: ./deploy.sh <cluster-name> [--dry-run]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}=============================================${NC}"
}

print_usage() {
    echo "Uso: $0 <cluster-name> [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --dry-run     Solo genera manifiestos, no aplica en ACM"
    echo "  --skip-download  No descarga CLife (usar si ya está descargado)"
    echo "  --help        Muestra esta ayuda"
    echo ""
    echo "Clusters disponibles:"
    ls -1 "${SCRIPT_DIR}/../clusters/" 2>/dev/null | sed 's/^/  - /'
    echo ""
    echo "Ejemplos:"
    echo "  $0 paas-arqlab"
    echo "  $0 paas-srepg --dry-run"
}

# Parsear argumentos
CLUSTER_NAME=""
DRY_RUN="false"
SKIP_DOWNLOAD="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --skip-download)
            SKIP_DOWNLOAD="true"
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        -*)
            echo "Opción desconocida: $1"
            print_usage
            exit 1
            ;;
        *)
            if [[ -z "${CLUSTER_NAME}" ]]; then
                CLUSTER_NAME="$1"
            else
                echo "ERROR: Solo se puede especificar un cluster"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "${CLUSTER_NAME}" ]]; then
    echo "ERROR: Debe especificar un cluster"
    echo ""
    print_usage
    exit 1
fi

export CLUSTER_NAME
export DRY_RUN

print_header "Desplegando cluster: ${CLUSTER_NAME}"

# Paso 1: Descargar CLife
if [[ "${SKIP_DOWNLOAD}" != "true" ]]; then
    print_header "Paso 1/4: Descargando CLife"
    "${SCRIPT_DIR}/01_download_clife.sh"
else
    echo -e "${YELLOW}Saltando descarga de CLife${NC}"
fi

# Paso 2: Generar manifiestos
print_header "Paso 2/4: Generando manifiestos"
"${SCRIPT_DIR}/02_generate_manifests.sh"

# Paso 3: Crear recursos en ACM
print_header "Paso 3/4: Creando recursos en ACM"
"${SCRIPT_DIR}/03_create_acm_resources.sh"

# Paso 4: Instrucciones finales
print_header "Paso 4/4: Próximos pasos"

CLUSTER_DIR="${SCRIPT_DIR}/../clusters/${CLUSTER_NAME}"

echo ""
if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}MODO DRY-RUN: No se aplicaron cambios en ACM${NC}"
    echo ""
fi

echo "Manifiestos generados en:"
echo "  ${CLUSTER_DIR}/manifests/"
echo "  ${CLUSTER_DIR}/clife-tmp/"
echo ""
echo "Para completar el despliegue:"
echo ""
echo "  1. Verificar/crear secrets faltantes en ACM:"
echo "     - ${CLUSTER_NAME}-pull-secret"
echo "     - ${CLUSTER_NAME}-vsphere-creds"
echo "     - ${CLUSTER_NAME}-vsphere-certs (si aplica)"
echo ""
echo "  2. Aplicar ClusterDeployment:"
echo "     kubectl apply -f ${CLUSTER_DIR}/manifests/clusterdeployment.yaml"
echo ""
echo "  3. Monitorear instalación:"
echo "     CLUSTER_NAME=${CLUSTER_NAME} ./04_verify_install.sh"
echo ""
echo "  4. Ejecutar tests de conectividad:"
echo "     CLUSTER_NAME=${CLUSTER_NAME} ./05_connectivity_test.sh"
echo ""
echo -e "${GREEN}✓ Preparación completada para ${CLUSTER_NAME}${NC}"
