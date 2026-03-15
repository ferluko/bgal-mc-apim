#!/usr/bin/env bash
# =============================================================================
# Collector: estado de pods en todos los namespaces
# Señales: CrashLoopBackOff, OOMKilled, Pending, Evicted, reinicios altos.
# Uso: ./pods.sh <cluster> <outdir>
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

CLUSTER="${1:?Cluster requerido}"
OUTDIR="${2:?Outdir requerido}"
mkdir -p "$OUTDIR"

log "[$CLUSTER] pods → $OUTDIR"

oc_cluster "$CLUSTER" get pods -A -o wide \
    > "$OUTDIR/pods-all.txt" 2>&1

# Pods problemáticos (no Running/Completed/Succeeded)
oc_cluster "$CLUSTER" get pods -A --no-headers 2>/dev/null \
    | grep -Ev "(Running|Completed|Succeeded)" \
    > "$OUTDIR/pods-notrunning.txt" || echo "NONE" > "$OUTDIR/pods-notrunning.txt"

COUNT_NOTRUNNING=$(grep -c . "$OUTDIR/pods-notrunning.txt" 2>/dev/null || echo 0)
if [[ "$COUNT_NOTRUNNING" -gt 0 ]] && ! grep -q "^NONE$" "$OUTDIR/pods-notrunning.txt"; then
    warn "[$CLUSTER] $COUNT_NOTRUNNING pods NO en estado Running/Completed"
else
    ok "[$CLUSTER] Todos los pods en estado esperado"
fi

# Reinicios por pod (top 20 por restart count)
oc_cluster "$CLUSTER" get pods -A -o json 2>/dev/null | jq -r '
    .items[] |
    .metadata.namespace as $ns |
    .metadata.name as $pod |
    .status.containerStatuses[]? |
    [$ns, $pod, .name, (.restartCount | tostring)] | @tsv
' | sort -t$'\t' -k4 -rn | head -20 \
    > "$OUTDIR/pods-restarts-top20.txt" 2>/dev/null || true

# OOMKilled en los últimos 30 minutos
oc_cluster "$CLUSTER" get pods -A -o json 2>/dev/null | jq -r '
    .items[] |
    .metadata.namespace as $ns |
    .metadata.name as $pod |
    .status.containerStatuses[]? |
    select(.lastState.terminated.reason == "OOMKilled") |
    [$ns, $pod, .name, "OOMKilled", (.lastState.terminated.finishedAt // "?")] | @tsv
' > "$OUTDIR/pods-oomkilled.txt" 2>/dev/null || true

# Uso de recursos (requiere metrics-server)
oc_cluster "$CLUSTER" adm top pods -A \
    > "$OUTDIR/pods-top.txt" 2>&1 || warn "[$CLUSTER] metrics-server no disponible para top pods"

log "[$CLUSTER] pods completado"
