#!/usr/bin/env bash
# =============================================================================
# LIVE TTY-3: Pods no Running + top reinicios — AMBOS clusters
# Ejecutar en terminal dedicada durante el ejercicio DRP.
# Uso: ./watch-pods.sh [pga|cmz|all]
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

TARGET="${1:-all}"
INTERVAL="${EVENT_POLL_INTERVAL:-5}"

show_pods() {
    local cluster="$1"
    local label="$2"
    local kc_var="KUBECONFIG_${label}"
    echo -e "${BOLD}── $label ($cluster) — Pods problemáticos ──────────────${NC}"

    NOTRUNNING=$(KUBECONFIG="${!kc_var}" oc get pods -A --no-headers 2>/dev/null \
        | grep -Ev "(Running|Completed|Succeeded)" || true)

    if [[ -z "$NOTRUNNING" ]]; then
        echo -e "${GREEN}  Todos los pods en estado OK${NC}"
    else
        echo -e "${RED}$NOTRUNNING${NC}"
    fi

    echo ""
    echo -e "${BOLD}── $label — Top 10 restarts ────────────────────────────${NC}"
    KUBECONFIG="${!kc_var}" oc get pods -A -o json 2>/dev/null | jq -r '
        .items[] |
        .metadata.namespace as $ns |
        .metadata.name as $pod |
        .status.containerStatuses[]? |
        [$ns, $pod, .name, (.restartCount | tostring)] | @tsv
    ' 2>/dev/null | sort -t$'\t' -k4 -rn | head -10 \
        | while IFS=$'\t' read -r ns pod container restarts; do
            if [[ "$restarts" -gt 5 ]]; then
                echo -e "${RED}  [$ns] $pod / $container — reinicios: $restarts${NC}"
            elif [[ "$restarts" -gt 0 ]]; then
                echo -e "${YELLOW}  [$ns] $pod / $container — reinicios: $restarts${NC}"
            else
                echo -e "  [$ns] $pod / $container — reinicios: $restarts"
            fi
        done || echo -e "${RED}  [No se pudo conectar]${NC}"
    echo ""
}

while true; do
    clear
    echo -e "${BOLD}DRP WAR ROOM — PODS $(date '+%H:%M:%S')${NC}"
    echo ""

    case "$TARGET" in
        pga) show_pods "$CLUSTER_PGA" "PGA" ;;
        cmz) show_pods "$CLUSTER_CMZ" "CMZ" ;;
        all)
            show_pods "$CLUSTER_PGA" "PGA"
            show_pods "$CLUSTER_CMZ" "CMZ"
            ;;
    esac

    sleep "$INTERVAL"
done
