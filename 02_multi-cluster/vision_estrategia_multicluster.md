# Visión y Estrategia Multicluster — Banco Galicia

**Documento de alto nivel**  
**Fuentes:** Repositorio actual (doc, apim, muticluster, arquitectura, ebpf, gitops) + reuniones Granola (últimos 180 días)  
**Versión:** 1.0  
**Fecha:** Febrero 2026  

---

## Resumen ejecutivo

El banco opera hoy con **un cluster OpenShift monolítico** que concentra la mayoría de las cargas de contenedores. La estrategia acordada es migrar a una **arquitectura multicluster** (~30 clusters menores, 7–8 productivos) para reducir blast radius, mejorar escalabilidad y acortar ventanas de mantenimiento. Este documento describe la **situación actual (as-is)**, la **estrategia a alto nivel** y los **objetivos de la nueva arquitectura**, nutrido del repositorio de documentación y de las reuniones de los últimos 180 días.

---

## 1. Situación actual (as-is)

### 1.1 Topología principal

- **Un cluster OpenShift masivo** concentra la operación:
  - ~100 nodos, ~10.000 pods, ~600 namespaces, ~2.000 servicios [[9]](https://notes.granola.ai/d/e81b7e4e-6ae4-49b8-aa5d-d6435ed183bd)
  - ~120 nodos workers en configuración **stretch** entre dos sitios (Plaza y Matriz) [[15]](https://notes.granola.ai/d/5605c781-adf8-4209-bdfb-81b13b62a020)
  - Maneja **más del 50% de la facturación** del banco [[64]](https://notes.granola.ai/d/20fc13dd-8d38-4209-bdfb-81b13b62a020)

- **Red y sitios:**
  - **Stretch network** entre Plaza y Matriz; latencia 2–3 µs entre datacenters [[75]](https://notes.granola.ai/d/76a648e8-86f6-4cd4-9b5c-b4b03ef04d42)
  - Clusters **activo/standby** sincronizados vía GitOps [[75]](https://notes.granola.ai/d/76a648e8-86f6-4cd4-9b5c-b4b03ef04d42)

- **APIs y tráfico:**
  - ~2.200 APIs en producción gestionadas por 3Scale [[123]](https://notes.granola.ai/d/23da94f3-8642-413b-af2b-06fd9152a7f2)
  - Tráfico interno ~7.500 M requests/mes; externo ~500 M requests/mes [[123]](https://notes.granola.ai/d/23da94f3-8642-413b-af2b-06fd9152a7f2)
  - **Hairpinning:** microservicios salen del cluster y re-entran por load balancer externo para comunicarse entre sí [[26]](https://notes.granola.ai/d/24f6ed07-aca3-42ed-a662-dee3f61888c1) [[9]](https://notes.granola.ai/d/e81b7e4e-6ae4-49b8-aa5d-d6435ed183bd)
  - Todo el tráfico inter-namespace pasa por 3Scale (API management) [[82]](https://notes.granola.ai/d/8b112c42-5a60-43be-b004-118965b8b460)

**Detalle técnico relevante (capas):**

| Capa | Situación actual |
| ------ | ------------------ |
| **IaaS / virtualización** | VMs sobre VMware; storage SAN con LUNs compartidas con bases de datos y otros servidores |
| **Plataforma** | OpenShift (OCP) único cluster stretch; versión actual 4.15–4.16; soporte vence 31 oct [[137]](https://notes.granola.ai/d/2776ca2f-66c0-453b-be99-09972e5b1424) |
| **Red** | Stretch entre sitios; F5/HAProxy en el path; network policies fuerzan tráfico cross-namespace por 3Scale |
| **Storage** | ODF múltiple por cluster; SAN con una controladora; OpenShift sensible a latencia de disco [[40]](https://notes.granola.ai/d/9c67ae86-36f8-4766-b0c1-80034433d787); CSI VMware no explotado de forma efectiva |
| **API/Ingress** | 3Scale (Apicast); límite 500 routes por instancia vs 2.200 APIs [[128]](https://notes.granola.ai/d/7f41a0f9-380f-4e74-a0c2-77ea8d768aca); EOL mediados 2027 |
| **GitOps** | ArgoCD/OpenShift GitOps; sincronización activo/standby; no hay modelo hub-spoke multicluster aún |

---

### 1.2 Limitaciones técnicas

- **Escalabilidad:**
  - Cluster con **overcommit ~210%** en algunos nodos [[54]](https://notes.granola.ai/d/79a4800a-ed3b-411d-a7c6-c2fd3017622c)
  - Plataforma diseñada hace 3–4 años sin arquitecto formal; decisiones históricas no escalables [[137]](https://notes.granola.ai/d/2776ca2f-66c0-453b-be99-09972e5b1424) [[133]](https://notes.granola.ai/d/70825521-1e6c-4153-9a90-33bb91d44538)
  - 3Scale: límite de 500 routes por instancia; reload completo de Apicast, no dinámico [[128]](https://notes.granola.ai/d/7f41a0f9-380f-4e74-a0c2-77ea8d768aca)

- **Storage:**
  - Mala utilización de SAN; discos compartidos con DBs; **una sola controladora** → impacto masivo en fallas [[137]](https://notes.granola.ai/d/2776ca2f-66c0-453b-be99-09972e5b1424)
  - ODF múltiple, alto costo operativo; ODF atascado en 4.15.20, incompatible con upgrades (p. ej. mesh en 4.20) [[26]](https://notes.granola.ai/d/41a103c1-8e90-4772-b4e7-a0d1b41e7b2)

- **Comunicación y observabilidad:**
  - Hairpinning impone latencia y bottleneck; observabilidad rota (3Scale corta traces end-to-end)
  - Sin capacidad declarativa en 3Scale (todo en base de datos, no GitOps)

---

### 1.3 Limitaciones operativas y escalabilidad

- **Blast radius:** Un solo cluster implica que un incidente puede impactar **toda la operación bancaria** [[9]](https://notes.granola.ai/d/e81b7e4e-6ae4-49b8-aa5d-d6435ed183bd); caídas frecuentes afectan la operación completa [[106]](https://notes.granola.ai/d/8c5660c6-0b67-4546-a61c-82976367a238); **punto único de fallo** [[54]](https://notes.granola.ai/d/79a4800a-ed3b-411d-a7c6-c2fd3017622c).

- **Impacto cruzado:** Cargas de negocio, infra y batch conviven en el mismo cluster; problemas de un dominio afectan a otros; no hay aislamiento por línea de negocio o criticidad.

- **Ventanas de mantenimiento y lifecycle:**
  - **Vedas:** Cambios automáticos bloqueados en períodos de veda; solo ~9 días sin veda en febrero para cambios críticos [[3]](https://notes.granola.ai/d/f1924f34-f44e-4d5f-b564-e10f29d62ad0); calendario muy ocupado feb–mar [[15]](https://notes.granola.ai/d/5605c781-adf8-4209-bdfb-81b13b62a020).
  - **Actualizaciones:** Por tamaño del cluster, **imposible actualización directa**; proceso obligatoriamente dividido en etapas [[111]](https://notes.granola.ai/d/6a3e41f8-b098-49e6-9847-217ce5a3cda5); ventanas de mantenimiento **muy largas**.
  - **Presión de ciclo de vida:** Soporte OpenShift vence 31 octubre; 3Scale EOL mediados 2027 [[123]](https://notes.granola.ai/d/23da94f3-8642-413b-af2b-06fd9152a7f2).

---

### 1.4 Síntesis as-is

| Dimensión | Estado actual |
| ----------- | ---------------- |
| **Topología** | Un cluster monolítico stretch, ~100 nodos, 10k pods, 600 ns, 2k servicios |
| **Blast radius** | Enorme; un fallo impacta operación completa |
| **Escalabilidad** | Limitada por overcommit, límites 3Scale y diseño histórico |
| **Mantenimiento** | Ventanas largas; actualizaciones por etapas; vedas estrictas |
| **Comunicación** | Hairpinning; todo inter-namespace por 3Scale |
| **Storage** | SAN compartido, ODF múltiple, una controladora, latencia y costo |

---

## 2. Estrategia a alto nivel a implementar

### 2.1 Dirección general

- **Transición de 1 cluster monolítico a una flota de clusters menores.** Referencia consolidada: **21 clusters** en total (15 en producción, 6 en no producción), con tipología detallada por dominio (gobierno, APIM prd/dr, workload PROD/DR, QA, servicios compartidos, laboratorio, DEV, STG). Alternativa discutida en fases previas: ~30 clusters con 7–8 productivos; ver 7.1 Modelo multicluster objetivo y segmentación de dominios.
- **Ejecución en dos pasos (steps):** Step 1 (H1): habilitadores, ingress sharding, IaaS dedicado por sitio, dominios de clusters; Step 2 (H2): patrones de tráfico north-south/east-west, segmentación operativa, movimiento de cargas y consolidación de HA. Detalle en 13.1 Fases de implementación y 13.5 Hitos y entregables.
- **Clusters por propósito:** ACM dedicado (gobierno), clusters de **servicios centralizados** (observabilidad, storage as a service, secretos, CI/CD), **clusters aplicativos** por tribu/dominio, y clusters **especializados** (APIM, laboratorio, p. ej. BFFA con GPU).
- **Sin big bang:** migración **servicio por servicio**, con **período de convivencia** entre plataforma actual y nueva [[91]](https://notes.granola.ai/d/aec43520-a806-40f3-b6b1-fd7508ac987d).

### 2.2 Pilares técnicos

1. **Fleet management y GitOps**
   - **ACM (Advanced Cluster Management)** como hub; modelo **hub-spoke** con ArgoCD.
   - **4 instancias ArgoCD por cluster** (infra, aplicaciones/DevOps, seguridad/RBAC, API Management/Middleware) (ref. `arquitectura/topologia/gral_acordado_via_call.md`).
   - Configuraciones de infraestructura (RBAC, NetworkPolicies, IngressController, etc.) en Git central; Terraform/Ansible para IaaS y networking (F5, DNS).

2. **Red y comunicaciones**
   - **Service mesh** (Istio Ambient u otra opción sidecar-less) para tráfico **este-oeste**: eliminar hairpinning, comunicación directa pod-a-pod, gateways este-oeste dedicados [[54]](https://notes.granola.ai/d/79a4800a-ed3b-411d-a7c6-c2fd3017622c).
   - **Cuatro puntos de entrada** por función [[91]](https://notes.granola.ai/d/aec43520-a806-40f3-b6b1-fd7508ac987d): HAProxy nativo (gestión OCP), HAProxy actual (Triskel durante migración), API Gateway interno (este-oeste), API Management externo (norte-sur).
   - **DNS local** (InfoBlox) + external-DNS para actualización automática; certificados con cert-manager.

3. **Storage y persistencia**
   - **Cluster dedicado ODF** proveyendo buckets y PVs a otros clusters; **CSI directo** a cajón de disco (evitar capa VMware intermedia donde aplique) (ref. `muticluster/gartner/analisis_storage_reuniones.md`).
   - Reducir múltiples ODF por cluster; storage classes por tipo (RWO/RWX/object) y SLA.

4. **API Management y Gateway**
   - **Separar** API Management (norte-sur, externo) de API Gateway / mesh (este-oeste, interno).
   - Reemplazo de 3Scale (EOL 2027): tráfico interno vía **service mesh + API gateway liviano**; tráfico externo con **API Manager** con portal (candidatos: Red Hat Connectivity Link, Kong, Traefik, Tyk) (ref. `apim/05_arquitectura_objetivo.md`).

5. **Observabilidad**
   - **Grafana Cloud** como backbone; **Alloy** como pipeline de telemetría; **OpenTelemetry** para métricas, logs y traces.
   - **eBPF** (Cilium/Hubble u otro) para mapas de servicio, visibilidad de tráfico y heat maps antes de partir clusters (ref. `ebpf/ebpf_detallado.md`, `muticluster/gartner/analisis_gartner_vs_meetings.md`).

6. **Seguridad y secretos**
   - **HashiCorp Vault** (arquitectura híbrida: control plane SaaS + agentes on-prem); VSO o Vault Agent Injector.
   - RBAC multicluster centralizado vía GitOps; repositorio centralizado para network policies y auditoría.

### 2.3 IaaS y virtualización (alto nivel)

- **VMware** como capa de virtualización actual; evolución hacia uso más efectivo de **CSI** y, donde corresponda, consumo directo de LUNs/cajón de disco para reducir latencia y puntos únicos de fallo.
- **Automatización día 0:** ACM para creación de clusters; Terraform + Ansible para red y F5; certificados y DNS automáticos.
- **Automatización día 2:** Tres tracks (infra/nodos, seguridad/RBAC, DevOps/release); preflight checks en VIP y DNS reverso.

### 2.4 Especificaciones objetivo (referencia reuniones)

- **Clusters de producción:** 64 GB RAM, 32 cores por nodo; 3 masters + 3 infra + 3 login + 3 workers dedicados [[gral_acordado_via_call]].
- **Versión target OpenShift:** 4.20.12 (hoy 4.15–4.16).
- **Cluster BFFA (GPU):** A100, 16 nodos (3 masters + 7 workers GPU + 3 infra + 3 ODF) para modelos LLM y cargas intensivas [[gral_acordado_via_call]].

### 2.5 Timeline de referencia (reuniones)

- **Marzo 2026:** Todos los clusters en plaza; inicio generación de clusters para migraciones [[63]](https://notes.granola.ai/d/8ef65b68-3f7b-4df8-938e-584303216be9).
- **Abril–Junio 2026:** Despliegue de servicios [[63]](https://notes.granola.ai/d/8ef65b68-3f7b-4df8-938e-584303216be9).
- **Q1 2026:** ACM desplegado, Vault corporativo, automatización día 2 operativa.
- **Q2 2026:** Migración de servicios; retrasar cambios de API platform para no superponer con migración.
- **Mediados 2027:** Deadline 3Scale (EOL).

La migración se considera de **magnitud comparable o mayor** a OpenShift 3→4, con impacto organizacional fuerte; requiere coordinación PM dedicado y sponsor C-suite [[44]](https://notes.granola.ai/d/1db696dc-6167-4ca0-9484-272141f1ba12).

---

## 3. Objetivos de la nueva arquitectura

### 3.0 Marco canonico de objetivos (alineado con 1.2)

Para mantener consistencia con el documento estrategico, la arquitectura objetivo se rige por estos 8 objetivos:

1. **Escalabilidad y segmentacion**
2. **Resiliencia y continuidad de negocio**
3. **Seguridad integral**
4. **Observabilidad y trazabilidad end-to-end**
5. **Gobernanza y automatizacion operativa**
6. **Portabilidad de workloads**
7. **Preparacion para migracion a nube**
8. **Minimizacion de vendor lock-in**

### 3.1 Resiliencia y blast radius

- **Reducir blast radius:** Fallas acotadas a un cluster o dominio, no a toda la operación [[9]](https://notes.granola.ai/d/e81b7e4e-6ae4-49b8-aa5d-d6435ed183bd).
- **Aislamiento:** Separar aplicaciones críticas de no críticas y por línea de negocio [[145]](https://notes.granola.ai/d/76fb3204-fe56-4f72-80ef-7d2c29b805ec).
- **Alta disponibilidad:** Objetivo activo-activo donde corresponda; control granular por namespace/cluster en lugar de “todo o nada”.

### 3.2 Operación y ciclo de vida

- **Ventanas de mantenimiento más cortas:** Actualizaciones y cambios por cluster o grupo de clusters, no sobre un monolito.
- **Gestión independiente:** Actualizaciones y mantenimiento por dominio, sin bloquear al resto [[54]](https://notes.granola.ai/d/79a4800a-ed3b-411d-a7c6-c2fd3017622c).
- **Automatización día 0 y día 2:** Provisioning, configuración, seguridad y release management repetibles y declarativos.

### 3.3 Escalabilidad y rendimiento

- **Escalabilidad horizontal:** Añadir capacidad mediante nuevos clusters o nodos sin sobrecargar un único cluster.
- **Eliminación de hairpinning:** Comunicación este-oeste directa (mesh), menor latencia y menor dependencia del load balancer externo [[33]](https://notes.granola.ai/d/04644ff4-a759-4fae-824b-9427d22efd0e).
- **Service discovery y control planes federados** para visibilidad y políticas globales donde sea necesario [[54]](https://notes.granola.ai/d/79a4800a-ed3b-411d-a7c6-c2fd3017622c).

### 3.4 Agilidad y estándares

- **Mayor agilidad:** Equipos con menor dependencia de ventanas únicas y de otros dominios [[133]](https://notes.granola.ai/d/70825521-1e6c-4153-9a90-33bb91d44538).
- **Estándares abiertos:** Priorizar OCI, CNI/CSI, Gateway API, OpenTelemetry, GitOps; reducir dependencia de vendor donde compense (según análisis Gartner vs reuniones) (ref. `muticluster/gartner/analisis_gartner_vs_meetings.md`).
- **Configuración como código:** GitOps para infraestructura, políticas y aplicaciones; trazabilidad y rollback automatizado.

### 3.5 API, observabilidad y seguridad

- **Separación norte-sur / este-oeste:** API Management para externos; mesh + gateway liviano para interno; gobernanza basada en identidades (Kubernetes/mTLS) más que en API keys estáticas.
- **Observabilidad end-to-end:** Trazas y métricas sin “cortes” en 3Scale; eBPF para mapas de tráfico y heat maps; correlación métricas-trazas.
- **Secretos e IAM:** Vault centralizado; IAM desacoplado del API gateway; RBAC multicluster gobernado por GitOps.

### 3.6 Resumen de objetivos

| Objetivo de reingenieria | Traduccion en arquitectura objetivo |
| ---------- | ------------- |
| **Escalabilidad y segmentacion** | Crecimiento por clusters/nodos, distribucion por dominios y eliminacion progresiva de cuellos de botella del monolito. |
| **Resiliencia y continuidad de negocio** | Blast radius acotado, patrones activo-activo/activo-standby segun criticidad y failover validado por pruebas. |
| **Seguridad integral** | IAM desacoplado, secretos centralizados, RBAC GitOps y politicas de red con cumplimiento auditable. |
| **Observabilidad y trazabilidad end-to-end** | OTEL + eBPF + Grafana Cloud para correlacion de metricas/logs/trazas sin cortes entre dominios. |
| **Gobernanza y automatizacion operativa** | Modelo hub-spoke, dia 0/1/2 declarativo y ownership claro por dominio tecnico. |
| **Portabilidad de workloads** | Estandares Kubernetes/Gateway API, contratos de plataforma y patrones repetibles entre entornos. |
| **Preparacion para migracion a nube** | Evolucion hibrida por oleadas, sin big bang ni refactorizaciones masivas como precondicion. |
| **Minimizacion de vendor lock-in** | Interfaces desacopladas y seleccion de componentes reemplazables con balance entre neutralidad y operabilidad. |

---

## Referencias

- **Repositorio:** `doc/` — apim (01_contexto_situacion_actual, 05_arquitectura_objetivo), arquitectura (topologia/gral_acordado_via_call, entornos/consolidacion_de_entornos), muticluster/gartner (analisis_gartner_vs_meetings, analisis_storage_reuniones), ebpf/ebpf_detallado, gitops/argocd.
- **Reuniones Granola:** últimos 180 días; citas en formato [[n]](url) en el cuerpo del documento.
- **Documentos Gartner referenciados en repo:** Minimizing Vendor Dependence in Container Platforms (G00841999); Backup and Disaster Recovery; Comparing Approaches multicluster.
