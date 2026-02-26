#!/bin/bash
# =============================================================================
# Ejecuta tests de conectividad de Cilium en OpenShift
# Uso: CLUSTER_NAME=paas-arqlab ./05_connectivity_test.sh
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

echo "=== Test de Conectividad Cilium: ${CLUSTER_NAME} ==="
echo ""

# Verificar conexión
if ! oc whoami &>/dev/null; then
    echo "ERROR: No hay sesión activa de oc."
    echo "Ejecutar: oc login https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443"
    exit 1
fi

CILIUM_NS="cilium"
if ! oc get ns ${CILIUM_NS} &>/dev/null; then
    CILIUM_NS="openshift-cilium"
fi

# -----------------------------------------------------------------------------
# 1. Crear SecurityContextConstraints para tests
# -----------------------------------------------------------------------------
echo "--- Preparando entorno de test ---"

cat << 'EOF' | oc apply -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: cilium-test
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: true
allowHostPID: false
allowHostPorts: true
allowPrivilegeEscalation: false
allowPrivilegedContainer: false
allowedCapabilities: null
defaultAddCapabilities: null
fsGroup:
  type: MustRunAs
groups: []
priority: null
readOnlyRootFilesystem: false
requiredDropCapabilities:
- KILL
- MKNOD
- SETUID
- SETGID
runAsUser:
  type: MustRunAsRange
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
users: []
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
EOF

print_status ok "SecurityContextConstraints 'cilium-test' creado"

# Crear namespace de test
TEST_NS="cilium-test-1"
oc create ns ${TEST_NS} --dry-run=client -o yaml | oc apply -f -
oc adm policy add-scc-to-group cilium-test system:serviceaccounts:${TEST_NS}

print_status ok "Namespace '${TEST_NS}' preparado"

echo ""

# -----------------------------------------------------------------------------
# 2. Ejecutar connectivity test
# -----------------------------------------------------------------------------
echo "--- Ejecutando Cilium Connectivity Test ---"
echo ""

# Verificar si cilium CLI está disponible
if command -v cilium &>/dev/null; then
    echo "Usando cilium CLI local..."
    cilium connectivity test --test-namespace=${TEST_NS} --multi-cluster=false
    TEST_EXIT_CODE=$?
else
    echo "cilium CLI no disponible localmente."
    echo "Ejecutando desde pod de Cilium..."
    
    # Obtener un pod de cilium
    CILIUM_POD=$(oc -n ${CILIUM_NS} get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -n "${CILIUM_POD}" ]]; then
        print_status info "Usando pod: ${CILIUM_POD}"
        oc -n ${CILIUM_NS} exec -it ${CILIUM_POD} -- cilium connectivity test --test-namespace=${TEST_NS} --multi-cluster=false
        TEST_EXIT_CODE=$?
    else
        print_status fail "No se encontró pod de Cilium para ejecutar tests"
        TEST_EXIT_CODE=1
    fi
fi

echo ""

# -----------------------------------------------------------------------------
# 3. Tests básicos adicionales
# -----------------------------------------------------------------------------
echo "--- Tests básicos de red ---"

# Test DNS
echo "Testing DNS resolution..."
oc run dns-test --rm -i --restart=Never --image=busybox:1.36 -- nslookup kubernetes.default.svc.cluster.local
if [[ $? -eq 0 ]]; then
    print_status ok "DNS resolution funciona"
else
    print_status fail "DNS resolution falló"
fi

# Test conectividad entre pods
echo ""
echo "Testing pod-to-pod connectivity..."
oc -n ${TEST_NS} run test-server --image=nginx:alpine --restart=Never --dry-run=client -o yaml | oc apply -f -
sleep 5
SERVER_IP=$(oc -n ${TEST_NS} get pod test-server -o jsonpath='{.status.podIP}' 2>/dev/null)

if [[ -n "${SERVER_IP}" ]]; then
    oc -n ${TEST_NS} run test-client --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- --timeout=5 http://${SERVER_IP}:80
    if [[ $? -eq 0 ]]; then
        print_status ok "Pod-to-pod connectivity funciona"
    else
        print_status fail "Pod-to-pod connectivity falló"
    fi
else
    print_status warn "No se pudo obtener IP del pod de test"
fi

# Cleanup test server
oc -n ${TEST_NS} delete pod test-server --ignore-not-found=true

echo ""

# -----------------------------------------------------------------------------
# 4. Verificar Hubble (si está habilitado)
# -----------------------------------------------------------------------------
echo "--- Verificando Hubble ---"

HUBBLE_PODS=$(oc get pods -n ${CILIUM_NS} -l k8s-app=hubble-relay --no-headers 2>/dev/null | wc -l)
if [[ ${HUBBLE_PODS} -gt 0 ]]; then
    print_status ok "Hubble relay está desplegado"
    
    if command -v hubble &>/dev/null; then
        hubble status 2>/dev/null || print_status warn "hubble status no disponible"
    else
        print_status info "hubble CLI no instalado localmente"
    fi
else
    print_status info "Hubble relay no desplegado (opcional)"
fi

echo ""

# -----------------------------------------------------------------------------
# 5. Cleanup
# -----------------------------------------------------------------------------
echo "--- Limpieza ---"

read -p "¿Eliminar recursos de test? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    oc delete ns ${TEST_NS} --ignore-not-found=true
    oc delete scc cilium-test --ignore-not-found=true
    print_status ok "Recursos de test eliminados"
else
    print_status info "Recursos de test conservados en namespace '${TEST_NS}'"
fi

echo ""

# -----------------------------------------------------------------------------
# 6. Resumen
# -----------------------------------------------------------------------------
echo "=== Resumen de Tests ==="
if [[ ${TEST_EXIT_CODE:-0} -eq 0 ]]; then
    print_status ok "Connectivity tests PASSED"
else
    print_status fail "Connectivity tests FAILED (exit code: ${TEST_EXIT_CODE})"
fi

echo ""
echo "Para más detalles, revisar:"
echo "  - Logs de Cilium: oc -n ${CILIUM_NS} logs -l k8s-app=cilium"
echo "  - Hubble observe: hubble observe --namespace ${TEST_NS}"
