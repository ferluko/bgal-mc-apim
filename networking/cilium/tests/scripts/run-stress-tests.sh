#!/bin/bash
#
# run-stress-tests.sh - Ejecuta k6 stress test desde máquina local
#
# Requisitos: k6 instalado localmente, oc/kubectl, conectividad al cluster.
# Mayor carga que run-tests.sh para acentuar diferencias entre CNIs.
#
# Uso:
#   ./run-stress-tests.sh [opciones]
#
# Opciones:
#   -n, --namespace    Namespace (default: network-perf-test)
#   -o, --output       Directorio de resultados
#   -s, --skip-deploy  No desplegar targets (usar existentes)
#   -p, --port-forward Usar port-forward en vez de NodePort
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
MANIFESTS_DIR="${TESTS_DIR}/manifests"
K6_DIR="${TESTS_DIR}/k6"

NAMESPACE="network-perf-test"
SKIP_DEPLOY=false
USE_PORT_FORWARD=false
OUTPUT_DIR=""
PF_PID=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

cleanup() {
    if [ -n "$PF_PID" ] && kill -0 "$PF_PID" 2>/dev/null; then
        log_info "Deteniendo port-forward..."
        kill "$PF_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -s|--skip-deploy) SKIP_DEPLOY=true; shift ;;
        -p|--port-forward) USE_PORT_FORWARD=true; shift ;;
        -h|--help)
            echo "Uso: $(basename "$0") [-n namespace] [-o output-dir] [-s] [-p]"
            echo "  -s  Skip deploy (targets ya desplegados)"
            echo "  -p  Usar port-forward en vez de NodePort"
            exit 0
            ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
    esac
done

# Prerrequisitos
log_info "Verificando prerrequisitos..."
command -v k6 >/dev/null 2>&1 || { log_warn "k6 no encontrado. Instalar: https://k6.io/docs/getting-started/installation/"; exit 1; }
OC=$(command -v oc 2>/dev/null || command -v kubectl 2>/dev/null || { log_warn "Se requiere oc o kubectl"; exit 1; })
$OC cluster-info >/dev/null 2>&1 || { log_warn "No hay conexión al cluster"; exit 1; }
log_success "Prerrequisitos OK"

CNI_TYPE=$($OC get network cluster -o jsonpath='{.spec.networkType}' 2>/dev/null || echo "Unknown")
log_info "CNI: $CNI_TYPE"

if [ -n "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    cd "$OUTPUT_DIR"
fi

RESULTS_DIR="${OUTPUT_DIR:-.}/stress-results-${CNI_TYPE}-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"
log_info "Resultados en: $RESULTS_DIR"

# Desplegar targets
if [ "$SKIP_DEPLOY" = false ]; then
    log_info "Desplegando targets..."
    $OC apply -f "${MANIFESTS_DIR}/target-deployment.yaml" -n "$NAMESPACE"
    $OC wait --for=condition=available deployment/perf-target -n "$NAMESPACE" --timeout=120s
    log_success "Targets listos"
else
    $OC get deployment perf-target -n "$NAMESPACE" >/dev/null 2>&1 || { log_warn "Targets no encontrados. Ejecutar sin -s"; exit 1; }
fi

# Obtener URL target
TARGET_URL=""
if [ "$USE_PORT_FORWARD" = true ]; then
    log_info "Iniciando port-forward..."
    $OC port-forward -n "$NAMESPACE" svc/perf-target-clusterip 8080:8080 &
    PF_PID=$!
    sleep 3
    TARGET_URL="http://localhost:8080"
else
    NODE_IP=$($OC get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    TARGET_URL="http://${NODE_IP}:30080"
    log_info "Target NodePort: $TARGET_URL"
fi

# Ejecutar k6 stress test
log_info "Ejecutando k6 stress test (~3 min, carga alta)..."
echo ""

cd "$RESULTS_DIR"
k6 run \
    -e TARGET_URL="$TARGET_URL" \
    -e CNI_TYPE="$CNI_TYPE" \
    --summary-trend-stats="min,avg,p(95),p(99),max" \
    "${K6_DIR}/stress-test.js" 2>&1 | tee stress-output.log

log_success "Stress test completado"
echo ""
echo "Resultados guardados en: $RESULTS_DIR"
