# Análisis profundo: Pixie (observabilidad eBPF en tiempo real para Kubernetes)

## Objetivo

Este documento profundiza en **Pixie** como solución de observabilidad basada en **eBPF** orientada a **debugging y análisis en tiempo real** en Kubernetes/OpenShift, y propone cómo evaluarla con ejes como **HA, retención, backends y costos**.

## Alcance (qué cubre y qué no)

- **Cubre**: capacidades principales (live debugging, PxL, profiling), arquitectura (PEM/Vizier), despliegue en OpenShift, modelos de retención/export, consideraciones de HA y costos.
- **No cubre**: instrumentación “APM clásica” de aplicación (spans OTel end-to-end como objetivo principal). Pixie puede integrarse con pipelines, pero su foco diferencial es el **tiempo real**.

## Qué es Pixie (en una frase)

**Pixie** es una plataforma de observabilidad para Kubernetes que usa **eBPF** (kprobes/uprobes) para capturar señales del sistema y protocolos, permitiendo **consultas interactivas en vivo** (PxL) sin redeploy ni cambios de código.

## Qué preguntas responde Pixie (casos de uso)

- **Debugging en vivo**:
  - ¿Qué requests está recibiendo un servicio ahora mismo?
  - ¿Qué endpoints están fallando y con qué latencias?
  - ¿Qué consultas SQL se observan (según protocolo soportado) y qué tiempos tienen?
- **Análisis operativo**:
  - Top N de latencias/errores por servicio/pod.
  - Correlación “red → proceso → contenedor” sin instrumentación.
- **Profiling / performance**:
  - CPU profiling y análisis de hotspots (según capacidades/feature set y configuración).
- **Entornos con cifrado**:
  - En algunos escenarios puede observar señales a nivel de librerías (uprobes) aun con tráfico cifrado (el valor real depende del stack TLS/runtime y del modo de captura).

## Lo que Pixie no reemplaza (límites)

- **No reemplaza el histórico largo plazo**: su fortaleza es *live*; el histórico real depende de export/backends.
- **No garantiza cobertura total de protocolos**: la visibilidad depende de lo que el proyecto soporte y de la compatibilidad con runtimes/librerías.
- **No es un SIEM**: aunque aporta señales valiosas, no es una plataforma de seguridad por sí misma.

## Arquitectura (componentes y rol)

En un despliegue típico:

- **PEM (Pixie Edge Module)**: agentes por nodo (normalmente `DaemonSet`) que ejecutan programas eBPF y recolectan telemetría.
- **Vizier**: plano de control por clúster (componentes en `Deployment`/`StatefulSet` según versión) que:
  - coordina PEMs,
  - sirve consultas PxL,
  - expone UI y APIs,
  - gestiona almacenamiento/retención de corto plazo.
- **Pixie Cloud (opcional, según modo)**: capa SaaS para administración multi-clúster y/o UI centralizada, dependiendo del modelo de despliegue elegido.

Implicación clave: Pixie introduce **componentes por clúster** (además de los agentes por nodo), lo cual impacta en HA, upgrades y operación.

## OpenShift: consideraciones específicas (SCC y acceso al host)

Como la mayoría de soluciones eBPF:

- **Permisos/SCC**: suele requerir `privileged` o capacidades elevadas (acceso a kernel, `tracefs`, `bpffs`, `hostPID`), lo cual se gestiona vía **SCC** en OpenShift.
- **Aprobación de seguridad**: conviene tratarlo como componente de plataforma (revisión de permisos, imágenes, hardening, controles).
- **Compatibilidad kernel**: depende del kernel de los nodos y de la versión/feature set de eBPF disponible.

Enfoque recomendado:

- **Piloto acotado** (cluster o namespace controlado) para validar:
  - overhead,
  - compatibilidad con workloads,
  - cobertura de protocolos real,
  - seguridad/controles.

## Ejes propuestos para evaluar Pixie (y compararlo con otros candidatos)

### 1) Alta disponibilidad (HA)

Preguntas a responder:

- **¿Qué queda “single point of failure”?** (componentes de Vizier, UI, servicios internos)
- **¿Qué pasa si cae un nodo con PEM?** (se pierde visibilidad del nodo afectado; el resto del clúster sigue operando)
- **¿Qué pasa si cae el control plane de Pixie en el clúster?** (impacto en queries PxL, UI, agregación)

Criterios prácticos:

- **Réplicas/anti-affinity** en componentes de control plane cuando aplique.
- **Resource limits** y dimensionamiento para evitar degradación bajo carga (picos de queries en incidentes).
- **SLO operativo**: latencia de consultas “live”, degradación aceptable y comportamiento en fallas.

### 2) Retención (corto plazo vs histórico)

Pixie está diseñado para **near real-time** y retención **limitada** en el clúster (dependiendo de configuración y recursos).

Decisiones a explicitar:

- **Objetivo de retención local** (horas/días) para “investigación durante incidente”.
- **Qué exportar** para histórico:
  - métricas agregadas,
  - eventos seleccionados,
  - resultados de queries,
  - señales de performance.

Regla práctica: si se requiere **histórico largo** (semanas/meses), Pixie debe integrarse con un backend/pipeline externo.

### 3) Backends (export e integración)

Evaluar Pixie por su capacidad de:

- **Exportar** (cuando aplique) a:
  - sistemas de métricas (Prometheus/remote-write),
  - pipelines OTel/OTLP,
  - logging/analytics (eventos estructurados),
  - APIs para integrar con tooling interno.
- **Operar en conjunto** con el stack existente (Grafana/Prometheus/OTel Collector, etc.).

Punto crítico: definir el “contrato” de datos exportados (volumen, schema, cardinalidad) para que el backend sea sostenible.

### 4) Costos (infra, operación, licencia)

Separar costos:

- **Costos de infraestructura**:
  - CPU/mem en nodos por PEM (eBPF + procesamiento),
  - recursos para Vizier/control plane,
  - almacenamiento temporal si se usa retención local.
- **Costos operativos**:
  - upgrades del control plane y compatibilidad,
  - soporte a equipos en el uso de PxL (prácticas, “playbooks”),
  - gobernanza de permisos (SCC) y auditoría.
- **Costos de licenciamiento**:
  - dependerá del modo OSS vs Cloud/Enterprise (si aplica al modelo adoptado).

Regla práctica: el costo total está muy ligado a (a) **intensidad de uso** en incidentes (queries), (b) dimensionamiento del control plane, y (c) si se agrega backend para histórico.

## Riesgos y mitigaciones

- **Cadencia de releases vs expectativas**:
  - Si el proyecto muestra poca cadencia pública de releases, mitigar con pruebas de upgrade y un “upgrade window” conservador.
- **Cobertura real de protocolos**:
  - Validar en piloto con tráfico real. No asumir que “lo soporta todo”.
- **Overhead bajo picos de consulta**:
  - Definir límites de uso (quién ejecuta queries pesadas), y dimensionar el control plane.
- **Seguridad/privilegios**:
  - Revisar SCC, aislamiento, control de imágenes, y hardening del despliegue.

## Contra quién se compara Pixie (y posibles candidatos de reemplazo)

Pixie se diferencia por su capacidad de **consultas interactivas en vivo** (PxL) y debugging “sin tocar código”. Al compararlo o pensar reemplazos, conviene partir del **objetivo principal**.

### Si el objetivo principal es “live debugging” en Kubernetes

- **BPF-based auto-instrumentation (Beyla / OTel OBI)**:
  - **Cuándo encaja**: cuando se quiere observabilidad más “APM/OTel” (métricas RED + trazas) con export estándar, aunque no ofrece el mismo modelo de queries interactivas tipo PxL.
  - **Trade-off**: se gana alineación OTel/backends y retención; se pierde parte del “exploratorio en vivo” de Pixie.
- **Odigos**:
  - **Cuándo encaja**: cuando el foco es estandarizar instrumentación y ruteo a backends OTel sin tocar código (más pipeline que “live debugging”).
  - **Trade-off**: excelente para gobernanza OTel; no es equivalente a la experiencia de debugging interactivo.

### Si el objetivo principal es “observabilidad de red/políticas” (no aplicación)

- **Cilium + Hubble**:
  - **Cuándo encaja**: cuando el dolor principal es networking/policies/drops/DNS/dependencias y se acepta la decisión de CNI.
  - **Trade-off**: visibilidad de red muy fuerte; no sustituye debugging de protocolos de app “a demanda” como Pixie.

### Si el objetivo principal es “APM end-to-end + retención + costos predecibles”

- **New Relic (eBPF) / otras plataformas SaaS**:
  - **Cuándo encaja**: cuando se prioriza time-to-value, retención gestionada y operación simplificada, aceptando el modelo comercial.
  - **Trade-off**: menos control fino del plano de datos y del “modo laboratorio” que habilita Pixie; el costo suele moverse al SaaS.

### Heurística rápida de elección (para “reemplazo”)

- **Necesito debugging exploratorio en vivo** → Pixie suele ser el mejor ajuste.
- **Necesito estándar OTel + backends + retención** → Beyla/OBI u Odigos (y Pixie como complemento “live” si hay valor).
- **Necesito red/políticas como capability** → Cilium/Hubble (y APM por otra herramienta).
- **Necesito simplificar operación y retención con un vendor** → New Relic u otra plataforma SaaS comparable.

## Cuándo conviene Pixie (posicionamiento)

- **Muy conveniente si**:
  - se prioriza **debugging interactivo en vivo** sin instrumentación y sin redeploy,
  - se busca acelerar MTTR en incidentes de performance/latencia,
  - se acepta que el histórico largo plazo se resuelve con export/backends.
- **Menos conveniente si**:
  - el objetivo principal es APM con spans/metrics estándar y retención larga sin integrar backends,
  - hay restricciones estrictas para SCC/privilegios en OpenShift y no hay margen para excepciones controladas.
