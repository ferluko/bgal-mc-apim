#!/bin/bash
#
# compare-stress-results.sh - Compara resultados del stress test entre CNIs
#
# Uso:
#   ./compare-stress-results.sh <cilium-dir> <ovn-dir>
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

[ $# -ge 2 ] || { echo "Uso: $0 <cilium-dir> <ovn-dir>"; exit 1; }

CILIUM_DIR="$1"
OVN_DIR="$2"

CILIUM_LOG=$(ls -t "$CILIUM_DIR"/*.log 2>/dev/null | head -1)
OVN_LOG=$(ls -t "$OVN_DIR"/*.log 2>/dev/null | head -1)

[ -n "$CILIUM_LOG" ] || { echo "No hay logs en $CILIUM_DIR"; exit 1; }
[ -n "$OVN_LOG" ] || { echo "No hay logs en $OVN_DIR"; exit 1; }

extract_stress_metric() {
    local file="$1"
    local scenario="$2"
    local pos="$3"
    local line=$(grep "${scenario}" "$file" 2>/dev/null | grep -E "[0-9]+\.[0-9]+" | head -1)
    [ -z "$line" ] && { echo "N/A"; return; }
    echo "$line" | grep -oE "[0-9]+\.[0-9]+" | sed -n "${pos}p"
}

scenarios=("Ramp (0->150" "Constante 300" "Burst 500" "Spike 0->400")
positions=(3 3 3 3)  # P95

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║              STRESS TEST - Comparación Cilium vs OVN                         ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
printf "${BOLD}%-28s %10s %10s %12s %10s${NC}\n" "Escenario" "Cilium" "OVN" "Diferencia" "Mejor"
printf "%-28s %10s %10s %12s\n" "----------------------------" "----------" "----------" "------------"

for i in "${!scenarios[@]}"; do
    s="${scenarios[$i]}"
    c=$(extract_stress_metric "$CILIUM_LOG" "$s" 3)
    o=$(extract_stress_metric "$OVN_LOG" "$s" 3)
    
    if [[ "$c" != "N/A" ]] && [[ "$o" != "N/A" ]]; then
        diff=$(awk -v c="$c" -v o="$o" 'BEGIN { printf "%.1f", ((o-c)/c)*100 }')
        if (( $(echo "$diff > 5" | bc -l 2>/dev/null || echo 0) )); then
            winner="${GREEN}← Cilium${NC}"
        elif (( $(echo "$diff < -5" | bc -l 2>/dev/null || echo 0) )); then
            winner="${RED}OVN →${NC}"
        else
            winner="${YELLOW}≈${NC}"
        fi
        printf "%-28s %9sms %9sms %11s%% %b\n" "$s" "$c" "$o" "$diff" "$winner"
    else
        printf "%-28s %9s %9s %12s\n" "$s" "${c:-N/A}" "${o:-N/A}" "N/A"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
