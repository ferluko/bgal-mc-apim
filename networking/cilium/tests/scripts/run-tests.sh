#!/bin/bash
#
# run-tests.sh - Ejecuta pruebas de performance de red en OpenShift
#
# Compara latencia y throughput entre:
# - Cilium con KPR (Kube-Proxy Replacement)
# - OVN-Kubernetes CNI
#
# Uso:
#   ./run-tests.sh [opciones]
#
# Opciones:
#   -n, --namespace    Namespace para las pruebas (default: network-perf-test)
#   -o, --output       Directorio de salida para resultados
#   -s, --skip-deploy  Saltar despliegue de recursos (usar existentes)
#   -c, --cleanup      Limpiar recursos al finalizar
#   -h, --help         Mostrar ayuda
#

set -euo pipefail

# =============================================================================
# Configuración
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
MANIFESTS_DIR="${TESTS_DIR}/manifests"
K6_DIR="${TESTS_DIR}/k6"

NAMESPACE="network-perf-test"
SKIP_DEPLOY=false
CLEANUP=false
OUTPUT_DIR=""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# Funciones auxiliares
# =============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Uso: $(basename "$0") [opciones]

Ejecuta pruebas de performance de red en OpenShift para comparar
Cilium KPR vs OVN-Kubernetes.

Opciones:
  -n, --namespace NAME    Namespace para las pruebas (default: network-perf-test)
  -o, --output DIR        Directorio de salida para resultados
  -s, --skip-deploy       Saltar despliegue de recursos (usar existentes)
  -c, --cleanup           Limpiar recursos al finalizar
  -h, --help              Mostrar esta ayuda

Ejemplos:
  $(basename "$0")                           # Ejecutar todas las pruebas
  $(basename "$0") -o ./results              # Guardar resultados en ./results
  $(basename "$0") -s                        # Usar recursos ya desplegados
  $(basename "$0") -c                        # Limpiar al finalizar

EOF
}

check_prerequisites() {
    log_info "Verificando prerrequisitos..."
    
    # Verificar oc/kubectl
    if ! command -v oc &> /dev/null; then
        if ! command -v kubectl &> /dev/null; then
            log_error "Se requiere 'oc' o 'kubectl'"
            exit 1
        fi
        OC="kubectl"
    else
        OC="oc"
    fi
    
    # Verificar conexión al cluster
    if ! $OC cluster-info &> /dev/null; then
        log_error "No hay conexión al cluster. Ejecutar 'oc login' primero."
        exit 1
    fi
    
    log_success "Prerrequisitos verificados"
}

get_cni_type() {
    CNI_TYPE=$($OC get network cluster -o jsonpath='{.spec.networkType}' 2>/dev/null || echo "Unknown")
    echo "$CNI_TYPE"
}

get_kpr_status() {
    if [ "$CNI_TYPE" == "Cilium" ]; then
        # Verificar si KPR está habilitado
        KPR_ENABLED=$($OC get ciliumconfig -n openshift-cilium ciliumconfig -o jsonpath='{.spec.kubeProxyReplacement}' 2>/dev/null || echo "false")
        if [ "$KPR_ENABLED" == "true" ]; then
            echo "enabled"
        else
            echo "disabled"
        fi
    else
        echo "n/a"
    fi
}

deploy_resources() {
    log_info "Desplegando recursos de prueba..."
    
    # Crear namespace
    $OC create namespace "$NAMESPACE" --dry-run=client -o yaml | $OC apply -f -
    
    # Desplegar target pods
    log_info "Desplegando pods target..."
    $OC apply -f "${MANIFESTS_DIR}/target-deployment.yaml" -n "$NAMESPACE"
    
    # Esperar a que los pods estén listos
    log_info "Esperando a que los pods estén listos..."
    $OC wait --for=condition=available deployment/perf-target -n "$NAMESPACE" --timeout=120s
    
    # Desplegar iperf3
    log_info "Desplegando iperf3..."
    $OC apply -f "${MANIFESTS_DIR}/iperf3.yaml" -n "$NAMESPACE"
    $OC wait --for=condition=ready pod/iperf3-server -n "$NAMESPACE" --timeout=60s
    $OC wait --for=condition=ready pod/iperf3-client -n "$NAMESPACE" --timeout=60s
    
    # Desplegar netperf
    log_info "Desplegando netperf..."
    $OC apply -f "${MANIFESTS_DIR}/netperf.yaml" -n "$NAMESPACE"
    $OC wait --for=condition=ready pod/netperf-server -n "$NAMESPACE" --timeout=60s
    $OC wait --for=condition=ready pod/netperf-client -n "$NAMESPACE" --timeout=60s
    
    log_success "Recursos desplegados"
}

get_test_endpoints() {
    log_info "Obteniendo endpoints de prueba..."
    
    # Obtener IPs de pods target
    PODS_INFO=$($OC get pods -n "$NAMESPACE" -l app=perf-target -o jsonpath='{range .items[*]}{.metadata.name},{.status.podIP},{.spec.nodeName}{"\n"}{end}')
    
    # Obtener nodo donde corre el cliente k6 (primer worker)
    K6_NODE=$($OC get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].metadata.name}')
    
    # Encontrar pod en mismo nodo y diferente nodo
    POD_IP_SAME_NODE=""
    POD_IP_DIFF_NODE=""
    
    while IFS=',' read -r pod_name pod_ip node_name; do
        if [ -n "$pod_ip" ]; then
            if [ "$node_name" == "$K6_NODE" ]; then
                POD_IP_SAME_NODE="$pod_ip"
            else
                POD_IP_DIFF_NODE="$pod_ip"
            fi
        fi
    done <<< "$PODS_INFO"
    
    # Si no hay pod en el mismo nodo, usar cualquiera
    if [ -z "$POD_IP_SAME_NODE" ]; then
        POD_IP_SAME_NODE=$(echo "$PODS_INFO" | head -1 | cut -d',' -f2)
    fi
    if [ -z "$POD_IP_DIFF_NODE" ]; then
        POD_IP_DIFF_NODE=$(echo "$PODS_INFO" | tail -1 | cut -d',' -f2)
    fi
    
    # Obtener IP de nodo para NodePort
    NODE_IP=$($OC get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    # Service ClusterIP
    SERVICE_CLUSTERIP="perf-target-clusterip.${NAMESPACE}.svc"
    
    log_info "Endpoints configurados:"
    log_info "  Pod mismo nodo: $POD_IP_SAME_NODE"
    log_info "  Pod diferente nodo: $POD_IP_DIFF_NODE"
    log_info "  Node IP: $NODE_IP"
    log_info "  Service ClusterIP: $SERVICE_CLUSTERIP"
}

create_k6_configmap() {
    log_info "Creando ConfigMap con scripts k6..."
    
    $OC create configmap k6-scripts \
        --from-file=latency-test.js="${K6_DIR}/latency-test.js" \
        --from-file=connection-test.js="${K6_DIR}/connection-test.js" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | $OC apply -f -
    
    log_success "ConfigMap creado"
}

run_k6_tests() {
    log_info "Ejecutando pruebas k6..."
    
    # Crear PVC para resultados
    $OC apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: k6-results
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
    
    # Crear Job de k6
    $OC apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-latency-test-$(date +%s)
  namespace: $NAMESPACE
spec:
  ttlSecondsAfterFinished: 3600
  backoffLimit: 2
  template:
    metadata:
      labels:
        app: k6-runner
    spec:
      nodeSelector:
        node-role.kubernetes.io/worker: ""
      restartPolicy: Never
      containers:
      - name: k6
        image: grafana/k6:0.49.0
        command:
        - k6
        - run
        - --out
        - json=/results/output.json
        - /scripts/latency-test.js
        env:
        - name: POD_IP_SAME_NODE
          value: "$POD_IP_SAME_NODE"
        - name: POD_IP_DIFF_NODE
          value: "$POD_IP_DIFF_NODE"
        - name: SERVICE_CLUSTERIP
          value: "$SERVICE_CLUSTERIP"
        - name: NODE_IP
          value: "$NODE_IP"
        - name: NODE_PORT
          value: "30080"
        - name: CNI_TYPE
          value: "$CNI_TYPE"
        - name: TARGET_PORT
          value: "80"
        volumeMounts:
        - name: scripts
          mountPath: /scripts
          readOnly: true
        - name: results
          mountPath: /results
        resources:
          requests:
            cpu: 1000m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 2Gi
      volumes:
      - name: scripts
        configMap:
          name: k6-scripts
      - name: results
        persistentVolumeClaim:
          claimName: k6-results
EOF
    
    # Obtener nombre del job
    JOB_NAME=$($OC get jobs -n "$NAMESPACE" -l app=k6-runner --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
    
    log_info "Job creado: $JOB_NAME"
    log_info "Esperando a que finalice (esto puede tomar ~15 minutos)..."
    
    # Esperar a que el job termine
    if $OC wait --for=condition=complete job/"$JOB_NAME" -n "$NAMESPACE" --timeout=20m; then
        log_success "Pruebas k6 completadas"
    else
        log_warn "El job no completó en el tiempo esperado"
    fi
    
    # Obtener logs
    POD_NAME=$($OC get pods -n "$NAMESPACE" -l job-name="$JOB_NAME" -o jsonpath='{.items[0].metadata.name}')
    $OC logs "$POD_NAME" -n "$NAMESPACE"
}

run_iperf3_tests() {
    log_info "Ejecutando pruebas iperf3..."
    
    IPERF_SERVER_IP=$($OC get pod iperf3-server -n "$NAMESPACE" -o jsonpath='{.status.podIP}')
    
    echo ""
    echo "=== PRUEBA IPERF3: TCP THROUGHPUT ==="
    $OC exec -n "$NAMESPACE" iperf3-client -- iperf3 -c "$IPERF_SERVER_IP" -t 30 -P 4
    
    echo ""
    echo "=== PRUEBA IPERF3: UDP THROUGHPUT ==="
    $OC exec -n "$NAMESPACE" iperf3-client -- iperf3 -c "$IPERF_SERVER_IP" -t 30 -u -b 10G
    
    log_success "Pruebas iperf3 completadas"
}

run_netperf_tests() {
    log_info "Ejecutando pruebas netperf..."
    
    NETPERF_SERVER_IP=$($OC get pod netperf-server -n "$NAMESPACE" -o jsonpath='{.status.podIP}')
    
    echo ""
    echo "=== PRUEBA NETPERF: TCP_RR (Request/Response Latency) ==="
    $OC exec -n "$NAMESPACE" netperf-client -- netperf -H "$NETPERF_SERVER_IP" -t TCP_RR -l 30 -- -o min_latency,mean_latency,max_latency,p99_latency,transaction_rate
    
    echo ""
    echo "=== PRUEBA NETPERF: TCP_CRR (Connect/Request/Response) ==="
    $OC exec -n "$NAMESPACE" netperf-client -- netperf -H "$NETPERF_SERVER_IP" -t TCP_CRR -l 30 -- -o min_latency,mean_latency,max_latency,transaction_rate
    
    echo ""
    echo "=== PRUEBA NETPERF: TCP_STREAM (Throughput) ==="
    $OC exec -n "$NAMESPACE" netperf-client -- netperf -H "$NETPERF_SERVER_IP" -t TCP_STREAM -l 30
    
    log_success "Pruebas netperf completadas"
}

run_traceroute_analysis() {
    log_info "Analizando saltos de red (hops)..."
    
    # Crear pod de debug si no existe
    $OC run debug-network --image=nicolaka/netshoot --restart=Never -n "$NAMESPACE" --command -- sleep 3600 2>/dev/null || true
    $OC wait --for=condition=ready pod/debug-network -n "$NAMESPACE" --timeout=60s 2>/dev/null || true
    
    # Obtener IPs
    TARGET_POD_IP=$($OC get pods -n "$NAMESPACE" -l app=perf-target -o jsonpath='{.items[0].status.podIP}')
    SERVICE_IP=$($OC get svc perf-target-clusterip -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
    
    echo ""
    echo "=== TRACEROUTE A POD ($TARGET_POD_IP) ==="
    $OC exec -n "$NAMESPACE" debug-network -- traceroute -n -m 10 "$TARGET_POD_IP" 2>/dev/null || echo "traceroute no disponible"
    
    echo ""
    echo "=== TRACEROUTE A SERVICE CLUSTERIP ($SERVICE_IP) ==="
    $OC exec -n "$NAMESPACE" debug-network -- traceroute -n -m 10 "$SERVICE_IP" 2>/dev/null || echo "traceroute no disponible"
    
    # Limpiar pod de debug
    $OC delete pod debug-network -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
    
    log_success "Análisis de hops completado"
}

collect_cilium_metrics() {
    if [ "$CNI_TYPE" != "Cilium" ]; then
        return
    fi
    
    log_info "Recolectando métricas de Cilium..."
    
    CILIUM_POD=$($OC get pods -n openshift-cilium -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
    
    echo ""
    echo "=== CILIUM STATUS ==="
    $OC exec -n openshift-cilium "$CILIUM_POD" -- cilium status --verbose
    
    echo ""
    echo "=== CILIUM BPF LB LIST ==="
    $OC exec -n openshift-cilium "$CILIUM_POD" -- cilium bpf lb list 2>/dev/null || echo "No disponible"
    
    echo ""
    echo "=== CILIUM BPF CT LIST (primeros 20) ==="
    $OC exec -n openshift-cilium "$CILIUM_POD" -- cilium bpf ct list global 2>/dev/null | head -20 || echo "No disponible"
    
    log_success "Métricas de Cilium recolectadas"
}

cleanup_resources() {
    log_info "Limpiando recursos..."
    $OC delete namespace "$NAMESPACE" --ignore-not-found=true
    log_success "Recursos eliminados"
}

generate_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    RESUMEN DE PRUEBAS DE RED - OpenShift                     ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║  CNI Type:        $(printf '%-60s' "$CNI_TYPE")║"
    echo "║  KPR Status:      $(printf '%-60s' "$(get_kpr_status)")║"
    echo "║  Namespace:       $(printf '%-60s' "$NAMESPACE")║"
    echo "║  Fecha:           $(printf '%-60s' "$(date '+%Y-%m-%d %H:%M:%S')")║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

# =============================================================================
# Parseo de argumentos
# =============================================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--skip-deploy)
            SKIP_DEPLOY=true
            shift
            ;;
        -c|--cleanup)
            CLEANUP=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║         PRUEBAS DE PERFORMANCE DE RED - Cilium KPR vs OVN-Kubernetes         ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    
    CNI_TYPE=$(get_cni_type)
    log_info "CNI detectado: $CNI_TYPE"
    log_info "KPR Status: $(get_kpr_status)"
    
    if [ -n "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        exec > >(tee -a "${OUTPUT_DIR}/test-output-${CNI_TYPE}-$(date +%Y%m%d-%H%M%S).log") 2>&1
    fi
    
    if [ "$SKIP_DEPLOY" = false ]; then
        deploy_resources
    fi
    
    get_test_endpoints
    create_k6_configmap
    
    # Ejecutar todas las pruebas
    run_traceroute_analysis
    run_iperf3_tests
    run_netperf_tests
    run_k6_tests
    collect_cilium_metrics
    
    generate_summary
    
    if [ "$CLEANUP" = true ]; then
        cleanup_resources
    fi
    
    log_success "Todas las pruebas completadas"
}

main "$@"
