#!/bin/bash
# =============================================================================
# Crea la configuración para un nuevo cluster
# Uso: ./new-cluster.sh <cluster-name> <cluster-id>
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CLUSTERS_DIR="${BASE_DIR}/clusters"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_usage() {
    echo "Uso: $0 <cluster-name> <cluster-id>"
    echo ""
    echo "Argumentos:"
    echo "  cluster-name  Nombre del cluster (ej: paas-prod)"
    echo "  cluster-id    ID único 1-255 para Cluster Mesh"
    echo ""
    echo "El script calculará automáticamente el Pod CIDR basado en el ID."
    echo ""
    echo "Plan de subredes:"
    echo "  ID 1  → 10.128.0.0/18"
    echo "  ID 2  → 10.128.64.0/18"
    echo "  ID 3  → 10.128.128.0/18"
    echo "  ..."
    echo ""
    echo "Clusters existentes:"
    for dir in "${CLUSTERS_DIR}"/*/; do
        if [[ -f "${dir}env.sh" ]]; then
            source "${dir}env.sh"
            echo "  - ${CLUSTER_NAME} (ID: ${CLUSTER_ID}, CIDR: ${POD_CIDR})"
        fi
    done 2>/dev/null || echo "  (ninguno)"
}

if [[ $# -lt 2 ]]; then
    print_usage
    exit 1
fi

CLUSTER_NAME="$1"
CLUSTER_ID="$2"

# Validar cluster ID
if ! [[ "${CLUSTER_ID}" =~ ^[0-9]+$ ]] || [[ ${CLUSTER_ID} -lt 1 ]] || [[ ${CLUSTER_ID} -gt 255 ]]; then
    echo "ERROR: cluster-id debe ser un número entre 1 y 255"
    exit 1
fi

# Verificar que no exista
if [[ -d "${CLUSTERS_DIR}/${CLUSTER_NAME}" ]]; then
    echo "ERROR: El cluster '${CLUSTER_NAME}' ya existe"
    exit 1
fi

# Calcular Pod CIDR basado en el ID
# Red base: 10.128.0.0/14, dividida en /18 (16 subredes)
# Cada /18 = 16384 IPs, offset = (ID-1) * 16384
calculate_cidr() {
    local id=$1
    local base_octet2=128
    local base_octet3=0
    
    # Cada subred /18 avanza 64 en el tercer octeto
    # Cuando llega a 192, incrementa el segundo octeto
    local subnet_index=$((id - 1))
    local octet3_offset=$((subnet_index % 4 * 64))
    local octet2_offset=$((subnet_index / 4))
    
    local octet2=$((base_octet2 + octet2_offset))
    local octet3=${octet3_offset}
    
    echo "10.${octet2}.${octet3}.0/18"
}

POD_CIDR=$(calculate_cidr ${CLUSTER_ID})

echo "=== Creando configuración para ${CLUSTER_NAME} ==="
echo "  Cluster ID: ${CLUSTER_ID}"
echo "  Pod CIDR:   ${POD_CIDR}"
echo ""

# Crear directorio
mkdir -p "${CLUSTERS_DIR}/${CLUSTER_NAME}"

# Crear env.sh con template
cat > "${CLUSTERS_DIR}/${CLUSTER_NAME}/env.sh" << EOF
#!/bin/bash
# =============================================================================
# Configuración del cluster: ${CLUSTER_NAME}
# Generado: $(date -Iseconds)
# =============================================================================

# --- Identificación del cluster ---
export CLUSTER_NAME="${CLUSTER_NAME}"
export CLUSTER_ID="${CLUSTER_ID}"                          # Único 1-255 para Cluster Mesh
export BASE_DOMAIN="bancogalicia.com.ar"

# --- Networking (ver docs/00_subnetting_plan.md) ---
export POD_CIDR="${POD_CIDR}"                # Subred ${CLUSTER_ID}/16 del /14
export HOST_PREFIX="24"                         # 256 IPs por nodo
export SERVICE_CIDR="172.30.0.0/16"
export MACHINE_CIDR="10.254.120.0/21"          # TODO: Ajustar

# --- VIPs --- TODO: Configurar
export API_VIP="10.254.124.XXX"
export INGRESS_VIP="10.254.124.XXX"

# --- vSphere --- TODO: Configurar
export VSPHERE_SERVER="vcenterocp.bancogalicia.com.ar"
export VSPHERE_DATACENTER="cpd intersite"
export VSPHERE_CLUSTER="/cpd intersite/host/ocp - lan - cluster"
export VSPHERE_DATASTORE="/cpd intersite/datastore/9500/TODO/TODO"
export VSPHERE_NETWORK="dvPG-VMNET-VLANXXX"
export VSPHERE_RESOURCE_POOL="/cpd intersite/host/ocp - lan - cluster/Resources"
export VSPHERE_USER="uoscp11m@bgcmz.bancogalicia.com.ar"

# --- Hosts (IPs estáticas) --- TODO: Configurar
export HOST_GATEWAY="10.254.XXX.254"
export HOST_NAMESERVERS="10.0.52.1,10.0.53.1"
export HOST_BOOTSTRAP_IP="10.254.XXX.10"
export HOST_MASTER_IPS="10.254.XXX.11,10.254.XXX.12,10.254.XXX.13"
export HOST_WORKER_IPS="10.254.XXX.20,10.254.XXX.21,10.254.XXX.22"

# --- Recursos de nodos ---
export MASTER_CPUS="8"
export MASTER_MEMORY_MB="32768"
export MASTER_DISK_GB="120"
export WORKER_CPUS="8"
export WORKER_MEMORY_MB="32768"
export WORKER_DISK_GB="120"
EOF

chmod +x "${CLUSTERS_DIR}/${CLUSTER_NAME}/env.sh"

echo -e "${GREEN}✓ Configuración creada en:${NC}"
echo "  ${CLUSTERS_DIR}/${CLUSTER_NAME}/env.sh"
echo ""
echo -e "${YELLOW}IMPORTANTE: Editar env.sh para completar:${NC}"
echo "  - VIPs (API_VIP, INGRESS_VIP)"
echo "  - vSphere (VSPHERE_DATASTORE, VSPHERE_NETWORK)"
echo "  - Hosts (HOST_GATEWAY, HOST_*_IPS)"
echo ""
echo "Luego ejecutar:"
echo "  ./deploy.sh ${CLUSTER_NAME}"
