#!/bin/bash
#
# measure-hops.sh - Analiza saltos de red y rutas en el datapath
#
# Compara el número de hops entre Cilium KPR y OVN-Kubernetes
#
# Uso:
#   ./measure-hops.sh [-n namespace]
#

set -euo pipefail

NAMESPACE="${1:-network-perf-test}"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Detectar CLI
if command -v oc &> /dev/null; then
    OC="oc"
else
    OC="kubectl"
fi

# Detectar CNI
CNI_TYPE=$($OC get network cluster -o jsonpath='{.spec.networkType}' 2>/dev/null || echo "Unknown")

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    ANÁLISIS DE SALTOS DE RED (HOPS)                          ║"
echo "╠══════════════════════════════════════════════════════════════════════════════╣"
echo "║  CNI: $(printf '%-70s' "$CNI_TYPE")║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Crear pod de debug
log_info "Creando pod de debug..."
$OC run debug-hops --image=nicolaka/netshoot --restart=Never -n "$NAMESPACE" --command -- sleep 600 2>/dev/null || true
$OC wait --for=condition=ready pod/debug-hops -n "$NAMESPACE" --timeout=60s

# Obtener información de pods target
log_info "Obteniendo información de pods target..."
echo ""

PODS_INFO=$($OC get pods -n "$NAMESPACE" -l app=perf-target -o jsonpath='{range .items[*]}{.metadata.name} {.status.podIP} {.spec.nodeName}{"\n"}{end}')

echo "┌────────────────────────────────────────────────────────────────────────────┐"
echo "│                           PODS TARGET                                      │"
echo "├────────────────────────────────────────────────────────────────────────────┤"
printf "│ %-25s %-20s %-25s │\n" "POD" "IP" "NODO"
echo "├────────────────────────────────────────────────────────────────────────────┤"

while read -r pod_name pod_ip node_name; do
    if [ -n "$pod_name" ]; then
        printf "│ %-25s %-20s %-25s │\n" "$pod_name" "$pod_ip" "$node_name"
    fi
done <<< "$PODS_INFO"
echo "└────────────────────────────────────────────────────────────────────────────┘"
echo ""

# Obtener Service ClusterIP
SERVICE_IP=$($OC get svc perf-target-clusterip -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
log_info "Service ClusterIP: $SERVICE_IP"
echo ""

# Traceroute a cada pod
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                          TRACEROUTE A PODS                                    "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

while read -r pod_name pod_ip node_name; do
    if [ -n "$pod_ip" ]; then
        echo "--- Traceroute a $pod_name ($pod_ip) en $node_name ---"
        $OC exec -n "$NAMESPACE" debug-hops -- traceroute -n -m 10 -w 2 "$pod_ip" 2>/dev/null || echo "traceroute falló"
        
        # Contar hops
        HOPS=$($OC exec -n "$NAMESPACE" debug-hops -- traceroute -n -m 10 -w 2 "$pod_ip" 2>/dev/null | grep -c "^[[:space:]]*[0-9]" || echo "0")
        echo -e "${GREEN}Hops: $HOPS${NC}"
        echo ""
    fi
done <<< "$PODS_INFO"

# Traceroute al Service
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                      TRACEROUTE A SERVICE CLUSTERIP                           "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "--- Traceroute a Service ClusterIP ($SERVICE_IP) ---"
$OC exec -n "$NAMESPACE" debug-hops -- traceroute -n -m 10 -w 2 "$SERVICE_IP" 2>/dev/null || echo "traceroute falló"
echo ""

# Análisis específico de Cilium
if [ "$CNI_TYPE" == "Cilium" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                         ANÁLISIS CILIUM BPF                                   "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    CILIUM_POD=$($OC get pods -n openshift-cilium -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
    
    echo "--- Cilium BPF Policy ---"
    $OC exec -n openshift-cilium "$CILIUM_POD" -- cilium bpf policy get 2>/dev/null | head -30 || echo "No disponible"
    echo ""
    
    echo "--- Cilium Endpoint List ---"
    $OC exec -n openshift-cilium "$CILIUM_POD" -- cilium endpoint list 2>/dev/null | head -20 || echo "No disponible"
    echo ""
    
    echo "--- Cilium Service List ---"
    $OC exec -n openshift-cilium "$CILIUM_POD" -- cilium service list 2>/dev/null | grep -E "perf-target|ClusterIP" | head -10 || echo "No disponible"
    echo ""
fi

# Análisis de OVN
if [ "$CNI_TYPE" == "OVNKubernetes" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                           ANÁLISIS OVN                                        "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    OVN_POD=$($OC get pods -n openshift-ovn-kubernetes -l app=ovnkube-node -o jsonpath='{.items[0].metadata.name}')
    
    echo "--- OVN Logical Flows (Service related) ---"
    $OC exec -n openshift-ovn-kubernetes "$OVN_POD" -c ovnkube-controller -- ovn-sbctl lflow-list 2>/dev/null | grep -i "load_balancer" | head -20 || echo "No disponible"
    echo ""
fi

# Resumen
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                              RESUMEN                                          "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "CNI Type: $CNI_TYPE"
echo ""

if [ "$CNI_TYPE" == "Cilium" ]; then
    echo "Cilium con KPR típicamente tiene:"
    echo "  - 1 hop para pod-to-pod en mismo nodo (directo vía eBPF)"
    echo "  - 1-2 hops para pod-to-pod en diferente nodo"
    echo "  - 1 hop para pod-to-service (load balancing en eBPF, sin kube-proxy)"
    echo ""
    echo "Ventajas de KPR:"
    echo "  - Elimina iptables/IPVS de kube-proxy"
    echo "  - Load balancing directo en eBPF"
    echo "  - Menor latencia en acceso a Services"
else
    echo "OVN-Kubernetes típicamente tiene:"
    echo "  - 1-2 hops para pod-to-pod en mismo nodo"
    echo "  - 2-3 hops para pod-to-pod en diferente nodo"
    echo "  - 2+ hops para pod-to-service (pasa por OVN logical router + kube-proxy)"
    echo ""
    echo "Características:"
    echo "  - Usa OVS (Open vSwitch) para switching"
    echo "  - kube-proxy maneja Services (iptables/IPVS)"
    echo "  - Más saltos en el datapath"
fi

echo ""

# Limpiar
log_info "Limpiando pod de debug..."
$OC delete pod debug-hops -n "$NAMESPACE" --ignore-not-found=true &>/dev/null

echo "Análisis completado."
