#!/usr/bin/env bash
# =============================================================================
# Collector: eventos del cluster ordenados por tiempo
# Señales: Warning events, BackOff, FailedScheduling, Unhealthy probes.
# Uso: ./events.sh <cluster> <outdir>
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

CLUSTER="${1:?Cluster requerido}"
OUTDIR="${2:?Outdir requerido}"
mkdir -p "$OUTDIR"

log "[$CLUSTER] events → $OUTDIR"

# Todos los eventos ordenados por lastTimestamp
oc_cluster "$CLUSTER" get events -A \
    --sort-by='.lastTimestamp' \
    > "$OUTDIR/events-all.txt" 2>&1

# Solo eventos Warning
oc_cluster "$CLUSTER" get events -A \
    --field-selector type=Warning \
    --sort-by='.lastTimestamp' \
    > "$OUTDIR/events-warning.txt" 2>&1

COUNT_WARN=$(grep -c "" "$OUTDIR/events-warning.txt" 2>/dev/null || echo 0)
if [[ "$COUNT_WARN" -gt 1 ]]; then
    warn "[$CLUSTER] $COUNT_WARN eventos Warning detectados"
else
    ok "[$CLUSTER] Sin eventos Warning significativos"
fi

# Eventos críticos (BackOff, Killing, Failed, Unhealthy, OOMKilling)
oc_cluster "$CLUSTER" get events -A -o json 2>/dev/null | jq -r '
    .items[] |
    select(.type == "Warning") |
    select(.reason | test("BackOff|Killing|Failed|Unhealthy|OOMKilling|FailedScheduling|Evicted|NodeNotReady"; "i")) |
    [.lastTimestamp, .namespace, .reason, .involvedObject.kind, .involvedObject.name, .message] | @tsv
' | sort > "$OUTDIR/events-critical.txt" 2>/dev/null || true

COUNT_CRIT=$(grep -c "" "$OUTDIR/events-critical.txt" 2>/dev/null || echo 0)
if [[ "$COUNT_CRIT" -gt 0 ]]; then
    warn "[$CLUSTER] $COUNT_CRIT eventos CRÍTICOS:"
    head -10 "$OUTDIR/events-critical.txt" | while IFS= read -r line; do
        warn "  $line"
    done
fi

# JSON completo para correlación post-mortem
oc_cluster "$CLUSTER" get events -A -o json \
    > "$OUTDIR/events-all.json" 2>&1 || true

log "[$CLUSTER] events completado"
