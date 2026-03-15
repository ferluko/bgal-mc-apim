#!/usr/bin/env bash
# =============================================================================
# LIVE TTY-7 (opcional): Watcher de recursos críticos en tiempo real
# Detecta cualquier cambio en deployments, routes, configmaps.
# Requiere un terminal por cluster/recurso.
# Uso: ./watch-changes.sh <pga|cmz> <deploy|routes|cm|all>
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

CLUSTER_LABEL="${1:-pga}"
RESOURCE="${2:-deploy}"

case "${CLUSTER_LABEL,,}" in
    pga) CLUSTER="$CLUSTER_PGA"; KCF="$KUBECONFIG_PGA" ;;
    cmz) CLUSTER="$CLUSTER_CMZ"; KCF="$KUBECONFIG_CMZ" ;;
    *) err "Uso: $0 [pga|cmz] [deploy|routes|cm|all]"; exit 1 ;;
esac

echo -e "${BOLD}DRP WAR ROOM — CHANGES WATCH${NC}"
echo -e "Cluster: ${CYAN}$CLUSTER${NC} | Recurso: ${YELLOW}$RESOURCE${NC}  |  Ctrl+C para salir"
echo ""

watch_resource() {
    local res="$1"
    echo -e "${CYAN}── Watching $res -A ─────────────────────────────${NC}"
    KUBECONFIG="$KCF" oc get "$res" -A -w 2>/dev/null \
        | while IFS= read -r line; do
            echo -e "$(date '+%H:%M:%S') ${YELLOW}$line${NC}"
        done
}

case "$RESOURCE" in
    deploy)  watch_resource "deployments" ;;
    routes)  watch_resource "routes" ;;
    cm)      watch_resource "configmaps" ;;
    all)
        # En modo all, mostrar los tres en paralelo (output mezclado, usar tmux)
        watch_resource "deployments" &
        PID1=$!
        watch_resource "routes" &
        PID2=$!
        watch_resource "configmaps" &
        PID3=$!
        trap "kill $PID1 $PID2 $PID3 2>/dev/null; exit 0" INT TERM
        wait
        ;;
    *) err "Recurso inválido: $RESOURCE"; exit 1 ;;
esac
