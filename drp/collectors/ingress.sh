#!/usr/bin/env bash
# =============================================================================
# Collector: estado de ingress controllers y routers
# Señales: pods router caídos, IngressController degradado, errores de backend.
# Uso: ./ingress.sh <cluster> <outdir>
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../00_env.sh"

CLUSTER="${1:?Cluster requerido}"
OUTDIR="${2:?Outdir requerido}"
mkdir -p "$OUTDIR"

log "[$CLUSTER] ingress → $OUTDIR"

# IngressControllers
oc_cluster "$CLUSTER" get ingresscontroller -n openshift-ingress-operator -o wide \
    > "$OUTDIR/ingresscontrollers.txt" 2>&1

oc_cluster "$CLUSTER" get ingresscontroller -n openshift-ingress-operator -o json \
    > "$OUTDIR/ingresscontrollers.json" 2>&1

# Pods del router
oc_cluster "$CLUSTER" get pods -n openshift-ingress -o wide \
    > "$OUTDIR/router-pods.txt" 2>&1

# Routers no Running
ROUTER_NOTRUNNING=$(oc_cluster "$CLUSTER" get pods -n openshift-ingress --no-headers 2>/dev/null \
    | grep -v "Running" || true)

if [[ -n "$ROUTER_NOTRUNNING" ]]; then
    warn "[$CLUSTER] Pods de ROUTER no en Running:"
    echo "$ROUTER_NOTRUNNING" | while read -r line; do warn "  → $line"; done
    echo "$ROUTER_NOTRUNNING" > "$OUTDIR/router-pods-notrunning.txt"
else
    ok "[$CLUSTER] Todos los pods de router Running"
    echo "NONE" > "$OUTDIR/router-pods-notrunning.txt"
fi

# Describe IngressControllers (condiciones)
oc_cluster "$CLUSTER" describe ingresscontroller -n openshift-ingress-operator \
    > "$OUTDIR/ingresscontrollers-describe.txt" 2>&1 || true

# Endpoints del servicio de ingress (LoadBalancer/NodePort)
oc_cluster "$CLUSTER" get svc -n openshift-ingress \
    > "$OUTDIR/ingress-services.txt" 2>&1

# Logs recientes del router (últimas 200 líneas de cada pod)
ROUTER_PODS=$(oc_cluster "$CLUSTER" get pods -n openshift-ingress --no-headers 2>/dev/null \
    | awk '{print $1}' || true)

mkdir -p "$OUTDIR/router-logs"
while IFS= read -r pod; do
    [[ -z "$pod" ]] && continue
    oc_cluster "$CLUSTER" logs -n openshift-ingress "$pod" --tail=200 \
        > "$OUTDIR/router-logs/${pod}.txt" 2>&1 || true
done <<< "$ROUTER_PODS"

# Routes en estado degradado (rejected)
oc_cluster "$CLUSTER" get routes -A \
    > "$OUTDIR/routes-all.txt" 2>&1

oc_cluster "$CLUSTER" get routes -A -o json 2>/dev/null | jq -r '
    .items[] |
    .metadata.namespace as $ns |
    .metadata.name as $name |
    .status.ingress[]? |
    select(.conditions[]? | select(.type=="Admitted" and .status!="True")) |
    [$ns, $name, .host, "NOT_ADMITTED"] | @tsv
' > "$OUTDIR/routes-not-admitted.txt" 2>/dev/null || true

log "[$CLUSTER] ingress completado"
