#!/usr/bin/env bash
# =============================================================================
# Paso 3 — Discovery Fase 3 (LTM) y 4 (GTM): F5 BIG-IP
# Variables: F5_HOST, F5_USER, F5_PASSWORD (o F5_TOKEN).
# Para varios F5: invocar desde deploy.sh con F5_HOST distinto o usar F5_HOSTS.
# Uso: desde deploy.sh o F5_HOST=10.0.0.1 F5_USER=admin F5_PASSWORD=xxx ./03_discover_f5.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
mkdir -p "$OUTPUT_DIR"
TS=$(date +%Y%m%d-%H%M%S)

F5_HOST="${F5_HOST:-}"
F5_USER="${F5_USER:-admin}"
F5_PASSWORD="${F5_PASSWORD:-}"
F5_TOKEN="${F5_TOKEN:-}"
F5_PARTITION="${F5_PARTITION:-}"

if [[ -z "$F5_HOST" ]]; then
  echo "F5_HOST no definido. Uso: F5_HOST=<ip|fqdn> F5_USER=admin F5_PASSWORD=xxx $0"
  echo "Discovery F5 omitido (placeholders en $OUTPUT_DIR)."
  echo '{"error":"F5_HOST not set","virtual_servers":[],"pools":[],"monitors":[]}' > "$OUTPUT_DIR/discovery-f5-ltm-$TS.json"
  echo '{"error":"F5_HOST not set","wide_ips":[]}' > "$OUTPUT_DIR/discovery-f5-gtm-$TS.json"
  exit 0
fi

if [[ -n "$F5_TOKEN" ]]; then
  AUTH_HEADER="Authorization: Bearer $F5_TOKEN"
else
  AUTH_HEADER="Authorization: Basic $(echo -n "${F5_USER}:${F5_PASSWORD}" | base64)"
fi
BASE_URL="https://${F5_HOST}/mgmt/tm"
CURL_OPTS=(-s -k -H "Content-Type: application/json" -H "$AUTH_HEADER")

if ! command -v jq &>/dev/null; then
  echo "AVISO: jq no encontrado; instalar jq para salida JSON."
fi

list_ltm() {
  local path="$1"
  curl "${CURL_OPTS[@]}" "${BASE_URL}/ltm/${path}" 2>/dev/null | jq -r '.items[]? // empty | .fullPath // .name // .' 2>/dev/null || true
}

echo "=== Discovery F5 LTM ($F5_HOST) ==="
echo "--- Partitions ---"
curl "${CURL_OPTS[@]}" "${BASE_URL}/ltm/virtual" 2>/dev/null | jq -r '.items[]? | .partition' 2>/dev/null | sort -u | tee "$OUTPUT_DIR/discovery-f5-partitions-$TS.txt" || true
echo "--- Virtual Servers ---"
curl "${CURL_OPTS[@]}" "${BASE_URL}/ltm/virtual" 2>/dev/null | jq '.' > "$OUTPUT_DIR/discovery-f5-virtual-$TS.json" 2>/dev/null || true
list_ltm "virtual" | tee "$OUTPUT_DIR/discovery-f5-virtual-list-$TS.txt" || true
echo "--- Pools ---"
curl "${CURL_OPTS[@]}" "${BASE_URL}/ltm/pool" 2>/dev/null | jq '.' > "$OUTPUT_DIR/discovery-f5-pools-$TS.json" 2>/dev/null || true
list_ltm "pool" | tee "$OUTPUT_DIR/discovery-f5-pools-list-$TS.txt" || true
echo "--- Pool members ---"
for pool in $(list_ltm "pool"); do
  enc=$(echo -n "$pool" | jq -sRr @uri 2>/dev/null || echo "$pool")
  curl "${CURL_OPTS[@]}" "${BASE_URL}/ltm/pool/~${enc}/members" 2>/dev/null | jq '.' > "$OUTPUT_DIR/discovery-f5-pool-members-${pool//\//-}-$TS.json" 2>/dev/null || true
done
echo "--- Monitors ---"
curl "${CURL_OPTS[@]}" "${BASE_URL}/ltm/monitor" 2>/dev/null | jq '.' > "$OUTPUT_DIR/discovery-f5-monitors-$TS.json" 2>/dev/null || true
echo "--- SSL / SNAT / iRules ---"
curl "${CURL_OPTS[@]}" "${BASE_URL}/ltm/profile/server-ssl" 2>/dev/null | jq '.items[]? | {name, partition}' 2>/dev/null || true
curl "${CURL_OPTS[@]}" "${BASE_URL}/ltm/snat" 2>/dev/null | jq '.items[]? | {name, partition}' 2>/dev/null || true
curl "${CURL_OPTS[@]}" "${BASE_URL}/ltm/rule" 2>/dev/null | jq '.items[]? | {name, partition}' 2>/dev/null || true

ltm_report="$OUTPUT_DIR/discovery-f5-ltm-$TS.json"
if command -v jq &>/dev/null; then
  echo "{\"host\":\"$F5_HOST\",\"ts\":\"$TS\",\"virtual_servers_file\":\"discovery-f5-virtual-$TS.json\",\"pools_file\":\"discovery-f5-pools-$TS.json\"}" | jq '.' > "$ltm_report" 2>/dev/null || true
fi
echo "LTM report: $ltm_report"

echo ""
echo "=== Discovery F5 GTM ==="
GTM_WIDE=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/gtm/wideip" 2>/dev/null) || true
gtm_report="$OUTPUT_DIR/discovery-f5-gtm-$TS.json"
if echo "$GTM_WIDE" | jq -e '.items' &>/dev/null; then
  echo "$GTM_WIDE" | jq '.' > "$OUTPUT_DIR/discovery-f5-wideip-$TS.json"
  echo "$GTM_WIDE" | jq -r '.items[]? | .fullPath // .name'
  curl "${CURL_OPTS[@]}" "${BASE_URL}/gtm/pool" 2>/dev/null | jq '.' > "$OUTPUT_DIR/discovery-f5-gtm-pools-$TS.json" 2>/dev/null || true
  curl "${CURL_OPTS[@]}" "${BASE_URL}/gtm/datacenter" 2>/dev/null | jq '.' > "$OUTPUT_DIR/discovery-f5-datacenter-$TS.json" 2>/dev/null || true
  echo '{"host":"'"$F5_HOST"'","gtm_available":true}' | jq '.' > "$gtm_report" 2>/dev/null || true
else
  echo "  GTM no disponible o sin licencia."
  echo '{"host":"'"$F5_HOST"'","gtm_available":false}' | jq '.' > "$gtm_report" 2>/dev/null || true
fi
echo "GTM report: $gtm_report"

echo ""
echo "--- Device group / HA ---"
curl "${CURL_OPTS[@]}" "https://${F5_HOST}/mgmt/tm/cm/device-group" 2>/dev/null | jq '.items[]? | {name, type}' 2>/dev/null || true
echo "=== Fin 03_discover_f5. Output: $OUTPUT_DIR ==="
