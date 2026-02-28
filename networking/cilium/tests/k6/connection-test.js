/**
 * k6 Connection Establishment Test
 * 
 * Mide el tiempo de establecimiento de conexiones TCP
 * Útil para comparar el overhead de Cilium KPR vs OVN con kube-proxy
 * 
 * Uso:
 *   k6 run connection-test.js \
 *     -e TARGET_URL=http://perf-target-clusterip.network-perf-test.svc \
 *     -e CNI_TYPE=Cilium
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Métricas de conexión
const tcpConnectTime = new Trend('tcp_connect_time_ms', true);
const tlsHandshakeTime = new Trend('tls_handshake_time_ms', true);
const ttfb = new Trend('time_to_first_byte_ms', true);
const totalDuration = new Trend('total_duration_ms', true);

const connectionsTotal = new Counter('connections_total');
const connectionsFailed = new Counter('connections_failed');
const errorRate = new Rate('connection_error_rate');

const TARGET_URL = __ENV.TARGET_URL || 'http://perf-target-clusterip.network-perf-test.svc';
const CNI_TYPE = __ENV.CNI_TYPE || 'Unknown';

export const options = {
  scenarios: {
    // Conexiones secuenciales (mide establecimiento individual)
    sequential_connections: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: 100,
      maxDuration: '5m',
      tags: { scenario: 'sequential', cni: CNI_TYPE },
      exec: 'testSequentialConnections',
    },
    
    // Conexiones concurrentes (mide bajo carga)
    concurrent_connections: {
      executor: 'constant-vus',
      vus: 50,
      duration: '2m',
      startTime: '5m30s',
      tags: { scenario: 'concurrent', cni: CNI_TYPE },
      exec: 'testConcurrentConnections',
    },
    
    // Ráfaga de conexiones (simula spike)
    burst_connections: {
      executor: 'shared-iterations',
      vus: 100,
      iterations: 1000,
      maxDuration: '1m',
      startTime: '8m',
      tags: { scenario: 'burst', cni: CNI_TYPE },
      exec: 'testBurstConnections',
    },
  },
  
  thresholds: {
    'tcp_connect_time_ms': ['p(95)<10', 'p(99)<20'],
    'time_to_first_byte_ms': ['p(95)<50', 'p(99)<100'],
    'connection_error_rate': ['rate<0.01'],
  },
};

function recordTimings(res) {
  connectionsTotal.add(1);
  
  // Extraer tiempos de conexión
  if (res.timings) {
    tcpConnectTime.add(res.timings.connecting || 0);
    tlsHandshakeTime.add(res.timings.tls_handshaking || 0);
    ttfb.add(res.timings.waiting || 0);
    totalDuration.add(res.timings.duration || 0);
  }
  
  const success = check(res, {
    'connection established': (r) => r.status === 200,
  });
  
  if (!success) {
    connectionsFailed.add(1);
  }
  
  errorRate.add(!success);
  
  return success;
}

export function testSequentialConnections() {
  // Forzar nueva conexión cada vez (sin keep-alive)
  const res = http.get(TARGET_URL, {
    headers: { 'Connection': 'close' },
    timeout: '10s',
  });
  
  recordTimings(res);
  sleep(0.5); // Pausa entre conexiones
}

export function testConcurrentConnections() {
  const res = http.get(TARGET_URL, {
    timeout: '10s',
  });
  
  recordTimings(res);
  sleep(0.1);
}

export function testBurstConnections() {
  const res = http.get(TARGET_URL, {
    headers: { 'Connection': 'close' },
    timeout: '10s',
  });
  
  recordTimings(res);
}

export function handleSummary(data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  
  let report = `
╔══════════════════════════════════════════════════════════════════════════════╗
║         REPORTE DE ESTABLECIMIENTO DE CONEXIONES - OpenShift                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CNI: ${CNI_TYPE.padEnd(70)}║
║  Fecha: ${new Date().toISOString().padEnd(68)}║
╚══════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                           TIEMPOS DE CONEXIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

`;

  const metrics = data.metrics;
  const connectionMetrics = [
    { name: 'tcp_connect_time_ms', label: 'TCP Connect' },
    { name: 'tls_handshake_time_ms', label: 'TLS Handshake' },
    { name: 'time_to_first_byte_ms', label: 'Time to First Byte' },
    { name: 'total_duration_ms', label: 'Total Duration' },
  ];

  report += '┌────────────────────────┬─────────┬─────────┬─────────┬─────────┬─────────┐\n';
  report += '│ Métrica                │   Min   │   Avg   │   P95   │   P99   │   Max   │\n';
  report += '├────────────────────────┼─────────┼─────────┼─────────┼─────────┼─────────┤\n';

  for (const metric of connectionMetrics) {
    const m = metrics[metric.name];
    if (m && m.values) {
      const min = (m.values.min || 0).toFixed(2).padStart(6);
      const avg = (m.values.avg || 0).toFixed(2).padStart(6);
      const p95 = (m.values['p(95)'] || 0).toFixed(2).padStart(6);
      const p99 = (m.values['p(99)'] || 0).toFixed(2).padStart(6);
      const max = (m.values.max || 0).toFixed(2).padStart(6);
      report += `│ ${metric.label.padEnd(22)} │ ${min}ms │ ${avg}ms │ ${p95}ms │ ${p99}ms │ ${max}ms │\n`;
    }
  }

  report += '└────────────────────────┴─────────┴─────────┴─────────┴─────────┴─────────┘\n';

  const total = metrics.connections_total?.values?.count || 0;
  const failed = metrics.connections_failed?.values?.count || 0;
  const errRate = metrics.connection_error_rate?.values?.rate || 0;

  report += `
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                            ESTADÍSTICAS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total conexiones:      ${total}
  Conexiones fallidas:   ${failed}
  Tasa de error:         ${(errRate * 100).toFixed(2)}%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
`;

  return {
    'stdout': report,
    [`/results/connection-test-${CNI_TYPE}-${timestamp}.json`]: JSON.stringify(data, null, 2),
    [`/results/connection-test-${CNI_TYPE}-${timestamp}.txt`]: report,
  };
}
