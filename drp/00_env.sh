#!/usr/bin/env bash
# =============================================================================
# Entorno para ejercicio DRP — Banco Galicia
#
# Arquitectura real (ver diagrama F5):
#   - F5 Active-Active cluster: mismas VIPs en PGA y CMZ
#   - Durante DR: pool members cambian de PGA → CMZ (VIPs no cambian)
#   - DNS: CNAMEs agnósticos cambian de appsprdf5-1 (PGA) → appsprdf5 (CMZ)
#
# Fases:
#   PRE    → PGA activo  / CMZ pasivo (pool members PGA habilitados)
#   DURING → CMZ activo  / PGA pasivo (pool members CMZ habilitados)
#   POST   → PGA activo  / CMZ pasivo (pool members PGA restaurados)
#
# Uso: source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
DRP_DIR="$SCRIPT_DIR"
REPORTS_DIR="${REPORTS_DIR:-$DRP_DIR/reports}"

# ---------------------------------------------------------------------------
# Clusters OpenShift de producción
# ---------------------------------------------------------------------------
CLUSTER_PGA="${CLUSTER_PGA:-paas-prdpg}"     # Plaza Galicia (sitio primario)
CLUSTER_CMZ="${CLUSTER_CMZ:-paas-prdmz}"     # Casa Matriz   (sitio DR)

# Kubeconfigs por cluster (ajustar rutas según entorno real)
KUBECONFIG_PGA="${KUBECONFIG_PGA:-$HOME/.kube/kubeconfig-prdpg}"
KUBECONFIG_CMZ="${KUBECONFIG_CMZ:-$HOME/.kube/kubeconfig-prdmz}"

# ---------------------------------------------------------------------------
# DNS — estructura real según diagrama
# ---------------------------------------------------------------------------
BASE_DOMAIN="${BASE_DOMAIN:-bancogalicia.com.ar}"

# FQDN agnóstico de plataforma (wildcard apps)
AGNOSTIC_FQDN="${AGNOSTIC_FQDN:-paas-prd.bancogalicia.com.ar}"

# FQDN API agnóstico
API_AGNOSTIC_FQDN="${API_AGNOSTIC_FQDN:-api.paas-prd.bancogalicia.com.ar}"

# CNAMEs concretos por site (targets del switch DNS)
# PGA: appsprdf5-1.apps.paas-prd.bancogalicia.com.ar
# CMZ: appsprdf5.apps.paas-prd.bancogalicia.com.ar
DNS_APPS_TARGET_PGA="${DNS_APPS_TARGET_PGA:-appsprdf5-1.apps.paas-prd.bancogalicia.com.ar}"
DNS_APPS_TARGET_CMZ="${DNS_APPS_TARGET_CMZ:-appsprdf5.apps.paas-prd.bancogalicia.com.ar}"

# Apps1 router (apunta a appsa1.paas-prd.bancogalicia.com.ar)
DNS_APPSA1_TARGET="${DNS_APPSA1_TARGET:-appsa1.paas-prd.bancogalicia.com.ar}"

# API por cluster (usados como CNAME targets del switch DNS de API)
API_FQDN_PGA="${API_FQDN_PGA:-api.paas-prdpg.bancogalicia.com.ar}"
API_FQDN_CMZ="${API_FQDN_CMZ:-api.paas-prdmz.bancogalicia.com.ar}"

# ---------------------------------------------------------------------------
# F5 LTM — Active-Active Cluster
# Durante DR los POOL MEMBERS cambian de PGA → CMZ, no los VIPs.
# ---------------------------------------------------------------------------

# Management IPs de cada nodo del cluster F5 (para consultas iControl REST)
F5_HOST="${F5_HOST:-}"                  # Floating management IP del cluster (preferido)
F5_HOST_PGA="${F5_HOST_PGA:-}"          # Management IP nodo PGA (si se necesita por separado)
F5_HOST_CMZ="${F5_HOST_CMZ:-}"          # Management IP nodo CMZ (si se necesita por separado)
F5_USER="${F5_USER:-admin}"
F5_PASSWORD="${F5_PASSWORD:-}"          # Preferir var de entorno o vault

# VIPs del cluster F5 (mismas IPs en ambos sites)
F5_VIP_MAIN="10.254.50.1"             # VS-PaaS-Prd-HTTP/S   (default router)
F5_VIP_APPSA1="10.254.50.11"          # VS-Appsa1-PaaS-prd-HTTP/S
F5_VIP_APPSA2="10.254.50.12"          # VS-Appsa2-PaaS-prd-HTTP/S
F5_VIP_APPSA3="10.254.50.13"          # VS-Appsa3-PaaS-prd-HTTP/S
F5_VIP_APPSA4="10.254.50.14"          # VS-Appsa4-PaaS-prd-HTTP/S
F5_VIP_APPSA5="10.254.50.15"          # VS-Appsa5-PaaS-prd-HTTP/S
F5_VIP_APPSA6="10.254.50.16"          # VS-Appsa6-PaaS-prd-HTTP/S

# Nombres de Virtual Servers en F5
declare -a F5_VS_NAMES=(
    "VS-PaaS-Prd-HTTP"
    "VS-PaaS-Prd-HTTPS"
    "VS-Appsa1-PaaS-prd-HTTP"
    "VS-Appsa1-PaaS-prd-HTTPS"
    "VS-Appsa2-PaaS-prd-HTTP"
    "VS-Appsa2-PaaS-prd-HTTPS"
    "VS-Appsa3-PaaS-prd-HTTP"
    "VS-Appsa3-PaaS-prd-HTTPS"
    "VS-Appsa4-PaaS-prd-HTTP"
    "VS-Appsa4-PaaS-prd-HTTPS"
    "VS-Appsa5-PaaS-prd-HTTP"
    "VS-Appsa5-PaaS-prd-HTTPS"
    "VS-Appsa6-PaaS-prd-HTTP"
    "VS-Appsa6-PaaS-prd-HTTPS"
)
export F5_VS_NAMES

# Prefijos de pool para identificar site durante discovery
# Convención esperada: pool members con addr de PGA vs CMZ
F5_POOL_PREFIX_PGA="${F5_POOL_PREFIX_PGA:-PGA}"    # ajustar a convención real de pools F5
F5_POOL_PREFIX_CMZ="${F5_POOL_PREFIX_CMZ:-CMZ}"

# ---------------------------------------------------------------------------
# 3scale / APIM
# Namespace único para toda la plataforma 3scale
# ---------------------------------------------------------------------------
AMP_NS="${AMP_NS:-amp}"

# ---------------------------------------------------------------------------
# Timeouts y polling
# ---------------------------------------------------------------------------
DNS_POLL_INTERVAL="${DNS_POLL_INTERVAL:-2}"          # segundos entre resoluciones DNS
EVENT_POLL_INTERVAL="${EVENT_POLL_INTERVAL:-5}"      # segundos entre polls de eventos
LIVE_TAIL_LINES="${LIVE_TAIL_LINES:-30}"             # líneas mostradas en watches

# ---------------------------------------------------------------------------
# Colores para output
# ---------------------------------------------------------------------------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN $(date '+%H:%M:%S')]${NC} $*"; }
err()  { echo -e "${RED}[ERROR $(date '+%H:%M:%S')]${NC} $*" >&2; }
ok()   { echo -e "${GREEN}[OK   $(date '+%H:%M:%S')]${NC} $*"; }

# Wrapper oc que elige kubeconfig según cluster
oc_cluster() {
    local cluster="$1"; shift
    case "$cluster" in
        "$CLUSTER_PGA") KUBECONFIG="$KUBECONFIG_PGA" oc "$@" ;;
        "$CLUSTER_CMZ") KUBECONFIG="$KUBECONFIG_CMZ" oc "$@" ;;
        *) err "Cluster desconocido: $cluster"; return 1 ;;
    esac
}

# iControl REST helper
f5_api() {
    local path="$1"
    local host="${F5_HOST:-${F5_HOST_PGA}}"
    curl -sk -u "${F5_USER}:${F5_PASSWORD}" \
        -H "Content-Type: application/json" \
        "https://${host}/mgmt/tm/${path}"
}

export SCRIPT_DIR DRP_DIR REPORTS_DIR
export CLUSTER_PGA CLUSTER_CMZ
export KUBECONFIG_PGA KUBECONFIG_CMZ
export BASE_DOMAIN AGNOSTIC_FQDN API_AGNOSTIC_FQDN
export DNS_APPS_TARGET_PGA DNS_APPS_TARGET_CMZ DNS_APPSA1_TARGET
export API_FQDN_PGA API_FQDN_CMZ
export F5_HOST F5_HOST_PGA F5_HOST_CMZ F5_USER F5_PASSWORD
export F5_VIP_MAIN F5_VIP_APPSA1 F5_VIP_APPSA2 F5_VIP_APPSA3
export F5_VIP_APPSA4 F5_VIP_APPSA5 F5_VIP_APPSA6
export F5_POOL_PREFIX_PGA F5_POOL_PREFIX_CMZ
export AMP_NS
export DNS_POLL_INTERVAL EVENT_POLL_INTERVAL LIVE_TAIL_LINES
export RED YELLOW GREEN CYAN BOLD NC
