#!/usr/bin/env bash
# =============================================================================
# LIVE TTY-2: Eventos Warning en tiempo real — AMBOS clusters
# Ejecutar en terminal dedicada durante el ejercicio DRP.
# Uso: ./watch-events.sh [pga|cmz|all]
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

TARGET="${1:-all}"
INTERVAL="${EVENT_POLL_INTERVAL:-5}"

clear
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         DRP WAR ROOM — TTY2: CLUSTER EVENTS              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "Clusters: ${CYAN}$CLUSTER_PGA (ACTIVO→PGA) | $CLUSTER_CMZ (DR→CMZ)${NC}"
echo -e "Refresh: cada ${INTERVAL}s  |  Ctrl+C para salir"
echo ""

show_events() {
    local cluster="$1"
    local label="$2"
    echo -e "${BOLD}── $label ($cluster) ──────────────────────────────────${NC}"
    KUBECONFIG_VAR="KUBECONFIG_${label}"
    KUBECONFIG="${!KUBECONFIG_VAR}" oc get events -A \
        --field-selector type=Warning \
        --sort-by='.lastTimestamp' \
        --no-headers 2>/dev/null \
        | tail -"${LIVE_TAIL_LINES}" \
        | while IFS= read -r line; do
            echo -e "${YELLOW}$line${NC}"
        done || echo -e "${RED}  [No se pudo conectar]${NC}"
    echo ""
}

while true; do
    clear
    echo -e "${BOLD}DRP WAR ROOM — EVENTS $(date '+%H:%M:%S')${NC}"
    echo ""

    case "$TARGET" in
        pga) show_events "$CLUSTER_PGA" "PGA" ;;
        cmz) show_events "$CLUSTER_CMZ" "CMZ" ;;
        all)
            show_events "$CLUSTER_PGA" "PGA"
            show_events "$CLUSTER_CMZ" "CMZ"
            ;;
    esac

    sleep "$INTERVAL"
done
