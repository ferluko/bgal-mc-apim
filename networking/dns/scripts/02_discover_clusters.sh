#!/usr/bin/env bash
# =============================================================================
# Paso 2 — Discovery Fase 2: clusters OpenShift (srepg, arqlab)
# Requiere: oc en PATH y sesión en cada cluster (o KUBECONFIG con contextos).
# Uso: desde deploy.sh o ./02_discover_clusters.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
mkdir -p "$OUTPUT_DIR"

report_cluster() {
  local name="$1"
  local kc="${2:-}"
  local out="$OUTPUT_DIR/discovery-cluster-${name}-$(date +%Y%m%d-%H%M%S).txt"
  export KUBECONFIG="${kc}"

  echo "=== Discovery cluster: $name ===" | tee "$out"
  if ! oc whoami &>/dev/null; then
    echo "  ERROR: No hay sesión oc para $name (KUBECONFIG=${kc:-default})" | tee -a "$out"
    echo "  Ejemplo: oc login https://api.${name}.${BASE_DOMAIN}:6443 -u <user>" | tee -a "$out"
    return 1
  fi

  echo "" | tee -a "$out"
  echo "--- Versión OpenShift ---" | tee -a "$out"
  oc version 2>/dev/null | tee -a "$out" || true
  oc get clusterversion version -o wide 2>/dev/null | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "--- IngressControllers ---" | tee -a "$out"
  oc get ingresscontroller -n openshift-ingress-operator -o wide 2>/dev/null | tee -a "$out" || true
  oc get ingresscontroller -n openshift-ingress-operator -o yaml 2>/dev/null | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "--- Routes (all namespaces) ---" | tee -a "$out"
  oc get routes -A 2>/dev/null | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "--- Wildcard / default domain ---" | tee -a "$out"
  oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.domain}' 2>/dev/null | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "--- Certificados (openshift-ingress) ---" | tee -a "$out"
  oc get certificate -n openshift-ingress 2>/dev/null | tee -a "$out" || true
  oc get secret -n openshift-ingress 2>/dev/null | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "--- Namespaces ---" | tee -a "$out"
  oc get ns 2>/dev/null | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "--- Operadores (F5/CIS) ---" | tee -a "$out"
  oc get csv -A 2>/dev/null | grep -iE "f5|cis|bigip|ingress" || true | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "--- Servicios (LoadBalancer/NodePort) ---" | tee -a "$out"
  oc get svc -A -o wide 2>/dev/null | grep -E "LoadBalancer|NodePort" | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "--- Router / ingress ---" | tee -a "$out"
  oc get svc -n openshift-ingress 2>/dev/null | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "--- Endpoints candidatos LTM ---" | tee -a "$out"
  oc get svc router-default -n openshift-ingress -o jsonpath='{.status.loadBalancer.ingress}' 2>/dev/null | tee -a "$out" || true
  echo "" | tee -a "$out"
  echo "  Report: $out" | tee -a "$out"
  return 0
}

echo "=== Discovery clusters (CLUSTERS=$CLUSTERS) ==="
for c in $CLUSTERS; do
  report_cluster "$c" "${KUBECONFIG:-}" || true
done
echo "=== Fin 02_discover_clusters. Output: $OUTPUT_DIR ==="
