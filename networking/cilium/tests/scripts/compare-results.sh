#!/bin/bash
#
# compare-results.sh - Compara resultados de pruebas entre Cilium y OVN
#
# Uso:
#   ./compare-results.sh <cilium-results-dir> <ovn-results-dir>
#

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo "Uso: $0 <cilium-results-dir> <ovn-results-dir>"
    exit 1
fi

CILIUM_DIR="$1"
OVN_DIR="$2"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║           COMPARACIÓN DE RENDIMIENTO: Cilium KPR vs OVN-Kubernetes           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Función para extraer métricas de k6 JSON
extract_k6_metric() {
    local file="$1"
    local metric="$2"
    local stat="$3"
    
    if [ -f "$file" ]; then
        jq -r ".metrics.\"$metric\".values.\"$stat\" // \"N/A\"" "$file" 2>/dev/null || echo "N/A"
    else
        echo "N/A"
    fi
}

# Función para calcular diferencia porcentual
calc_diff() {
    local val1="$1"
    local val2="$2"
    
    if [[ "$val1" == "N/A" ]] || [[ "$val2" == "N/A" ]]; then
        echo "N/A"
        return
    fi
    
    local diff=$(echo "scale=2; (($val2 - $val1) / $val1) * 100" | bc 2>/dev/null || echo "N/A")
    echo "$diff"
}

# Función para colorear diferencia
color_diff() {
    local diff="$1"
    local lower_is_better="${2:-true}"
    
    if [[ "$diff" == "N/A" ]]; then
        echo -e "${YELLOW}N/A${NC}"
        return
    fi
    
    local num_diff=$(echo "$diff" | sed 's/%//')
    
    if [ "$lower_is_better" = true ]; then
        if (( $(echo "$num_diff < -5" | bc -l) )); then
            echo -e "${GREEN}${diff}%${NC}"
        elif (( $(echo "$num_diff > 5" | bc -l) )); then
            echo -e "${RED}${diff}%${NC}"
        else
            echo -e "${YELLOW}${diff}%${NC}"
        fi
    else
        if (( $(echo "$num_diff > 5" | bc -l) )); then
            echo -e "${GREEN}${diff}%${NC}"
        elif (( $(echo "$num_diff < -5" | bc -l) )); then
            echo -e "${RED}${diff}%${NC}"
        else
            echo -e "${YELLOW}${diff}%${NC}"
        fi
    fi
}

# Buscar archivos de resultados k6
CILIUM_K6=$(find "$CILIUM_DIR" -name "summary-Cilium-*.json" -o -name "output.json" 2>/dev/null | head -1)
OVN_K6=$(find "$OVN_DIR" -name "summary-OVN*.json" -o -name "output.json" 2>/dev/null | head -1)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                              LATENCIA (P95)                                   "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

printf "%-35s %12s %12s %12s\n" "Escenario" "Cilium" "OVN" "Diferencia"
printf "%-35s %12s %12s %12s\n" "-----------------------------------" "------------" "------------" "------------"

metrics=(
    "latency_pod_same_node_ms:Pod-to-Pod (mismo nodo)"
    "latency_pod_diff_node_ms:Pod-to-Pod (diferente nodo)"
    "latency_clusterip_ms:Pod-to-Service (ClusterIP)"
    "latency_nodeport_ms:Pod-to-Service (NodePort)"
    "latency_throughput_ms:Throughput (bajo carga)"
)

for metric_pair in "${metrics[@]}"; do
    metric="${metric_pair%%:*}"
    label="${metric_pair##*:}"
    
    cilium_val=$(extract_k6_metric "$CILIUM_K6" "$metric" "p(95)")
    ovn_val=$(extract_k6_metric "$OVN_K6" "$metric" "p(95)")
    
    if [[ "$cilium_val" != "N/A" ]]; then
        cilium_val=$(printf "%.2f" "$cilium_val")
    fi
    if [[ "$ovn_val" != "N/A" ]]; then
        ovn_val=$(printf "%.2f" "$ovn_val")
    fi
    
    diff=$(calc_diff "$cilium_val" "$ovn_val")
    diff_colored=$(color_diff "$diff" true)
    
    printf "%-35s %10sms %10sms %12s\n" "$label" "$cilium_val" "$ovn_val" "$diff_colored"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                           TIEMPOS DE CONEXIÓN (P95)                           "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

conn_metrics=(
    "tcp_connect_time_ms:TCP Connect"
    "time_to_first_byte_ms:Time to First Byte"
    "total_duration_ms:Total Duration"
)

printf "%-35s %12s %12s %12s\n" "Métrica" "Cilium" "OVN" "Diferencia"
printf "%-35s %12s %12s %12s\n" "-----------------------------------" "------------" "------------" "------------"

for metric_pair in "${conn_metrics[@]}"; do
    metric="${metric_pair%%:*}"
    label="${metric_pair##*:}"
    
    cilium_val=$(extract_k6_metric "$CILIUM_K6" "$metric" "p(95)")
    ovn_val=$(extract_k6_metric "$OVN_K6" "$metric" "p(95)")
    
    if [[ "$cilium_val" != "N/A" ]]; then
        cilium_val=$(printf "%.2f" "$cilium_val")
    fi
    if [[ "$ovn_val" != "N/A" ]]; then
        ovn_val=$(printf "%.2f" "$ovn_val")
    fi
    
    diff=$(calc_diff "$cilium_val" "$ovn_val")
    diff_colored=$(color_diff "$diff" true)
    
    printf "%-35s %10sms %10sms %12s\n" "$label" "$cilium_val" "$ovn_val" "$diff_colored"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                              TASA DE ERROR                                    "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cilium_err=$(extract_k6_metric "$CILIUM_K6" "error_rate" "rate")
ovn_err=$(extract_k6_metric "$OVN_K6" "error_rate" "rate")

if [[ "$cilium_err" != "N/A" ]]; then
    cilium_err_pct=$(echo "scale=4; $cilium_err * 100" | bc)
else
    cilium_err_pct="N/A"
fi

if [[ "$ovn_err" != "N/A" ]]; then
    ovn_err_pct=$(echo "scale=4; $ovn_err * 100" | bc)
else
    ovn_err_pct="N/A"
fi

printf "%-35s %11s%% %11s%%\n" "Error Rate" "$cilium_err_pct" "$ovn_err_pct"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                              INTERPRETACIÓN                                   "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${GREEN}Verde${NC}:    Cilium es significativamente mejor (>5% mejora)"
echo -e "  ${YELLOW}Amarillo${NC}: Diferencia marginal (<5%)"
echo -e "  ${RED}Rojo${NC}:     OVN es significativamente mejor (>5% mejora)"
echo ""
echo "  Nota: Diferencia negativa = Cilium tiene menor latencia (mejor)"
echo "        Diferencia positiva = OVN tiene menor latencia (mejor)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
