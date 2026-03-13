#!/usr/bin/env bash
# =============================================================================
# Paso 1 — Discovery Fase 1: barrido del repositorio
# Busca: manifiestos OCP, DNS, F5, scripts, VIPs, hostnames, certs.
# Uso: desde deploy.sh o ./01_discover_repo.sh (con 00_env.sh cargado)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
mkdir -p "$OUTPUT_DIR"

REPORT="${OUTPUT_DIR}/discovery-repo-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee -a "$REPORT") 2>&1

echo "=== Discovery Repo ==="
echo "REPO_ROOT=$REPO_ROOT"
echo "OUTPUT_DIR=$OUTPUT_DIR"
echo ""

echo "--- 1. Manifiestos OpenShift/Kubernetes ---"
grep -r -l -E "kind:\s*(Route|Ingress|Certificate|Secret|ClusterDeployment|ManagedCluster)" "$REPO_ROOT" \
  --include="*.yaml" --include="*.yml" 2>/dev/null | grep -v ".git/" || true
echo ""

echo "--- 2. Referencias DNS / domain / hostname / baseDomain ---"
grep -r -n -E "baseDomain|hostname|\.apps\.|api\.|bancogalicia\.com\.ar|external-dns|Infoblox" "$REPO_ROOT" \
  --include="*.yaml" --include="*.yml" --include="*.md" --include="*.sh" 2>/dev/null | grep -v ".git/" | head -80
echo ""

echo "--- 3. Scripts y playbooks ---"
find "$REPO_ROOT" -type f \( -name "*.sh" -o -name "*.yml" -o -name "*.yaml" \) 2>/dev/null | grep -v ".git/" | head -60
echo ""

echo "--- 4. Referencias F5 / LTM / GTM / VIP ---"
grep -r -n -iE "F5|BIG-IP|BIGIP|ltm|gtm|VS-Paas|virtual\.server|pool\.|monitor\.|partition" "$REPO_ROOT" \
  --include="*.yaml" --include="*.yml" --include="*.md" --include="*.sh" 2>/dev/null | grep -v ".git/" | head -60
echo ""

echo "--- 5. Referencias srepg / arqlab ---"
grep -r -l -i "srepg\|arqlab" "$REPO_ROOT" 2>/dev/null | grep -v ".git/" | head -40
echo ""

echo "--- 6. VIPs (env.sh por cluster) ---"
for f in "$REPO_ROOT"/networking/cilium/deployment/clusters/*/env.sh 2>/dev/null; do
  [[ -f "$f" ]] || continue
  echo ">> $f"
  grep -E "CLUSTER_NAME|API_VIP|INGRESS_VIP|BASE_DOMAIN" "$f" 2>/dev/null || true
  echo ""
done
echo ""

echo "--- 7. Wildcard / certificados / ingress ---"
grep -r -n -iE "wildcard|certificate|ingress|route\.openshift" "$REPO_ROOT" \
  --include="*.yaml" --include="*.yml" --include="*.md" 2>/dev/null | grep -v ".git/" | head -40
echo ""

echo "=== Fin 01_discover_repo. Report: $REPORT ==="
