#!/usr/bin/env bash
# =============================================================================
# Collector: salud del cluster (ClusterVersion + ClusterOperators)
# Señales: versión OCP, degradación de operadores, condiciones del cluster.
# Uso: ./cluster-health.sh <cluster> <outdir>
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

CLUSTER="${1:?Cluster requerido}"
OUTDIR="${2:?Outdir requerido}"
mkdir -p "$OUTDIR"

log "[$CLUSTER] cluster-health → $OUTDIR"

oc_cluster "$CLUSTER" get clusterversion -o wide \
    > "$OUTDIR/clusterversion.txt" 2>&1

oc_cluster "$CLUSTER" get clusterversion -o json \
    > "$OUTDIR/clusterversion.json" 2>&1

oc_cluster "$CLUSTER" get clusteroperators \
    > "$OUTDIR/clusteroperators.txt" 2>&1

oc_cluster "$CLUSTER" get clusteroperators -o json \
    > "$OUTDIR/clusteroperators.json" 2>&1

# Detectar operadores degradados
DEGRADED=$(oc_cluster "$CLUSTER" get co -o json 2>/dev/null \
    | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Degraded" and .status=="True")) | .metadata.name' \
    || true)

if [[ -n "$DEGRADED" ]]; then
    warn "[$CLUSTER] Operadores DEGRADADOS:"
    echo "$DEGRADED" | while read -r op; do warn "  → $op"; done
    echo "$DEGRADED" > "$OUTDIR/operators-degraded.txt"
else
    ok "[$CLUSTER] Todos los ClusterOperators saludables"
    echo "NONE" > "$OUTDIR/operators-degraded.txt"
fi

# Disponibilidad global del cluster
oc_cluster "$CLUSTER" get clusterversion -o jsonpath='{.items[0].status.conditions}' 2>/dev/null \
    | jq '.' > "$OUTDIR/clusterversion-conditions.json" 2>/dev/null || true

log "[$CLUSTER] cluster-health completado"
