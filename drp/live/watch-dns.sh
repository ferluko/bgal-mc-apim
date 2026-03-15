#!/usr/bin/env bash
# =============================================================================
# LIVE TTY-5: Resolución DNS en tiempo real — detecta el switch de site
#
# Monitorea:
#   api.paas-prd.bancogalicia.com.ar → CNAME a prdpg (PGA) o prdmz (CMZ)
#   appsprdf5-1 / appsprdf5 (targets de apps wildcard)
#
# Detecta el momento exacto del switch DNS y lo registra en log.
# Uso: ./watch-dns.sh
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

INTERVAL="${DNS_POLL_INTERVAL:-2}"
SWITCH_LOG="/tmp/drp-dns-switch-$(date +%Y%m%d).log"
PREV_API_CNAME=""
PREV_ACTIVE_SITE=""

clear
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         DRP WAR ROOM — TTY5: DNS WATCH                   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "API agnóstico: ${CYAN}$API_AGNOSTIC_FQDN${NC}"
echo -e "PGA target:    ${GREEN}$DNS_APPS_TARGET_PGA${NC}"
echo -e "CMZ target:    ${CYAN}$DNS_APPS_TARGET_CMZ${NC}"
echo -e "Refresh: cada ${INTERVAL}s  |  Switch log: $SWITCH_LOG  |  Ctrl+C para salir"
echo ""

infer_site() {
    local cname="$1"
    if echo "$cname" | grep -qi "prdpg\|pga\|plaza\|f5-1"; then
        echo "PGA"
    elif echo "$cname" | grep -qi "prdmz\|cmz\|matriz\|f5\."; then
        echo "CMZ"
    else
        echo "UNKNOWN"
    fi
}

while true; do
    TS=$(date '+%H:%M:%S')

    # Resolver CNAME del API agnóstico
    API_CNAME=$(dig "$API_AGNOSTIC_FQDN" CNAME +short 2>/dev/null | head -1 || echo "NXDOMAIN")
    API_IP=$(dig +short "$API_AGNOSTIC_FQDN" 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "?")
    API_TTL=$(dig "$API_AGNOSTIC_FQDN" +nocmd +noall +answer 2>/dev/null | awk '{print $2}' | head -1 || echo "?")

    ACTIVE_SITE=$(infer_site "$API_CNAME")

    # Detectar switch
    if [[ "$API_CNAME" != "$PREV_API_CNAME" && -n "$PREV_API_CNAME" ]]; then
        echo ""
        echo -e "${RED}${BOLD}!!! DNS SWITCH DETECTADO — $TS !!!${NC}"
        echo -e "  ${YELLOW}Anterior CNAME: $PREV_API_CNAME ($PREV_ACTIVE_SITE)${NC}"
        echo -e "  ${GREEN}Nuevo CNAME:    $API_CNAME ($ACTIVE_SITE)${NC}"
        echo ""
        echo "$TS | SWITCH | $PREV_API_CNAME ($PREV_ACTIVE_SITE) → $API_CNAME ($ACTIVE_SITE)" \
            | tee -a "$SWITCH_LOG"
        echo ""
    fi

    # Color por site activo
    case "$ACTIVE_SITE" in
        PGA) SITE_COLOR="${GREEN}" ;;
        CMZ) SITE_COLOR="${CYAN}" ;;
        *)   SITE_COLOR="${YELLOW}" ;;
    esac

    echo -e "[$TS] API: ${SITE_COLOR}${BOLD}$ACTIVE_SITE${NC}${SITE_COLOR} | CNAME→$API_CNAME | IP:$API_IP | TTL:${API_TTL}s${NC}"

    PREV_API_CNAME="$API_CNAME"
    PREV_ACTIVE_SITE="$ACTIVE_SITE"
    sleep "$INTERVAL"
done
