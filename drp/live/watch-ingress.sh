#!/usr/bin/env bash
# =============================================================================
# LIVE TTY-4: Estado de routers e IngressControllers — AMBOS clusters
# Ejecutar en terminal dedicada durante el ejercicio DRP.
# Uso: ./watch-ingress.sh [pga|cmz|all]
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

TARGET="${1:-all}"
INTERVAL="${EVENT_POLL_INTERVAL:-5}"

show_ingress() {
    local cluster="$1"
    local label="$2"
    local kc_var="KUBECONFIG_${label}"

    echo -e "${BOLD}── $label ($cluster) — IngressControllers ──────────────${NC}"
    KUBECONFIG="${!kc_var}" oc get ingresscontroller -n openshift-ingress-operator \
        --no-headers 2>/dev/null \
        | while IFS= read -r line; do
            if echo "$line" | grep -q "True.*True.*True"; then
                echo -e "${GREEN}  $line${NC}"
            else
                echo -e "${RED}  $line${NC}"
            fi
        done || echo -e "${RED}  [No se pudo conectar]${NC}"

    echo ""
    echo -e "${BOLD}── $label — Router pods ────────────────────────────────${NC}"
    KUBECONFIG="${!kc_var}" oc get pods -n openshift-ingress \
        --no-headers 2>/dev/null \
        | while IFS= read -r line; do
            if echo "$line" | grep -q "Running"; then
                echo -e "${GREEN}  $line${NC}"
            else
                echo -e "${RED}  $line${NC}"
            fi
        done || echo -e "${RED}  [No se pudo conectar]${NC}"

    echo ""
    echo -e "${BOLD}── $label — Últimas líneas router (errores) ────────────${NC}"
    ROUTER_POD=$(KUBECONFIG="${!kc_var}" oc get pods -n openshift-ingress \
        --no-headers 2>/dev/null | grep Running | head -1 | awk '{print $1}' || true)

    if [[ -n "$ROUTER_POD" ]]; then
        KUBECONFIG="${!kc_var}" oc logs -n openshift-ingress "$ROUTER_POD" \
            --tail=10 --since=2m 2>/dev/null \
            | grep -Ei "error|timeout|failed|refused|5[0-9][0-9]" \
            | tail -8 \
            | while IFS= read -r line; do echo -e "${YELLOW}  $line${NC}"; done || true
    fi
    echo ""
}

while true; do
    clear
    echo -e "${BOLD}DRP WAR ROOM — INGRESS $(date '+%H:%M:%S')${NC}"
    echo ""

    case "$TARGET" in
        pga) show_ingress "$CLUSTER_PGA" "PGA" ;;
        cmz) show_ingress "$CLUSTER_CMZ" "CMZ" ;;
        all)
            show_ingress "$CLUSTER_PGA" "PGA"
            show_ingress "$CLUSTER_CMZ" "CMZ"
            ;;
    esac

    sleep "$INTERVAL"
done
