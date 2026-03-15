#!/usr/bin/env bash
# =============================================================================
# LIVE TTY-6: Audit log en tiempo real — detecta cambios manuales de squads
# Muestra solo operaciones de escritura de usuarios no-system.
# Uso: ./watch-audit.sh [pga|cmz]
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

CLUSTER_LABEL="${1:-pga}"
case "${CLUSTER_LABEL,,}" in
    pga) CLUSTER="$CLUSTER_PGA"; KCF="$KUBECONFIG_PGA" ;;
    cmz) CLUSTER="$CLUSTER_CMZ"; KCF="$KUBECONFIG_CMZ" ;;
    *) err "Uso: $0 [pga|cmz]"; exit 1 ;;
esac

echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         DRP WAR ROOM — TTY6: AUDIT WATCH                 ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "Cluster: ${CYAN}$CLUSTER${NC}  |  Ctrl+C para salir"
echo -e "Mostrando: ${YELLOW}escrituras (patch/update/delete/create) de usuarios no-system${NC}"
echo ""

KUBECONFIG="$KCF" oc adm node-logs \
    --role=master \
    --path=openshift-apiserver/audit.log \
    -f 2>/dev/null \
    | while IFS= read -r line; do
        # Solo líneas JSON
        [[ "$line" != "{"* ]] && continue

        # Solo verbos de escritura
        VERB=$(echo "$line" | jq -r '.verb // ""' 2>/dev/null)
        [[ "$VERB" =~ ^(patch|update|delete|create|deletecollection)$ ]] || continue

        # Solo usuarios no-system
        USER=$(echo "$line" | jq -r '.user.username // ""' 2>/dev/null)
        [[ "$USER" =~ ^(system:|serviceaccount:) ]] && continue

        TS=$(echo "$line"    | jq -r '.requestReceivedTimestamp // ""' 2>/dev/null | cut -c1-19)
        NS=$(echo "$line"    | jq -r '.objectRef.namespace // "-"' 2>/dev/null)
        RESOURCE=$(echo "$line" | jq -r '.objectRef.resource // "-"' 2>/dev/null)
        NAME=$(echo "$line"  | jq -r '.objectRef.name // "-"' 2>/dev/null)
        CODE=$(echo "$line"  | jq -r '.responseStatus.code // "-"' 2>/dev/null)

        # Color por verbo
        case "$VERB" in
            delete|deletecollection) COLOR="${RED}" ;;
            create)   COLOR="${GREEN}" ;;
            patch|update) COLOR="${YELLOW}" ;;
            *) COLOR="${NC}" ;;
        esac

        echo -e "${COLOR}[$TS] ${BOLD}$USER${NC}${COLOR} | $VERB | $RESOURCE | $NS/$NAME | HTTP $CODE${NC}"
    done
