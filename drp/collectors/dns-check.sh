#!/usr/bin/env bash
# =============================================================================
# Collector: snapshot resolución DNS
#
# FQDNs monitoreados (según diagrama de arquitectura):
#   api.paas-prd.bancogalicia.com.ar
#     → PRE/POST: CNAME api.paas-prdpg.bancogalicia.com.ar (PGA)
#     → DURING:   CNAME api.paas-prdmz.bancogalicia.com.ar (CMZ)
#
#   *.paas-prd.bancogalicia.com.ar (wildcard apps — via F5)
#     → PRE/POST: CNAME appsprdf5-1.apps.paas-prd.bancogalicia.com.ar (PGA)
#     → DURING:   CNAME appsprdf5.apps.paas-prd.bancogalicia.com.ar   (CMZ)
#
#   appsa1.paas-prd.bancogalicia.com.ar (apps1 router)
#
# Uso: ./dns-check.sh <outdir>
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

OUTDIR="${1:?Outdir requerido}"
mkdir -p "$OUTDIR"

TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')
log "DNS snapshot → $OUTDIR ($TIMESTAMP)"

resolve_fqdn() {
    local fqdn="$1"
    local label="$2"
    local out_file="$3"

    {
        echo "=== $label ==="
        echo "FQDN: $fqdn"
        echo "Timestamp: $TIMESTAMP"
        echo ""

        echo "--- CNAME chain ---"
        dig "$fqdn" CNAME +nocmd +noall +answer 2>/dev/null || echo "(sin CNAME)"

        echo ""
        echo "--- Resolución final (A records) ---"
        dig +short "$fqdn" 2>/dev/null || echo "NXDOMAIN"

        echo ""
        echo "--- TTL ---"
        dig "$fqdn" +nocmd +noall +answer 2>/dev/null | awk '{printf "  %s  TTL:%s\n", $5, $2}' || true

    } | tee "$out_file"
}

# 1. API agnóstico
resolve_fqdn "$API_AGNOSTIC_FQDN" "API Agnóstico" "$OUTDIR/dns-api-agnostic.txt"

# 2. Apps wildcard (representativo — usar un hostname conocido si el wildcard no resuelve solo)
resolve_fqdn "$AGNOSTIC_FQDN" "Apps Wildcard (paas-prd)" "$OUTDIR/dns-apps-wildcard.txt"

# 3. CNAMEs específicos por site (verificar que resuelven)
resolve_fqdn "$DNS_APPS_TARGET_PGA" "Apps DNS Target PGA (appsprdf5-1)" "$OUTDIR/dns-target-pga.txt"
resolve_fqdn "$DNS_APPS_TARGET_CMZ" "Apps DNS Target CMZ (appsprdf5)"   "$OUTDIR/dns-target-cmz.txt"

# 4. Apps1 router
resolve_fqdn "$DNS_APPSA1_TARGET" "Apps1 Router Target" "$OUTDIR/dns-appsa1-target.txt"

# 5. APIs por cluster (para validar resolución directa)
resolve_fqdn "$API_FQDN_PGA" "API PGA directo" "$OUTDIR/dns-api-pga.txt"
resolve_fqdn "$API_FQDN_CMZ" "API CMZ directo" "$OUTDIR/dns-api-cmz.txt"

# ---------------------------------------------------------------------------
# Inferir site activo basado en CNAME del API agnóstico
# ---------------------------------------------------------------------------
CNAME_TARGET=$(dig "$API_AGNOSTIC_FQDN" CNAME +short 2>/dev/null | tr -d '.' | tr '[:upper:]' '[:lower:]' || true)

if echo "$CNAME_TARGET" | grep -q "prdpg\|pga\|plaza"; then
    ACTIVE_SITE="PGA"
    ok "DNS — Site activo inferido: PGA (api → $API_FQDN_PGA)"
elif echo "$CNAME_TARGET" | grep -q "prdmz\|cmz\|matriz"; then
    ACTIVE_SITE="CMZ"
    ok "DNS — Site activo inferido: CMZ (api → $API_FQDN_CMZ)"
else
    ACTIVE_SITE="UNKNOWN"
    warn "DNS — No se pudo inferir site activo (CNAME: $CNAME_TARGET)"
fi

# Verificar también por CNAME de apps
APPS_CNAME=$(dig "$API_AGNOSTIC_FQDN" CNAME +short 2>/dev/null | head -1 || true)

# JSON estructurado para comparación entre fases
{
    echo "{"
    echo "  \"timestamp\": \"$TIMESTAMP\","
    echo "  \"api_agnostic\": {"
    echo "    \"fqdn\": \"$API_AGNOSTIC_FQDN\","
    echo "    \"cname\": \"$(dig "$API_AGNOSTIC_FQDN" CNAME +short 2>/dev/null | tr -d '\n')\","
    echo "    \"resolved\": $(dig +short "$API_AGNOSTIC_FQDN" 2>/dev/null | jq -Rs 'split("\n")|map(select(length>0))' 2>/dev/null || echo '[]')"
    echo "  },"
    echo "  \"apps_wildcard\": {"
    echo "    \"fqdn\": \"$AGNOSTIC_FQDN\","
    echo "    \"target_pga\": \"$DNS_APPS_TARGET_PGA\","
    echo "    \"target_cmz\": \"$DNS_APPS_TARGET_CMZ\""
    echo "  },"
    echo "  \"active_site_inferred\": \"$ACTIVE_SITE\""
    echo "}"
} > "$OUTDIR/dns-snapshot.json"

echo "DNS_ACTIVE_SITE=$ACTIVE_SITE" > "$OUTDIR/dns-drp-state.env"

log "DNS snapshot completado — site activo inferido: ${BOLD}$ACTIVE_SITE${NC}"
