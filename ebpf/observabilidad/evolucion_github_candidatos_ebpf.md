# Evolución en GitHub – Candidatos de Observabilidad eBPF (zero-code)

## Alcance y método

Este documento revisa la **evolución del proyecto en GitHub** de los 6 candidatos del comparativo eBPF, usando señales públicas de salud/madurez:

- **Actividad**: `pushed_at`, commits semanales (últimos 12 meses vía `stats/commit_activity` cuando está disponible).
- **Release cadence**: último release (`releases/latest`) y patrón observable.
- **Comunidad**: estrellas/forks, volumen de issues abiertos.
- **Mantenimiento**: issues/PRs actualizados recientemente, fuerte uso de bots (Renovate/Dependabot) vs cambios funcionales.

> Nota: los números son un *snapshot* consultado en `api.github.com` (Feb 2026). En proyectos grandes, el conteo de “open issues” incluye PRs.

---

## Resumen comparativo (lectura rápida)

| Candidato | Señal de actividad reciente | Señal de releases | Lectura “evolución” |
|----------|------------------------------|-------------------|---------------------|
| **Grafana Beyla** (y upstream **OTel OBI**) | Muy activo (push Feb 2026). Beyla con commits semanales moderados; OBI con commits semanales moderados/altos desde 2025 | Beyla `v2.8.5` (Jan 2026). OBI `v0.4.1` (Jan 2026) | Proyecto “en transición”: **Beyla → upstream OpenTelemetry (OBI)**. Evoluciona rápido, con cambio de gobernanza y de “repo principal”. |
| **Pixie** | Push Feb 2026, pero commits semanales muy bajos y largos períodos con 0 | Último release “cloud” visible `v0.1.9` (Jan 2025) | Código vivo, pero **cadencia de releases baja**; muchas actualizaciones recientes son de dependencias/bots. Señal de “mantenimiento” más que evolución fuerte. |
| **Odigos** | Muy activo (push Feb 2026) y commits semanales altos y sostenidos | `v1.17.1` (Feb 2026) | Evolución **constante** (release frecuente + commit velocity alta). Buen indicador de roadmap activo. |
| **Cilium + Hubble** | Cilium: altísima actividad semanal y release reciente. Hubble repo: commits bajos (probable “capa estable”) | Cilium `v1.19.0` (Feb 2026). Hubble `v1.18.6` (Feb 2026) | Ecosistema **maduro** con evolución fuerte en el core (Cilium). Hubble avanza, pero gran parte de la evolución ocurre en Cilium. Implica **decisión de CNI** (plataforma), que si se toma a tiempo suele ser netamente positiva. |
| **New Relic (eBPF)** (GitHub = helm-charts) | Repo de charts con push Feb 2026 y releases muy frecuentes (automatizadas) | `nr-k8s-otel-collector-0.10.4` (Feb 2026) + releases de bundle/charts | La “evolución” visible en GitHub es del **artefacto de despliegue** (Helm). El motor eBPF/eAPM es **producto SaaS**: menos señal de evolución técnica desde repos públicos. |
| **Coroot** | Muy activo (push Feb 2026), repo único con alta actividad | `v1.17.9` (Jan 2026) | Observabilidad full-stack open-source (APM, traces, SLO, AI root-cause). eBPF para zero-code; releases frecuentes y comunidad grande (stars/forks). |

---

## 1) Grafana Beyla + upstream OpenTelemetry OBI

### Repos analizados

- Beyla: `https://github.com/grafana/beyla`
- Upstream OBI: `https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation`

### Snapshot (GitHub API)

- **Beyla (`grafana/beyla`)**
  - **Creado**: 2023-02-20
  - **Stars/Forks**: 1919 / 166
  - **Open issues**: 135
  - **Último push**: 2026-02-11
  - **Último release**: `v2.8.5` publicado 2026-01-13
  - **Commits semanales (último año)**: variable (hay semanas de 0, otras >20; típico de proyecto con releases y bursts).
- **OBI (`open-telemetry/opentelemetry-ebpf-instrumentation`)**
  - **Creado**: 2025-04-16
  - **Stars/Forks**: 365 / 73
  - **Open issues**: 130
  - **Último push**: 2026-02-11
  - **Último release**: `v0.4.1` publicado 2026-01-11
  - **Commits semanales (último año)**: acelera desde 2025 (semanas con ~20–45 commits).

### Lectura “inteligente” de evolución

- **Cambio de “centro de gravedad”**: el proyecto se está consolidando en **OpenTelemetry (OBI)**, mientras Beyla actúa como distribución/derivado. En el release de Beyla aparecen referencias explícitas a cambios provenientes de `open-telemetry/opentelemetry-ebpf-instrumentation`.
- **Madurez en progreso**: OBI es “más nuevo” (2025) pero con velocidad sostenida; Beyla es “más viejo” (2023) y continúa activo.
- **Señal fuerte**: releases recientes y pushes en Feb 2026 en ambos repos.

### Riesgos/alertas (desde GitHub)

- **Riesgo de “repo equivocado”**: para evaluar evolución real, hay que mirar **ambos** (Beyla + OBI). Para contribuir o seguir roadmap, probablemente OBI sea el upstream.
- **Carga de mantenimiento**: open issues ~130–135 (no necesariamente malo; también indica adopción).

---

## 2) Pixie

### Repo analizado

- Pixie: `https://github.com/pixie-io/pixie`

### Snapshot (GitHub API)

- **Creado**: 2020-02-27
- **Stars/Forks**: 6354 / 492
- **Open issues**: 366
- **Último push**: 2026-02-09
- **Último release**: `release/cloud/v0.1.9` publicado 2025-01-24
- **Commits semanales (último año)**: bajos (muchas semanas 0–1; algunas de 4–8).

### Lectura “inteligente” de evolución

- **Evidencia de vida**: hay pushes recientes (Feb 2026) y PRs/updates activos (incl. Dependabot), pero…
- **Cadencia de release pública baja**: el último `releases/latest` quedó en Jan 2025 (esto suele indicar que el “release train” público no es el principal canal de evolución, o que la evolución está enfocada en integraciones/consumo comercial).
- **Escala de comunidad**: alto número de stars y issues abiertos; esto suele venir con backlog significativo.

### Riesgos/alertas (desde GitHub)

- **“Release gap”**: si el plan depende de upgrades frecuentes vía releases, Pixie muestra una señal más débil que los demás.
- **Carga de issues**: 366 abiertos (sugiere backlog grande; conviene mirar tiempos de respuesta/triage si esto se vuelve criterio).

---

## 3) Odigos

### Repo analizado

- Odigos: `https://github.com/odigos-io/odigos`

### Snapshot (GitHub API)

- **Creado**: 2022-06-08
- **Stars/Forks**: 3618 / 241
- **Open issues**: 57
- **Último push**: 2026-02-11
- **Último release**: `v1.17.1` publicado 2026-02-10
- **Commits semanales (último año)**: altos y bastante estables (típicamente ~15–40 commits/semana).

### Lectura “inteligente” de evolución

- **Evolución sostenida**: release “muy fresco” (Feb 2026) + push del mismo período, con commit velocity consistentemente alta.
- **Señal de producto activo**: baja cantidad de issues abiertas relativo a la actividad sugiere buen triage o backlog controlado (no garantiza, pero es buena señal).

### Riesgos/alertas (desde GitHub)

- **Complejidad operativa**: al ser “orquestador” (operador + pipelines + instrumentaciones), la evolución rápida puede implicar **cambios frecuentes** en CRDs/valores Helm. (Esto no es negativo, pero requiere gobernanza de upgrades).

---

## 4) Isovalent / Cilium Hubble (y core Cilium)

### Repos analizados

- Hubble: `https://github.com/cilium/hubble`
- Core Cilium: `https://github.com/cilium/cilium`

### Snapshot (GitHub API)

- **Hubble (`cilium/hubble`)**
  - **Creado**: 2019-11-19
  - **Stars/Forks**: 4079 / 282
  - **Open issues**: 47
  - **Último push**: 2026-02-10
  - **Último release**: `v1.18.6` publicado 2026-02-09
  - **Commits semanales (último año)**: bajos (típicamente 0–3/semana).
- **Cilium (`cilium/cilium`)**
  - **Creado**: 2015-12-16
  - **Stars/Forks**: 23663 / 3605
  - **Open issues**: 978
  - **Último push**: 2026-02-11
  - **Último release**: `v1.19.0` publicado 2026-02-04
  - **Commits semanales (último año)**: muy altos (decenas a >100/semana).

### Lectura “inteligente” de evolución

- **Hubble “estable”, Cilium “motor”**: el repo de Hubble muestra poca actividad semanal, pero hay releases recientes; el grueso de la evolución del datapath/observabilidad suele vivir en **Cilium**, que muestra enorme velocidad.
- **Madurez + ritmo**: Cilium tiene release reciente con grandes highlights; es típico de un proyecto CNCF grande: evolución continua + procesos estrictos (signoff requerido).

### Análisis: Hubble y el “cambio de CNI” (por qué no debería ser un issue)

Hubble no es una librería “instalable encima” de cualquier red: su valor real viene de operar **Cilium como CNI**. Eso puede sonar a barrera, pero en la práctica es una **decisión de plataforma** y, si el proyecto está a tiempo, suele ser una mejora neta.

- **Timing (estamos a tiempo)**:
  - Si todavía se está definiendo el “baseline” de clúster o la estrategia de observabilidad, decidir Cilium ahora evita el peor caso: intentar “encajar” observabilidad de red avanzada después, cuando la plataforma ya está rígida.
  - La evaluación se puede hacer sin comprometer producción: **piloto en un clúster** no productivo o un entorno dedicado.
- **Beneficio real**:
  - **Observabilidad accionable**: flujos, drops, DNS, verdicts de política y dependencias; ideal para troubleshooting y para gobernanza de NetworkPolicy.
  - **Capacidades de plataforma**: además de Hubble, Cilium aporta un datapath eBPF con features de red/seguridad que normalmente obligan a sumar más componentes con otros CNIs.
- **Cómo abordarlo sin riesgo innecesario**:
  - Tratar Cilium como componente crítico: versionado, upgrades, runbooks, validación con cargas reales (ingress/egress, DNS, service types, políticas).
  - Considerar la transición como **migración por clúster** (o adopción en nuevos clústeres) más que como “toggle” trivial en un clúster existente; esto reduce incertidumbre y permite control de blast radius.

### Riesgos/alertas (desde GitHub)

- **Backlog grande en el core**: open issues cercano a 1k en `cilium/cilium` (normal en proyectos enormes, pero es una señal de escala del backlog).
- **Acoplamiento al CNI**: el valor de Hubble depende de la adopción/operación de Cilium (la “dependencia” es real, pero también es la fuente del valor; por eso conviene evaluarlo como decisión de plataforma, no como add-on).

---

## 5) New Relic (eBPF) – señales desde GitHub público

### Repo analizado (artefactos de despliegue)

- Helm charts: `https://github.com/newrelic/helm-charts`
  - En este repo se publica el chart `nr-ebpf-agent` (por ejemplo bajo `charts/nr-ebpf-agent/`).

### Snapshot (GitHub API)

- **Creado**: 2020-04-20
- **Stars/Forks**: 106 / 232
- **Open issues**: 85
- **Último push**: 2026-02-11
- **Último release (tag más reciente del repo)**: `nr-k8s-otel-collector-0.10.4` publicado 2026-02-11
- **Señal de cadencia**: releases muy frecuentes y automatizadas (muchos tags por charts/bundles).

### Lectura “inteligente” de evolución

- **Evolución del packaging**: GitHub muestra evolución del **despliegue/integraciones (Helm)** y su mantenimiento (updates, rollbacks, dependencias).
- **Evolución del motor eBPF**: la parte central de eAPM/eBPF es producto de plataforma (SaaS) y su evolución suele verse mejor en **docs/“What’s New”** y en versiones de chart/agente, no en un repo único de core.

### Riesgos/alertas (desde GitHub)

- **Señal parcial**: usar solo GitHub para medir “evolución” técnica del eBPF agent puede subestimar (o no reflejar) cambios del producto.

---


## 6) Coroot

### Repo analizado

- Coroot: `https://github.com/coroot/coroot`

### Snapshot (GitHub API)

- **Creado**: 2022-08-22
- **Stars/Forks**: 7384 / 346
- **Open issues**: 117
- **Último push**: 2026-02-05
- **Último release**: `v1.17.9` publicado 2026-01-13
- **Licencia**: Apache-2.0
- **Commits semanales (último año)**: actividad sostenida (repo único con backend, frontend, agentes; típicamente evolución continua).

### Lectura "inteligente" de evolución

- **Full-stack open-source**: plataforma de observabilidad y APM con eBPF para instrumentación zero-code (HTTP, Postgres, MySQL, Redis, MongoDB, Memcached), métricas, logs, traces, profiling y alerting SLO; análisis de causa raíz asistido por IA.
- **Señal fuerte de comunidad**: alto número de stars y forks; releases recientes (v1.17.x) con cadencia regular; documentación de eBPF-based tracing y despliegue (Helm/operator).
- **Modelo de despliegue**: coroot-node-agent por nodo, almacenamiento con ClickHouse; instalación por Helm o Coroot Operator; kernel Linux ≥ 5.1 para eBPF.

### Riesgos/alertas (desde GitHub)

- **Alcance amplio**: al cubrir métricas, logs, traces, SLO y costes, la evolución puede repartirse en muchas áreas; conviene seguir el roadmap y release notes para prioridades.
- **Requisitos de plataforma**: eBPF implica privilegios y compatibilidad de kernel (OpenShift: planificar SCC y acceso al host como en el resto de candidatos).

---

## Anexo: endpoints consultados (referencia)

- Repo metadata: `https://api.github.com/repos/{owner}/{repo}`
- Latest release: `https://api.github.com/repos/{owner}/{repo}/releases/latest`
- Commit activity (52 semanas): `https://api.github.com/repos/{owner}/{repo}/stats/commit_activity`
- Issues recientes: `https://api.github.com/repos/{owner}/{repo}/issues?state=open&per_page=5&sort=updated&direction=desc`
