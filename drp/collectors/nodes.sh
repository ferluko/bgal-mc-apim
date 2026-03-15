#!/usr/bin/env bash
# =============================================================================
# Collector: estado de nodos
# Señales: NotReady, MemoryPressure, DiskPressure, PIDPressure, taints.
# Uso: ./nodes.sh <cluster> <outdir>
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

CLUSTER="${1:?Cluster requerido}"
OUTDIR="${2:?Outdir requerido}"
mkdir -p "$OUTDIR"

log "[$CLUSTER] nodes → $OUTDIR"

oc_cluster "$CLUSTER" get nodes -o wide \
    > "$OUTDIR/nodes.txt" 2>&1

oc_cluster "$CLUSTER" get nodes -o json \
    > "$OUTDIR/nodes.json" 2>&1

# Nodos NOT Ready
NOT_READY=$(oc_cluster "$CLUSTER" get nodes --no-headers 2>/dev/null \
    | grep -v " Ready" | grep -v "^NAME" || true)

if [[ -n "$NOT_READY" ]]; then
    warn "[$CLUSTER] Nodos NO READY:"
    echo "$NOT_READY" | while read -r line; do warn "  → $line"; done
    echo "$NOT_READY" > "$OUTDIR/nodes-notready.txt"
else
    ok "[$CLUSTER] Todos los nodos Ready"
    echo "NONE" > "$OUTDIR/nodes-notready.txt"
fi

# Condiciones de presión
oc_cluster "$CLUSTER" get nodes -o json 2>/dev/null | jq -r '
    .items[] |
    .metadata.name as $name |
    .status.conditions[] |
    select(.type != "Ready" and .status == "True") |
    [$name, .type, .status, .message] | @tsv
' > "$OUTDIR/nodes-pressure.txt" 2>/dev/null || true

# Taints de nodos (puede indicar cordón/drain)
oc_cluster "$CLUSTER" get nodes -o json 2>/dev/null | jq -r '
    .items[] |
    select(.spec.taints != null) |
    .metadata.name as $name |
    .spec.taints[] |
    [$name, .key, .effect] | @tsv
' > "$OUTDIR/nodes-taints.txt" 2>/dev/null || true

# Uso de recursos (requiere metrics-server)
oc_cluster "$CLUSTER" adm top nodes \
    > "$OUTDIR/nodes-top.txt" 2>&1 || warn "[$CLUSTER] metrics-server no disponible para top nodes"

log "[$CLUSTER] nodes completado"
