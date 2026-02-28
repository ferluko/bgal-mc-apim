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
        echo "--- Conectividad a $pod_name ($pod_ip) en $node_name ---"
        
        # Usar ping como alternativa (más confiable con eBPF)
        echo "Ping test:"
        $OC exec -n "$NAMESPACE" debug-hops -- ping -c 3 -W 2 "$pod_ip" 2>/dev/null || echo "ping falló"
        
        # Intentar traceroute con TCP en lugar de ICMP
        echo ""
        echo "Traceroute TCP (puerto 8080):"
        $OC exec -n "$NAMESPACE" debug-hops -- traceroute -T -p 8080 -n -m 10 -w 2 "$pod_ip" 2>/dev/null || \
        $OC exec -n "$NAMESPACE" debug-hops -- tracepath -n "$pod_ip" 2>/dev/null || \
        echo "traceroute/tracepath no disponible o bloqueado por eBPF"
        
        # HTTP check para verificar conectividad real
        echo ""
        echo "HTTP check:"
        $OC exec -n "$NAMESPACE" debug-hops -- curl -s -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" "http://${pod_ip}:8080/" 2>/dev/null || echo "curl falló"
        echo ""
    fi
done <<< "$PODS_INFO"

# Traceroute al Service
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                      CONECTIVIDAD A SERVICE CLUSTERIP                         "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "--- Service ClusterIP ($SERVICE_IP) ---"
echo "Ping test:"
$OC exec -n "$NAMESPACE" debug-hops -- ping -c 3 -W 2 "$SERVICE_IP" 2>/dev/null || echo "ping a ClusterIP no soportado (normal en Kubernetes)"

echo ""
echo "HTTP check (múltiples requests para ver load balancing):"
for i in 1 2 3 4 5; do
    RESPONSE=$($OC exec -n "$NAMESPACE" debug-hops -- curl -s -o /dev/null -w "%{http_code} %{time_total}s" "http://${SERVICE_IP}:8080/" 2>/dev/null || echo "failed")
    echo "  Request $i: $RESPONSE"
done
echo ""

# Análisis específico de Cilium
if [ "$CNI_TYPE" == "Cilium" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                         ANÁLISIS CILIUM BPF                                   "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Detectar namespace de Cilium (puede ser cilium, openshift-cilium, kube-system)
    CILIUM_NS=""
    for ns in cilium openshift-cilium kube-system; do
        if $OC get pods -n "$ns" -l k8s-app=cilium -o name 2>/dev/null | grep -q pod; then
            CILIUM_NS="$ns"
            break
        fi
        # También probar con label app.kubernetes.io/name=cilium-agent
        if $OC get pods -n "$ns" -l app.kubernetes.io/name=cilium-agent -o name 2>/dev/null | grep -q pod; then
            CILIUM_NS="$ns"
            break
        fi
    done
    
    if [ -z "$CILIUM_NS" ]; then
        echo "No se encontró namespace de Cilium. Buscando pods..."
        $OC get pods -A | grep -i cilium | head -10
    else
        log_info "Cilium namespace detectado: $CILIUM_NS"
        
        # Obtener pod de Cilium agent
        CILIUM_POD=$($OC get pods -n "$CILIUM_NS" -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
                     $OC get pods -n "$CILIUM_NS" -l app.kubernetes.io/name=cilium-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
                     $OC get pods -n "$CILIUM_NS" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        if [ -n "$CILIUM_POD" ]; then
            log_info "Usando pod: $CILIUM_POD"
            echo ""
            
            echo "--- Cilium Status ---"
            $OC exec -n "$CILIUM_NS" "$CILIUM_POD" -- cilium status --brief 2>/dev/null || echo "No disponible"
            echo ""
            
            echo "--- Cilium Endpoint List (pods en network-perf-test) ---"
            $OC exec -n "$CILIUM_NS" "$CILIUM_POD" -- cilium endpoint list 2>/dev/null | grep -E "ENDPOINT|perf-target|network-perf" | head -20 || echo "No disponible"
            echo ""
            
            echo "--- Cilium Service List (perf-target) ---"
            $OC exec -n "$CILIUM_NS" "$CILIUM_POD" -- cilium service list 2>/dev/null | grep -E "ID|perf-target" | head -15 || echo "No disponible"
            echo ""
            
            echo "--- Cilium BPF LB List (load balancer entries) ---"
            $OC exec -n "$CILIUM_NS" "$CILIUM_POD" -- cilium bpf lb list 2>/dev/null | grep -E "SERVICE|$SERVICE_IP" | head -10 || echo "No disponible"
            echo ""
        else
            echo "No se pudo encontrar pod de Cilium agent"
        fi
    fi
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
