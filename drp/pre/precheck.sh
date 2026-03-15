#!/usr/bin/env bash
# =============================================================================
# FASE PRE — Estado de referencia (baseline)
# Condición esperada: PGA activo / CMZ pasivo
#
# Qué valida:
#   - Ambos clusters saludables antes del ejercicio
#   - PGA recibiendo tráfico (router activo, F5 VIPs habilitados)
#   - CMZ en stand-by (sin tráfico ingress, F5 VIPs deshabilitados)
#   - DNS resolviendo a IPs de PGA
#   - Sin pods problemáticos ni operadores degradados
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
OUTDIR="$REPORTS_DIR/$TIMESTAMP/pre"
mkdir -p "$OUTDIR"

log "======================================================"
log "  FASE PRE — DRP Ejercicio — $TIMESTAMP"
log "  Activo: $CLUSTER_PGA  |  Pasivo: $CLUSTER_CMZ"
log "======================================================"

# Ejecutar todos los collectors
"$(dirname "${BASH_SOURCE[0]}")/../collectors/_run-all.sh" pre "$OUTDIR"

# Resumen rápido al finalizar
log ""
log "── Resumen PRE ──────────────────────────────────────"

for CLUSTER in "$CLUSTER_PGA" "$CLUSTER_CMZ"; do
    ROLE="ACTIVO"; [[ "$CLUSTER" == "$CLUSTER_CMZ" ]] && ROLE="PASIVO"
    log "Cluster $CLUSTER [$ROLE]:"

    DEGRADED=$(cat "$OUTDIR/$CLUSTER/cluster-health/operators-degraded.txt" 2>/dev/null || echo "?")
    NOTRUNNING=$(grep -c "" "$OUTDIR/$CLUSTER/pods/pods-notrunning.txt" 2>/dev/null || echo "?")
    WARN_EVENTS=$(grep -c "" "$OUTDIR/$CLUSTER/events/events-warning.txt" 2>/dev/null || echo "?")

    [[ "$DEGRADED" == "NONE" ]] && ok "  Operators: OK" || warn "  Operators degradados: $DEGRADED"
    [[ "$NOTRUNNING" -le 1 ]] && ok "  Pods: OK" || warn "  Pods problemáticos: $NOTRUNNING"
    log "  Warning events: $WARN_EVENTS"
done

DNS_FILE=$(ls "$OUTDIR/dns/"dns-snapshot-*.txt 2>/dev/null | tail -1)
if [[ -n "$DNS_FILE" ]]; then
    DNS_IP=$(grep -A1 "dig +short" "$DNS_FILE" | tail -1)
    log "DNS $AGNOSTIC_FQDN → $DNS_IP"
fi

log ""
log "Evidencia PRE almacenada en: $OUTDIR"
log "Listo para iniciar ejercicio DRP."
echo "$OUTDIR" > /tmp/drp-last-pre-outdir.txt
