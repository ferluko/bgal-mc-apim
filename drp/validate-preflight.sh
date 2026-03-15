#!/usr/bin/env bash
# =============================================================================
# PREFLIGHT VALIDATION — Ejercicio DRP
# Banco Galicia — OCP paas-prdpg / paas-prdmz + F5 LTM
#
# OBJETIVO: validar ANTES del ejercicio que todo el framework funciona.
#           Solo lectura. No modifica nada en clusters ni en F5.
#
# Uso:
#   ./validate-preflight.sh            # usa 00_credentials.env si existe
#   ./validate-preflight.sh --report   # genera reporte en reports/preflight-<ts>.txt
#
# Requiere: oc, jq, curl, dig
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDS_FILE="$SCRIPT_DIR/00_credentials.env"
REPORT_MODE=false
[[ "${1:-}" == "--report" ]] && REPORT_MODE=true

# ---------------------------------------------------------------------------
# Colores
# ---------------------------------------------------------------------------
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0
REPORT_LINES=()

ts()   { date '+%H:%M:%S'; }
log()  { echo -e "${CYAN}[$(ts)]${NC} $*"; }
ok()   { echo -e "${GREEN}[PASS $(ts)]${NC} $*"; PASS=$((PASS+1)); REPORT_LINES+=("PASS | $*"); }
fail() { echo -e "${RED}[FAIL $(ts)]${NC} $*"; FAIL=$((FAIL+1)); REPORT_LINES+=("FAIL | $*"); }
warn() { echo -e "${YELLOW}[WARN $(ts)]${NC} $*"; WARN=$((WARN+1)); REPORT_LINES+=("WARN | $*"); }
section() {
    echo ""
    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  $*${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
    REPORT_LINES+=("" "=== $* ===")
}

# ---------------------------------------------------------------------------
# Cargar credenciales
# ---------------------------------------------------------------------------
if [[ -f "$CREDS_FILE" ]]; then
    source "$CREDS_FILE"
    log "Credenciales cargadas desde $CREDS_FILE"
else
    warn "00_credentials.env no encontrado — usando variables de entorno"
fi

# Verificar que las variables necesarias estén definidas
OCP_TOKEN_PGA="${OCP_TOKEN_PGA:-}"
OCP_SERVER_PGA="${OCP_SERVER_PGA:-}"
OCP_TOKEN_CMZ="${OCP_TOKEN_CMZ:-}"
OCP_SERVER_CMZ="${OCP_SERVER_CMZ:-}"
F5_HOST="${F5_HOST:-}"
F5_USER="${F5_USER:-admin}"
F5_PASSWORD="${F5_PASSWORD:-}"

# ---------------------------------------------------------------------------
# Kubeconfigs temporales (no tocar el ~/.kube/config del sistema)
# ---------------------------------------------------------------------------
KUBECONFIG_TMP_PGA="/tmp/kubeconfig-drp-prdpg-$$"
KUBECONFIG_TMP_CMZ="/tmp/kubeconfig-drp-prdmz-$$"
cleanup() { rm -f "$KUBECONFIG_TMP_PGA" "$KUBECONFIG_TMP_CMZ"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# SECCIÓN 1 — Herramientas requeridas
# ---------------------------------------------------------------------------
section "1. Herramientas del sistema"

check_tool() {
    local tool="$1"
    local version_flag="${2:---version}"
    if command -v "$tool" &>/dev/null; then
        VER=$("$tool" $version_flag 2>&1 | head -1 || true)
        ok "$tool → $VER"
    else
        fail "$tool — NO ENCONTRADO (requerido)"
    fi
}

check_tool oc   version
check_tool jq   --version
check_tool curl --version
check_tool dig  -v
check_tool python3 --version

# ---------------------------------------------------------------------------
# SECCIÓN 2 — Variables de entorno / credenciales
# ---------------------------------------------------------------------------
section "2. Variables de configuración"

check_var() {
    local name="$1"; local val="$2"; local sensitive="${3:-false}"
    if [[ -n "$val" ]]; then
        if [[ "$sensitive" == "true" ]]; then
            ok "$name → ${val:0:12}... (${#val} chars)"
        else
            ok "$name → $val"
        fi
    else
        fail "$name → NO DEFINIDO"
    fi
}

check_var "OCP_TOKEN_PGA"   "$OCP_TOKEN_PGA"  true
check_var "OCP_SERVER_PGA"  "$OCP_SERVER_PGA" false
check_var "OCP_TOKEN_CMZ"   "$OCP_TOKEN_CMZ"  true
check_var "OCP_SERVER_CMZ"  "$OCP_SERVER_CMZ" false
check_var "F5_HOST"         "$F5_HOST"        false
check_var "F5_USER"         "$F5_USER"        false
check_var "F5_PASSWORD"     "$F5_PASSWORD"    true

# ---------------------------------------------------------------------------
# SECCIÓN 3 — Conectividad de red (API endpoints)
# ---------------------------------------------------------------------------
section "3. Conectividad de red"

check_tcp() {
    local label="$1"; local host="$2"; local port="$3"
    if curl -sk --connect-timeout 5 --max-time 8 "https://${host}:${port}/" -o /dev/null 2>/dev/null; then
        ok "TCP $label → ${host}:${port} alcanzable"
    elif curl -sk --connect-timeout 5 --max-time 8 -o /dev/null -w "%{http_code}" \
            "https://${host}:${port}/" 2>/dev/null | grep -qE "^[0-9]"; then
        ok "TCP $label → ${host}:${port} alcanzable (con respuesta HTTP)"
    else
        # intentar solo connect
        if timeout 6 bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
            ok "TCP $label → ${host}:${port} puerto abierto"
        else
            fail "TCP $label → ${host}:${port} NO alcanzable"
        fi
    fi
}

PGA_HOST=$(echo "$OCP_SERVER_PGA" | sed 's|https://||' | cut -d: -f1)
PGA_PORT=$(echo "$OCP_SERVER_PGA" | sed 's|https://||' | cut -d: -f2)
CMZ_HOST=$(echo "$OCP_SERVER_CMZ" | sed 's|https://||' | cut -d: -f1)
CMZ_PORT=$(echo "$OCP_SERVER_CMZ" | sed 's|https://||' | cut -d: -f2)

check_tcp "API PGA ($CLUSTER_PGA 2>/dev/null || echo paas-prdpg)" "$PGA_HOST" "${PGA_PORT:-6443}"
check_tcp "API CMZ (paas-prdmz)" "$CMZ_HOST" "${CMZ_PORT:-6443}"
check_tcp "F5 iControl REST" "$F5_HOST" "443"

# ---------------------------------------------------------------------------
# SECCIÓN 4 — Login OCP cluster PGA
# ---------------------------------------------------------------------------
section "4. Login OCP — paas-prdpg (PGA)"

if [[ -z "$OCP_TOKEN_PGA" || -z "$OCP_SERVER_PGA" ]]; then
    fail "Token o server PGA no definidos — saltando checks OCP PGA"
else
    log "Login PGA → $OCP_SERVER_PGA"
    if KUBECONFIG="$KUBECONFIG_TMP_PGA" oc login \
            --token="$OCP_TOKEN_PGA" \
            --server="$OCP_SERVER_PGA" \
            --insecure-skip-tls-verify=true \
            2>/dev/null; then
        ok "Login PGA exitoso"
    else
        fail "Login PGA FALLIDO — token expirado o server inaccesible"
    fi

    if [[ -f "$KUBECONFIG_TMP_PGA" ]]; then
        # whoami
        WHO=$(KUBECONFIG="$KUBECONFIG_TMP_PGA" oc whoami 2>/dev/null || echo "ERROR")
        [[ "$WHO" != "ERROR" ]] && ok "PGA whoami → $WHO" || fail "PGA oc whoami falló"

        # ClusterVersion
        CV=$(KUBECONFIG="$KUBECONFIG_TMP_PGA" oc get clusterversion version \
            -o jsonpath='{.status.desired.version}' 2>/dev/null || echo "ERROR")
        [[ "$CV" != "ERROR" ]] && ok "PGA OCP version → $CV" || fail "PGA oc get clusterversion falló"

        # Nodos
        NODE_COUNT=$(KUBECONFIG="$KUBECONFIG_TMP_PGA" oc get nodes --no-headers 2>/dev/null \
            | wc -l | tr -d ' ' || echo 0)
        NOT_READY=$(KUBECONFIG="$KUBECONFIG_TMP_PGA" oc get nodes --no-headers 2>/dev/null \
            | grep -v " Ready" | wc -l | tr -d ' ' || echo 0)
        ok "PGA nodos totales → $NODE_COUNT"
        [[ "$NOT_READY" -eq 0 ]] && ok "PGA nodos NotReady → 0" || \
            warn "PGA nodos NotReady → $NOT_READY"

        # ClusterOperators degradados
        DEGRADED=$(KUBECONFIG="$KUBECONFIG_TMP_PGA" oc get co -o json 2>/dev/null \
            | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Degraded" and .status=="True")) | .metadata.name' \
            2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "")
        [[ -z "$DEGRADED" ]] && ok "PGA ClusterOperators → todos healthy" || \
            warn "PGA ClusterOperators degradados → $DEGRADED"

        # Pods no Running (rápido — solo openshift-ingress y amp)
        for NS in openshift-ingress amp; do
            NOTRUNNING=$(KUBECONFIG="$KUBECONFIG_TMP_PGA" oc get pods -n "$NS" \
                --no-headers 2>/dev/null \
                | grep -Evc "(Running|Completed|Succeeded)" || echo 0)
            [[ "$NOTRUNNING" -eq 0 ]] && ok "PGA ns/$NS → pods OK" || \
                warn "PGA ns/$NS → $NOTRUNNING pods no-Running"
        done

        # IngressController
        IC_STATUS=$(KUBECONFIG="$KUBECONFIG_TMP_PGA" oc get ingresscontroller default \
            -n openshift-ingress-operator \
            -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null \
            || echo "Unknown")
        [[ "$IC_STATUS" == "True" ]] && ok "PGA IngressController default → Available" || \
            warn "PGA IngressController default → $IC_STATUS"

        # Exportar kubeconfig path para uso posterior
        cp "$KUBECONFIG_TMP_PGA" "/tmp/kubeconfig-prdpg"
        ok "PGA kubeconfig guardado → /tmp/kubeconfig-prdpg"
    fi
fi

# ---------------------------------------------------------------------------
# SECCIÓN 5 — Login OCP cluster CMZ
# ---------------------------------------------------------------------------
section "5. Login OCP — paas-prdmz (CMZ)"

if [[ -z "$OCP_TOKEN_CMZ" || -z "$OCP_SERVER_CMZ" ]]; then
    fail "Token o server CMZ no definidos — saltando checks OCP CMZ"
else
    log "Login CMZ → $OCP_SERVER_CMZ"
    if KUBECONFIG="$KUBECONFIG_TMP_CMZ" oc login \
            --token="$OCP_TOKEN_CMZ" \
            --server="$OCP_SERVER_CMZ" \
            --insecure-skip-tls-verify=true \
            2>/dev/null; then
        ok "Login CMZ exitoso"
    else
        fail "Login CMZ FALLIDO — token expirado o server inaccesible"
    fi

    if [[ -f "$KUBECONFIG_TMP_CMZ" ]]; then
        WHO=$(KUBECONFIG="$KUBECONFIG_TMP_CMZ" oc whoami 2>/dev/null || echo "ERROR")
        [[ "$WHO" != "ERROR" ]] && ok "CMZ whoami → $WHO" || fail "CMZ oc whoami falló"

        CV=$(KUBECONFIG="$KUBECONFIG_TMP_CMZ" oc get clusterversion version \
            -o jsonpath='{.status.desired.version}' 2>/dev/null || echo "ERROR")
        [[ "$CV" != "ERROR" ]] && ok "CMZ OCP version → $CV" || fail "CMZ oc get clusterversion falló"

        NODE_COUNT=$(KUBECONFIG="$KUBECONFIG_TMP_CMZ" oc get nodes --no-headers 2>/dev/null \
            | wc -l | tr -d ' ' || echo 0)
        NOT_READY=$(KUBECONFIG="$KUBECONFIG_TMP_CMZ" oc get nodes --no-headers 2>/dev/null \
            | grep -v " Ready" | wc -l | tr -d ' ' || echo 0)
        ok "CMZ nodos totales → $NODE_COUNT"
        [[ "$NOT_READY" -eq 0 ]] && ok "CMZ nodos NotReady → 0" || \
            warn "CMZ nodos NotReady → $NOT_READY"

        DEGRADED=$(KUBECONFIG="$KUBECONFIG_TMP_CMZ" oc get co -o json 2>/dev/null \
            | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Degraded" and .status=="True")) | .metadata.name' \
            2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "")
        [[ -z "$DEGRADED" ]] && ok "CMZ ClusterOperators → todos healthy" || \
            warn "CMZ ClusterOperators degradados → $DEGRADED"

        for NS in openshift-ingress amp; do
            NOTRUNNING=$(KUBECONFIG="$KUBECONFIG_TMP_CMZ" oc get pods -n "$NS" \
                --no-headers 2>/dev/null \
                | grep -Evc "(Running|Completed|Succeeded)" || echo 0)
            [[ "$NOTRUNNING" -eq 0 ]] && ok "CMZ ns/$NS → pods OK" || \
                warn "CMZ ns/$NS → $NOTRUNNING pods no-Running"
        done

        IC_STATUS=$(KUBECONFIG="$KUBECONFIG_TMP_CMZ" oc get ingresscontroller default \
            -n openshift-ingress-operator \
            -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null \
            || echo "Unknown")
        [[ "$IC_STATUS" == "True" ]] && ok "CMZ IngressController default → Available" || \
            warn "CMZ IngressController default → $IC_STATUS"

        cp "$KUBECONFIG_TMP_CMZ" "/tmp/kubeconfig-prdmz"
        ok "CMZ kubeconfig guardado → /tmp/kubeconfig-prdmz"
    fi
fi

# ---------------------------------------------------------------------------
# SECCIÓN 6 — F5 LTM iControl REST
# ---------------------------------------------------------------------------
section "6. F5 LTM — $F5_HOST"

if [[ -z "$F5_HOST" || -z "$F5_PASSWORD" ]]; then
    fail "F5_HOST o F5_PASSWORD no definidos"
else
    F5_BASE="https://${F5_HOST}/mgmt/tm"
    F5_CURL=(-sk --connect-timeout 8 --max-time 15 -u "${F5_USER}:${F5_PASSWORD}" \
             -H "Content-Type: application/json")

    # Autenticación básica
    HTTP_CODE=$(curl "${F5_CURL[@]}" -o /dev/null -w "%{http_code}" \
        "$F5_BASE/sys/version" 2>/dev/null || echo "000")

    case "$HTTP_CODE" in
        200)
            ok "F5 auth → HTTP 200 OK"
            # Versión TMOS
            F5_VER=$(curl "${F5_CURL[@]}" "$F5_BASE/sys/version" 2>/dev/null \
                | jq -r '.entries | to_entries[0].value.nestedStats.entries.Version.description' \
                2>/dev/null || echo "?")
            ok "F5 TMOS version → $F5_VER"
            ;;
        401) fail "F5 auth → HTTP 401 UNAUTHORIZED — credenciales incorrectas" ;;
        000) fail "F5 → sin respuesta (timeout/network)" ;;
        *)   warn "F5 auth → HTTP $HTTP_CODE (inesperado)" ;;
    esac

    if [[ "$HTTP_CODE" == "200" ]]; then
        # Virtual Servers PaaS
        VS_COUNT=$(curl "${F5_CURL[@]}" "$F5_BASE/ltm/virtual" 2>/dev/null \
            | jq -r '.items[]? | select(.name | test("PaaS-prd|Appsa"; "i")) | .name' \
            2>/dev/null | wc -l | tr -d ' ' || echo 0)
        [[ "$VS_COUNT" -gt 0 ]] && ok "F5 Virtual Servers PaaS encontrados → $VS_COUNT" || \
            warn "F5 Virtual Servers PaaS → 0 encontrados (verificar naming)"

        # Pools
        POOL_COUNT=$(curl "${F5_CURL[@]}" "$F5_BASE/ltm/pool" 2>/dev/null \
            | jq '.items | length' 2>/dev/null || echo 0)
        ok "F5 pools totales → $POOL_COUNT"

        # Pool members habilitados
        ENABLED_MEMBERS=$(curl "${F5_CURL[@]}" "$F5_BASE/ltm/pool" 2>/dev/null \
            | jq -r '.items[]?.name' 2>/dev/null | head -3 | while read -r pool; do
                curl "${F5_CURL[@]}" \
                    "$F5_BASE/ltm/pool/~Common~${pool}/members" 2>/dev/null \
                    | jq -r '.items[]? | select(.session == "user-enabled") | .name' 2>/dev/null
            done | wc -l | tr -d ' ')
        ok "F5 pool members enabled (muestra 3 pools) → $ENABLED_MEMBERS"

        # Específicos VS PaaS-Prd
        for VS_NAME in "VS-PaaS-Prd-HTTP" "VS-PaaS-Prd-HTTPS"; do
            VS_STATE=$(curl "${F5_CURL[@]}" \
                "$F5_BASE/ltm/virtual/~Common~${VS_NAME}" 2>/dev/null \
                | jq -r 'if .enabled then "ENABLED" elif .disabled then "DISABLED" else "NOT_FOUND" end' \
                2>/dev/null || echo "NOT_FOUND")
            case "$VS_STATE" in
                ENABLED)   ok "F5 VS $VS_NAME → ENABLED" ;;
                DISABLED)  warn "F5 VS $VS_NAME → DISABLED (esperado solo en DR)" ;;
                NOT_FOUND) warn "F5 VS $VS_NAME → no encontrado (verificar nombre exacto)" ;;
            esac
        done
    fi
fi

# ---------------------------------------------------------------------------
# SECCIÓN 7 — DNS
# ---------------------------------------------------------------------------
section "7. DNS — FQDNs del ejercicio"

check_dns() {
    local label="$1"; local fqdn="$2"
    if ! command -v dig &>/dev/null; then
        warn "dig no disponible — omitiendo $label"
        return
    fi
    RESULT=$(dig +short "$fqdn" 2>/dev/null | head -3 | tr '\n' ' ' || echo "NXDOMAIN")
    TTL=$(dig "$fqdn" +nocmd +noall +answer 2>/dev/null | awk '{print $2}' | head -1 || echo "?")
    if [[ -n "$RESULT" && "$RESULT" != " " ]]; then
        ok "DNS $label → $RESULT (TTL:${TTL}s)"
    else
        warn "DNS $label → NXDOMAIN o sin respuesta"
    fi
}

check_dns "api.paas-prd.bancogalicia.com.ar" "api.paas-prd.bancogalicia.com.ar"
check_dns "api.paas-prdpg (directo)" "api.paas-prdpg.bancogalicia.com.ar"
check_dns "api.paas-prdmz (directo)" "api.paas-prdmz.bancogalicia.com.ar"
check_dns "appsprdf5-1 (apps target PGA)" "appsprdf5-1.apps.paas-prd.bancogalicia.com.ar"
check_dns "appsprdf5   (apps target CMZ)" "appsprdf5.apps.paas-prd.bancogalicia.com.ar"
check_dns "appsa1 (apps1 router)" "appsa1.paas-prd.bancogalicia.com.ar"

# Inferir site activo por CNAME del API agnóstico
API_CNAME=$(dig "api.paas-prd.bancogalicia.com.ar" CNAME +short 2>/dev/null | head -1 || echo "")
if echo "$API_CNAME" | grep -qi "prdpg"; then
    ok "DNS — Site activo inferido: PGA (api → $API_CNAME)"
elif echo "$API_CNAME" | grep -qi "prdmz"; then
    warn "DNS — Site activo: CMZ — ¿ya se hizo el switch? (api → $API_CNAME)"
else
    warn "DNS — No se pudo inferir site activo (CNAME: ${API_CNAME:-vacío})"
fi

# ---------------------------------------------------------------------------
# SECCIÓN 8 — Validar que los collectors del framework funcionan
# ---------------------------------------------------------------------------
section "8. Smoke test — collectors del framework"

# Verificar que los kubeconfigs quedaron disponibles
if [[ -f "/tmp/kubeconfig-prdpg" ]]; then
    ok "Kubeconfig PGA disponible en /tmp/kubeconfig-prdpg"
    # Test rápido del collector cluster-health
    KUBECONFIG="/tmp/kubeconfig-prdpg" oc get clusteroperators --no-headers 2>/dev/null \
        | wc -l | tr -d ' ' | xargs -I{} bash -c \
        "[[ {} -gt 0 ]] && echo -e '${GREEN}[PASS $(ts)]${NC} PGA cluster-health collector → {} operators' || echo -e '${RED}[FAIL]${NC} PGA cluster-health collector → 0 operators'"
else
    warn "Kubeconfig PGA no disponible — login PGA probablemente falló"
fi

if [[ -f "/tmp/kubeconfig-prdmz" ]]; then
    ok "Kubeconfig CMZ disponible en /tmp/kubeconfig-prdmz"
    KUBECONFIG="/tmp/kubeconfig-prdmz" oc get clusteroperators --no-headers 2>/dev/null \
        | wc -l | tr -d ' ' | xargs -I{} bash -c \
        "[[ {} -gt 0 ]] && echo -e '${GREEN}[PASS $(ts)]${NC} CMZ cluster-health collector → {} operators' || echo -e '${RED}[FAIL]${NC} CMZ cluster-health collector → 0 operators'"
else
    warn "Kubeconfig CMZ no disponible — login CMZ probablemente falló"
fi

# Verificar que 00_env.sh sourceable
if source "$SCRIPT_DIR/00_env.sh" 2>/dev/null; then
    ok "00_env.sh sourceable sin errores"
else
    fail "00_env.sh tiene errores de sintaxis"
fi

# Verificar que los kubeconfigs generados funcionan con oc_cluster()
if [[ -f "/tmp/kubeconfig-prdpg" && -f "/tmp/kubeconfig-prdmz" ]]; then
    export KUBECONFIG_PGA="/tmp/kubeconfig-prdpg"
    export KUBECONFIG_CMZ="/tmp/kubeconfig-prdmz"
    source "$SCRIPT_DIR/00_env.sh" 2>/dev/null || true

    WHO_PGA=$(oc_cluster paas-prdpg whoami 2>/dev/null || echo "ERROR")
    [[ "$WHO_PGA" != "ERROR" ]] && ok "oc_cluster() PGA → $WHO_PGA" || \
        fail "oc_cluster() PGA → falló"

    WHO_CMZ=$(oc_cluster paas-prdmz whoami 2>/dev/null || echo "ERROR")
    [[ "$WHO_CMZ" != "ERROR" ]] && ok "oc_cluster() CMZ → $WHO_CMZ" || \
        fail "oc_cluster() CMZ → falló"
fi

# ---------------------------------------------------------------------------
# RESUMEN FINAL
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  RESUMEN PREFLIGHT — $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}PASS: $PASS${NC}"
echo -e "  ${YELLOW}WARN: $WARN${NC}"
echo -e "  ${RED}FAIL: $FAIL${NC}"
echo ""

if [[ -f "/tmp/kubeconfig-prdpg" && -f "/tmp/kubeconfig-prdmz" ]]; then
    echo -e "${GREEN}Kubeconfigs listos para el ejercicio:${NC}"
    echo -e "  export KUBECONFIG_PGA=/tmp/kubeconfig-prdpg"
    echo -e "  export KUBECONFIG_CMZ=/tmp/kubeconfig-prdmz"
    echo ""
fi

if [[ "$FAIL" -eq 0 && "$WARN" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ PREFLIGHT OK — Listo para el ejercicio DRP${NC}"
    VERDICT="PASSED"
elif [[ "$FAIL" -eq 0 ]]; then
    echo -e "${YELLOW}${BOLD}  ⚠ PREFLIGHT OK con advertencias — Revisar WARNs antes del ejercicio${NC}"
    VERDICT="PASSED_WITH_WARNINGS"
else
    echo -e "${RED}${BOLD}  ✗ PREFLIGHT FALLIDO — Resolver FAILs antes del ejercicio${NC}"
    VERDICT="FAILED"
fi
echo ""

# ---------------------------------------------------------------------------
# Guardar reporte si se pidió
# ---------------------------------------------------------------------------
if $REPORT_MODE; then
    REPORT_DIR="$SCRIPT_DIR/reports"
    mkdir -p "$REPORT_DIR"
    REPORT_FILE="$REPORT_DIR/preflight-$(date '+%Y%m%d-%H%M%S').txt"
    {
        echo "PREFLIGHT REPORT — $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Verdict: $VERDICT"
        echo "PASS: $PASS  WARN: $WARN  FAIL: $FAIL"
        echo ""
        printf '%s\n' "${REPORT_LINES[@]}"
    } > "$REPORT_FILE"
    echo -e "Reporte guardado: ${CYAN}$REPORT_FILE${NC}"
fi

[[ "$FAIL" -eq 0 ]]   # exit 0 si no hay FAILs, exit 1 si hay
