#!/bin/bash
# =============================================================================
# Verifica la instalación del cluster con Cilium
# Uso: CLUSTER_NAME=paas-arqlab ./04_verify_install.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    case $status in
        ok)   echo -e "${GREEN}✓${NC} ${message}" ;;
        fail) echo -e "${RED}✗${NC} ${message}" ;;
        warn) echo -e "${YELLOW}!${NC} ${message}" ;;
        info) echo -e "  ${message}" ;;
    esac
}

echo "=== Verificación de instalación: ${CLUSTER_NAME} ==="
echo ""

# -----------------------------------------------------------------------------
# 1. Verificar ClusterDeployment en ACM
# -----------------------------------------------------------------------------
echo "--- Estado en ACM Hub ---"

if oc whoami &>/dev/null; then
    CD_STATUS=$(oc -n ${ACM_NAMESPACE} get clusterdeployment ${CLUSTER_NAME} -o jsonpath='{.status.conditions[?(@.type=="Provisioned")].status}' 2>/dev/null || echo "NotFound")
    
    if [[ "${CD_STATUS}" == "True" ]]; then
        print_status ok "ClusterDeployment: Provisioned"
    elif [[ "${CD_STATUS}" == "NotFound" ]]; then
        print_status fail "ClusterDeployment: No encontrado"
        echo ""
        echo "El ClusterDeployment no existe. Verificar:"
        echo "  kubectl -n ${ACM_NAMESPACE} get clusterdeployment"
        exit 1
    else
        print_status warn "ClusterDeployment: En progreso o con errores"
        echo ""
        echo "Ver detalles:"
        oc -n ${ACM_NAMESPACE} get clusterdeployment ${CLUSTER_NAME} -o yaml | grep -A 20 "status:"
    fi
else
    print_status warn "No hay sesión en el hub ACM"
fi

echo ""

# -----------------------------------------------------------------------------
# 2. Intentar conectar al cluster desplegado
# -----------------------------------------------------------------------------
echo "--- Conectando al cluster ${CLUSTER_NAME} ---"

API_URL="https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443"

# Obtener kubeconfig del cluster (si está disponible en ACM)
KUBECONFIG_SECRET="${CLUSTER_NAME}-admin-kubeconfig"
if oc -n ${ACM_NAMESPACE} get secret ${KUBECONFIG_SECRET} &>/dev/null; then
    print_status ok "Secret de kubeconfig encontrado"
    
    # Extraer kubeconfig temporal
    TEMP_KUBECONFIG="/tmp/${CLUSTER_NAME}-kubeconfig"
    oc -n ${ACM_NAMESPACE} get secret ${KUBECONFIG_SECRET} -o jsonpath='{.data.kubeconfig}' | base64 -d > "${TEMP_KUBECONFIG}"
    export KUBECONFIG="${TEMP_KUBECONFIG}"
    
    if oc whoami &>/dev/null; then
        print_status ok "Conexión al cluster exitosa"
    else
        print_status fail "No se pudo conectar al cluster"
        exit 1
    fi
else
    print_status warn "Kubeconfig no disponible aún en ACM"
    echo "  Intentar login manual: oc login ${API_URL}"
    
    # Preguntar si continuar con login manual
    read -p "¿Tiene acceso manual al cluster? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Abortando verificación. Reintentar cuando el cluster esté disponible."
        exit 0
    fi
fi

echo ""

# -----------------------------------------------------------------------------
# 3. Verificar Network Config
# -----------------------------------------------------------------------------
echo "--- Configuración de Red ---"

NETWORK_TYPE=$(oc get network cluster -o jsonpath='{.spec.networkType}' 2>/dev/null || echo "Unknown")
if [[ "${NETWORK_TYPE}" == "Cilium" ]]; then
    print_status ok "networkType: Cilium"
else
    print_status fail "networkType: ${NETWORK_TYPE} (esperado: Cilium)"
fi

CLUSTER_CIDR=$(oc get network cluster -o jsonpath='{.spec.clusterNetwork[0].cidr}' 2>/dev/null || echo "Unknown")
print_status info "clusterNetwork CIDR: ${CLUSTER_CIDR}"

if [[ "${CLUSTER_CIDR}" == "${POD_CIDR}" ]]; then
    print_status ok "Pod CIDR coincide con configuración"
else
    print_status warn "Pod CIDR diferente al esperado (${POD_CIDR})"
fi

echo ""

# -----------------------------------------------------------------------------
# 4. Verificar pods de Cilium
# -----------------------------------------------------------------------------
echo "--- Pods de Cilium ---"

CILIUM_NS="cilium"
if ! oc get ns ${CILIUM_NS} &>/dev/null; then
    CILIUM_NS="openshift-cilium"
fi

CILIUM_PODS=$(oc get pods -n ${CILIUM_NS} --no-headers 2>/dev/null | wc -l)
CILIUM_RUNNING=$(oc get pods -n ${CILIUM_NS} --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [[ ${CILIUM_PODS} -gt 0 ]]; then
    print_status ok "Pods de Cilium encontrados: ${CILIUM_RUNNING}/${CILIUM_PODS} Running"
    oc get pods -n ${CILIUM_NS} --no-headers 2>/dev/null | head -10
else
    print_status fail "No se encontraron pods de Cilium"
fi

echo ""

# -----------------------------------------------------------------------------
# 5. Verificar CiliumConfig
# -----------------------------------------------------------------------------
echo "--- CiliumConfig ---"

if oc get ciliumconfig ciliumconfig -n ${CILIUM_NS} &>/dev/null; then
    print_status ok "CiliumConfig encontrado"
    
    CONFIG_CLUSTER_NAME=$(oc get ciliumconfig ciliumconfig -n ${CILIUM_NS} -o jsonpath='{.spec.cluster.name}' 2>/dev/null)
    CONFIG_CLUSTER_ID=$(oc get ciliumconfig ciliumconfig -n ${CILIUM_NS} -o jsonpath='{.spec.cluster.id}' 2>/dev/null)
    CONFIG_POD_CIDR=$(oc get ciliumconfig ciliumconfig -n ${CILIUM_NS} -o jsonpath='{.spec.ipam.operator.clusterPoolIPv4PodCIDRList[0]}' 2>/dev/null)
    
    print_status info "cluster.name: ${CONFIG_CLUSTER_NAME}"
    print_status info "cluster.id: ${CONFIG_CLUSTER_ID}"
    print_status info "Pod CIDR: ${CONFIG_POD_CIDR}"
    
    if [[ "${CONFIG_CLUSTER_NAME}" == "${CLUSTER_NAME}" ]]; then
        print_status ok "cluster.name coincide"
    else
        print_status warn "cluster.name no coincide (esperado: ${CLUSTER_NAME})"
    fi
else
    print_status warn "CiliumConfig no encontrado"
fi

echo ""

# -----------------------------------------------------------------------------
# 6. Cilium status (si está disponible el CLI)
# -----------------------------------------------------------------------------
echo "--- Cilium Status ---"

if command -v cilium &>/dev/null; then
    cilium status --wait=false 2>/dev/null || print_status warn "cilium status no disponible"
else
    print_status info "CLI de cilium no instalado localmente"
    echo "  Ejecutar desde un pod de cilium:"
    echo "  oc -n ${CILIUM_NS} exec -it ds/cilium -- cilium status"
fi

echo ""

# -----------------------------------------------------------------------------
# 7. Resumen
# -----------------------------------------------------------------------------
echo "=== Resumen ==="
echo ""
echo "Cluster:     ${CLUSTER_NAME}"
echo "API URL:     ${API_URL}"
echo "Pod CIDR:    ${POD_CIDR}"
echo "Cluster ID:  ${CLUSTER_ID}"
echo ""

# Limpiar kubeconfig temporal
if [[ -f "/tmp/${CLUSTER_NAME}-kubeconfig" ]]; then
    rm -f "/tmp/${CLUSTER_NAME}-kubeconfig"
fi

echo "✓ Verificación completada"
echo ""
echo "Próximos pasos:"
echo "  - Ejecutar test de conectividad: ./05_connectivity_test.sh"
