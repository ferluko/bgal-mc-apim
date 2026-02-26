#!/bin/bash
# =============================================================================
# Configuración global y carga de configuración por cluster
# =============================================================================

# --- Verificar que se especificó un cluster ---
if [[ -z "${CLUSTER_NAME:-}" ]]; then
    echo "ERROR: Debe especificar CLUSTER_NAME"
    echo ""
    echo "Uso:"
    echo "  export CLUSTER_NAME=paas-arqlab && ./script.sh"
    echo "  o"
    echo "  CLUSTER_NAME=paas-arqlab ./script.sh"
    echo ""
    echo "Clusters disponibles:"
    ls -1 "$(dirname "${BASH_SOURCE[0]}")/../clusters/" 2>/dev/null || echo "  (ninguno)"
    exit 1
fi

# --- Paths base ---
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BASE_DIR="$(dirname "$SCRIPT_DIR")"
export CLUSTERS_DIR="${BASE_DIR}/clusters"
export CLUSTER_DIR="${CLUSTERS_DIR}/${CLUSTER_NAME}"

# --- Verificar que existe el cluster ---
if [[ ! -d "${CLUSTER_DIR}" ]]; then
    echo "ERROR: Cluster '${CLUSTER_NAME}' no encontrado en ${CLUSTERS_DIR}"
    echo ""
    echo "Clusters disponibles:"
    ls -1 "${CLUSTERS_DIR}" 2>/dev/null || echo "  (ninguno)"
    exit 1
fi

# --- Cargar configuración del cluster ---
if [[ -f "${CLUSTER_DIR}/env.sh" ]]; then
    source "${CLUSTER_DIR}/env.sh"
else
    echo "ERROR: No se encontró ${CLUSTER_DIR}/env.sh"
    exit 1
fi

# --- Paths específicos del cluster ---
export MANIFESTS_DIR="${CLUSTER_DIR}/manifests"
export CLIFE_TMP_DIR="${CLUSTER_DIR}/clife-tmp"

# --- Configuración global (compartida) ---
export BASE_DOMAIN="${BASE_DOMAIN:-bancogalicia.com.ar}"

# --- CLife ---
export CLIFE_VERSION="1.18.6"
export CLIFE_URL="https://docs.isovalent.com/v25.11/public/clife/clife-v${CLIFE_VERSION}.tar.gz"

# --- ACM ---
export ACM_NAMESPACE="${CLUSTER_NAME}"
export ACM_IMAGE_SET="${ACM_IMAGE_SET:-img4.18.21-x86-64-appsub}"

# --- SSH Key (path a las claves) ---
export SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE:-${HOME}/.ssh/id_rsa.pub}"
export SSH_PRIVATE_KEY_FILE="${SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/id_rsa}"

# --- Opciones ---
export ENABLE_KPR="${ENABLE_KPR:-true}"
export DRY_RUN="${DRY_RUN:-false}"

# --- Mostrar configuración cargada ---
echo "=== Configuración cargada ==="
echo "  Cluster:     ${CLUSTER_NAME}"
echo "  Cluster ID:  ${CLUSTER_ID}"
echo "  Pod CIDR:    ${POD_CIDR}"
echo "  API VIP:     ${API_VIP}"
echo "  Ingress VIP: ${INGRESS_VIP}"
echo "  Directorio:  ${CLUSTER_DIR}"
echo ""
