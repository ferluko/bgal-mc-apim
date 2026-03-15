#!/usr/bin/env bash
# =============================================================================
# Collector: estado de F5 LTM Active-Active Cluster via iControl REST
#
# Arquitectura real:
#   - F5 Active-Active: mismas VIPs en PGA y CMZ (misma IP en ambos sites)
#   - Durante DR los POOL MEMBERS cambian de PGA → CMZ (VIPs no se mueven)
#   - Los VS siempre están "enabled"; lo que cambia es el estado de los pool members
#
# VIPs conocidos (del diagrama de arquitectura):
#   10.254.50.1  → VS-PaaS-Prd-HTTP/S      (default router — clustered)
#   10.254.50.11 → VS-Appsa1-PaaS-prd-HTTP/S
#   10.254.50.12 → VS-Appsa2-PaaS-prd-HTTP/S
#   10.254.50.13 → VS-Appsa3-PaaS-prd-HTTP/S
#   10.254.50.14 → VS-Appsa4-PaaS-prd-HTTP/S
#   10.254.50.15 → VS-Appsa5-PaaS-prd-HTTP/S
#   10.254.50.16 → VS-Appsa6-PaaS-prd-HTTP/S
#
# Uso: ./f5-status.sh <outdir>
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

OUTDIR="${1:?Outdir requerido}"
mkdir -p "$OUTDIR"

log "F5 LTM status → $OUTDIR"

# Usar F5_HOST (floating cluster IP) o fallback a F5_HOST_PGA
F5="${F5_HOST:-${F5_HOST_PGA:-}}"
if [[ -z "$F5" ]]; then
    warn "F5_HOST no configurado — omitiendo collector F5"
    echo "F5_HOST_NOT_CONFIGURED" > "$OUTDIR/status.txt"
    exit 0
fi

BASE_URL="https://${F5}/mgmt/tm"
CURL_OPTS=(-sk -u "${F5_USER}:${F5_PASSWORD}" -H "Content-Type: application/json")

# ---------------------------------------------------------------------------
# 1. Virtual Servers — estado y destinos
# ---------------------------------------------------------------------------
log "F5 — consultando virtual servers"
curl "${CURL_OPTS[@]}" "$BASE_URL/ltm/virtual" \
    -o "$OUTDIR/virtual-servers.json" 2>/dev/null || {
    warn "F5 — no se pudo conectar a $F5"
    echo "CONNECTION_FAILED" > "$OUTDIR/status.txt"
    exit 0
}

# Resumen legible de VS
jq -r '
    .items[] |
    [.name,
     .destination,
     (if .enabled then "ENABLED" else "DISABLED" end),
     (.pool // "-")] | @tsv
' "$OUTDIR/virtual-servers.json" 2>/dev/null \
    | sort > "$OUTDIR/virtual-servers-summary.txt" || true

log "F5 — Virtual Servers:"
while IFS=$'\t' read -r name dest state pool; do
    [[ "$state" == "ENABLED" ]] && ok "  $name | $dest | $state | pool:$pool" \
                                || warn "  $name | $dest | $state | pool:$pool"
done < "$OUTDIR/virtual-servers-summary.txt" 2>/dev/null || true

# Filtrar solo los VS de PaaS conocidos
jq -r '
    .items[] |
    select(.name | test("VS-(PaaS-Prd|Appsa[1-6]-PaaS-prd)"; "i")) |
    [.name, .destination, (if .enabled then "ENABLED" else "DISABLED" end)] | @tsv
' "$OUTDIR/virtual-servers.json" 2>/dev/null \
    > "$OUTDIR/virtual-servers-paas.txt" || true

# ---------------------------------------------------------------------------
# 2. Pools — estado general
# ---------------------------------------------------------------------------
log "F5 — consultando pools"
curl "${CURL_OPTS[@]}" "$BASE_URL/ltm/pool" \
    -o "$OUTDIR/pools.json" 2>/dev/null || true

jq -r '
    .items[] |
    [.name, (.minActiveMembers | tostring), (.monitor // "-")] | @tsv
' "$OUTDIR/pools.json" 2>/dev/null \
    > "$OUTDIR/pools-summary.txt" || true

# ---------------------------------------------------------------------------
# 3. Pool Members — CRÍTICO para DRP
# Estado de cada member: enabled/disabled, up/down
# Durante DRP: PGA members = enabled/up; CMZ members = disabled o forced-offline
# ---------------------------------------------------------------------------
log "F5 — consultando pool members (clave para DRP)"

# Obtener cada pool y sus members
POOL_NAMES=$(jq -r '.items[].name' "$OUTDIR/pools.json" 2>/dev/null || true)
mkdir -p "$OUTDIR/pool-members"

while IFS= read -r pool_name; do
    [[ -z "$pool_name" ]] && continue
    POOL_ENC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$pool_name', safe=''))" 2>/dev/null \
        || echo "$pool_name" | sed 's|/|~|g')

    curl "${CURL_OPTS[@]}" \
        "$BASE_URL/ltm/pool/~Common~${pool_name}/members" \
        -o "$OUTDIR/pool-members/${pool_name}.json" 2>/dev/null || true

    jq -r '
        .items[]? |
        [.name, .address, .state, .session, (.ratio // 1 | tostring)] | @tsv
    ' "$OUTDIR/pool-members/${pool_name}.json" 2>/dev/null \
        >> "$OUTDIR/pool-members-all.txt" 2>/dev/null || true
done <<< "$POOL_NAMES"

# Resumen de members por estado
{
    echo "=== Pool Members — Estado DRP ==="
    echo ""
    echo "--- Members ENABLED (activos) ---"
    grep -E "\tenabled\t" "$OUTDIR/pool-members-all.txt" 2>/dev/null || echo "(ninguno)"
    echo ""
    echo "--- Members DISABLED / FORCED-OFFLINE (pasivos) ---"
    grep -E "\t(disabled|forced-offline)\t" "$OUTDIR/pool-members-all.txt" 2>/dev/null || echo "(ninguno)"
    echo ""
    echo "--- Members DOWN ---"
    grep -Ei "\tdown\t" "$OUTDIR/pool-members-all.txt" 2>/dev/null || echo "(ninguno)"
} > "$OUTDIR/pool-members-drp-summary.txt"

cat "$OUTDIR/pool-members-drp-summary.txt"

# ---------------------------------------------------------------------------
# 4. Stats de conexiones por VIP (tráfico real)
# ---------------------------------------------------------------------------
log "F5 — consultando stats de conexiones"
curl "${CURL_OPTS[@]}" "$BASE_URL/ltm/virtual/stats" \
    -o "$OUTDIR/virtual-stats.json" 2>/dev/null || true

jq -r '
    .entries | to_entries[] |
    .value.nestedStats.entries |
    [
        (.tmName.description // "?"),
        ("clientside.curConns:" + (.["clientside.curConns"].value | tostring)),
        ("clientside.totConns:" + (.["clientside.totConns"].value | tostring)),
        ("status.availabilityState:" + (.["status.availabilityState"].description // "?"))
    ] | @tsv
' "$OUTDIR/virtual-stats.json" 2>/dev/null \
    > "$OUTDIR/virtual-stats-summary.txt" || true

# ---------------------------------------------------------------------------
# 5. Detectar activo esperado según pool members
# ---------------------------------------------------------------------------
{
    PGA_ACTIVE=$(grep -c "enabled" "$OUTDIR/pool-members-all.txt" 2>/dev/null || echo 0)
    CMZ_ACTIVE=$(grep -c "enabled" "$OUTDIR/pool-members-all.txt" 2>/dev/null || echo 0)
    echo "F5_POOL_ENABLED_COUNT=$PGA_ACTIVE"
    echo "F5_POOL_DISABLED_COUNT=$(grep -c "disabled\|forced-offline" "$OUTDIR/pool-members-all.txt" 2>/dev/null || echo 0)"
} > "$OUTDIR/f5-drp-state.env"

log "F5 LTM status completado — ver: $OUTDIR/pool-members-drp-summary.txt"
