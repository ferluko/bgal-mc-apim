#!/bin/bash
# =============================================================================
# Debug de instalación de Cilium durante bootstrap
# 
# Este script ayuda a diagnosticar problemas durante la instalación de
# OpenShift con Cilium via RHACM/Hive
#
# Uso:
#   CLUSTER_NAME=paas-arqlab ./debug_bootstrap.sh
#   CLUSTER_NAME=paas-arqlab ./debug_bootstrap.sh --ssh  # Conectar via SSH al bootstrap
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar configuración si existe
if [[ -f "${SCRIPT_DIR}/00_env.sh" ]] && [[ -n "${CLUSTER_NAME:-}" ]]; then
    source "${SCRIPT_DIR}/00_env.sh" 2>/dev/null || true
fi

CLUSTER_NAME="${CLUSTER_NAME:-}"
SSH_MODE="${1:-}"

if [[ -z "${CLUSTER_NAME}" ]]; then
    echo "ERROR: CLUSTER_NAME no definido"
    echo "Uso: CLUSTER_NAME=mi-cluster ./debug_bootstrap.sh"
    exit 1
fi

echo "============================================="
echo "  DEBUG: Instalación de ${CLUSTER_NAME}"
echo "============================================="
echo ""

# -----------------------------------------------------------------------------
# 1. Estado en RHACM/Hive (Hub cluster)
# -----------------------------------------------------------------------------
echo "=== 1. Estado en RHACM Hub ==="
echo ""

echo "ClusterDeployment:"
kubectl get clusterdeployment -n ${CLUSTER_NAME} 2>/dev/null || echo "  No encontrado"
echo ""

echo "Pods de instalación:"
kubectl get pods -n ${CLUSTER_NAME} 2>/dev/null || echo "  No encontrados"
echo ""

echo "Condiciones del ClusterDeployment:"
kubectl get clusterdeployment ${CLUSTER_NAME} -n ${CLUSTER_NAME} -o jsonpath='{range .status.conditions[*]}{.type}: {.status} - {.message}{"\n"}{end}' 2>/dev/null || echo "  No disponible"
echo ""

# -----------------------------------------------------------------------------
# 2. Logs de provisión
# -----------------------------------------------------------------------------
echo "=== 2. Últimos logs del job de provisión ==="
echo ""

PROVISION_POD=$(kubectl get pods -n ${CLUSTER_NAME} -l hive.openshift.io/cluster-deployment-name=${CLUSTER_NAME} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "${PROVISION_POD}" ]]; then
    echo "Pod: ${PROVISION_POD}"
    kubectl logs -n ${CLUSTER_NAME} ${PROVISION_POD} --tail=50 2>/dev/null | grep -E "(error|Error|ERROR|cilium|clife|network|CNI)" || echo "  Sin errores relevantes en las últimas 50 líneas"
else
    echo "  No hay pod de provisión activo"
fi
echo ""

# -----------------------------------------------------------------------------
# 3. ConfigMap de manifiestos (verificar que CLife está incluido)
# -----------------------------------------------------------------------------
echo "=== 3. ConfigMap de manifiestos CLife ==="
echo ""

CM_NAME="${CLUSTER_NAME}-clife-manifests"
if kubectl get configmap ${CM_NAME} -n ${CLUSTER_NAME} &>/dev/null; then
    echo "ConfigMap: ${CM_NAME} ✓ existe"
    echo ""
    echo "Claves (manifiestos incluidos):"
    kubectl get configmap ${CM_NAME} -n ${CLUSTER_NAME} -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null | while read key; do
        echo "  - $key"
    done
    
    # Verificar que el Deployment de CLife está incluido
    echo ""
    echo "Verificando Deployment de CLife:"
    DEPLOY_KEY="apps_v1_deployment_clife-controller-manager.yaml"
    if kubectl get configmap ${CM_NAME} -n ${CLUSTER_NAME} -o jsonpath="{.data.${DEPLOY_KEY}}" 2>/dev/null | grep -q "hostNetwork: true"; then
        echo "  ✓ Deployment incluido con hostNetwork: true"
    else
        echo "  ✗ ERROR: Deployment no encontrado o sin hostNetwork"
    fi
else
    echo "  ✗ ConfigMap ${CM_NAME} no encontrado"
fi
echo ""

# -----------------------------------------------------------------------------
# 4. Instrucciones para debug en el nodo
# -----------------------------------------------------------------------------
echo "============================================="
echo "  VERIFICAR EN EL CLUSTER DESTINO"
echo "============================================="
echo ""
echo "Una vez que el cluster tenga API disponible, ejecutar:"
echo ""
echo "  # Obtener kubeconfig del cluster"
echo "  oc extract secret/${CLUSTER_NAME}-admin-kubeconfig -n ${CLUSTER_NAME} --to=- > /tmp/${CLUSTER_NAME}.kubeconfig"
echo ""
echo "  # Verificar CLife Deployment"
echo "  KUBECONFIG=/tmp/${CLUSTER_NAME}.kubeconfig kubectl get deployment -n cilium"
echo "  KUBECONFIG=/tmp/${CLUSTER_NAME}.kubeconfig kubectl get pods -n cilium"
echo ""
echo "  # Ver logs del operador CLife"
echo "  KUBECONFIG=/tmp/${CLUSTER_NAME}.kubeconfig kubectl logs -n cilium -l app.kubernetes.io/name=clife"
echo ""
echo "  # Ver estado de CiliumConfig"
echo "  KUBECONFIG=/tmp/${CLUSTER_NAME}.kubeconfig kubectl get ciliumconfig -n cilium -o yaml"
echo ""

# -----------------------------------------------------------------------------
# 5. Debug en nodo bootstrap (si se solicita)
# -----------------------------------------------------------------------------
if [[ "${SSH_MODE}" == "--ssh" ]]; then
    echo "============================================="
    echo "  DEBUG VIA SSH (Bootstrap/Master node)"
    echo "============================================="
    echo ""
    
    BOOTSTRAP_IP="${HOST_BOOTSTRAP_IP:-}"
    if [[ -z "${BOOTSTRAP_IP}" ]]; then
        echo "HOST_BOOTSTRAP_IP no definido. Especificar manualmente:"
        echo ""
        echo "  ssh core@<IP-BOOTSTRAP> 'sudo crictl ps | grep clife'"
        echo "  ssh core@<IP-BOOTSTRAP> 'sudo crictl logs \$(sudo crictl ps -q --name clife)'"
        echo ""
        echo "Para ver todos los contenedores de red:"
        echo "  ssh core@<IP-BOOTSTRAP> 'sudo crictl ps | grep -E \"cilium|clife|network\"'"
    else
        echo "Conectando a bootstrap ${BOOTSTRAP_IP}..."
        echo ""
        
        echo "=== Contenedores relacionados con Cilium/CLife ==="
        ssh -o StrictHostKeyChecking=no core@${BOOTSTRAP_IP} 'sudo crictl ps 2>/dev/null | grep -E "cilium|clife" || echo "No hay contenedores cilium/clife corriendo"' 2>/dev/null || echo "No se pudo conectar"
        
        echo ""
        echo "=== Pods en namespace cilium ==="
        ssh -o StrictHostKeyChecking=no core@${BOOTSTRAP_IP} 'sudo crictl pods 2>/dev/null | grep cilium || echo "No hay pods en namespace cilium"' 2>/dev/null || echo "No se pudo conectar"
        
        echo ""
        echo "=== Logs de CLife (si existe) ==="
        ssh -o StrictHostKeyChecking=no core@${BOOTSTRAP_IP} 'CLIFE_CONTAINER=$(sudo crictl ps -q --name clife 2>/dev/null); if [ -n "$CLIFE_CONTAINER" ]; then sudo crictl logs --tail=20 $CLIFE_CONTAINER; else echo "Contenedor clife no encontrado"; fi' 2>/dev/null || echo "No se pudo conectar"
    fi
fi

echo ""
echo "============================================="
echo "  COMANDOS ÚTILES ADICIONALES"
echo "============================================="
echo ""
echo "# Ver eventos de Hive:"
echo "  kubectl get events -n ${CLUSTER_NAME} --sort-by='.lastTimestamp'"
echo ""
echo "# Ver install-config usado:"
echo "  kubectl get secret ${CLUSTER_NAME}-install-config -n ${CLUSTER_NAME} -o jsonpath='{.data.install-config\\.yaml}' | base64 -d"
echo ""
echo "# Forzar re-provisión (CUIDADO - elimina y recrea):"
echo "  kubectl delete clusterdeployment ${CLUSTER_NAME} -n ${CLUSTER_NAME}"
echo "  kubectl apply -f clusters/${CLUSTER_NAME}/manifests/clusterdeployment.yaml"
echo ""
echo "# Conectar al nodo bootstrap/master vía SSH:"
echo "  ssh core@<IP-NODO>"
echo ""
echo "# En el nodo, verificar manifiestos aplicados:"
echo "  ls -la /etc/kubernetes/manifests/"
echo "  sudo crictl ps"
echo "  journalctl -u kubelet -f"
