#!/bin/bash
#
# compare-results.sh - Compara resultados de pruebas entre Cilium y OVN
#
# Uso:
#   ./compare-results.sh <cilium-results-dir> <ovn-results-dir>
#
# Los directorios deben contener archivos .log generados por run-tests.sh
#

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo "Uso: $0 <cilium-results-dir> <ovn-results-dir>"
    echo ""
    echo "Ejemplo:"
    echo "  $0 results-cilium/ results-ovn/"
    exit 1
fi

CILIUM_DIR="$1"
OVN_DIR="$2"

# Buscar el log más reciente en cada directorio
CILIUM_LOG=$(ls -t "$CILIUM_DIR"/*.log 2>/dev/null | head -1)
OVN_LOG=$(ls -t "$OVN_DIR"/*.log 2>/dev/null | head -1)

if [ -z "$CILIUM_LOG" ]; then
    echo "Error: No se encontraron archivos .log en $CILIUM_DIR"
    exit 1
fi

if [ -z "$OVN_LOG" ]; then
    echo "Error: No se encontraron archivos .log en $OVN_DIR"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║           COMPARACIÓN DE RENDIMIENTO: Cilium KPR vs OVN-Kubernetes           ║"
echo "╠══════════════════════════════════════════════════════════════════════════════╣"
echo "║  Cilium log: $(printf '%-63s' "$(basename "$CILIUM_LOG")")║"
echo "║  OVN log:    $(printf '%-63s' "$(basename "$OVN_LOG")")║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Función para extraer métrica de un log
# Formato: │ Escenario                      │   Min   │   Avg   │   P95   │   P99   │   Max   │
# Posiciones de valores (después de extraer números): 1=Min, 2=Avg, 3=P95, 4=P99, 5=Max
extract_metric() {
    local file="$1"
    local scenario="$2"
    local position="$3"  # 1=Min, 2=Avg, 3=P95, 4=P99, 5=Max
    
    # Buscar la línea con el escenario y extraer todos los números con "ms"
    local line=$(grep "${scenario}" "$file" 2>/dev/null | grep -E "[0-9]+\.[0-9]+ms" | head -1)
    
    if [ -z "$line" ]; then
        echo "N/A"
        return
    fi
    
    # Extraer todos los valores numéricos (formato X.XXms)
    local value=$(echo "$line" | grep -oE "[0-9]+\.[0-9]+" | sed -n "${position}p")
    
    if [ -z "$value" ]; then
        echo "N/A"
    else
        echo "$value"
    fi
}

# Función para calcular diferencia porcentual
calc_diff() {
    local cilium_val="$1"
    local ovn_val="$2"
    
    if [[ "$cilium_val" == "N/A" ]] || [[ "$ovn_val" == "N/A" ]]; then
        echo "N/A"
        return
    fi
    
    # Diferencia: positivo = OVN es más lento (Cilium mejor)
    # negativo = Cilium es más lento (OVN mejor)
    local diff=$(echo "scale=1; (($ovn_val - $cilium_val) / $cilium_val) * 100" | bc 2>/dev/null || echo "N/A")
    echo "$diff"
}

# Función para colorear diferencia
# Positivo (OVN más lento) = Verde (Cilium mejor)
# Negativo (Cilium más lento) = Rojo (OVN mejor)
color_diff() {
    local diff="$1"
    
    if [[ "$diff" == "N/A" ]]; then
        echo "N/A"
        return
    fi
    
    # Quitar posible signo negativo para comparación
    local abs_diff=$(echo "$diff" | sed 's/-//')
    
    if (( $(echo "$abs_diff < 5" | bc -l 2>/dev/null || echo 0) )); then
        # Diferencia marginal
        echo -e "${YELLOW}${diff}%${NC}"
    elif (( $(echo "$diff > 0" | bc -l 2>/dev/null || echo 0) )); then
        # Positivo = OVN más lento = Cilium mejor
        echo -e "${GREEN}+${diff}%${NC}"
    else
        # Negativo = Cilium más lento = OVN mejor
        echo -e "${RED}${diff}%${NC}"
    fi
}

# Función para mostrar ganador
show_winner() {
    local diff="$1"
    
    if [[ "$diff" == "N/A" ]]; then
        echo ""
        return
    fi
    
    if (( $(echo "$diff > 5" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${GREEN}← Cilium${NC}"
    elif (( $(echo "$diff < -5" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${RED}OVN →${NC}"
    else
        echo -e "${YELLOW}≈${NC}"
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                           LATENCIA P95 (milisegundos)                          "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "${BOLD}%-32s %10s %10s %12s %10s${NC}\n" "Escenario" "Cilium" "OVN" "Diferencia" "Mejor"
printf "%-32s %10s %10s %12s %10s\n" "--------------------------------" "----------" "----------" "------------" "----------"

scenarios=(
    "Pod-to-Pod (mismo nodo)"
    "Pod-to-Pod (diferente nodo)"
    "Pod-to-Service (ClusterIP)"
    "Pod-to-Service (NodePort)"
    "Throughput (bajo carga)"
)

for scenario in "${scenarios[@]}"; do
    # P95 está en posición 3 (Min=1, Avg=2, P95=3, P99=4, Max=5)
    cilium_p95=$(extract_metric "$CILIUM_LOG" "$scenario" 3)
    ovn_p95=$(extract_metric "$OVN_LOG" "$scenario" 3)
    diff=$(calc_diff "$cilium_p95" "$ovn_p95")
    diff_colored=$(color_diff "$diff")
    winner=$(show_winner "$diff")
    
    printf "%-32s %9sms %9sms %12s %10s\n" "$scenario" "$cilium_p95" "$ovn_p95" "$diff_colored" "$winner"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                           LATENCIA PROMEDIO (milisegundos)                     "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "${BOLD}%-32s %10s %10s %12s %10s${NC}\n" "Escenario" "Cilium" "OVN" "Diferencia" "Mejor"
printf "%-32s %10s %10s %12s %10s\n" "--------------------------------" "----------" "----------" "------------" "----------"

for scenario in "${scenarios[@]}"; do
    # Avg está en posición 2
    cilium_avg=$(extract_metric "$CILIUM_LOG" "$scenario" 2)
    ovn_avg=$(extract_metric "$OVN_LOG" "$scenario" 2)
    diff=$(calc_diff "$cilium_avg" "$ovn_avg")
    diff_colored=$(color_diff "$diff")
    winner=$(show_winner "$diff")
    
    printf "%-32s %9sms %9sms %12s %10s\n" "$scenario" "$cilium_avg" "$ovn_avg" "$diff_colored" "$winner"
done

# Extraer métricas de iperf3 si existen
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                              THROUGHPUT (iperf3)                               "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Buscar throughput TCP en los logs
cilium_tcp=$(grep -A2 "TCP THROUGHPUT" "$CILIUM_LOG" 2>/dev/null | grep -oE "[0-9]+\.?[0-9]* [GM]bits/sec" | tail -1 || echo "N/A")
ovn_tcp=$(grep -A2 "TCP THROUGHPUT" "$OVN_LOG" 2>/dev/null | grep -oE "[0-9]+\.?[0-9]* [GM]bits/sec" | tail -1 || echo "N/A")

cilium_udp=$(grep -A2 "UDP THROUGHPUT" "$CILIUM_LOG" 2>/dev/null | grep -oE "[0-9]+\.?[0-9]* [GM]bits/sec" | tail -1 || echo "N/A")
ovn_udp=$(grep -A2 "UDP THROUGHPUT" "$OVN_LOG" 2>/dev/null | grep -oE "[0-9]+\.?[0-9]* [GM]bits/sec" | tail -1 || echo "N/A")

printf "${BOLD}%-32s %15s %15s${NC}\n" "Métrica" "Cilium" "OVN"
printf "%-32s %15s %15s\n" "--------------------------------" "---------------" "---------------"
printf "%-32s %15s %15s\n" "TCP Throughput" "$cilium_tcp" "$ovn_tcp"
printf "%-32s %15s %15s\n" "UDP Throughput" "$cilium_udp" "$ovn_udp"

# Extraer métricas de netperf si existen
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                              LATENCIA (netperf)                                "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# TCP_RR transactions per second
cilium_rr=$(grep -A5 "TCP_RR" "$CILIUM_LOG" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+" | tail -1 || echo "N/A")
ovn_rr=$(grep -A5 "TCP_RR" "$OVN_LOG" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+" | tail -1 || echo "N/A")

printf "${BOLD}%-32s %15s %15s${NC}\n" "Métrica" "Cilium" "OVN"
printf "%-32s %15s %15s\n" "--------------------------------" "---------------" "---------------"
printf "%-32s %15s %15s\n" "TCP_RR (trans/sec)" "$cilium_rr" "$ovn_rr"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                                 RESUMEN                                        "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Contar victorias
cilium_wins=0
ovn_wins=0
ties=0

for scenario in "${scenarios[@]}"; do
    # P95 está en posición 3
    cilium_p95=$(extract_metric "$CILIUM_LOG" "$scenario" 3)
    ovn_p95=$(extract_metric "$OVN_LOG" "$scenario" 3)
    diff=$(calc_diff "$cilium_p95" "$ovn_p95")
    
    if [[ "$diff" != "N/A" ]]; then
        if (( $(echo "$diff > 5" | bc -l 2>/dev/null || echo 0) )); then
            ((cilium_wins++))
        elif (( $(echo "$diff < -5" | bc -l 2>/dev/null || echo 0) )); then
            ((ovn_wins++))
        else
            ((ties++))
        fi
    fi
done

echo -e "  ${GREEN}Cilium mejor:${NC}  $cilium_wins escenarios"
echo -e "  ${RED}OVN mejor:${NC}     $ovn_wins escenarios"
echo -e "  ${YELLOW}Empate:${NC}        $ties escenarios"
echo ""

if [ $cilium_wins -gt $ovn_wins ]; then
    echo -e "  ${GREEN}${BOLD}>>> Cilium KPR muestra mejor rendimiento general <<<${NC}"
elif [ $ovn_wins -gt $cilium_wins ]; then
    echo -e "  ${RED}${BOLD}>>> OVN-Kubernetes muestra mejor rendimiento general <<<${NC}"
else
    echo -e "  ${YELLOW}${BOLD}>>> Rendimiento similar entre ambos CNIs <<<${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                              INTERPRETACIÓN                                    "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${GREEN}+N%${NC}  = OVN es N% más lento que Cilium (Cilium mejor)"
echo -e "  ${RED}-N%${NC}  = Cilium es N% más lento que OVN (OVN mejor)"
echo -e "  ${YELLOW}±5%${NC} = Diferencia marginal (empate técnico)"
echo ""
echo "  Nota: Latencias más bajas = mejor rendimiento"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
