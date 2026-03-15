#!/usr/bin/env bash
# =============================================================================
# Collector: audit logs del API server
# Señales: cambios manuales de squads (patch/update/delete/create/scale).
# Uso: ./audit.sh <cluster> <outdir> [minutos]
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

CLUSTER="${1:?Cluster requerido}"
OUTDIR="${2:?Outdir requerido}"
MINUTES="${3:-60}"   # últimos N minutos de audit logs
mkdir -p "$OUTDIR"

log "[$CLUSTER] audit → $OUTDIR (últimos ${MINUTES} min)"

# Captura de audit log del openshift-apiserver
oc_cluster "$CLUSTER" adm node-logs \
    --role=master \
    --path=openshift-apiserver/audit.log \
    > "$OUTDIR/audit-openshift-apiserver-raw.log" 2>&1 || \
    warn "[$CLUSTER] No se pudo obtener audit log de openshift-apiserver"

# Captura del kube-apiserver audit log
oc_cluster "$CLUSTER" adm node-logs \
    --role=master \
    --path=kube-apiserver/audit.log \
    > "$OUTDIR/audit-kube-apiserver-raw.log" 2>&1 || \
    warn "[$CLUSTER] No se pudo obtener audit log de kube-apiserver"

# Filtrar solo operaciones de escritura (no GET/WATCH/LIST)
for f in "$OUTDIR"/audit-*-raw.log; do
    [[ -f "$f" ]] || continue
    BASE=$(basename "$f" -raw.log)
    grep -E '"verb":"(patch|update|delete|create|deletecollection)"' "$f" \
        > "$OUTDIR/${BASE}-writes.log" 2>/dev/null || true
done

# Extraer cambios relevantes con jq (usuario, acción, recurso)
for f in "$OUTDIR"/audit-*-writes.log; do
    [[ -f "$f" ]] || continue
    BASE=$(basename "$f" -writes.log)
    # Parsear línea a línea (cada línea es un JSON)
    while IFS= read -r line; do
        echo "$line" | jq -r '
            [.requestReceivedTimestamp,
             .user.username,
             .verb,
             .objectRef.resource,
             ((.objectRef.namespace // "-") + "/" + (.objectRef.name // "-")),
             (.responseStatus.code | tostring)] | @tsv
        ' 2>/dev/null
    done < "$f" | sort > "$OUTDIR/${BASE}-summary.tsv" 2>/dev/null || true
done

# Detectar usuarios no-system que realizaron cambios
for f in "$OUTDIR"/audit-*-summary.tsv; do
    [[ -f "$f" ]] || continue
    BASE=$(basename "$f" -summary.tsv)
    grep -Ev "system:|serviceaccount:" "$f" \
        > "$OUTDIR/${BASE}-human-changes.tsv" 2>/dev/null || true

    COUNT=$(grep -c "" "$OUTDIR/${BASE}-human-changes.tsv" 2>/dev/null || echo 0)
    if [[ "$COUNT" -gt 0 ]]; then
        warn "[$CLUSTER] $COUNT cambios manuales detectados en ${BASE}:"
        head -5 "$OUTDIR/${BASE}-human-changes.tsv" | while IFS= read -r line; do
            warn "  $line"
        done
    fi
done

log "[$CLUSTER] audit completado"
