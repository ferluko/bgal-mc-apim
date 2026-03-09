# Platform Engineering

# OCP Multicluster Implementation

## STRATEGY DEFINITION AND OVERALL COMPONENT TOPOLOGY

| Metadata | Value |
|----------|-------|
| **Version** | 1.0 |
| **Date** | March 2026 |
| **Author/Owner** | Platform Engineering |
| **Classification** | Confidential |

*Change log:* v1.0 (Mar 2026) -- Initial version.

---

## Table of Contents

1. [**Introduction and context**](#sec-1)
   - 1.1 Document purpose
   - 1.2 Scope and objective
   - 1.3 Executive summary
   - 1.4 Risks of not evolving the platform
     - 1.4.1 Operational and continuity risk
     - 1.4.2 Scalability and growth risk
     - 1.4.3 Technology and obsolescence risk
     - 1.4.4 Organizational and operational risk
     - 1.4.5 Strategic risk

2. [**Current situation**](#sec-2)
   - 2.1 Topology and capacity (As-is)
   - 2.2 Priority technical limitations
   - 2.3 Current reference topology diagram

3. [**Target multicluster architecture**](#sec-3)
   - 3.1 Domain segmentation and cluster typology
   - 3.2 Target traffic patterns (Step 2 -- north-south and east-west)
   - 3.3 Ingress/egress, global DNS, and load balancing
   - 3.4 Control plane and data plane model
   - 3.5 End-to-end multicluster security
   - 3.6 Federated observability and reliability
   - 3.7 Target operating model

4. [**Most relevant architectural decisions**](#sec-4)

5. [**Multicluster evolution strategy (phase detail)**](#sec-5)
   - 5.1 Foundational phase: platform enablers
   - 5.2 Ingress sharding and flow decoupling phase
   - 5.3 Operational segmentation and governance phase
   - 5.4 Workload movement process consolidation and maturity phase
   - 5.5 Implementation and migration to the new APIM
   - 5.6 High-availability pattern consolidation phase

6. [**Target architecture and topology -- First stage (H1)**](#sec-6)
   - 6.1 Overview -- Step 1 (H1)
   - 6.2 Fundamentals, enablers, and day 0 / day 1 / day 2 automation
   - 6.3 Ingress sharding consolidation
   - 6.4 Dedicated IaaS per site
   - 6.5 New traffic model with F5 GTM
   - 6.6 Cluster domains and separation of responsibilities
   - 6.7 Workload placement strategy by tribe/domain
   - 6.8 High-availability and internal traffic scheme in H1
   - 6.9 End-to-end observability deployment with eBPF

7. [**High-level execution plan**](#sec-7)
   - 7.1 Executive control deliverables

8. [**Critical risks and mitigations of the multicluster program**](#sec-8)

9. [**Conclusion**](#sec-9)

10. [**References to detailed documentation (@architecture)**](#sec-10)
    - 10.1 Index and overall view
    - 10.2 Current state and diagnosis (as-is)
    - 10.3 Target architecture and decisions
    - 10.4 Evolution, operations, and execution
    - 10.5 Security, compliance, and observability
    - 10.6 APIM documentation (API infrastructure modernization)

---

<a id="sec-1"></a>
## 1. Introduction and context

### 1.1 Document purpose

The purpose of this document is to describe Banco Galicia's current situation in the use and operation of the OpenShift platform. Based on this analysis, a set of definitions related to the evolution of this technology are identified, supported by the tests carried out by the team in researching and developing new paradigms for microservice usage and execution. As a final result, a high-level initiative execution plan is detailed to achieve the final objective [1](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/indice_tentativo.md), [2](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md).

### 1.2 Scope and objective

The reengineering of our OpenShift platform (OCP) aims to redesign, modernize, and optimize the architecture, components, and operational processes that sustain Banco Galicia's container platform. This initiative seeks to ensure future scalability to cover organizational needs, supporting the growth of critical workloads, multicluster models, and the availability and resilience requirements demanded by the financial industry.

The main objective is to evolve the platform from its current state to a model that guarantees 7 aspects [18](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.1_estandarizacion_y_automatizacion_por_defecto.md), [19](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.2_escalabilidad_horizontal_y_elasticidad.md), [20](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md), [21](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.4_seguridad_by_design_y_zero_trust.md), [22](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.5_observabilidad_integral_y_operabilidad.md):

1. **Higher operational efficiency** through automation, standardization, and use of a technology stack that builds a framework.
2. **Scalability and elasticity** to support multiple business domains and peaks in transaction volume/demand.
3. **High availability and resilience** through multicluster topologies and market-standard practices that minimize cross-impact from failures.
4. **Reduce technical complexity** and remove legacy components that are not evolving and are projected to be out of support.
5. **Improve development experience** by enabling more controlled security and communication schemes that provide better traceability for internal and external service consumption.
6. **Strengthen the cybersecurity posture** under banking-industry standards.
7. **Implement end-to-end observability capabilities** for a more proactive operation.

### 1.3 Executive summary

Today, a single production cluster concentrates critical workloads from multiple business lines, with high transaction volume and strong dependence on manual processes. This design amplifies blast radius in incidents, extends maintenance windows, and limits real elasticity. API Manager (3scale) reaches end of life in 2027, which requires acting in advance. The transformation is not only a targeted APIM replacement: it is the evolution from a monolithic scheme to a multicluster architecture with centralized governance and domain-based operations.

The target strategy defines a collection of clusters with clear responsibilities, segmentation by criticality and service type, differentiated patterns for north-south and east-west traffic, and a GitOps + IaC operating model (day 0 / day 1 / day 2). API Manager is used as a pilot case to validate networking, security, resilience, and operations decisions that are later extended to the rest of OpenShift. The expected benefit is reduced cross-impact during incidents, improved operational continuity, and sustained business growth without increasing complexity in the same proportion.

It is recommended to move forward with the multicluster strategy in phases based on the enablers defined in this document. Details and references are developed in sections 2-7 and in the documentation linked in section 10. Reading this document reflects your role as a key stakeholder and required collaborator for the success of the program; your contribution and alignment are essential to move it forward.

### 1.4 Risks of not evolving the platform

Keeping the current active-passive monolithic OpenShift model is not neutral. It implies accepting a series of structural risks that increase in proportion to business growth, transaction volume, and the criticality of digital services.

#### 1.4.1 Operational and continuity risk [11](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md), [14](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md)

- Concentrating critical workloads in a single cluster amplifies blast radius in infrastructure, network, storage, or configuration failures.
- Recent incidents show that partial failures (storage, load balancing, networking) have bank-wide cross-impact, even when they do not fully compromise the cluster.
- Continuity depends on manual interventions, coordination among multiple teams, and long operating windows, increasing effective RTO.

**IMPACT:** higher probability of high-impact incidents and longer recovery times in the face of failures.

#### 1.4.2 Scalability and growth risk [12](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.2_limites_de_escalabilidad_y_elasticidad.md), [6](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md)

- The monolithic cluster acts as an indivisible scaling unit, limiting real elasticity as domains grow.
- Technical and operational limits in: number of routes, API density, non-dynamic reloads of ingress/APIM components.
- Internal traffic hair-pinning penalizes latency and transaction efficiency.

**IMPACT:** future growth becomes increasingly expensive, complex, and risky.

#### 1.4.3 Technology and obsolescence risk [6](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md), [26](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.2_alternativas_de_api_management_y_api_gateway.md)

- The current model maintains strong dependencies on components without a clear evolution path.
- 3scale reaches end of life in 2027, creating a concrete continuity risk if replacement is not anticipated.
- Delaying reengineering forces a reactive migration under time pressure, with higher technical and operational risk.

**IMPACT:** reduced room for technology decisions and increased risk of forced transition.

#### 1.4.4 Organizational and operational risk [13](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md), [40](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md), [48](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md)

- High manual effort and coexistence of partial automation generate: operational variability, dependency on tacit knowledge, and difficulty scaling teams and responsibilities.
- The current model limits effective adoption of GitOps, IaC, and domain-based operations.

**IMPACT:** higher operational load, greater probability of human error, and slower delivery.

#### 1.4.5 Strategic risk [17](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.7_complejidad_heredada_legacy_y_friccion_para_equipos_de_desarrollo.md)

- Keeping the current model means continuing to invest in an architecture with known limits.
- Every new project builds on a foundation that does not reduce systemic risk, but increases it.
- The platform stops being a business enabler and becomes a restrictive factor.

**IMPACT:** loss of competitiveness and reduced ability to respond to new business demands.

The materialization of these risks is mitigated by the program described in sections 5 to 7; specific risks of the migration program are detailed in [section 8](#sec-8).

---

<a id="sec-2"></a>
## 2. Current situation

### 2.1 Topology and capacity (As-is)

[🔗 View As-Is Topology Miro Dashboard](https://miro.com/app/board/uXjVG38NsdE=/?moveToWidget=3458764662371332578&cot=14)

![As-is topology -- General view (DMZ, PAAS, VMware, IBM Storage)](implementacion-ocp-imagenes/diagrama-as-is.jpeg)

*Figure 1 -- As-is topology overview: external access layers, DMZ, PAAS (PGA/CMZ), virtualization, and storage.*

#### OpenShift platform scale

The platform has **9 OpenShift clusters** centrally managed by Red Hat Advanced Cluster Manager (ACM Hub), distributed across Plaza Galicia (PGA), Casa Matriz (CMZ), and a dedicated DMZ perimeter site [3](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md), [2](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md). Although there are several clusters (dev, qa, staging, etc.), **critical production load** is concentrated in the active-passive pair (paas-prdpg / paas-prdmz), which operates as a logical unit of scale and risk; the remaining non-production clusters do not reduce production blast radius. Detailed as-is view in the multicluster vision and strategy document [2](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md).

**Production Clusters:**

- **paas-prdpg** (PGA) -- Active Production
- **paas-prdmz** (CMZ) -- Passive/Standby Production
- **paas-qa** (CMZ) -- Quality Assurance

**Non-Production Clusters:**

- **paas-dev** (CMZ) -- Development
- **paas-stg** (CMZ) -- Staging / Integration
- **paas-lab** (PGA) -- Laboratory
- **paas-sre** (PGA) -- SRE/Operations Lab

**External Exposure Cluster:**

- **paas-dmz** (DMZ Site) -- Internet access, Banking Clients, Banking Partners, with hybrid connectivity to AWS (Direct Connect) and Azure (ExpressRoute)

#### Total capacity [3](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md), [6](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md), [7](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.5_almacenamiento_y_servicios_de_datos.md)

| Concept | Value |
|----------|-------|
| Nodes | +500 distributed across both datacenters |
| Applications | +15,000 deployed |
| Containers | +40,000 running |
| Production APIs | ~2,200 exposed |

#### Transaction volume [5](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md)

- ~8 billion requests/month in production
- Predominance of east-west traffic (7.5B) over north-south (~500M)
- High exposure density with multiple ingress controllers

#### Base infrastructure [7](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.5_almacenamiento_y_servicios_de_datos.md)

- **VMware vSphere** (Stretched Cluster between PGA and CMZ): +65 vmHosts, +5,800 vCPUs, +64TB Memory
- **IBM System Storage:** +1,024TB shared storage with synchronous cross-site replication

#### Networking and security stack

- Fortinet Firewall -- Perimeter security
- Infoblox -- Corporate DNS
- Cisco Stretched Networks -- Extended network between datacenters
- F5 -- WAF + Load Balancer
- Netscout Arbor Edge Defense -- DDoS protection

#### High availability model [4](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md)

The platform operates with a stretched topology between Plaza Galicia and Casa Matriz. The production environment runs in an **active-passive** scheme: paas-prdpg receives active traffic and paas-prdmz remains on standby. APIM contingency also operates in an active-standby scheme. The inter-site communication load balancer (F5) determines which cluster is active at any given time.

#### As-Is Production Architecture -- Overview [3](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md), [5](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md)

[🔗 View As-Is Production Miro Dashboard](https://miro.com/app/board/uXjVG38NsdE=/?moveToWidget=3458764662372442082&cot=14)

![As-is production architecture -- Orchestration, workload, and synchronization](implementacion-ocp-imagenes/diagrama-as-is-production.jpeg)

*Figure 2 -- As-is production architecture: orchestration clusters (paas-acm), workload (active paas-prdpg / passive paas-prdmz), traffic, and synchronization.*

- **Corporate network layer:** Cisco Stretched Networks across both datacenters.
- **Orchestration clusters:** OpenShift paas-acm (Plaza Galicia) as central hub (ODF, ArgoCD for APIM, RHACM Operator). Nodes: Storage, Master, Worker, Infra.
- **Workload clusters:**
  - **Active -- paas-prdpg (PGA):** ODF, multiple applications, apps exposed via Ingress Routers (Apps1-5) with Traffic Enabled.
  - **Passive -- paas-prdmz (CMZ):** Same architecture; apps in Traffic Disabled mode (standby).
- **Load balancing:** F5 LTM -- Traffic Enabled to paas-prdpg, Traffic Disabled to paas-prdmz; multiple VIPs (VS-Paas-Prd-HTTPS) with per-application sharding.
- **Synchronization:** Pipelines, GitOps, automations, and manual backlog.
- **VMware infrastructure:** Stretched vSphere (+32 vmhosts PGA, +32 vmhosts CMZ). IBM System Storage with synchronous PGA-CMZ replication.

Manual failover between sites: switch Traffic Enabled/Disabled in F5 LTM and DNS-agnostic behavior.

### 2.2 Priority technical limitations [4](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md), [13](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md), [6](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md), [11](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md), [12](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.2_limites_de_escalabilidad_y_elasticidad.md), [14](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md), [15](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.5_brechas_de_observabilidad_y_trazabilidad_end_to_end.md), [16](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.6_brechas_de_seguridad_y_gobierno_tecnico.md)

Limitations are grouped into four pillars: **operating model**, **scalability**, **blast radius**, and **life cycle** (Figure 3). They are illustrated and detailed below.

![Technical limitation pillars -- Operating model, Scalability, Blast radius, Life cycle](implementacion-ocp-imagenes/diagrama-pilares-modelo-operativo-escalabilidad-blast-lifecycle.png)

*Figure 3 -- Four pillars of priority technical limitations: operating model, scalability, blast radius, and life cycle.*

They are grouped into 4 categories:

| Category | Description |
|-----------|-------------|
| **Operating model** | High manual effort (VIPs, DNS, certificates, secrets, synchronization, DR, networking). Dependency on tickets and cross-team coordination. Coexistence of partial automation with manual procedures. |
| **Scalability** | Monolithic cluster as scaling unit; overcommit in parts of the environment. APIM limitations (routes/APIs, non-dynamic reloads). Internal hair-pinning with latency impact. Stretched clusters increase blast radius. |
| **Cross-impact (blast radius)** | Capacity, network, storage, or configuration failures with transversal impact. Shared dependencies (load balancing, DNS, storage, identity, APIM). Nov-2025 incident: storage degradation with transversal impact. Feb-2026 incident: F5/load balancer failure affecting cluster operation. |
| **Maintenance and windows** | Long windows due to cluster size and phased updates. Risk of inter-site configuration drift. Life-cycle pressure: OCP 4.16 -> 4.20.x; 3scale EOL 2027. |

### 2.3 Current reference topology diagram [5](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md), [37](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md)

- **Datacenters:** Two sites (Plaza and Matriz) with extended network (DWDM, bandwidth to be checked). Perimeter with F5/Fortinet and edge security components.
- **Flows:** North-south: Internet/partners (DMZ)/core-legacy -> OpenShift ingress sharding/APIM -> services. East-west: in several paths traffic exits and re-enters through external load balancers.
- **Hardware and critical components:** Shared storage and transversal components with bank-wide effect during failure. Strong integration with corporate network (DNS, load balancing, certificates).
- **Versions and evolution:** Base 4.16; target 4.20.x. Compatibility dependencies (including storage) condition the upgrade sequence.

---

<a id="sec-3"></a>
## 3. Target multicluster architecture

### Target architecture diagram -- Clusters by environment and domain

Below is the target topology of the OpenShift fleet, distributed across Plaza Galicia (PGA) and Casa Matriz (CMZ). It serves as a reference for the scale and roles detailed in the following sections.

[🔗 View To-Be Clusters Miro Dashboard](https://miro.com/app/board/uXjVG38NsdE=/?moveToWidget=3458764662373131260&cot=14)

![Target multicluster topology -- Production and non-production environments (Plaza Galicia / Casa Matriz)](implementacion-ocp-imagenes/diagrama-to-be-clusters.jpeg)

*Figure 4 -- Target OpenShift cluster architecture: distribution across production environments (Governance, APIM, Workload PROD/DR, QA, Shared Services) and non-production environments (Laboratory, Shared Services, DEV, STG) between Plaza Galicia and Casa Matriz.*

**Target number of clusters:** initially, the target fleet is estimated at **21 clusters** total: **15** in production environments (governance, APIM prd/dr, workload prd/dr, QA, shared services) and **6** in non-production (laboratory, shared services, DEV, STG). Domain-level detail is described in [section 3.1](#sec-3).


### 3.1 Domain segmentation and cluster typology [34](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md)

The target cluster distribution ([Figure 4](#sec-3)) is organized by environment and domain as detailed below:

- **Governance (orchestration):** one production governance cluster (*paas-bgacm-prd*) for centralized management (ACM, global policies, life cycle). Hub-spoke multicluster operation.
- **APIM Clusters:** two clusters -- production (*paas-apim-prd*) and disaster recovery (*paas-apim-dr*), distributed between Plaza Galicia and Casa Matriz for L7 governance and secure API exposure.
- **Workload Clusters (PROD):** six clusters -- three production clusters (*paas-apps1-prd*, *paas-apps2-prd*, *paas-apps3-prd*) and three DR clusters (*paas-apps1-dr*, *paas-apps2-dr*, *paas-apps3-dr*) for critical application workloads by tribe/domain (vCPU, RAM, Q APIs).
- **Workload Clusters (QA):** four clusters (*paas-apps1-qa* to *paas-apps4-qa*) for Quality Assurance, split across PGA and CMZ.
- **Shared Services & Storage (production):** two clusters (*paas-svcprdpg*, *paas-svcprdmz*) -- transversal site capabilities: observability, Cloud Storage as a Service, secrets, CI/CD, consoles, automation, cloud-native backup.
- **Shared Services & Storage (non-production):** two clusters (*paas-svclpg*, *paas-svclmz*) for shared services in non-production environments.
- **Laboratory:** two clusters (*paas-arqlab*, *paas-srepg*) for architecture and SRE labs; experimentation and specialized testing.
- **Workload Clusters (DEV / STG):** one development cluster (*paas-devmz*) and one staging cluster (*paas-stgmz*) in Casa Matriz for development and preproduction integration.
- **Explicit separation** between critical and non-critical services; grouping can be reviewed based on growth.

> **Target scale:** a fleet of **21 total clusters** is aligned with the target architecture diagram, but the number may be adjusted based on tribe/domain segmentation and installed capacity.

### 3.2 Target traffic patterns

Target traffic patterns explicitly distinguish **API ingress and exposure** (north-south) from **internal service-to-service communication** (east-west). This separation enables assigning layer-by-layer responsibilities -- perimeter, API governance, service mesh -- and aligning the architecture with APIM modernization and evolution of the service layer.

[🔗 View To-Be Production - Step 2 Miro Dashboard](https://miro.com/app/board/uXjVG38NsdE=/?moveToWidget=3458764662373131260&cot=14)

![APIM and Workload Clusters -- North-south and east-west traffic](implementacion-ocp-imagenes/diagrama-to-be-prod-step2.jpeg)

*Figure 5 -- Traffic patterns: APIM Clusters (prd/dr) and Workload Clusters with external/internal F5 GTM and East-West network (Step 2).*

**North-south (ingress and exposure)** [35](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md)

Traffic entering from Internet, core/legacy systems, or partners toward APIs hosted on OpenShift is handled as **north-south**. The objective is to concentrate L7 governance (authentication, rate limiting, versioning, analytics) in a dedicated layer and keep a clear boundary between the perimeter and backends.

- **Three-layer architecture:** (1) **DMZ** -- entry point; F5, firewalls, and DDoS protection; initial SSL/TLS termination, third-party (partner) authentication, routing to API Manager. (2) **API Manager (B2B/B2C)** -- dedicated cluster or namespaces; OAuth2/JWT, rate limiting and throttling per client/API, request/response transformation, developer portal, API versioning, and business policies. (3) **Service mesh / backends** -- once authorized in APIM, traffic reaches the mesh and microservices in OpenShift.
- **Summary flow:** Internet / Core / Legacy / DMZ -> API Manager -> Ingress Routing -> Service Mesh -> Backend Services. Temporary coexistence with the current model (RH 3Scale) during transition; the 3scale replacement for API Manager is not yet defined and will be resolved by domain/phase according to [01_apim -- Target architecture](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/05_arquitectura_objetivo.md).
- **Envoy L7 gateway deployment:** on-demand model per namespace when advanced L7 capabilities are required (rate limits, circuit breakers, canary, traffic splitting), with declarative configuration and GitOps [01_apim -- Technical decisions](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/04_decisiones_tecnicas.md).

**East-west (internal service-to-service communication)** [36](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.3_patron_este_oeste_malla_de_servicios_y_seguridad_de_comunicacion.md), [27](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.3_alternativas_de_service_mesh_para_trafico_este_oeste.md)

**Service-to-service** traffic inside OpenShift (and between clusters where applicable) follows the **east-west** pattern. The priority is to eliminate current hair-pinning (exit through load balancer and re-enter), reduce latency, and provide observability and security (mTLS, identity-based policies) without depending on static API keys.

- **Flow:** Service A -> Service Mesh (sidecarless) -> Service B, with direct pod-to-pod communication where mesh capabilities allow it. No hair-pinning; automatic mTLS; service discovery; end-to-end observability; optional per-namespace L7 policies when needed (circuit breakers, canary, traffic splitting).
- **Stack and responsibilities:** Sidecarless service mesh for multicluster east-west; platform provides L4 (connectivity, mTLS, service discovery), DevOps instruments advanced L7 on demand through Envoy L7 gateway. Internal API governance through native mesh policies (Kubernetes identities, e.g., service accounts) instead of static API keys; see [01_apim -- Target architecture](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/05_arquitectura_objetivo.md) and [technical decisions](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/04_decisiones_tecnicas.md).

> **Alignment with multicluster strategy:** in the current stage, stable north-south is prioritized while preparing the foundation for east-west evolution (observability, security, routing governance); the implementation sequence does not limit the internal and multicluster mesh objective defined in the APIM program scheduled for H2.

### 3.3 Ingress/egress, global DNS, and load balancing [37](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md)

- Standardized ingress by environment, service, and/or domain; egress with explicit policies and traceability.
- Improvements in load balancer health checks for traffic distribution across clusters.
- Automation of DNS updates and dynamic integration with global load balancing (F5 GTM/Infoblox).
- Objective: transparent switchover or balancing between sites with minimal manual intervention, without depending on TTL.

### 3.4 Control plane and data plane model [40](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md), [31](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.7_alternativas_de_operacion_multicluster_y_gobierno_de_flota.md), [44](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md)

- Centralized multicluster governance in hub-spoke topology (ACM), policies and life cycle from versioned repositories.
- Distributed data planes by cluster/site with autonomy under temporary loss of control plane connectivity.
- Domain-distributed GitOps (infra, security/RBAC, applications, middleware/APIs).

### 3.5 End-to-end multicluster security [21](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.4_seguridad_by_design_y_zero_trust.md), [38](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.5_modelo_de_seguridad_integral_iam_rbac_secretos_cifrado_politicas.md), [55](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.2_gestion_de_secretos_y_credenciales.md)

- Zero Trust for east-west communication; authentication and authorization based on immutable identity (Pod labels, Service Accounts).
- IAM integrated with corporate identity and least privilege.
- Declarative RBAC by repository, continuous reconciliation, and segregation of duties.
- Progressive migration from static credentials to workload identity.
- Vault as secrets backend with controlled synchronization in Kubernetes.
- Default deny network policies; explicit communication and egress controls.
- Segregation of duties and auditable traceability per change.

### 3.6 Federated observability and reliability [39](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md), [59](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.1_arquitectura_de_telemetria_metricas_logs_trazas_eventos.md), [62](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.4_alertado_respuesta_a_incidentes_y_postmortems.md)

- Federation of metrics, logs, and traces for unified cross-cluster visibility.
- OpenTelemetry as a transversal pattern and eBPF for network/mesh visibility and dependency mapping.
- Integration of alerting, incident response, and postmortems into a single operational discipline.

### 3.7 Target operating model [40](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md), [48](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md), [49](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.2_self_service_y_automatizacion_de_provision.md), [50](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.3_framework_tecnologico_estandarizado_para_equipos.md)

- GitOps + IaC as the change standard (infrastructure, policies, applications).
- Day 0 / day 1 / day 2 automation to reduce manual tasks and drift.
- Self-service with platform templates (provisioning, onboarding, deployment with guardrails).
- Platform-product operating model with clear roles: Platform Engineering, Security, Network/Communications, SRE/DevOps, and product teams.

---

<a id="sec-4"></a>
## 4. Most relevant architectural decisions (problem -> decision -> benefit)

The table summarizes the most relevant architectural decisions of the program; full detail on principles, evaluated alternatives, and target patterns is in the referenced documentation ([section 10](#sec-10)).

| Structural problem | Architectural decision | Expected benefit |
|----------------------|-------------------------|---------------------|
| Extensive cross-impact (blast radius) | Limit blast radius through domain segmentation, VMware cluster hardening (compute and storage by site), and isolation policies | Minimized impact of individual failures, less incident propagation across domains and datacenters, improved resilience and issue containment [11](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md), [34](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md) |
| Risk concentration in a single cluster | Domain/criticality-based multicluster segmentation | Reduced blast radius and better continuity [11](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md), [20](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md), [34](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md) |
| Vertical scaling limitation and overload in a single cluster | Horizontal scaling by domains, policy-based elasticity (Cluster Autoscaler, criticality limits), traffic-oriented capacity | Capacity aligned with demand without degradation; growth without multiplying manual effort [19](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.2_escalabilidad_horizontal_y_elasticidad.md), [52](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.5_gestion_de_capacidad_slo_sla_y_operacion_continua.md) |
| CNI obsolescence and risky migration without rollback | Deploy new clusters with a different enterprise-ready CNI broadly adopted by the industry and higher versions | 24-month lead time in update calendar [24](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.7_simplicidad_operativa_y_reduccion_de_complejidad_tecnica.md), [31](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.7_alternativas_de_operacion_multicluster_y_gobierno_de_flota.md) |
| Service exposure, availability, and consumption coupled to physical location with high manual ingress intervention | Ingress/egress with global DNS, GTM/LTM, function-based sharding, and DNS update automation | Fast failover, lower dependency on network tickets, multicluster scaling without redesigning exposure on each change [37](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md), [41](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md) |
| Hair-pinning and latency in internal traffic | Prepare the foundation and future evolution toward east-west mesh (sidecarless); in the current stage prioritize stable north-south | Lower latency and less dependency on legacy network once mesh is implemented; during transition, greater stability and lower risk [27](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.3_alternativas_de_service_mesh_para_trafico_este_oeste.md), [36](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.3_patron_este_oeste_malla_de_servicios_y_seguridad_de_comunicacion.md) |
| Mix of external and internal needs in APIM | North-south (API Gateway) vs east-west (mesh) separation | L7 governance where it adds value; internal traffic efficiency [26](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.2_alternativas_de_api_management_y_api_gateway.md), [35](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md) |
| 3scale end of life (EOL 2027) and unified L7 governance | Transition to a new API Manager/API Gateway (3scale replacement still undefined), 3-layer architecture DMZ->APIM->mesh, phased migration | API governance continuity and compliance before EOL; detail in [01_apim](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/00_indice.md) ([section 10.6](#sec-10)) |
| Strong vendor coupling and evolution difficulty | Portability: open standards (Gateway API, OTel, OCI), declarative configuration, documented exit strategy per critical dependency | Evolution and replacement capability without structural lock-in [23](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.6_portabilidad_desacople_y_minimizacion_de_vendor_lock_in.md), [47](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.6_estrategia_de_salida_y_reemplazabilidad_tecnologica.md) |
| Operational manual work and drift between sites | GitOps + IaC + centralized multicluster control | Auditable, repeatable changes with rollback [40](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md), [18](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.1_estandarizacion_y_automatizacion_por_defecto.md) |
| Migration without clear workload prioritization criteria | Eligibility model (cloud-ready / cloud-compatible / on-prem-bound), wave-based prioritization, workload go/no-go criteria | Lower forced-migration risk, better capacity use, executive transparency [43](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.2_criterios_de_elegibilidad_y_priorizacion_de_workloads.md), [44](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md) |
| Security based on static credentials | Workload identity, declarative RBAC, Vault, mTLS | Better compliance, effective revocation, and traceability [21](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.4_seguridad_by_design_y_zero_trust.md), [55](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.2_gestion_de_secretos_y_credenciales.md) |
| Fragmented observability | Federated observability with OTel + eBPF | End-to-end diagnosis and MTTR reduction [22](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.5_observabilidad_integral_y_operabilidad.md), [39](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md), [59](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.1_arquitectura_de_telemetria_metricas_logs_trazas_eventos.md) |
| DR with high manual intervention | Global DNS + health checks + runbooks/drills + progressive automation | Better effective RTO and lower operational variability [14](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md), [41](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md) |

---

<a id="sec-5"></a>
## 5. Multicluster evolution strategy (phase detail)

The evolution is executed in **two major steps**:

- **Step 1** (first half of the year) -- platform enablers, ingress sharding consolidation, operational segmentation with governance, and consolidation/maturity of the workload movement process (phases 5.1 to 5.4).
- **Step 2** (second half of the year) -- implementation and migration to the new APIM, high-availability pattern consolidation (phases 5.5 and 5.6), and traffic flow.

Timing detail is reflected in the execution plan ([section 7](#sec-7)).

### 5.1 Foundational phase: platform enablers [18](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.1_estandarizacion_y_automatizacion_por_defecto.md), [40](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md), [48](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md)

- Establish a common foundation to execute migration without increasing risk.
- Define security, observability, and technical governance baseline per cluster.
- Formalize source of truth repository for RBAC, network policies, ingress/egress, and secrets.
- Align day 0 / day 1 / day 2 model with ownership and RACI by domain.
- Prepare deployment strategy, versions, and dependencies for OCP upgrade to 4.20.x.

### 5.2 Ingress sharding and flow decoupling phase [37](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md), [35](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md)

- Decouple routes and allow gradual transition without massive outages.
- Deploy Global DNS Services (GTM) and local Load Balancers (LTM).
- Separate ingress points by function (OCP management, current routes, internal gateway, external API management).
- Enable selective migration with VIPs/CNAMEs by project.
- Maintain controlled coexistence between current and target models, with automatic validation to prevent drift.

### 5.3 Operational segmentation and governance phase [31](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.7_alternativas_de_operacion_multicluster_y_gobierno_de_flota.md), [40](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md), [14](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md)

- Move from exception-based centralized operation to domain-based operation with guardrails.
- Build shared services clusters and bring their operators into operation (observability, secrets, transversal components, CI/CD, consoles).
- Delegate and migrate observability to shared services clusters; consolidate federated telemetry (metrics, logs, traces) per site.
- Activate centralized multicluster control plane with distributed data planes for API Gateway L7.
- Standardize APIM/API Gateway as a multitenant north-south capability by domain.
- Automate RBAC and global policies with continuous reconciliation.
- Execute staged upgrades (control plane/core first, then compute pools); run risk tests for network/CNI migrations.
- Strengthen continuity by refining DRP invocation process, runbooks, and no-go-live criteria.
- Identify HA-ready applications and domains as the first migration wave.
- Define the first workload wave and migration sequence for execution in H1.

### 5.4 Workload movement process consolidation and maturity phase [44](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md), [43](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.2_criterios_de_elegibilidad_y_priorizacion_de_workloads.md), [51](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.4_practicas_de_entrega_segura_cicd_controles_gobernanza.md)

- Define migration backlog by domain and wave, including dependencies and workload go/no-go criteria.
- Reorganize namespaces and workloads by criticality/function to prepare target assignment in destination clusters.
- Standardize application templates and automated movement pipelines to reduce variability across waves.
- Execute migrations with a lift-and-reshape approach by domains and waves, maintaining temporary source/target coexistence.
- Perform progressive traffic switchover per wave with controlled rollback and prior technical validations.
- Measure post-movement stability (errors, latency, availability) and adjust the process for subsequent waves.

### 5.5 Implementation and migration to the new APIM [26](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.2_alternativas_de_api_management_y_api_gateway.md), [35](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md), [44](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md)

- Implement the target APIM/API Gateway platform resulting from the technical evaluation, with controlled coexistence with 3scale during transition.
- Deploy the target APIM domain topology (DMZ->APIM->mesh), clearly separating governance, execution, and exposure planes.
- Migrate APIs, products, consumers, and policies in waves, with explicit go/no-go criteria, regression testing, and rollback by domain.
- Progressively reroute north-south traffic to the new APIM through GTM/LTM, DNS, and staged functional/performance validation.
- Complete operational transition (runbooks, observability, support) and execute planned 3scale decommissioning before EOL.

### 5.6 High-availability pattern consolidation phase [41](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md), [14](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md)

- Stabilize multicluster operation with verifiable recovery capability.
- Adopt active-active or active-passive models based on service criticality and nature.
- Integrate global DNS, load balancing, and multi-layer health checks for controlled switchover.
- Define RTO/RPO by business domain and validate with representative drills.
- Ensure state and data recovery for stateful workloads, not only manifest redeploy.

---

<a id="sec-6"></a>
## 6. Target architecture and topology -- First stage (H1)

This section details the **target architecture and topology** for the **first stage (H1)** of the program. It establishes the **foundations**, defines **enablers**, sets up **day 0 / day 1 / day 2 automation**, **consolidates ingress sharding**, builds **dedicated IaaS per site**, **applies the new traffic model** with F5 GTM, establishes **cluster domains** with clear separation of responsibilities, and **deploys end-to-end observability through eBPF**. It corresponds to phases 5.1 to 5.4 ([section 5](#sec-5)); Step 2 (H2) extends this base with APIM/workload traffic patterns, implementation and migration to the new APIM, and HA consolidation ([section 3.2](#sec-3), [section 5.5](#sec-5)-5.6).

### 6.1 Overview -- Step 1 (H1) [34](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md)

[🔗 View As-Is Production - Step 1 Miro Dashboard](https://miro.com/app/board/uXjVG38NsdE=/?moveToWidget=3458764662448484972&cot=14)

![Target proposal -- PAAS and IaaS by site (Plaza / Matriz)](implementacion-ocp-imagenes/diagrama-to-be-prod-step1.jpeg)

*Figure 6 -- OCP multicluster implementation proposal (Step 1 / H1): PAAS layers (orchestration, workload prd/dr, shared services and storage) and IaaS layers (site-based vSphere, dedicated storage).*

High-level representation of the H1 fleet: governance, initial workload, shared services, and site-based IaaS (Plaza Galicia and Casa Matriz).

### 6.2 Fundamentals, enablers, and day 0 / day 1 / day 2 automation [18](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.1_estandarizacion_y_automatizacion_por_defecto.md), [40](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md), [48](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md)

- **Fundamentals:** Establish a common foundation to execute migration without increasing risk: source-of-truth repository for RBAC, network policies, ingress/egress, and secrets; security, observability, and technical governance baseline per cluster; preparation of deployment strategy and dependencies for OCP upgrade to 4.20.x.
- **Enablers:** Define and deploy platform enablers that allow operation of the new domains: GitOps/IaC as change standard (infrastructure, policies, applications); centralized multicluster control plane (ACM) with distributed data planes; templates and guardrails by domain.
- **Day 0 / day 1 / day 2 automation:** Align the operating model with ownership and RACI by domain: day 0 (provisioning, onboarding), day 1 (configuration, initial deployment), day 2 (operations, changes, remediation). Reduce manual tasks and drift through declarative configuration and continuous reconciliation [40](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md).

### 6.3 Ingress sharding consolidation [37](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md), [35](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md)

- **Route decoupling:** Separate ingress points by function (OCP management, current routes, internal gateway, external API management) to allow gradual transition without massive outages.
- **Global DNS services (GTM) and local load balancers (LTM):** Deploy and configure F5 GTM for global traffic distribution and site/cluster LTMs; integrate with corporate DNS (Infoblox) and automate updates.
- **Selective migration:** Enable VIPs/CNAMEs by project or domain; controlled coexistence between current and target models, with automatic validation to prevent drift.
- **Standardized ingress** by environment, service, and/or domain; egress with explicit policies and traceability.

### 6.4 Dedicated IaaS per site

- **Compute:** Two **independent** vSphere clusters (Plaza Galicia and Casa Matriz), **not stretched**. Site isolation; each site operates its own host pool and management.
- **Storage:** **Dedicated storage per site**, without synchronous IaaS-level replication between sites. Consumption through CSI and dedicated datastores per vSphere cluster; progressive elimination of dependency on stretched shared storage.
- **Transition:** Migration from the current model (stretch, synchronous replication) is executed in phases: H1 consolidates enablers, ingress sharding, operational governance, and workload movement process maturity (phases 5.1-5.4); H2 completes APIM domain migration and HA consolidation (phases 5.5 and 5.6 / Step 2), prioritizing domains with lower dependency on synchronous replication.

### 6.5 New traffic model with F5 GTM [37](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md)

- **Traffic model application:** Use **F5 GTM** (Global Traffic Manager) for traffic routing and distribution across sites and clusters; LTM (Local Traffic Manager) for local balancing by cluster or service group.
- **Health checks and switchover:** Improvements in load balancer health checks for traffic distribution across clusters; objective of transparent switchover/balancing between sites with minimal manual intervention, without depending only on TTL.
- **DNS and load balancing:** DNS update automation and dynamic integration with global load balancing (F5 GTM/Infoblox). H1 establishes the foundation; H2 deepens north-south/east-west patterns with APIM and workload clusters ([section 3.2](#sec-3)).

### 6.6 Cluster domains and separation of responsibilities [34](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md), [38](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.5_modelo_de_seguridad_integral_iam_rbac_secretos_cifrado_politicas.md), [39](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md), [40](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md)

In H1, **cluster domains are established** with **clear separation of responsibilities**, aligned with the 21-cluster target topology ([section 3.1](#sec-3)) and the governance/execution/ingress/communication logical view:

| Cluster type | Responsibility |
|-----------------|-----------------|
| **Management clusters (governance)** | Multicluster operations, global policies, life cycle, GitOps/IaC. Central control plane (ACM). |
| **Business/application workload clusters** | Domain service execution with own SLO/SLA; domain-distributed data planes. |
| **Common services clusters** | Observability, secrets, shared components, CI/CD, consoles; transversal site capabilities. |
| **Specialized clusters** | Specific use cases: APIM, AI workloads, transversal products (e.g., POM). |

- **Governance layer:** Centralized multicluster control plane (hub-spoke) for policies and life cycle.
- **Execution layer:** Distributed data planes by cluster/site with autonomy under temporary control plane connectivity loss.
- **North-south ingress layer:** External exposure and core/legacy channels; integrated with F5 GTM/LTM and ingress sharding.
- **East-west communication layer:** Internal and intercluster traffic; in H1, stable north-south is prioritized and foundations are prepared for east-west evolution (observability, security, routing governance) [42](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.1_estrategia_hibrida_on_premise_cloud.md).

### 6.7 Workload placement strategy by tribe/domain [43](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.2_criterios_de_elegibilidad_y_priorizacion_de_workloads.md), [34](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md)

**Business clusters** (workload clusters) for application workloads are distributed by **tribe/domain**, using each domain's **resource usage** (vCPU, RAM, number of APIs) as reference. **Today applications are published in each ingress shard this way**; the placement strategy keeps that distribution as a baseline. This is a **first segmentation**; in the future, grouping may change based on growth of projects within each tribe/domain. The strategy will evolve with support from **end-to-end visibility (e2e) via eBPF** ([section 6.9](#sec-6-9)), enabling finer placement and prioritization according to observed traffic and behavior.

![Groups by tribe/domain -- Application workload distribution (workload clusters)](implementacion-ocp-imagenes/diagrama-grupos-tribus-dominio.png)

*Figure 7 -- Tribe/domain grouping for workload placement in business clusters; it corresponds to how applications are currently published in each ingress shard.*

Initially, workloads are placed according to the six groups in Figure 7; details are listed below:

| Group     | Tribes / domains |
|---------|-------------------|
|**Group 1** | Channel Architecture |
|**Group 2** | Coe Automation; Every Day Banking Tribe; Investments Tribe; Payment Methods Tribe |
|**Group 3** | Administration & Finance; Core Payments and Transfers; Collections and Payments Tribe |
|**Group 4** | Core Banking; Branches and Channels; Contactability Tribe; Omnichannel Tribe |
|**Group 5** | Architecture; Development; DevSecOps; Commercial Management; Undetermined; QA; Stand Alone; Technology; Comex Tribe; Data & Analytics Tribe; Loyalty Tribe; Segments Tribe |
| **Group 6** | Core Investments; Commerce Tribe; Lending Tribe |

Workload assignment to clusters and wave-based prioritization are governed by the eligibility and go/no-go criteria defined in the program ([section 4](#sec-4), decisions table; [section 5.4](#sec-5) and [section 5.5](#sec-5)).

### 6.8 High-availability and internal traffic scheme in H1 [41](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md), [14](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md)

- **HA scheme in H1:** In the first stage, high availability **remains active-passive** (active site / standby site), consistent with the current model and with the objective of not increasing risk while building foundations and enablers. In parallel, **the basis for improved schemes is built** (active-active, automatic failover, global DNS, and multi-layer health checks), to be consolidated in H2 with phases 5.5 and 5.6 ([section 5](#sec-5)).
- **Intra-namespace and service-to-service consumption:** In H1, **consumption remains exactly as it is today**: **north-south traffic with hair-pinning** (exit through load balancer and re-entry into the cluster) for service-to-service or intra-namespace communication. The change to direct east-west mesh is not introduced in this stage; evolution toward pod-to-pod communication without hair-pinning is prepared by observability, security, and routing governance foundations, and will be addressed in H2 with the APIM program and service mesh ([section 3.2](#sec-3)).

<a id="sec-6-9"></a>
### 6.9 End-to-end observability deployment with eBPF [39](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md), [59](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.1_arquitectura_de_telemetria_metricas_logs_trazas_eventos.md), [60](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.2_observabilidad_de_red_y_servicios_incluyendo_ebpf.md)

- **End-to-end observability (e2e):** In H1, **e2e observability** is deployed as a platform enabler, providing unified visibility of metrics, logs, and traces across traffic flows (north-south and service-to-service), dependency diagnosis, and MTTR reduction.
- **eBPF:** Instrumentation with **eBPF** provides network and service visibility at kernel level without modifying applications: connectivity mapping, latency, pod-to-pod flows, and dependency detection. It integrates with the telemetry stack (OpenTelemetry, metrics, logs) for a correlated application-platform-network view.
- **Scope in H1:** Deploy eBPF-based observability capabilities in first-stage target clusters; federation and aggregation of signals for unified cross-cluster visibility. Foundation for H2 evolution (east-west mesh, APIM) and for no-go-live criteria based on operational visibility.

---

<a id="sec-7"></a>
## 7. High-level execution plan [48](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md), [44](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md)

The plan is structured in **two major steps**. Target dates are conditioned by banking freeze periods and change windows; no-go-live criteria are applied per phase. Deliverables for each step are detailed in [section 6](#sec-6) (H1, phases 5.1-5.4) and in [sections 3.2](#sec-3), [5.5](#sec-5)-5.6 (H2, with implementation and migration to the new APIM and high-availability consolidation).

| Step | Period | Target date (reference) | Scope and deliverable |
|------|---------|----------------------------|---------------------|
| **Step 1** | H1 2026 | Mar-Jun 2026 | PAAS/IaaS topology by site, enablers, ingress sharding, operational segmentation, governance, and consolidation/maturity of the workload movement process ([section 6.1](#sec-6), [section 5.1](#sec-5)-5.4). Closure of target architecture and execution governance definitions. Fundamentals and enablers; day 0 / day 1 / day 2 automation. Ingress sharding consolidation (F5 GTM/LTM, DNS). Dedicated IaaS per site (non-stretched vSphere, dedicated storage). New traffic model with F5 GTM. Cluster domains with separation of responsibilities. Active-passive HA scheme and foundations for improved schemes. End-to-end observability deployment with eBPF. Hardening/performance POC and validation of critical scenarios. |
| **Step 2** | H2 2026 | Jul-Dec 2026 | North-south and east-west traffic patterns; APIM and workload clusters ([section 3.2](#sec-3)). Implementation and migration to the new APIM; high-availability pattern consolidation ([section 5.5](#sec-5)-5.6). Progressive migration by waves; operational consolidation of the new topology. APIM domain transition closure before 3scale EOL. |

### 7.1 Executive control deliverables [48](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md), [52](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.5_gestion_de_capacidad_slo_sla_y_operacion_continua.md), [63](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.5_indicadores_de_salud_tecnica_por_cluster_y_por_dominio.md)

| Deliverable | Owner | Completion criterion |
|------------|-------------|--------------------|
| Detailed architecture approved by domain | Architecture / Platform Engineering | Approval by Technical Committee or equivalent |
| Dependency matrix and technical sequencing | PM / Architecture | Baselined document reviewed with impacted teams |
| Progress/no-go-live criteria by phase | Program governance | Defined and communicated before each phase starts |
| Integrated plan for risks, mitigations, and contingency | PM / Risks | Updated risk register and assigned mitigations |

---

<a id="sec-8"></a>
## 8. Critical risks and mitigations of the multicluster program [11](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md), [14](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md), [15](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.5_brechas_de_observabilidad_y_trazabilidad_end_to_end.md), [16](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.6_brechas_de_seguridad_y_gobierno_tecnico.md), [62](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.4_alertado_respuesta_a_incidentes_y_postmortems.md)

Risks ordered by criticality; detailed analysis can be expanded in a program risk register.

**Classification by origin:** Distinguishes **internal risks** (program, execution, platform, or organization: capacity, processes, configuration, internal coordination) and **third-party risks** (providers, vendors, external dependencies: support, contracts, component or service availability). In the table, the **Origin** column indicates **P** (internal) or **T** (third party).

| Risk | Origin | Prob. | Impact | Priority | Mitigation |
|--------|--------|-------|---------|-----------|------------|
| **R1:** Instability in critical cross-cluster patterns | P | H | H | High | Mandatory pod churn tests for cross-cluster patterns in POC/staging/preproduction; no-go-live criterion if consistent stability is not achieved |
| **R2:** Platform and network upgrade complexity | P | H | H | High | Staged execution, domain-level prior technical validations, explicit compatibility dependency management |
| **R3:** Configuration drift between clusters/sites | P | M | H | High | Declarative baseline, continuous reconciliation via GitOps, and drift controls in operational monitoring |
| **R4:** Security gaps during identity/secret transition | P | M | H | High | Domain-based migration plan, segregation of duties, change traceability, and gradual removal of static credentials |
| **R5:** Delays or unavailability in delivery of hardware, networking components, storage, or other third-party supplies (including licenses, features, software patches) | T | H | H | High | Early planning of orders and lead times (servers, storage, network equipment); alignment with IaaS providers and manufacturers; alternative assessment and schedule buffer; software life-cycle tracking (e.g., 3scale EOL) |
| **R6:** Administrative or contractual blockers with providers or internal areas | T | H | M | High | Early identification of contractual/approval dependencies; follow-up in program governance; plan B or explicit deadline dates |
| **R7:** Operational overload during coexistence of models | P | M | M | Medium | Wave-based migration, limited scope per phase, automation of repetitive tasks, and runbooks |
| **R8:** Observability gaps in federated operation | P | M | M | Medium | Default instrumentation in new clusters, single indicator catalog, and app/platform/network correlation |
| **R9:** Insufficient vendor support or response capacity (F5, Red Hat, APIM/mesh vendor, etc.) | T | M | M | Medium | Contract-defined SLAs; documented enterprise support escalation and contacts; contingency plan and internal knowledge for critical incidents |

*Origin: P = internal (program/execution/platform/organization); T = third party (providers, vendors, external dependencies). Prob.: Probability (Low/Medium/High). Impact: L/M/H. Priority derived from Probability and Impact. Additional internal or third-party risks should be added to the program risk register and reviewed in the integrated plan ([section 7.1](#sec-7)).*

---

<a id="sec-9"></a>
## 9. Conclusion [2](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md)

The multicluster transformation is not a response to an isolated technology preference: it responds to a **concrete business risk**. Concentrating critical workloads in a monolithic model amplifies cross-impact in infrastructure, network, or configuration failures and limits continuity and growth. The objective of this strategy is to **reduce systemic risk**, **sustain banking continuity**, and **enable growth** with lower operational friction, through a domain-based architecture, centralized governance, and declarative operation [2](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md), [34](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md).

**APIM replacement** (3scale EOL mid-2027) is a relevant front within that transformation -- and a modeling case for network, security, and resilience decisions -- but **it is not the final objective**: the objective is the platform's end-to-end evolution toward multicluster, with defined north-south and east-west patterns, a target fleet of 21 clusters, and GitOps + IaC operation [26](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.2_alternativas_de_api_management_y_api_gateway.md). APIM technical detail and roadmap are documented in [01_apim](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/00_indice.md) ([section 10.6](#sec-10)).

Execution is structured in **two steps** (Step 1: H1 -- PAAS/IaaS topology, enablers, sharding, operational segmentation, governance, and workload movement consolidation/maturity; Step 2: H2 -- traffic patterns, implementation and migration to the new APIM, and HA consolidation), with phases detailed in [section 5](#sec-5), target topology in [section 6](#sec-6), plan and deliverables in [section 7](#sec-7), and critical risks with mitigations in [section 8](#sec-8). The expected result depends on **executing the sequence correctly**: (1) segment risk, (2) standardize operation, (3) migrate in phased waves with control and no-go-live criteria, (4) consolidate resilience based on evidence [44](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md), [41](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md). With this execution, the platform evolves from a concentrated and reactive model to a **distributed, auditable architecture prepared for sustained growth**.

---

<a id="sec-10"></a>
## 10. References to detailed documentation (@architecture)

*Numbers in brackets in the body of this document refer to sections of the detailed architecture documentation.*

### 10.1 Index and overall view

| Ref. | Document |
|------|-----------|
| 1 | [Strategic reengineering index](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/indice_tentativo.md) |
| 2 | [Multicluster vision and strategy](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md) |

### 10.2 Current state and diagnosis (as-is)

| Ref. | Document |
|------|-----------|
| 3 | [3.1 Current topology and installed capacity](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md) |
| 4 | [3.2 Operating model (day 0, day 1, day 2)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md) |
| 5 | [3.3 Networking, ingress/egress, and service exposure](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md) |
| 6 | [3.4 API management and APIM status](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md) |
| 7 | [3.5 Storage and data services](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.5_almacenamiento_y_servicios_de_datos.md) |
| 8 | [3.6 Current security (IAM/RBAC, secrets, encryption, policies)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.6_seguridad_actual_iam_rbac_secretos_cifrado_politicas.md) |
| 9 | [3.7 Current observability and monitoring](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.7_observabilidad_y_monitoreo_actual.md) |
| 10 | [3.8 Current operational and licensing costs](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.8_costos_operativos_y_de_licenciamiento_actuales.md) |
| 11 | [4.1 Systemic risk and blast radius](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md) |
| 12 | [4.2 Scalability and elasticity limits](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.2_limites_de_escalabilidad_y_elasticidad.md) |
| 13 | [4.3 Operational complexity and manual tasks](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md) |
| 14 | [4.4 Resilience and disaster recovery gaps](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md) |
| 15 | [4.5 End-to-end observability and traceability gaps](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.5_brechas_de_observabilidad_y_trazabilidad_end_to_end.md) |
| 16 | [4.6 Security and technical governance gaps](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.6_brechas_de_seguridad_y_gobierno_tecnico.md) |
| 17 | [4.7 Legacy complexity and team friction](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.7_complejidad_heredada_legacy_y_friccion_para_equipos_de_desarrollo.md) |

### 10.3 Target architecture and decisions

| Ref. | Document |
|------|-----------|
| 18 | [5.1 Standardization and automation by default](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.1_estandarizacion_y_automatizacion_por_defecto.md) |
| 19 | [5.2 Horizontal scalability and elasticity](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.2_escalabilidad_horizontal_y_elasticidad.md) |
| 20 | [5.3 Multicluster resilience and high availability](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md) |
| 21 | [5.4 Security by design and zero trust](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.4_seguridad_by_design_y_zero_trust.md) |
| 22 | [5.5 End-to-end observability and operability](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.5_observabilidad_integral_y_operabilidad.md) |
| 23 | [5.6 Portability, decoupling, and minimization of vendor lock-in](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.6_portabilidad_desacople_y_minimizacion_de_vendor_lock_in.md) |
| 24 | [5.7 Operational simplicity and technical complexity reduction](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.7_simplicidad_operativa_y_reduccion_de_complejidad_tecnica.md) |
| 25 | [6.1 Evaluation framework and comparative criteria](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.1_marco_de_evaluacion_y_criterios_comparativos.md) |
| 26 | [6.2 API Management and API Gateway alternatives](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.2_alternativas_de_api_management_y_api_gateway.md) |
| 27 | [6.3 Service mesh alternatives for east-west traffic](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.3_alternativas_de_service_mesh_para_trafico_este_oeste.md) |
| 28 | [6.4 Networking and service discovery alternatives](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.4_alternativas_de_networking_y_service_discovery.md) |
| 29 | [6.5 Observability alternatives (metrics, logs, traces, eBPF)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.5_alternativas_de_observabilidad_metricas_logs_trazas_ebpf.md) |
| 30 | [6.6 Secret and identity management alternatives](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.6_alternativas_de_gestion_de_secretos_e_identidad.md) |
| 31 | [6.7 Multicluster operations and fleet governance alternatives](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.7_alternativas_de_operacion_multicluster_y_gobierno_de_flota.md) |
| 32 | [6.8 Trade-off evaluation (technical/operational/economic/risk)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.8_evaluacion_de_trade_offs_tecnicos_operativos_economicos_riesgo.md) |
| 33 | [6.9 Domain-level technology recommendation](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.9_recomendacion_tecnologica_por_dominio.md) |
| 34 | [7.1 Target multicluster model and domain segmentation](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md) |
| 35 | [7.2 North-south pattern (ingress, exposure, and API governance)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md) |
| 36 | [7.3 East-west pattern (mesh and communication security)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.3_patron_este_oeste_malla_de_servicios_y_seguridad_de_comunicacion.md) |
| 37 | [7.4 Ingress/egress and global DNS architecture](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md) |
| 38 | [7.5 End-to-end security model](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.5_modelo_de_seguridad_integral_iam_rbac_secretos_cifrado_politicas.md) |
| 39 | [7.6 Federated multicluster observability](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md) |
| 40 | [7.7 GitOps + IaC operating model](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md) |
| 41 | [7.8 Resilience, failover, and continuity patterns](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md) |

### 10.4 Evolution, operations, and execution

| Ref. | Document |
|------|-----------|
| 42 | [8.1 Hybrid on-premise + cloud strategy](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.1_estrategia_hibrida_on_premise_cloud.md) |
| 43 | [8.2 Eligibility criteria and workload prioritization](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.2_criterios_de_elegibilidad_y_priorizacion_de_workloads.md) |
| 44 | [8.3 Progressive migration approach with minimal refactor](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md) |
| 45 | [8.4 Interoperability across platforms and environments](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.4_interoperabilidad_entre_plataformas_y_entornos.md) |
| 46 | [8.5 Critical dependencies for cloud adoption](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.5_dependencias_criticas_para_adopcion_cloud.md) |
| 47 | [8.6 Exit strategy and technology replaceability](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.6_estrategia_de_salida_y_reemplazabilidad_tecnologica.md) |
| 48 | [9.1 Platform operating model](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md) |
| 49 | [9.2 Self-service and provisioning automation](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.2_self_service_y_automatizacion_de_provision.md) |
| 50 | [9.3 Standardized technology framework for teams](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.3_framework_tecnologico_estandarizado_para_equipos.md) |
| 51 | [9.4 Safe delivery practices (CI/CD and governance)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.4_practicas_de_entrega_segura_cicd_controles_gobernanza.md) |
| 52 | [9.5 Capacity management, SLO/SLA, and continuous operations](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.5_gestion_de_capacidad_slo_sla_y_operacion_continua.md) |
| 53 | [9.6 Developer experience and productivity improvements](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.6_mejora_de_developer_experience_y_productividad.md) |

### 10.5 Security, compliance, and observability

| Ref. | Document |
|------|-----------|
| 54 | [10.1 Multicluster identity and access governance](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.1_gobierno_de_identidades_y_accesos_multicluster.md) |
| 55 | [10.2 Secret and credential management](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.2_gestion_de_secretos_y_credenciales.md) |
| 56 | [10.3 Platform hardening and network security](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.3_hardening_de_plataforma_y_seguridad_de_red.md) |
| 57 | [10.4 Traceability, auditing, and regulatory evidence](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.4_trazabilidad_auditoria_y_evidencias_regulatorias.md) |
| 58 | [10.5 Vulnerability management and supply chain security](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.5_gestion_de_vulnerabilidades_y_seguridad_de_cadena_de_suministro.md) |
| 59 | [11.1 Telemetry architecture (metrics, logs, traces, events)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.1_arquitectura_de_telemetria_metricas_logs_trazas_eventos.md) |
| 60 | [11.2 Network and service observability (including eBPF)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.2_observabilidad_de_red_y_servicios_incluyendo_ebpf.md) |
| 61 | [11.3 Application experience and dependency monitoring](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.3_monitoreo_de_experiencia_de_aplicacion_y_dependencias.md) |
| 62 | [11.4 Alerting, incident response, and postmortems](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.4_alertado_respuesta_a_incidentes_y_postmortems.md) |
| 63 | [11.5 Technical health indicators by cluster and domain](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.5_indicadores_de_salud_tecnica_por_cluster_y_por_dominio.md) |

### 10.6 APIM documentation (API infrastructure modernization)

*Technical documentation for APIM / API Gateway modernization (01_apim), referenced in section 3.2 Target traffic patterns and in the multicluster program.*

| Document | Description |
|------------|-------------|
| [APIM -- Consolidated technical document](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/apim_consolidado_tecnico.md) | Consolidated executive summary, context, target architecture, technical decisions, and roadmap |
| [00 Index](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/00_indice.md) | APIM documentation index and table of contents |
| [01 Context and current situation](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/01_contexto_situacion_actual.md) | Current state of API infrastructure and 3scale |
| [02 Path traveled](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/02_camino_transitado.md) | Project evolution and path traveled |
| [03 Lessons learned](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/03_lecciones_aprendidas.md) | Lessons learned |
| [04 Technical and architectural decisions](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/04_decisiones_tecnicas.md) | Technical decisions (service mesh, API Gateway, 3-layer north-south, L4/L7, etc.) |
| [05 Target architecture](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/05_arquitectura_objetivo.md) | Target architecture (north-south, east-west, components, HA/DR) |
| [06 Vendor evaluation](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/06_evaluacion_proveedores.md) | Vendor evaluation |
| [07 Technical roadmap](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/07_roadmap_tecnico.md) | Required steps and technical roadmap |
| [08 Risks and mitigations](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/08_riesgos_mitigaciones.md) | APIM program risks and mitigations |
| [09 Conclusions and next steps](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/01_apim/09_conclusiones.md) | Conclusions and next steps |
