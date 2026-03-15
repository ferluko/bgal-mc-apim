#!/usr/bin/env bash
# =============================================================================
# FASE DURANTE — Observación mientras CMZ está activo
# Condición esperada: CMZ activo / PGA pasivo
#
# Qué valida:
#   - CMZ recibe tráfico (router cargado, F5 VIPs habilitados en CMZ)
#   - PGA en stand-by (F5 VIPs deshabilitados)
#   - DNS resolviendo a IPs de CMZ
#   - Sin degradación en routers, pods, operadores de CMZ
#   - Detectar cambios manuales de squads durante el ejercicio
#
# Puede ejecutarse MÚLTIPLES veces durante el ejercicio para
# tener snapshots intermedios (ej: cada 5 minutos).
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
# Usar la carpeta del ejercicio en curso si existe, sino crear nueva
EXERCISE_DIR="${DRP_EXERCISE_DIR:-$REPORTS_DIR/$(date '+%Y%m%d-%H%M%S')}"
OUTDIR="$EXERCISE_DIR/during/$TIMESTAMP"
mkdir -p "$OUTDIR"

log "======================================================"
log "  FASE DURANTE — Snapshot $TIMESTAMP"
log "  Activo esperado: $CLUSTER_CMZ  |  Pasivo: $CLUSTER_PGA"
log "======================================================"

# Ejecutar todos los collectors
"$(dirname "${BASH_SOURCE[0]}")/../collectors/_run-all.sh" during "$OUTDIR"

# Validaciones específicas de la fase DURANTE
log ""
log "── Validaciones DURANTE ─────────────────────────────"

# 1. Verificar que DNS ya resolvió a CMZ
DNS_FILE=$(ls "$OUTDIR/dns/"dns-snapshot-*.txt 2>/dev/null | tail -1)
if [[ -n "$DNS_FILE" ]]; then
    DNS_IP=$(grep -A1 "dig +short" "$DNS_FILE" | tail -1 || echo "?")
    log "DNS $AGNOSTIC_FQDN → $DNS_IP"
    if [[ -n "$INGRESS_VIP_CMZ" ]] && echo "$DNS_IP" | grep -q "$INGRESS_VIP_CMZ"; then
        ok "DNS apunta a CMZ ✓"
    else
        warn "DNS aún NO apunta a CMZ (o INGRESS_VIP_CMZ no configurado)"
    fi
fi

# 2. Estado de routers en CMZ (debe estar activo)
ROUTER_CMZ="$OUTDIR/$CLUSTER_CMZ/ingress/router-pods-notrunning.txt"
if [[ -f "$ROUTER_CMZ" ]]; then
    CONTENT=$(cat "$ROUTER_CMZ")
    [[ "$CONTENT" == "NONE" ]] && ok "Routers CMZ: todos Running" || \
        warn "Routers CMZ con problemas: $CONTENT"
fi

# 3. Detectar cambios manuales detectados
for CLUSTER in "$CLUSTER_PGA" "$CLUSTER_CMZ"; do
    HUMAN_CHANGES=$(find "$OUTDIR/$CLUSTER/audit" -name "*human-changes.tsv" 2>/dev/null \
        | xargs -I{} grep -c "" {} 2>/dev/null | awk '{s+=$1} END {print s+0}')
    if [[ "${HUMAN_CHANGES:-0}" -gt 0 ]]; then
        warn "[$CLUSTER] $HUMAN_CHANGES cambios MANUALES detectados — revisar audit/"
    else
        ok "[$CLUSTER] Sin cambios manuales detectados"
    fi
done

# 4. Pods problemáticos en CMZ
NOTRUNNING_CMZ=$(grep -c "" "$OUTDIR/$CLUSTER_CMZ/pods/pods-notrunning.txt" 2>/dev/null || echo 0)
[[ "$NOTRUNNING_CMZ" -le 1 ]] && ok "Pods CMZ: OK" || \
    warn "CMZ — $NOTRUNNING_CMZ pods NO en Running"

log ""
log "Evidencia DURANTE almacenada en: $OUTDIR"
echo "$EXERCISE_DIR" > /tmp/drp-last-exercise-dir.txt
