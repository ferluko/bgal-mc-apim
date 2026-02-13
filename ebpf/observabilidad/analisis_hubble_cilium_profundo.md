# Análisis profundo: Cilium + Hubble (observabilidad de red con eBPF)

## Objetivo

Este documento profundiza en **Hubble (ecosistema Cilium)** como capacidad de observabilidad de **red y políticas** en Kubernetes/OpenShift, y propone **nuevos ejes de evaluación** (HA, retención, backends, costos) para incorporarlos al comparativo de herramientas eBPF.

## Alcance (qué cubre y qué no)

- **Cubre**: observabilidad *network-centric* (flows, DNS, drops, latencias, verdicts de política), arquitectura de componentes, opciones de export/retención, consideraciones de alta disponibilidad y costos operativos.
- **No cubre**: APM de aplicación basado en spans end-to-end (eso lo cubren Beyla/Odigos/New Relic eAPM). Hubble se trata como **complemento** para la capa red/política.

## Qué es Hubble (en una frase)

**Hubble** es la capa de observabilidad construida sobre el datapath eBPF de **Cilium (CNI)** que permite ver, filtrar y exportar **eventos de red** (y seguridad/políticas) de forma distribuida, sin instrumentar aplicaciones.

## Qué preguntas responde Hubble (casos de uso)

- **Troubleshooting de conectividad**: ¿qué flujo fue denegado?, ¿por qué?, ¿dónde se droppea?  
- **Gobernanza de NetworkPolicy**: ¿qué políticas están aplicando en la práctica?, ¿qué “verdicts” se observan?  
- **Dependencias entre servicios**: mapa de “quién habla con quién” a nivel de red (útil para auditoría y refactor).  
- **Observabilidad de DNS**: consultas/respuestas, latencias, errores.  
- **Detección temprana**: spikes de drops, resets, timeouts, patrones anómalos de comunicación.

## Lo que Hubble no reemplaza (límites)

- **No es tracing distribuido de negocio**: no genera spans OTel de la aplicación con contexto semántico (métodos internos, colas, DB queries con atributos de app, etc.).
- **Visibilidad de payload**: su foco es metadata y eventos de red; la inspección profunda (L7/payload) depende de configuración y objetivos, y no equivale a instrumentación de app.

## Arquitectura (componentes y rol)

En un despliegue típico:

- **Cilium (CNI)**: datapath eBPF en cada nodo; aplica networking y políticas.
- **Hubble en el agente**: genera eventos/flows desde el datapath (por nodo).
- **Hubble Relay**: agrega/consulta flows de múltiples nodos y expone API para consumidores.
- **Hubble UI / CLI**: consumidores para exploración operativa (near real-time).
- **Exporters** (según elección): emisión hacia Prometheus/OTel u otros pipelines para almacenamiento/retención.

Implicación clave: **sin Cilium como CNI no hay Hubble en su forma “nativa”**.

## OpenShift: por qué el cambio de CNI “no es issue” si se decide ahora

Hubble es una capacidad de plataforma. La “dificultad” no es técnica aislada, es de **decisión de baseline**:

- **Si el proyecto está a tiempo** (plataforma aún en definición o hay margen para piloto), el cambio de CNI es gestionable y reduce deuda técnica futura.
- **Beneficio compuesto**: no solo Hubble; Cilium aporta una base sólida para red/políticas/observabilidad con un datapath eBPF moderno.

Enfoque recomendado:

- **Piloto por clúster**: validar con cargas reales (ingress/egress, DNS, service types, políticas, performance, runbooks).
- **Estandarización**: adoptar Cilium+Hubble como “golden path” para clústeres nuevos.
- **Clústeres existentes**: tratarlo como **migración por clúster** o ventana controlada, evitando asumir un “toggle” trivial.

## Ejes propuestos para evaluar Hubble (y comparar con otros candidatos)

### 1) Alta disponibilidad (HA)

Preguntas a responder:

- **¿Qué componentes deben ser HA?** (relay, UI, exporters, pipelines)
- **¿Qué pasa si cae un nodo?** (se pierde observabilidad del nodo afectado; ¿hay buffering?, ¿reintentos?)
- **¿Qué pasa si cae Relay?** (impacto en consultas centralizadas; los agentes siguen generando eventos pero se pierde agregación/consumo)

Criterios prácticos:

- **Relay en HA**: múltiples réplicas detrás de Service; readiness/liveness; escalado horizontal.
- **Backpressure**: límites de tasa, filtros y sampling para no saturar relay/pipeline.
- **SLO operativo**: latencia de visualización (near real-time), degradación aceptable y comportamiento en incidentes.

### 2) Retención (near real-time vs histórico)

Hubble “en sí” es mayormente **near real-time**; el histórico real depende del **backend**.

Decisiones a explicitar:

- **Qué retener**: flows completos, métricas agregadas, eventos de drops/políticas, DNS, etc.
- **Cuánto retener**: días/semanas/meses (según auditoría, forensics, troubleshooting).
- **Nivel de detalle**: retener todo puede ser inviable; conviene retener agregados + eventos “importantes”.

Recomendación típica:

- **Operación diaria**: UI/CLI + métricas (Prometheus) para señales.
- **Investigación/auditoría**: export a backend con retención definida (OTel/logs/TSDB) para histórico filtrable.

### 3) Backends (almacenamiento y consulta)

Hubble puede integrarse mediante export hacia:

- **Prometheus/TSDB**: para métricas de red (series temporales) y alerting.
- **OpenTelemetry (OTLP) / collectors**: como “pipe” para enviar a backends elegidos (observabilidad centralizada).
- **Stack de logging/analytics**: si se convierten eventos a logs estructurados para búsqueda/histórico (según estándar interno).

Cómo evaluarlo:

- **Compatibilidad con el stack existente**: ¿ya hay Prometheus/OTel Collector?, ¿hay estándar OTLP?
- **Cardinalidad y volumen**: eventos de red pueden explotar en cardinalidad (labels por pod, namespace, destino, etc.).
- **Coste de consulta**: búsquedas tipo “forensics” en eventos pueden ser caras si se modelan como logs sin estrategia.

### 4) Costos (infra, operación, licencia)

Dividir costos para decidir sin sesgo:

- **Costos de infraestructura**:
  - CPU/memoria adicional en nodos (Cilium datapath + generación de eventos).
  - Recursos para Relay/UI/exporters/collectors.
  - Almacenamiento y egress hacia backend (si se retiene histórico).
- **Costos operativos**:
  - Curva de aprendizaje (runbooks, upgrades, troubleshooting).
  - Gestión de cardinalidad/volumen (filtros, sampling, políticas de retención).
  - Integración con seguridad/plataforma (SCC, auditoría, cambios de baseline).
- **Costos de licenciamiento/soporte**:
  - OSS vs enterprise (si se evalúa soporte comercial, features avanzadas, multi-cluster, etc.).

Regla práctica: el costo “dominante” suele ser el **backend/retención** (almacenamiento y consulta), no el componente Hubble en sí.

## Riesgos y mitigaciones (enfoque de plataforma)

- **Volumen de eventos**:
  - Mitigar con filtros por namespace, tipo de evento, sampling y enfoque “métricas primero” + eventos bajo demanda.
- **Cardinalidad en métricas**:
  - Definir cuáles labels son permitidas; evitar combinaciones explosivas por pod/destino.
- **Dependencia de baseline (CNI)**:
  - Tratar como decisión de plataforma: piloto, estándares, y un plan de migración por clúster cuando aplique.
- **Gobernanza de upgrades**:
  - Versionado, ventanas, validación en preproducción, compatibilidad con versión de OpenShift/kernel.

## Cómo quedaría en el comparativo (nuevos ejes sugeridos)

Para enriquecer el documento comparativo, agregar columnas/ejes transversales:

- **HA**: qué componentes soportan HA y qué implica operar en HA.
- **Retención nativa vs dependiente**: si la herramienta almacena algo por sí misma o depende 100% del backend.
- **Backends soportados**: OTLP, Prometheus, logs/analytics, SaaS.
- **Modelo de costos**:
  - Costo “en cluster” (agentes/control plane).
  - Costo “off cluster” (almacenamiento/consulta).
  - Complejidad operativa (SRE).

## Recomendación (posicionamiento)

- **Si el objetivo incluye observabilidad de red/políticas como capacidad estándar**: Hubble es un candidato fuerte, pero debe evaluarse como **decisión de CNI** y no como simple add-on.
- **Si el objetivo es principalmente APM de aplicaciones**: Hubble no sustituye a Beyla/Odigos/New Relic; se justifica cuando hay dolores de red/políticas o se quiere gobernanza fuerte.
