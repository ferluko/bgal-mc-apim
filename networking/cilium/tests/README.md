# Pruebas de Performance de Red - Cilium KPR vs OVN-Kubernetes

Suite de pruebas para comparar latencia, throughput y número de saltos (hops) entre:
- **Cilium** con Kube-Proxy Replacement (KPR)
- **OVN-Kubernetes** (CNI por defecto de OpenShift)

## Estructura

```
tests/
├── k6/                          # Scripts de Grafana k6
│   ├── latency-test.js          # Pruebas de latencia por escenario
│   └── connection-test.js       # Pruebas de establecimiento de conexión
├── manifests/                   # Manifiestos de Kubernetes
│   ├── target-deployment.yaml   # Pods y Services target
│   ├── iperf3.yaml              # Servidor/cliente iperf3
│   ├── netperf.yaml             # Servidor/cliente netperf
│   └── k6-job.yaml              # Job de k6 en Kubernetes
├── scripts/                     # Scripts de ejecución
│   ├── run-tests.sh             # Script principal de pruebas
│   ├── compare-results.sh       # Comparador de resultados
│   └── measure-hops.sh          # Análisis de saltos de red
└── README.md
```

## Prerrequisitos

- Acceso a cluster OpenShift con `oc` o `kubectl`
- Permisos para crear namespaces y pods
- Para pruebas locales de k6: [Grafana k6](https://k6.io/docs/getting-started/installation/)

## Uso Rápido

### 1. Ejecutar todas las pruebas

```bash
cd networking/cilium/tests/scripts
chmod +x *.sh

# En cluster con Cilium
./run-tests.sh -o ./results-cilium

# En cluster con OVN (cambiar contexto o cluster)
./run-tests.sh -o ./results-ovn
```

### 2. Comparar resultados

```bash
./compare-results.sh ./results-cilium ./results-ovn
```

### 3. Analizar saltos de red

```bash
./measure-hops.sh
```

## Escenarios de Prueba

### Latencia (k6)

| Escenario | Descripción | Duración |
|-----------|-------------|----------|
| Pod-to-Pod (mismo nodo) | Comunicación directa entre pods en el mismo worker | 2 min |
| Pod-to-Pod (diferente nodo) | Comunicación entre pods en diferentes workers | 2 min |
| Pod-to-Service (ClusterIP) | Acceso a Service tipo ClusterIP | 2 min |
| Pod-to-Service (NodePort) | Acceso a Service tipo NodePort | 2 min |
| Throughput (carga) | Prueba de carga progresiva (10→100→10 VUs) | 4 min |

### Throughput (iperf3)

- TCP throughput con 4 streams paralelos
- UDP throughput a 10 Gbps

### Latencia de conexión (netperf)

- TCP_RR: Request/Response latency
- TCP_CRR: Connect/Request/Response (incluye establecimiento TCP)
- TCP_STREAM: Throughput sostenido

## Métricas Recolectadas

### Latencia
- Min, Avg, P95, P99, Max (en milisegundos)
- Por escenario (pod-to-pod, service, etc.)

### Conexiones
- TCP Connect time
- Time to First Byte (TTFB)
- Total duration

### Throughput
- Mbps/Gbps (TCP y UDP)
- Requests por segundo

### Saltos (Hops)
- Número de hops en traceroute
- Análisis del datapath (eBPF para Cilium, OVS para OVN)

## Resultados Esperados

### Cilium con KPR

| Métrica | Valor Esperado |
|---------|----------------|
| Latencia pod-to-pod (mismo nodo) | < 0.5ms |
| Latencia pod-to-pod (diff nodo) | < 2ms |
| Latencia ClusterIP | < 2ms |
| Hops pod-to-pod | 1-2 |
| Hops pod-to-service | 1 |

**Ventajas de KPR:**
- Load balancing directo en eBPF (sin kube-proxy)
- Menor número de saltos
- Sin overhead de iptables/IPVS

### OVN-Kubernetes

| Métrica | Valor Esperado |
|---------|----------------|
| Latencia pod-to-pod (mismo nodo) | < 1ms |
| Latencia pod-to-pod (diff nodo) | < 3ms |
| Latencia ClusterIP | < 4ms |
| Hops pod-to-pod | 2-3 |
| Hops pod-to-service | 2+ |

**Características:**
- Usa OVS (Open vSwitch)
- kube-proxy maneja Services
- Más saltos en el datapath

## Ejecución Manual de k6

Para ejecutar k6 localmente (requiere conectividad al cluster):

```bash
# Obtener IPs de pods
POD_IP_SAME=$(oc get pods -n network-perf-test -l app=perf-target -o jsonpath='{.items[0].status.podIP}')
POD_IP_DIFF=$(oc get pods -n network-perf-test -l app=perf-target -o jsonpath='{.items[1].status.podIP}')
NODE_IP=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Ejecutar k6
k6 run k6/latency-test.js \
  -e POD_IP_SAME_NODE=$POD_IP_SAME \
  -e POD_IP_DIFF_NODE=$POD_IP_DIFF \
  -e SERVICE_CLUSTERIP=perf-target-clusterip.network-perf-test.svc \
  -e NODE_IP=$NODE_IP \
  -e CNI_TYPE=Cilium
```

## Integración con Prometheus/Grafana

Para enviar métricas de k6 a Prometheus:

```bash
k6 run --out experimental-prometheus-rw latency-test.js
```

Configurar en k6:
```javascript
export const options = {
  // ...
  ext: {
    loadimpact: {
      projectID: 123456,
      name: "Network Performance Test"
    }
  }
};
```

## Limpieza

```bash
# Eliminar namespace de pruebas
oc delete namespace network-perf-test

# O usar el script con flag -c
./run-tests.sh -c
```

## Troubleshooting

### Pods no inician
```bash
oc get events -n network-perf-test
oc describe pod <pod-name> -n network-perf-test
```

### k6 no puede conectar a los targets
- Verificar que los pods target están Running
- Verificar NetworkPolicies que puedan bloquear tráfico
- Verificar que el Service tiene endpoints: `oc get endpoints -n network-perf-test`

### Traceroute no funciona
- Algunos CNIs bloquean ICMP
- Usar `mtr` como alternativa
- Verificar con `ping` primero

## Referencias

- [Grafana k6 Documentation](https://k6.io/docs/)
- [Cilium Performance Tuning](https://docs.cilium.io/en/stable/operations/performance/)
- [OVN-Kubernetes Architecture](https://github.com/ovn-org/ovn-kubernetes)
- [Isovalent - Cilium KPR](https://docs.isovalent.com/ink/network/kube-proxy-replacement.html)
