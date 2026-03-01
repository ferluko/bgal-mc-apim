/**
 * k6 Stress Test - Mayor carga, pruebas cortas
 *
 * Diseñado para ejecutar desde máquina local con k6 instalado.
 * Mayor carga que latency-test para acentuar diferencias entre CNIs.
 *
 * Escenarios (total ~3 min):
 * - Ramp 0->150 VUs en 15s, sostenido 30s
 * - Constante 300 VUs por 30s
 * - Burst 500 VUs por 20s
 * - Spike: 0->400->0 en 40s
 *
 * Uso:
 *   k6 run stress-test.js -e TARGET_URL=http://NODE_IP:30080 -e CNI_TYPE=Cilium
 *   k6 run stress-test.js -e TARGET_URL=http://localhost:8080  # con port-forward
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

const latencyRamp = new Trend('latency_ramp_ms', true);
const latencyConstant = new Trend('latency_constant_ms', true);
const latencyBurst = new Trend('latency_burst_ms', true);
const latencySpike = new Trend('latency_spike_ms', true);

const requestsTotal = new Counter('requests_total');
const errorRate = new Rate('error_rate');

const TARGET_URL = __ENV.TARGET_URL || 'http://localhost:8080';
const CNI_TYPE = __ENV.CNI_TYPE || 'Unknown';

export const options = {
  scenarios: {
    // Ramp: 0 -> 150 VUs en 15s, mantener 30s
    ramp_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '15s', target: 150 },
        { duration: '30s', target: 150 },
      ],
      gracefulRampDown: '5s',
      tags: { scenario: 'ramp', cni: CNI_TYPE },
      exec: 'testRamp',
    },
    // Constante 300 VUs por 30s
    constant_load: {
      executor: 'constant-vus',
      vus: 300,
      duration: '30s',
      startTime: '55s',
      tags: { scenario: 'constant', cni: CNI_TYPE },
      exec: 'testConstant',
    },
    // Burst: 500 VUs por 20s
    burst: {
      executor: 'constant-vus',
      vus: 500,
      duration: '20s',
      startTime: '1m35s',
      tags: { scenario: 'burst', cni: CNI_TYPE },
      exec: 'testBurst',
    },
    // Spike: 0 -> 400 -> 0 en 40s
    spike: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '10s', target: 400 },
        { duration: '15s', target: 400 },
        { duration: '15s', target: 0 },
      ],
      startTime: '2m05s',
      tags: { scenario: 'spike', cni: CNI_TYPE },
      exec: 'testSpike',
    },
  },
  thresholds: {
    'latency_ramp_ms': ['p(95)<50', 'p(99)<100'],
    'latency_constant_ms': ['p(95)<75', 'p(99)<150'],
    'latency_burst_ms': ['p(95)<100', 'p(99)<200'],
    'error_rate': ['rate<0.05'],
  },
};

function makeRequest(url, metric) {
  const startTime = Date.now();
  const res = http.get(url, { timeout: '15s' });
  const latency = Date.now() - startTime;
  metric.add(latency);
  requestsTotal.add(1);
  errorRate.add(!check(res, { 'status is 200': (r) => r.status === 200 }));
  return latency;
}

export function testRamp() {
  makeRequest(TARGET_URL, latencyRamp);
  sleep(0.02);
}

export function testConstant() {
  makeRequest(TARGET_URL, latencyConstant);
  sleep(0.01);
}

export function testBurst() {
  makeRequest(TARGET_URL, latencyBurst);
  sleep(0.005);
}

export function testSpike() {
  makeRequest(TARGET_URL, latencySpike);
  sleep(0.01);
}

export function handleSummary(data) {
  const metrics = data.metrics;
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

  const scenarios = [
    { name: 'latency_ramp_ms', label: 'Ramp (0->150 VUs)' },
    { name: 'latency_constant_ms', label: 'Constante 300 VUs' },
    { name: 'latency_burst_ms', label: 'Burst 500 VUs' },
    { name: 'latency_spike_ms', label: 'Spike 0->400->0' },
  ];

  let report = `
╔══════════════════════════════════════════════════════════════════════════════╗
║                    STRESS TEST - ${CNI_TYPE.padEnd(60)}║
╚══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
│ Escenario                    │   Min   │   Avg   │   P95   │   P99   │   Max   │
├─────────────────────────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
`;

  for (const s of scenarios) {
    const m = metrics[s.name];
    if (m && m.values) {
      const min = (m.values.min || 0).toFixed(2).padStart(6);
      const avg = (m.values.avg || 0).toFixed(2).padStart(6);
      const p95 = (m.values['p(95)'] || 0).toFixed(2).padStart(6);
      const p99 = (m.values['p(99)'] || 0).toFixed(2).padStart(6);
      const max = (m.values.max || 0).toFixed(2).padStart(6);
      report += `│ ${s.label.padEnd(27)} │ ${min}ms │ ${avg}ms │ ${p95}ms │ ${p99}ms │ ${max}ms │\n`;
    }
  }

  report += '└─────────────────────────────┴─────────┴─────────┴─────────┴─────────┴─────────┘\n';

  const total = (metrics.requests_total && metrics.requests_total.values && metrics.requests_total.values.count) || 0;
  const errRate = (metrics.error_rate && metrics.error_rate.values && metrics.error_rate.values.rate) || 0;
  report += `\nRequests: ${total}  |  Error rate: ${(errRate * 100).toFixed(2)}%\n\n`;

  return {
    stdout: report,
    [`stress-${CNI_TYPE}-${timestamp}.json`]: JSON.stringify(data, null, 2),
    [`stress-${CNI_TYPE}-${timestamp}.txt`]: report,
  };
}
