#!/usr/bin/env bash
# =============================================================================
# Helper interno: ejecuta todos los collectors para ambos clusters.
# Uso: ./_run-all.sh <phase> <base-outdir>
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

PHASE="${1:?Fase requerida (pre|during|post)}"
BASE_OUTDIR="${2:?Outdir requerido}"
COL_DIR="$(dirname "${BASH_SOURCE[0]}")"

TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')
echo "$TIMESTAMP — fase: $PHASE" > "$BASE_OUTDIR/run-timestamp.txt"

log "======== FASE: $PHASE — $(date '+%Y-%m-%d %H:%M:%S') ========"

for CLUSTER in "$CLUSTER_PGA" "$CLUSTER_CMZ"; do
    CLUSTER_OUTDIR="$BASE_OUTDIR/$CLUSTER"
    mkdir -p "$CLUSTER_OUTDIR"

    log "--- Cluster: $CLUSTER ---"

    "$COL_DIR/cluster-health.sh" "$CLUSTER" "$CLUSTER_OUTDIR/cluster-health"
    "$COL_DIR/nodes.sh"          "$CLUSTER" "$CLUSTER_OUTDIR/nodes"
    "$COL_DIR/pods.sh"           "$CLUSTER" "$CLUSTER_OUTDIR/pods"
    "$COL_DIR/ingress.sh"        "$CLUSTER" "$CLUSTER_OUTDIR/ingress"
    "$COL_DIR/events.sh"         "$CLUSTER" "$CLUSTER_OUTDIR/events"
    "$COL_DIR/apim-3scale.sh"    "$CLUSTER" "$CLUSTER_OUTDIR/apim-3scale"
    "$COL_DIR/audit.sh"          "$CLUSTER" "$CLUSTER_OUTDIR/audit" 30
done

# DNS snapshot (aplica a ambos clusters — refleja FQDN agnóstico)
"$COL_DIR/dns-check.sh" "$BASE_OUTDIR/dns"

# Estado F5 — pool members por site
"$COL_DIR/f5-status.sh" "$BASE_OUTDIR/f5"

log "======== Recolección $PHASE completada en $BASE_OUTDIR ========"
