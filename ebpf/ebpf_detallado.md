# eBPF para Observabilidad (Zero-code): guía detallada

## Resumen ejecutivo

**eBPF** (extended Berkeley Packet Filter) es una tecnología del kernel de Linux que permite ejecutar **programas “sandboxed”** en un **contexto privilegiado** (el kernel) para **extender capacidades** del sistema de forma **segura y eficiente**, sin modificar el código fuente del kernel ni cargar módulos tradicionales. Esto habilita observabilidad “zero-code” (sin tocar aplicaciones) y, además, capacidades avanzadas de red y seguridad.

En observabilidad, eBPF aporta:

- **Cobertura transversal**: red, syscalls, CPU, I/O, procesos, contenedores y Kubernetes desde el host.
- **Menor fricción**: ideal cuando instrumentar código es inviable (legacy, terceros, múltiples lenguajes, binarios).
- **Señales útiles para operación**: troubleshooting, performance, dependencias de servicios, auditoría y control.

Este documento explica qué es eBPF, cuándo conviene, requisitos, modelos de despliegue, detalle técnico, rendimiento, instrumentación, beneficios, riesgos y criterios prácticos para usarlo en Kubernetes/OpenShift.

---

## 1) Qué es eBPF (definición y mental model)

Una definición útil (en línea con material de Isovalent) es:

- eBPF permite correr programas **sandboxed** dentro del kernel para extenderlo de forma segura, **sin** cambiar el kernel ni usar módulos.

### Por qué es relevante para observabilidad

En lugar de depender solo de:

- **Instrumentación en proceso** (SDKs OpenTelemetry, agentes APM por lenguaje), o
- **Logs / métricas expuestas por la app**,

eBPF permite observar “desde abajo”:

- **Tráfico y llamadas** que pasan por el sistema operativo.
- **Relación pod → proceso → socket → destino** (útil en Kubernetes).
- **Eventos de red/política** (enfoque CNI/eBPF como Cilium).

---

## 2) Historia (muy breve)

- **BPF clásico**: creado para filtrado de paquetes (pcap/tcpdump) con un VM simple.
- **eBPF**: evolución que amplía el modelo (más hooks, mapas, helpers, JIT) y lo convierte en una “plataforma” en-kernel para networking, tracing, observabilidad y seguridad.

---

## 3) Cómo funciona eBPF (detalle técnico esencial)

### 3.1 Componentes

- **Programas eBPF**: código que se carga al kernel y se “engancha” (attach) a eventos/hookpoints.
- **Verifier**: valida que el programa sea seguro (no loops no acotados, accesos inválidos, etc.).
- **JIT**: compila a código nativo para reducir overhead.
- **Maps**: estructuras key/value compartidas entre kernel y user space (estado, contadores, tablas).
- **Ring buffer / perf buffer**: canal para “emitir eventos” desde kernel hacia user space.
- **User-space agent/collector**: proceso que:
  - carga/actualiza programas,
  - lee buffers,
  - enriquece con metadata (p. ej. Kubernetes),
  - exporta a backends (OTLP/Prometheus/logs/SaaS).

### 3.2 Dónde se engancha (attach points típicos)

Dependiendo del objetivo, se usan distintos hookpoints:

- **Tracing / eventos**:
  - `kprobes`/`kretprobes` (funciones del kernel),
  - `tracepoints` (puntos estables de tracing),
  - `uprobes`/`uretprobes` (funciones en user space: librerías, runtimes).
- **Networking datapath**:
  - **TC** (ingress/egress),
  - **XDP** (muy temprano en RX, pensado para performance),
  - cgroup hooks para control por grupo de procesos.
- **Seguridad**:
  - hooks de control (p. ej. modelos tipo LSM/eBPF, según herramienta).

### 3.3 eBPF + Kubernetes

El kernel no “conoce Kubernetes”, así que el valor práctico depende del **enriquecimiento**:

- agente consulta el API/metadata del runtime para mapear:
  - PID/namespace/cgroup → contenedor → pod/namespace → labels.

---

## 4) Objetivos típicos al adoptar eBPF

Definir objetivos evita “recolectar por recolectar”.

- **Reducir MTTR**: troubleshooting más rápido en incidentes.
- **Cobertura zero-code**: observabilidad sin tocar pipelines de release.
- **Visibilidad de red/política**: “quién habla con quién”, drops, DNS, dependencias.
- **Performance**: profiling y latencias sin agentes por lenguaje (según herramienta).
- **Gobernanza/seguridad**: auditoría de tráfico, políticas, y detección de patrones.
- **Estandarización**: exportar a OTLP/Prometheus para retención centralizada.

---

## 4.1) Beneficios (qué se gana en la práctica)

- **Time-to-value**: se puede empezar a ver señales sin esperar ciclos de instrumentación y redeploy.
- **Cobertura transversal**: un mismo enfoque sirve para múltiples lenguajes/runtimes y para componentes no instrumentables.
- **Menos “agentes por lenguaje”**: reduce fricción de operación y de gobierno de librerías/SDK.
- **Observabilidad de red/política**: habilita troubleshooting y auditoría que no se obtiene solo con spans.
- **Complemento natural de OTel**: eBPF puede producir señales que luego se exportan/retienen en pipelines estándar.

---

## 5) Cuándo usar eBPF (y cuándo no)

### 5.1 Cuándo conviene

- **No se puede instrumentar código**:
  - apps legacy, binarios, proveedores, equipos sin ownership de código.
- **Muchos lenguajes/runtimes**:
  - reducir diversidad de agentes SDK por lenguaje.
- **Observabilidad de red/política**:
  - cuando el problema principal está en conectividad, DNS, drops, políticas.
- **Necesidad de visibilidad inmediata**:
  - debugging en vivo (según plataforma: Pixie), o troubleshooting de red (Hubble).

### 5.2 Cuándo NO conviene (o conviene como complemento)

- **Necesitas semántica de negocio**:
  - spans con atributos de aplicación, colas internas, métricas de dominio; ahí OTel/SDK suele ser superior.
- **Restricciones fuertes de seguridad**:
  - ambientes donde `privileged`/SCC elevados para agentes eBPF es impracticable.
- **Histórico largo y consultable**:
  - eBPF “genera señales”; el histórico depende del backend. Sin backend, quedas en “near real-time”.

---

## 6) Requerimientos y precondiciones (Linux/Kubernetes/OpenShift)

### 6.1 Kernel y host

- **Kernel Linux con soporte eBPF suficiente** (la versión mínima depende del producto/capacidades).
- Acceso a:
  - `bpffs` (BPF filesystem),
  - `tracefs`/`/sys` (según hooks),
  - `hostPID` y/o visibilidad de namespaces/cgroups (según necesidad).

### 6.2 OpenShift (SCC y gobierno de privilegios)

En OpenShift, muchos agentes eBPF requieren:

- **SCC** con privilegios elevados (`privileged` o capacidades específicas), y revisiones de seguridad.
- Tratar eBPF como **capacidad de plataforma**:
  - imágenes aprobadas, hardening, auditoría, y runbooks.

### 6.3 Plataforma de observabilidad (backend)

Decidir temprano:

- **Dónde se almacenará** (retención): Tempo/Jaeger (traces), Prometheus/Mimir (métricas), Loki/Elastic (eventos/logs), u opción SaaS.
- **Qué se exporta**: señales agregadas vs eventos detallados (volumen/cardinalidad).

---

## 7) Modelos de despliegue (patrones reales)

### 7.1 Agente por nodo (DaemonSet) + export (patrón más común)

- Un **DaemonSet** carga programas eBPF en cada nodo y recolecta señales.
- Exporta a:
  - **OTLP** (Collector),
  - **Prometheus** (scrape/remote-write),
  - o pipeline de logs/eventos.

Ejemplos: auto-instrumentación eBPF para métricas/traces de servicios, agentes de red, etc.

### 7.2 Agente por nodo + control plane por clúster

Se añade un plano de control para queries/UX/gestión:

- **Pixie**: agentes por nodo (PEM) + control plane (Vizier) para queries interactivas.
- Otros orquestadores: operador/control plane que decide qué instrumentar y cómo enrutar.

### 7.3 eBPF “embebido” en el CNI (modelo Cilium)

Cuando el datapath del cluster está basado en eBPF (p. ej. Cilium):

- observabilidad de red/política se vuelve nativa del plano de red.
- Hubble expone:
  - flujos, dependencias, verdicts, DNS, etc.

### 7.4 Agente “unificado” (vendor/SaaS)

Algunos proveedores empaquetan eBPF + collector + correlación en una sola oferta:

- Un agente por host/cluster recoge señales (incl. eBPF) y las envía a un backend SaaS con retención gestionada.
- Ventaja: time-to-value y operación simplificada.
- Trade-off: menor control del plano de datos y de la política de retención/consulta (depende del plan).

---

## 8) Instrumentación basada en eBPF (cómo se obtienen señales)

### 8.1 Observabilidad de red (flows, DNS, drops, dependencias)

Este enfoque observa a nivel de datapath del host/CNI:

- **Qué puedes responder bien**: “quién habla con quién”, latencia/errores de red, drops, DNS, veredictos de policy.
- **Qué no obtienes**: semántica interna de la aplicación (p. ej. una función interna lenta) sin otras señales.

Un punto operativo importante (ejemplo Hubble): mucha de la visibilidad es **near real-time** y depende de buffers. En el material de Hubble se enfatiza que:

- se observa desde un **buffer**,
- al llenarse, **eventos antiguos se descartan** automáticamente.

Esto no es un “bug”: es un diseño común para flujos a alta tasa; el histórico real requiere export a backend.

### 8.2 Auto-instrumentación de aplicaciones (HTTP/gRPC/etc.) sin SDK

Aquí el objetivo es producir señales “tipo APM” (métricas RED y/o spans) sin tocar código:

- Se usan **uprobes** sobre runtimes/librerías (p. ej. TLS/HTTP stacks) o puntos conocidos de frameworks.
- Trade-off: cobertura depende de:
  - protocolos soportados,
  - runtimes/librerías en uso,
  - compatibilidad de símbolos y versiones.

### 8.3 Tráfico cifrado (TLS) y límites prácticos

eBPF no “rompe” TLS en red. Lo que algunas herramientas hacen es engancharse (uprobes) en puntos **antes/después** de cifrar/descifrar en librerías TLS, para extraer metadata o payload bajo ciertas condiciones.

- Beneficio: visibilidad donde la captura en red no sirve.
- Riesgo/limitación: alta dependencia de librerías/versiones y consideraciones de privacidad/compliance (ver sección 10).

---

## 9) Rendimiento, overhead y escalabilidad (lo que realmente pega)

### 9.1 De qué depende el overhead

El costo no es solo “eBPF sí/no”; depende de:

- **hookpoint** (XDP/TC/tracepoints/uprobes),
- **frecuencia** del evento (p. ej. syscalls a altísima tasa),
- **cantidad de campos** y enriquecimiento,
- **volumen exportado** (red, CPU user-space, backend),
- **cardinalidad** (labels por pod/destino/endpoint),
- **consultas interactivas** (plataformas tipo “live debugging”).

### 9.2 Eventos vs métricas agregadas

Regla práctica:

- **métricas agregadas** (contadores/histogramas) suelen escalar mejor y son ideales para alerting,
- **eventos detallados** son valiosos para forensics/troubleshooting, pero requieren filtros, sampling y retención pensada.

### 9.3 Retención “nativa” suele ser limitada

Si la herramienta se apoya en ring buffers/buffers locales:

- la retención efectiva se mide en **cantidad de eventos**, no en “días”.
- bajo alta tasa, los eventos antiguos se pierden rápido.

Diseño recomendado:

- “near real-time” para operación,
- export selectiva a backend para histórico.

### 9.4 Performance en red: puntos a considerar (Cilium)

En el material de diseño de networking con Cilium aparecen dos ideas útiles para performance:

- **Native routing** puede evitar encapsulación de overlays (reduciendo overhead).
- **XDP acceleration** aparece como feature para mejorar performance en determinados caminos del datapath.

---

## 10) Seguridad y riesgos (y cómo mitigarlos)

### 10.1 Privilegios (el riesgo más frecuente)

La mayoría de despliegues eBPF en Kubernetes/OpenShift requieren acceso elevado al host:

- en OpenShift esto implica SCC/capacidades elevadas.

Mitigación:

- tratarlo como **componente de plataforma** (aprobación, imágenes, hardening, auditoría),
- limitar alcance por cluster/namespace cuando sea viable,
- definir runbooks y ownership (SRE/Plataforma).

### 10.2 Datos sensibles

Dependiendo de qué se capture (y especialmente si hay visibilidad a nivel de librería/protocolo):

- podría observarse metadata o payload sensible.

Mitigación:

- políticas claras de qué señales se recolectan,
- filtros por namespace/servicio,
- redacción/masking cuando aplique,
- retención y control de acceso en backend.

### 10.3 Compatibilidad y upgrades

Riesgos típicos:

- cambios de kernel,
- cambios de librerías/runtimes (para uprobes),
- upgrades de OpenShift.

Mitigación:

- piloto y validación con cargas reales,
- ventanas de upgrade,
- matrices de compatibilidad por herramienta.

---

## 11) Checklist de adopción (pragmático)

- **Objetivo**: ¿APM zero-code, red/política, live debugging, seguridad?
- **Restricciones**: OpenShift SCC, compliance, acceso a nodos.
- **Backend/retención**: dónde vive el histórico y por cuánto.
- **Modelo de datos**: qué exportar, cardinalidad, costos.
- **Piloto**: 1 cluster, 1-2 namespaces, medir overhead y valor.
- **Operación**: upgrades, runbooks, ownership, SLOs.

---

## 12) Referencias (material dentro del repo)

- `doc_files/Container-Security-Liz-Rice.pdf` (contexto de fundamentos Linux/containers y eBPF en el panorama moderno)
- `doc_files/Isovalent-Networking-For-Kubernetes-Design-Guide.pdf` (native routing, XDP acceleration y consideraciones de diseño)
- `doc_files/Kubernetes Network Policies Done the Right Way by Isovalent.pdf` (definición de eBPF + enfoque de policy/observabilidad con Cilium/Hubble)
- `doc_files/Cilium Network Policy Deep Dive by Isovalent.pdf` (Security Identity, labels y cómo se embebe identidad/policy en eBPF datapath)
- `doc_files/Isovalent - Cilium Hubble Cheat Sheet.pdf` (componentes de Hubble y comportamiento de buffer/flows)
- `observabilidad/analisis_pixie_profundo.md`
- `observabilidad/analisis_hubble_cilium_profundo.md`
- `observabilidad/evolucion_github_candidatos_ebpf.md`

---

*Fin del documento.*

<!-- EOF -->