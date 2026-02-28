/**
 * k6 Network Latency Test Script
 * 
 * Compara latencia y rendimiento entre:
 * - Cilium con KPR (Kube-Proxy Replacement)
 * - OVN-Kubernetes CNI
 * 
 * Escenarios:
 * 1. Pod-to-Pod (mismo nodo)
 * 2. Pod-to-Pod (diferente nodo)
 * 3. Pod-to-Service ClusterIP
 * 4. Pod-to-Service NodePort
 * 5. Throughput bajo carga
 * 
 * Uso:
 *   k6 run latency-test.js \
 *     -e POD_IP_SAME_NODE=10.128.x.x \
 *     -e POD_IP_DIFF_NODE=10.128.y.y \
 *     -e SERVICE_CLUSTERIP=perf-target-clusterip.network-perf-test.svc \
 *     -e NODE_IP=10.254.x.x \
 *     -e CNI_TYPE=Cilium
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Counter, Rate, Gauge } from 'k6/metrics';

// ============================================================================
// Métricas personalizadas
// ============================================================================
const latencyPodSameNode = new Trend('latency_pod_same_node_ms', true);
const latencyPodDiffNode = new Trend('latency_pod_diff_node_ms', true);
const latencyClusterIP = new Trend('latency_clusterip_ms', true);
const latencyNodePort = new Trend('latency_nodeport_ms', true);
const latencyThroughput = new Trend('latency_throughput_ms', true);

const requestsTotal = new Counter('requests_total');
const requestsSuccess = new Counter('requests_success');
const requestsFailed = new Counter('requests_failed');
const errorRate = new Rate('error_rate');

// ============================================================================
// Configuración
// ============================================================================
const POD_IP_SAME_NODE = __ENV.POD_IP_SAME_NODE || '127.0.0.1';
const POD_IP_DIFF_NODE = __ENV.POD_IP_DIFF_NODE || '127.0.0.1';
const SERVICE_CLUSTERIP = __ENV.SERVICE_CLUSTERIP || 'perf-target-clusterip.network-perf-test.svc';
const NODE_IP = __ENV.NODE_IP || '127.0.0.1';
const NODE_PORT = __ENV.NODE_PORT || '30080';
const CNI_TYPE = __ENV.CNI_TYPE || 'Unknown';
const TARGET_PORT = __ENV.TARGET_PORT || '80';

export const options = {
  scenarios: {
    // Escenario 1: Pod-to-Pod mismo nodo
    pod_same_node: {
      executor: 'constant-vus',
      vus: 10,
      duration: '2m',
      tags: { scenario: 'pod_same_node', cni: CNI_TYPE },
      exec: 'testPodSameNode',
    },
    
    // Escenario 2: Pod-to-Pod diferente nodo
    pod_diff_node: {
      executor: 'constant-vus',
      vus: 10,
      duration: '2m',
      startTime: '2m30s',
      tags: { scenario: 'pod_diff_node', cni: CNI_TYPE },
      exec: 'testPodDiffNode',
    },
    
    // Escenario 3: Pod-to-Service ClusterIP
    clusterip: {
      executor: 'constant-vus',
      vus: 10,
      duration: '2m',
      startTime: '5m',
      tags: { scenario: 'clusterip', cni: CNI_TYPE },
      exec: 'testClusterIP',
    },
    
    // Escenario 4: Pod-to-Service NodePort
    nodeport: {
      executor: 'constant-vus',
      vus: 10,
      duration: '2m',
      startTime: '7m30s',
      tags: { scenario: 'nodeport', cni: CNI_TYPE },
      exec: 'testNodePort',
    },
    
    // Escenario 5: Throughput bajo carga progresiva
    throughput: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '30s', target: 25 },
        { duration: '1m', target: 50 },
        { duration: '1m', target: 100 },
        { duration: '1m', target: 50 },
        { duration: '30s', target: 10 },
      ],
      startTime: '10m',
      tags: { scenario: 'throughput', cni: CNI_TYPE },
      exec: 'testThroughput',
    },
  },
  
  thresholds: {
    // Latencia esperada por escenario
    'latency_pod_same_node_ms': ['p(95)<5', 'p(99)<10'],      // <5ms p95
    'latency_pod_diff_node_ms': ['p(95)<15', 'p(99)<25'],     // <15ms p95
    'latency_clusterip_ms': ['p(95)<20', 'p(99)<30'],         // <20ms p95
    'latency_nodeport_ms': ['p(95)<25', 'p(99)<40'],          // <25ms p95
    'latency_throughput_ms': ['p(95)<50', 'p(99)<100'],       // <50ms p95 bajo carga
    
    // Tasa de error global
    'error_rate': ['rate<0.01'],  // <1% errores
    
    // Por escenario
    'http_req_duration{scenario:pod_same_node}': ['p(95)<10'],
    'http_req_duration{scenario:pod_diff_node}': ['p(95)<20'],
    'http_req_duration{scenario:clusterip}': ['p(95)<25'],
    'http_req_duration{scenario:nodeport}': ['p(95)<30'],
  },
};

// ============================================================================
// Funciones de prueba
// ============================================================================

function makeRequest(url, metricTrend, scenarioName) {
  const startTime = Date.now();
  
  const res = http.get(url, {
    timeout: '10s',
    tags: { name: scenarioName },
  });
  
  const latency = Date.now() - startTime;
  
  requestsTotal.add(1);
  metricTrend.add(latency);
  
  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response body exists': (r) => r.body && r.body.length > 0,
  });
  
  if (success) {
    requestsSuccess.add(1);
  } else {
    requestsFailed.add(1);
  }
  
  errorRate.add(!success);
  
  return { success, latency, status: res.status };
}

export function testPodSameNode() {
  const url = `http://${POD_IP_SAME_NODE}:${TARGET_PORT}/`;
  makeRequest(url, latencyPodSameNode, 'pod_same_node');
  sleep(0.1);
}

export function testPodDiffNode() {
  const url = `http://${POD_IP_DIFF_NODE}:${TARGET_PORT}/`;
  makeRequest(url, latencyPodDiffNode, 'pod_diff_node');
  sleep(0.1);
}

export function testClusterIP() {
  const url = `http://${SERVICE_CLUSTERIP}:${TARGET_PORT}/`;
  makeRequest(url, latencyClusterIP, 'clusterip');
  sleep(0.1);
}

export function testNodePort() {
  const url = `http://${NODE_IP}:${NODE_PORT}/`;
  makeRequest(url, latencyNodePort, 'nodeport');
  sleep(0.1);
}

export function testThroughput() {
  const url = `http://${SERVICE_CLUSTERIP}:${TARGET_PORT}/`;
  makeRequest(url, latencyThroughput, 'throughput');
  sleep(0.05); // Más agresivo para prueba de throughput
}

// ============================================================================
// Resumen personalizado
// ============================================================================

export function handleSummary(data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const summaryFile = `/results/summary-${CNI_TYPE}-${timestamp}.json`;
  const reportFile = `/results/report-${CNI_TYPE}-${timestamp}.txt`;
  
  const report = generateReport(data);
  
  return {
    'stdout': report,
    [summaryFile]: JSON.stringify(data, null, 2),
    [reportFile]: report,
  };
}

function generateReport(data) {
  const metrics = data.metrics;
  
  let report = `
╔══════════════════════════════════════════════════════════════════════════════╗
║           REPORTE DE PRUEBAS DE RENDIMIENTO DE RED - OpenShift               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CNI: ${CNI_TYPE.padEnd(70)}║
║  Fecha: ${new Date().toISOString().padEnd(68)}║
╚══════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                              RESUMEN DE LATENCIAS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

`;

  const latencyMetrics = [
    { name: 'latency_pod_same_node_ms', label: 'Pod-to-Pod (mismo nodo)' },
    { name: 'latency_pod_diff_node_ms', label: 'Pod-to-Pod (diferente nodo)' },
    { name: 'latency_clusterip_ms', label: 'Pod-to-Service (ClusterIP)' },
    { name: 'latency_nodeport_ms', label: 'Pod-to-Service (NodePort)' },
    { name: 'latency_throughput_ms', label: 'Throughput (bajo carga)' },
  ];

  report += '┌────────────────────────────────┬─────────┬─────────┬─────────┬─────────┬─────────┐\n';
  report += '│ Escenario                      │   Min   │   Avg   │   P95   │   P99   │   Max   │\n';
  report += '├────────────────────────────────┼─────────┼─────────┼─────────┼─────────┼─────────┤\n';

  for (const metric of latencyMetrics) {
    const m = metrics[metric.name];
    if (m && m.values) {
      const min = (m.values.min || 0).toFixed(2).padStart(6);
      const avg = (m.values.avg || 0).toFixed(2).padStart(6);
      const p95 = (m.values['p(95)'] || 0).toFixed(2).padStart(6);
      const p99 = (m.values['p(99)'] || 0).toFixed(2).padStart(6);
      const max = (m.values.max || 0).toFixed(2).padStart(6);
      report += `│ ${metric.label.padEnd(30)} │ ${min}ms │ ${avg}ms │ ${p95}ms │ ${p99}ms │ ${max}ms │\n`;
    }
  }

  report += '└────────────────────────────────┴─────────┴─────────┴─────────┴─────────┴─────────┘\n';

  // Estadísticas de requests
  const totalReqs = metrics.requests_total?.values?.count || 0;
  const successReqs = metrics.requests_success?.values?.count || 0;
  const failedReqs = metrics.requests_failed?.values?.count || 0;
  const errRate = metrics.error_rate?.values?.rate || 0;

  report += `
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                            ESTADÍSTICAS GENERALES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total de requests:     ${totalReqs}
  Requests exitosos:     ${successReqs}
  Requests fallidos:     ${failedReqs}
  Tasa de error:         ${(errRate * 100).toFixed(2)}%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                              THRESHOLDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

`;

  // Estado de thresholds
  if (data.thresholds) {
    for (const [name, threshold] of Object.entries(data.thresholds)) {
      const status = threshold.ok ? '✓ PASS' : '✗ FAIL';
      report += `  ${status}  ${name}\n`;
    }
  }

  report += `
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
`;

  return report;
}
