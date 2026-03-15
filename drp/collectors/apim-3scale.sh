#!/usr/bin/env bash
# =============================================================================
# Collector: estado de 3scale / APIcast
# Namespace: amp (único namespace de toda la plataforma 3scale)
# Señales: pods caídos, APIcast errors, upstream failures, rate limit issues.
# Uso: ./apim-3scale.sh <cluster> <outdir>
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

CLUSTER="${1:?Cluster requerido}"
OUTDIR="${2:?Outdir requerido}"
NS_DIR="$OUTDIR/amp"
mkdir -p "$NS_DIR"

log "[$CLUSTER] 3scale (ns: $AMP_NS) → $NS_DIR"

# Verificar que el namespace existe
if ! oc_cluster "$CLUSTER" get namespace "$AMP_NS" &>/dev/null; then
    warn "[$CLUSTER] Namespace '$AMP_NS' no encontrado"
    echo "NAMESPACE_NOT_FOUND" > "$NS_DIR/status.txt"
    exit 0
fi

# Todos los pods del namespace
oc_cluster "$CLUSTER" get pods -n "$AMP_NS" -o wide \
    > "$NS_DIR/pods.txt" 2>&1

# Pods no Running
oc_cluster "$CLUSTER" get pods -n "$AMP_NS" --no-headers 2>/dev/null \
    | grep -Ev "(Running|Completed)" \
    > "$NS_DIR/pods-notrunning.txt" || echo "NONE" > "$NS_DIR/pods-notrunning.txt"

COUNT_NR=$(grep -vc "^NONE$" "$NS_DIR/pods-notrunning.txt" 2>/dev/null || echo 0)
if [[ "$COUNT_NR" -gt 0 ]]; then
    warn "[$CLUSTER/amp] $COUNT_NR pods NO en Running:"
    head -5 "$NS_DIR/pods-notrunning.txt" | while IFS= read -r l; do warn "  $l"; done
else
    ok "[$CLUSTER/amp] Todos los pods Running"
fi

# Deployments y replicas disponibles
oc_cluster "$CLUSTER" get deployment -n "$AMP_NS" \
    > "$NS_DIR/deployments.txt" 2>&1

oc_cluster "$CLUSTER" get deployment -n "$AMP_NS" -o json 2>/dev/null | jq -r '
    .items[] |
    select((.status.availableReplicas // 0) < .spec.replicas) |
    [.metadata.name,
     "desired:" + (.spec.replicas | tostring),
     "available:" + ((.status.availableReplicas // 0) | tostring)] | @tsv
' > "$NS_DIR/deployments-degraded.txt" 2>/dev/null || true

# Logs de APIcast (todas las instancias — staging y production)
APICAST_PODS=$(oc_cluster "$CLUSTER" get pods -n "$AMP_NS" --no-headers 2>/dev/null \
    | grep "apicast" | awk '{print $1}' || true)

mkdir -p "$NS_DIR/apicast-logs"
while IFS= read -r pod; do
    [[ -z "$pod" ]] && continue
    oc_cluster "$CLUSTER" logs -n "$AMP_NS" "$pod" --tail=300 \
        > "$NS_DIR/apicast-logs/${pod}.txt" 2>&1 || true

    # Errores críticos en APIcast: upstream failures, auth errors, rate limits
    grep -Ei "upstream|error|5[0-9]{2}|failed|timeout|refused|429|auth" \
        "$NS_DIR/apicast-logs/${pod}.txt" \
        > "$NS_DIR/apicast-logs/${pod}-errors.txt" 2>/dev/null || true

    COUNT_ERR=$(grep -c "" "$NS_DIR/apicast-logs/${pod}-errors.txt" 2>/dev/null || echo 0)
    [[ "$COUNT_ERR" -gt 0 ]] && warn "[$CLUSTER/amp] $pod: $COUNT_ERR errores en logs"
done <<< "$APICAST_PODS"

# Logs de system-app (backend 3scale)
SYSAPP_PODS=$(oc_cluster "$CLUSTER" get pods -n "$AMP_NS" --no-headers 2>/dev/null \
    | grep "system-app" | awk '{print $1}' || true)

mkdir -p "$NS_DIR/system-app-logs"
while IFS= read -r pod; do
    [[ -z "$pod" ]] && continue
    oc_cluster "$CLUSTER" logs -n "$AMP_NS" "$pod" --tail=200 \
        > "$NS_DIR/system-app-logs/${pod}.txt" 2>&1 || true
done <<< "$SYSAPP_PODS"

# Routes expuestas por 3scale
oc_cluster "$CLUSTER" get routes -n "$AMP_NS" \
    > "$NS_DIR/routes.txt" 2>&1

# Events del namespace amp
oc_cluster "$CLUSTER" get events -n "$AMP_NS" \
    --sort-by='.lastTimestamp' \
    > "$NS_DIR/events.txt" 2>&1

# ConfigMaps relevantes
oc_cluster "$CLUSTER" get cm -n "$AMP_NS" \
    > "$NS_DIR/configmaps.txt" 2>&1

# Readiness de componentes críticos
for deploy in apicast-production apicast-staging system-app system-sidekiq backend-listener backend-worker; do
    READY=$(oc_cluster "$CLUSTER" get deployment -n "$AMP_NS" "$deploy" \
        -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "N/A")
    DESIRED=$(oc_cluster "$CLUSTER" get deployment -n "$AMP_NS" "$deploy" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "N/A")
    if [[ "$READY" == "$DESIRED" && "$READY" != "N/A" ]]; then
        ok "  [$CLUSTER/amp] $deploy: $READY/$DESIRED"
    else
        warn "  [$CLUSTER/amp] $deploy: $READY/$DESIRED ← DEGRADADO"
    fi
done >> "$NS_DIR/components-readiness.txt" 2>&1 || true

log "[$CLUSTER] 3scale/amp completado"
