#!/usr/bin/env bash
# =============================================================================
# FASE POST — Validación de retorno a normalidad
# Condición esperada: PGA activo / CMZ pasivo (igual que PRE)
#
# Qué valida:
#   - DNS volvió a resolver a IPs de PGA
#   - F5 VIPs habilitados en PGA, deshabilitados en CMZ
#   - Operadores y pods de PGA saludables
#   - Sin pods en CrashLoop después del failback
#   - Eventos post-ejercicio analizados
#   - Diff de cambios vs PRE (detecta qué cambió durante el ejercicio)
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
EXERCISE_DIR="${DRP_EXERCISE_DIR:-$REPORTS_DIR/$(date '+%Y%m%d-%H%M%S')}"
OUTDIR="$EXERCISE_DIR/post"
PRE_DIR="$EXERCISE_DIR/pre"
mkdir -p "$OUTDIR"

log "======================================================"
log "  FASE POST — Validación retorno — $TIMESTAMP"
log "  Activo: $CLUSTER_PGA  |  Pasivo: $CLUSTER_CMZ"
log "======================================================"

# Ejecutar todos los collectors
"$(dirname "${BASH_SOURCE[0]}")/../collectors/_run-all.sh" post "$OUTDIR"

# Validaciones post-ejercicio
log ""
log "── Validaciones POST ────────────────────────────────"

# 1. DNS debe apuntar nuevamente a PGA
DNS_FILE=$(ls "$OUTDIR/dns/"dns-snapshot-*.txt 2>/dev/null | tail -1)
if [[ -n "$DNS_FILE" ]]; then
    DNS_IP=$(grep -A1 "dig +short" "$DNS_FILE" | tail -1 || echo "?")
    log "DNS $AGNOSTIC_FQDN → $DNS_IP"
    if [[ -n "$INGRESS_VIP_PGA" ]] && echo "$DNS_IP" | grep -q "$INGRESS_VIP_PGA"; then
        ok "DNS restaurado a PGA ✓"
    else
        warn "DNS aún NO apunta a PGA (verificar manualmente)"
    fi
fi

# 2. Estado de operadores en PGA
for CLUSTER in "$CLUSTER_PGA" "$CLUSTER_CMZ"; do
    ROLE="ACTIVO"; [[ "$CLUSTER" == "$CLUSTER_CMZ" ]] && ROLE="PASIVO"
    DEGRADED=$(cat "$OUTDIR/$CLUSTER/cluster-health/operators-degraded.txt" 2>/dev/null || echo "?")
    [[ "$DEGRADED" == "NONE" ]] && ok "[$CLUSTER/$ROLE] Operators: OK" || \
        warn "[$CLUSTER/$ROLE] Operators degradados: $DEGRADED"
done

# 3. Pods problemáticos post-ejercicio
for CLUSTER in "$CLUSTER_PGA" "$CLUSTER_CMZ"; do
    NOTRUNNING=$(grep -c "" "$OUTDIR/$CLUSTER/pods/pods-notrunning.txt" 2>/dev/null || echo 0)
    [[ "$NOTRUNNING" -le 1 ]] && ok "[$CLUSTER] Pods: OK" || \
        warn "[$CLUSTER] $NOTRUNNING pods NO en estado Running"
done

# 4. Diff de pods entre PRE y POST (detecta qué quedó diferente)
if [[ -d "$PRE_DIR" ]]; then
    log ""
    log "── Diff PRE vs POST ─────────────────────────────────"
    for CLUSTER in "$CLUSTER_PGA" "$CLUSTER_CMZ"; do
        PRE_PODS="$PRE_DIR/$CLUSTER/pods/pods-all.txt"
        POST_PODS="$OUTDIR/$CLUSTER/pods/pods-all.txt"
        if [[ -f "$PRE_PODS" && -f "$POST_PODS" ]]; then
            diff "$PRE_PODS" "$POST_PODS" \
                > "$OUTDIR/$CLUSTER/pods/diff-pre-post.txt" 2>/dev/null || \
                log "[$CLUSTER] Cambios en pods vs PRE → $OUTDIR/$CLUSTER/pods/diff-pre-post.txt"
        fi

        # Diff de operadores
        PRE_CO="$PRE_DIR/$CLUSTER/cluster-health/clusteroperators.txt"
        POST_CO="$OUTDIR/$CLUSTER/cluster-health/clusteroperators.txt"
        if [[ -f "$PRE_CO" && -f "$POST_CO" ]]; then
            diff "$PRE_CO" "$POST_CO" \
                > "$OUTDIR/$CLUSTER/cluster-health/diff-pre-post.txt" 2>/dev/null || \
                log "[$CLUSTER] Cambios en operators vs PRE → ver diff-pre-post.txt"
        fi
    done
fi

# 5. Resumen de cambios manuales detectados durante TODO el ejercicio
log ""
log "── Cambios manuales (exercise summary) ──────────────"
find "$EXERCISE_DIR" -name "*human-changes.tsv" 2>/dev/null | while read -r f; do
    COUNT=$(grep -c "" "$f" 2>/dev/null || echo 0)
    [[ "$COUNT" -gt 0 ]] && warn "$(echo "$f" | sed "s|$EXERCISE_DIR/||"): $COUNT cambios"
done

# 6. Generar checklist de validación post-ejercicio
CHECKLIST="$OUTDIR/validation-checklist.txt"
{
    echo "=== CHECKLIST DRP EXERCISE — $TIMESTAMP ==="
    echo ""
    echo "PLATAFORMA"
    echo "[ ] ClusterOperators PGA todos healthy"
    echo "[ ] ClusterOperators CMZ todos healthy"
    echo "[ ] Nodos PGA todos Ready"
    echo "[ ] Nodos CMZ todos Ready"
    echo "[ ] Pods PGA — ninguno en CrashLoop/Pending"
    echo "[ ] Pods CMZ — ninguno en CrashLoop/Pending"
    echo ""
    echo "TRÁFICO"
    echo "[ ] F5 VIPs habilitados en PGA"
    echo "[ ] F5 VIPs deshabilitados en CMZ"
    echo "[ ] DNS $AGNOSTIC_FQDN → IPs de PGA"
    echo "[ ] Routers PGA: todos Running"
    echo ""
    echo "APIM"
    echo "[ ] 3scale pods Running en PGA"
    echo "[ ] APIcast respondiendo en PGA"
    echo ""
    echo "AUDIT"
    echo "[ ] Cambios manuales de squads revisados y aprobados"
    echo "[ ] Sin cambios no autorizados en producción"
    echo ""
    echo "EVIDENCIA"
    echo "[ ] Carpeta PRE capturada: $PRE_DIR"
    echo "[ ] Carpeta DURANTE capturada: $EXERCISE_DIR/during/"
    echo "[ ] Carpeta POST capturada: $OUTDIR"
    echo "[ ] Timeline del ejercicio documentado"
} > "$CHECKLIST"

log ""
log "Checklist generado: $CHECKLIST"
log "Evidencia POST almacenada en: $OUTDIR"
log ""
ok "====== EJERCICIO DRP COMPLETO ======"
