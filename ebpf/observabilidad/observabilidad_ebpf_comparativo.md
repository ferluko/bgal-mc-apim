# Comparativo: herramientas de observabilidad eBPF (zero-code)

> Documento de contexto técnico detallado: `doc_files/ebpf_detallado.md`

## Resumen ejecutivo

Este documento compara herramientas que usan **eBPF** para observabilidad **sin modificar aplicaciones**, con foco en:

- **Compatibilidad operativa con OpenShift** (SCC/privilegios, acceso al host, constraints reales).
- **Modelo de despliegue** (qué corre en nodos vs qué corre a nivel clúster).
- **Backend y retención** (qué queda “near real-time” vs qué se guarda en histórico).
- **Madurez / evolución** (señales públicas de repos, cuando aplica).

La idea central es separar “eBPF como tecnología” (ver `doc_files/ebpf_detallado.md`) de la decisión “qué herramienta conviene para qué objetivo”.

---

## 1) Hallazgos clave de los libros (para nutrir la comparación)

### 1.1 eBPF como base (definición operativa)

En el material de Isovalent se sintetiza eBPF como tecnología que corre programas **sandboxed** en un contexto privilegiado (kernel) para extender capacidades de forma segura, sin cambiar el kernel ni cargar módulos. Esto explica por qué eBPF es una base común para **red**, **observabilidad** y **políticas**.

### 1.2 Hubble: “near real-time” por diseño (buffers y drops)

En el cheat sheet de Hubble, el modelo explícito es:

- se observa desde un **buffer**,
- cuando el buffer se llena, los **eventos antiguos se descartan**.

Implicación: si se requiere histórico (días/semanas/meses), el comparativo debe evaluar **export a backend** y no asumir retención “nativa”.

### 1.3 Cilium: identidad/labels y enforcement en datapath eBPF

En el deep dive de Cilium Network Policy aparece un concepto clave para plataformas:

- **Security Identity** derivada de **labels** (identity-relevant),
- esa identidad se **embebe** en el datapath con programas eBPF y se usa para enforcement.

Implicación: el valor de Hubble/Cilium no es solo “ver red”, sino operar **política + observabilidad** con un modelo consistente (identidades), con consecuencias directas en troubleshooting y compliance.

### 1.4 Performance de red (diseño Cilium)

En la guía de diseño de networking con Cilium se destacan (a nivel conceptual) dos palancas:

- **native routing** para evitar overhead de encapsulación de overlays,
- **XDP acceleration** como feature para rutas críticas de performance.

Implicación: herramientas “embebidas en el datapath” pueden aportar beneficios de rendimiento además de observabilidad, pero son **decisión de baseline (CNI)**.

---

## 2) Tabla comparativa (orientada a decisión)

| Criterio | **Grafana Beyla / OTel eBPF** | **Pixie** | **Odigos** | **Cilium + Hubble** | **New Relic (eBPF)** | **Coroot** |
| --- | --- | --- | --- | --- | --- | --- |
| **Objetivo principal** | APM zero-code (métricas/traces) | Live debugging K8s (consultas en vivo) | Orquestar auto-instrumentación OTel | Observabilidad de red/política | Suite unificada (APM+infra+red) | Full-stack observabilidad/APM (métricas, logs, traces, SLO, AI root-cause) |
| **Modelo en clúster** | DaemonSet por nodo (+ collector) | DaemonSet por nodo + control plane (Vizier) | Operador/control plane + pipeline OTel | CNI (Cilium) + Relay/UI/CLI | Agente por nodo + integraciones | Node agent (eBPF) + backend (ClickHouse); Helm/Operator |
| **Retención “nativa”** | No (depende de backend) | Corto plazo (foco live) | No (depende de backend) | Near real-time por buffers; histórico vía export | SaaS (según plan) | Sí (ClickHouse; alta compresión logs) |
| **Export / estándar** | OTLP / Prometheus | API/exports (según modo) | OTLP (backends OTel) | Prometheus / OTLP (según configuración) | Backend SaaS New Relic | OpenTelemetry spans (eBPF); almacenamiento propio |
| **OpenShift (SCC)** | Requiere SCC/host access | Requiere SCC/host access | Requiere SCC/host access | Requiere **CNI Cilium** + operación de plataforma | Requiere SCC/host access (según modo) | Requiere SCC/host access (kernel ≥ 5.1) |
| **“Red/policy” fuerte** | Parcial (app-centric) | Parcial (útil para debug) | Parcial (app-centric) | **Sí** (flows, verdicts, DNS, deps) | Parcial (según producto) | Parcial (app-centric; service maps) |
| **Madurez/evolución (repo)** | Activo; upstream OTel (OBI) en transición | Repo activo pero releases públicas con gap | Muy activo, releases frecuentes | Core Cilium muy activo; Hubble más “estable” | GitHub refleja charts; core es SaaS | Muy activo; releases frecuentes; comunidad grande |

> Señales de evolución: ver `observabilidad/evolucion_github_candidatos_ebpf.md`.

---

## 3) Lectura rápida por herramienta (qué aporta y qué no)

### 3.1 Grafana Beyla / OpenTelemetry eBPF Instrumentation

- **Aporta**: métricas RED y trazas distribuidas sin SDK, export OTLP/Prometheus.
- **No reemplaza**: observabilidad “network policy / drops / DNS” tipo Hubble.
- **Clave**: elegir backend/retención primero (Tempo/Jaeger/Prometheus/Mimir, etc.).

### 3.2 Pixie

- **Aporta**: experiencia de **debugging en vivo** (consultas interactivas) sin redeploy.
- **Trade-off**: su fortaleza no es el histórico largo; el histórico serio se logra con export.
- **Clave**: evaluar HA, límites bajo picos de consulta y costo operativo del control plane.

### 3.3 Odigos

- **Aporta**: “gobernanza” de auto-instrumentación y ruteo de señales hacia backends OTel.
- **Trade-off**: suele implicar control plane/CRDs; upgrades requieren disciplina.
- **Clave**: si el objetivo es estandarizar OTel, encaja especialmente bien.

### 3.4 Cilium + Hubble

- **Aporta**: observabilidad de **red + política** con un modelo de identidades/labels; útil para Zero Trust y compliance.
- **Trade-off**: depende de operar **Cilium como CNI** (decisión de plataforma).
- **Clave**: near real-time por diseño (buffers); histórico depende del backend de export.

### 3.5 New Relic (eBPF)

- **Aporta**: consolidación (un vendor) y retención gestionada.
- **Trade-off**: menos control del plano de datos y costos ligados al SaaS.

### 3.6 Coroot

- **Aporta**: observabilidad full-stack open-source (métricas, logs, traces, profiling, SLO, alerting) con eBPF zero-code; auto-instrumentación HTTP y bases de datos (Postgres, MySQL, Redis, MongoDB, Memcached); service maps, análisis de causa raíz con IA; retención propia con ClickHouse.
- **Trade-off**: stack completo a operar (backend + agentes); requisitos de kernel y privilegios (SCC en OpenShift) como el resto de soluciones eBPF.
- **Clave**: buena opción si se busca una pila única open-source con retención incluida y sin depender de un backend OTel externo para el core.

---

## 4) Criterios de selección (foco OpenShift)

| Si tu prioridad es… | Entonces prioriza… | Comentario |
| --- | --- | --- |
| **APM zero-code (traces + métricas) con estándar OTLP** | Beyla u Odigos | Ambos dependen del backend elegido para retención. |
| **Debugging en vivo en incidentes** | Pixie | Ideal como “herramienta de guerra”; no asumir histórico largo. |
| **Red, DNS, drops, política y dependencias** | Cilium + Hubble | Requiere decisión CNI; aporta capability de plataforma. |
| **Operación/retención “listo” en un SaaS** | New Relic | Evaluar costo/lock-in vs time-to-value. |
| **Full-stack open-source con retención propia (sin SaaS)** | Coroot | ClickHouse + agentes eBPF; incluye SLO, AI root-cause, service maps. |
| **Compatibilidad/seguridad (SCC)** | Todos requieren trabajo de plataforma | eBPF suele implicar privilegios; planificarlo como baseline. |

---

## 5) Recomendaciones combinadas (patrones que suelen funcionar)

- **Sin cambiar CNI (en OpenShift actual)**:
  - **APM zero-code**: Beyla u Odigos + backend OTel/Prometheus propio.
  - **Full-stack open-source con retención incluida**: Coroot (evita desplegar backend OTel aparte si se acepta ClickHouse).
  - **Debug puntual**: sumar Pixie si el valor “live” lo justifica.
- **Con decisión de plataforma (Cilium como CNI)**:
  - **Red/política**: Hubble para flows/verdicts/DNS/dependencias.
  - **APM**: seguir usando Beyla/Odigos/Coroot (Hubble no sustituye spans de app).

---

## 6) Referencias internas (repo)

- `doc_files/ebpf_detallado.md`
- `observabilidad/analisis_pixie_profundo.md`
- `observabilidad/analisis_hubble_cilium_profundo.md`
- `observabilidad/evolucion_github_candidatos_ebpf.md`
- PDFs en `doc_files/`:
  - `Kubernetes Network Policies Done the Right Way by Isovalent.pdf`
  - `Cilium Network Policy Deep Dive by Isovalent.pdf`
  - `Isovalent - Cilium Hubble Cheat Sheet.pdf`
  - `Isovalent-Networking-For-Kubernetes-Design-Guide.pdf`
  - `Container-Security-Liz-Rice.pdf`
