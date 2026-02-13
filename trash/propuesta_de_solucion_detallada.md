# OpenShift Multicluster – Propuesta de Solución Técnica (Detallada)

# OpenShift Multiclúster – Propuesta de Solución Técnica

## 1. Contexto, Alcance y Objetivos

### 1.1 Situación Crítica Actual

#### Estado de la Infraestructura Productiva

**Clúster Monolítico – Métricas Críticas**:

```yaml
Hardware Productivo:
  - Clúster principal: 120 nodos worker
  - Overcommit de CPU: 210% (crítico)
  - Utilización promedio: 40% en 96 workers del clúster stretch
  - Memoria: >60 GB por nodo worker
  - Total CPUs del clúster: >1.000 vCPU
  - Storage: múltiples instancias de ODF generando desgaste operativo constante

Infraestructura de Laboratorio:
  - Nodos de laboratorio: 22 nodos (sobredimensionado)
  - Configuración ineficiente: recursos ociosos significativos
  - Problema: recursos de laboratorio no reutilizables para producción
```

**Namespaces y Aplicaciones – Escala Real**:

```yaml
Distribución de Workloads:
  - Namespaces totales: 600+ activos
  - Namespaces críticos: 50+ identificados para alta disponibilidad
  - Pods productivos: ~10.000
  - Servicios Kubernetes: ~2.000
  - APIs publicadas: ~2.200 (objetivo limpieza: 1.500)

Proyectos por ambiente:
  - Producción: ~450 proyectos
  - Desarrollo/QA: ~1.000+
  - Sin uso: 500–600 APIs para limpieza
```

#### Volumen de Tráfico y Transacciones

**Análisis de tráfico de APIs**:

```yaml
Volumen mensual:
  - Tráfico interno (east-west): 7.500.000.000 requests/mes
  - Tráfico externo (north-south): 500.000.000 requests/mes
  - Total: 8.000.000.000 requests (~8B)
  - Pico diario: ~250.000.000 requests
  - Pico RPS: 25.000 requests/segundo

Distribución por tenant (3scale):
  - B2C (interno): 80%
  - B2B (externo): 20%
  - Mainframe: múltiples llamadas por transacción
```

**Impacto del hair-pinning**:

```yaml
Ineficiencia:
  - Longitud del path: 7 saltos vs 2 posibles
  - Latencia añadida: 15–25 ms por llamada interna
  - Puntos de falla: 4 vs 1 optimizado
  - Ancho de banda: desperdicio por round-trips innecesarios
  - Carga F5: los 7.5B requests internos pasan por el balanceador externo
```

#### Equipos

```yaml
Escala organizacional:
  - Squads activos: ~100
  - Desarrolladores: ~1.000
  - Arquitectos: distribuidos por dominio
  - Platform engineers: <10 personas

Distribución:
  - Core banking: 25+ equipos
  - Canales digitales: 20+
  - APIs e integración: 15+
  - Infraestructura: 5
  - Seguridad y compliance: 3
```

---

### 1.2 Crisis Operativa

#### Modelo Operativo Insostenible

```yaml
Realidad del equipo plataforma:
  - Tiempo en incidentes: 95%
  - Tiempo en innovación: 5%
  - Horas extra: hasta 240 anuales/persona
  - Gestión de lifecycle: fuera del horario laboral
```

**Dependencias externas**:

```yaml
Red:
  - Tiempo de respuesta: 3 semanas
  - Proceso: tickets manuales

Storage:
  - Creación de LUN: ticket con SLA indefinido
  - Presentación: proceso separado

Seguridad:
  - Cambios RBAC: 8 meses sin resolución
  - Uso de admin compartido
```

#### Incidentes

```yaml
Incidentes mayores:
  - Falla de storage (LUNs de 50 GB)
  - Certificados SSL incorrectos
  - Loop de APIs sin rate limiting
  - Saturación de F5 por tráfico interno

Disponibilidad:
  - Objetivo: 99,9%+
  - Impacto: clúster monolítico extiende downtime
```

---

### 1.3 Drivers de Negocio

#### Compliance (BCRA)

```yaml
DRP obligatorio:
  - Fecha: 21 marzo 2026
  - Operación: 1 semana completa
  - SLA failover: 4 horas
  - Auditoría en 3 momentos
```

Limitaciones actuales:

* Aplicaciones no stateless
* Batch dependiente del pod
* Colas compiten entre sitios

---

#### Crecimiento del Negocio

```yaml
Crecimiento:
  - +30–40% por adquisición bancaria
  - Infraestructura actual saturada
  - Necesidad: 14 nuevos bare metal en 2026
```

---

#### Fin de vida de 3scale

```yaml
EOL:
  - Soporte hasta 2027
  - Decisión: Q4 2025
  - APIs: ~2.200

Complejidad:
  - Migración manual
  - Falta declaratividad
  - Convivencia durante transición
```

---

### 1.4 Limitaciones Técnicas

#### Storage

* Múltiples ODF generan sobrecarga
* LUNs mal distribuidas
* Sin uso de CSI de VMware
* Storage compartido impacta componentes críticos

#### Networking

Flujo actual:

```
Servicio A → kube-proxy → SDN → DNS → F5 → SDN → kube-proxy → Servicio B
```

Impacto:

* +15–25 ms
* 7.5B requests por F5
* 4 puntos de falla

#### Observabilidad

* APIM corta trazas
* No hay service maps
* No hay correlación end-to-end

#### Seguridad

* Admin compartido
* Tokens sin expiración
* Devs con permisos excesivos
* APIs internas sin autenticación robusta

---

### 1.5 Alcance Técnico

#### Arquitectura Multiclúster

```yaml
Gestión (ACM):
  - Solo governance
  - Sin workloads
Servicios:
  - ODF centralizado
  - Observabilidad
  - Vault
Aplicaciones:
  - Tier 1
  - Tier 2
  - Staging
  - Dev
  - Lab
```

#### Workloads

```yaml
Tier 1:
  - Login
  - Core banking
  - Pagos
  - SLA: 99.95%

Tier 2:
  - APIs negocio
  - BFFs
  - SLA: 99.9%
```

---

### 1.6 Objetivos Técnicos

#### Resiliencia

* Eliminar SPOF
* Aislar fallas por clúster
* Reducir dependencia de F5
* Consolidar storage

#### Performance

```yaml
Objetivo:
  - Llamadas internas: <5 ms
  - 80% tráfico interno por service mesh
  - F5 solo north-south
```

#### Autonomía

* Red automatizada
* Storage centralizado
* RBAC vía GitOps
* Self-service

#### Observabilidad

* eBPF
* Service maps automáticos
* Correlación multi-clúster
* Vista unificada

---

## 2. Principios de Arquitectura

### Principio 1: Separación por Especialización

* Gestión ≠ servicios ≠ aplicaciones
* Storage centralizado
* Observabilidad hub-and-spoke

---

### Principio 2: Automatización

* Sin dependencias manuales
* Infraestructura como código
* Git como trigger

---

### Principio 3: Observabilidad como Restricción de Diseño

* Nada sin métricas
* Nada sin trazas
* Nada sin logs

---

### Principio 4: Governance Centralizada, Enforcement Distribuido

* Policies en ACM
* Enforcement local
* GitOps RBAC

---

### Principio 5: GitOps como Fuente Única de Verdad

* Configuración declarativa
* Auditoría completa
* Recuperación automática

---

### Principio 6: Latencia como Métrica de Primer Orden

* Service-to-service directo
* Sin hair-pinning
* Failures aisladas

---

### Principio 7: Eficiencia por Consolidación

* Un ODF
* Observabilidad central
* Servicios compartidos

---

### Principio 8: Seguridad por Diseño

* Sin cuentas compartidas
* RBAC como código
* Secrets integrados

---

### Principio 9: Zero Trust

* Default deny
* mTLS
* Autorización L7

---

### Principio 10: Migración Incremental

* Convivencia con 3scale
* Rollback inmediato
* Migración por servicio

---

### Principio 11: Diseño Basado en Modos de Falla

* Sin destino compartido
* Recuperación automática
* Estrategia multi-sitio

---

## Análisis Histórico Profundo: Evidencia Cuantitativa

### Métricas Críticas del Sistema Actual
**Performance y Capacidad**:
- Cluster productivo: 120 workers, 210% CPU overcommit
- Promedio uso CPU: 40% en stretch cluster 96 workers
- Laboratorio: 22 nodos (superdimensionado vs necesidades reales)
- Pods activos estimados: ~11,500 (vs 22,000 con sidecars potenciales)

**Tráfico de APIs**:
```yaml
Volumen Total Mensual:
- Internal (East-West): 7,500,000,000 requests/mes
- External (North-South): 500,000,000 requests/mes  
- Daily Peak: ~250,000,000 requests/día
- Peak Load: 25,000 RPS durante horas críticas
- APIs Productivas: ~2,200 (objetivo limpieza a 1,500)

Distribución por Tenant:
- B2C (Interno): 80% del tráfico total
- B2B (Externo): 20% del tráfico total
```

**Equipos y Desarrollo**:
- Equipos desarrollo: ~100 equipos activos
- Desarrolladores: ~1,000 personas
- Namespaces: 600+ (objetivo consolidación)
- Aplicaciones críticas: 50+ namespaces identificados

**Incidents y Operación**:
- Tiempo en incidentes vs desarrollo: 95% / 5%
- Horas extras acumuladas: hasta 240 anuales/persona
- Horario operativo: 9AM-6PM + guardias nocturnas
- Tiempo respuesta otros equipos: 3 semanas (redes)

---

## 3. Modelo de Arquitectura Multicluster (Detallado)

### 🔴 Fundacional: Especificaciones Técnicas Precisas

#### ACM Management Cluster
**Hardware Specifications**:
```yaml
Masters (3 nodos):
  CPU: 8 cores (32GB RAM recomendado vs 16GB base)
  Storage: 120GB disco base
  Network: Dual-homed para HA
  
Workers (3 nodos):
  CPU: 8 cores  
  RAM: 32GB
  Storage: Local SSD para performance
  
Configuración Especial:
  - Sin ODF inicialmente (performance optimization)
  - CSI driver VMware para persistencia básica
  - Red /24 dedicada con DHCP desde IP 32+
  - IPs reservadas 1-31 para masters e infra
```

**Funcionalidades Específicas**:
```yaml
Observabilidad:
  - Thanos collector para ~30 clusters managed
  - Métricas retention: 30 días local, 6 meses objeto storage
  - Dashboard central para compliance reporting

Governance:
  - ACM Policy distribution a todos managed clusters
  - Compliance reporting automático para auditorías
  - Application lifecycle management para 2,000+ aplicaciones

Security:
  - Usuario local 'admin' para break-glass scenarios
  - Usuarios AD con roles específicos: 
    * acm-viewer: solo lectura
    * acm-operator: gestión clusters
    * acm-admin: governance policies
  - Rotación tokens automática cada 8 horas
```

#### Cluster de Servicios Compartidos
**Sizing Detallado**:
```yaml
Configuración Base:
  Masters: 3 nodos (16 vCPU, 32GB RAM)
  Infra: 3 nodos dedicados (ingress, monitoreo)
  Workers: 6-9 nodos según carga
  ODF: 3 nodos dedicados (500GB SSD por nodo mínimo)

Servicios Consolidados:
  Storage (ODF):
    - Object Storage: buckets para backups, logs, métricas
    - Block Storage: PVs para todos clusters aplicativos
    - File Storage: RWX para aplicaciones legacy
    
  Observabilidad:
    - Prometheus: 90 días retention, 2TB storage proyectado
    - Grafana: dashboards organizacionales + por squad
    - Loki: logs centralizados, 30 días retention
    - Tempo: tracing distribuido, 7 días retention
    
  Security & Governance:
    - HashiCorp Vault: secretos para ~450 proyectos productivos
    - Policy engines: Gatekeeper/OPA policies
    - Certificate management: cert-manager + CA interna
    
  DevOps Tools:
    - ArgoCD central: hub para 4 instancias por cluster
    - Container Registry: Quay enterprise con geo-replication
    - CI/CD Tools: Jenkins especializado jobs infraestructura
```

#### Clusters Aplicativos Especializados
**Topología por Criticidad**:

**Cluster Crítico (Tier 1)**:
```yaml
Workloads: Login, APIs core bancarias, pagos
Hardware: 
  - Masters: 3x (16 vCPU, 64GB RAM)
  - Infra: 6 nodos (HA cross-site) 
  - Workers: 20-30 nodos (escalable)
SLA: 99.95% uptime
Network: Dedicated VLAN, múltiples ingress
Storage: Sin ODF local, consume del cluster servicios
```

**Cluster Estándar (Tier 2)**:
```yaml
Workloads: APIs negocio, BFFs, microservicios estándar
Hardware:
  - Masters: 3x (8 vCPU, 32GB RAM)  
  - Infra: 3 nodos
  - Workers: 10-20 nodos (auto-scaling)
SLA: 99.9% uptime
Network: Shared VLAN con QoS
Storage: Cache distribuido, sin persistencia crítica
```

**Clusters Especializados**:
```yaml
GPU/AI Cluster:
  - GPU Nodes: 7 workers con A100 cards
  - Total GPUs: 11 unidades (10 prod + 1 backup)  
  - Use Case: Cloud Pak for Data, ML training
  - Timeline: Fin agosto 2026

Batch Processing:
  - Nodos dedicados con node selector
  - Jobs nativos Kubernetes vs pods standby
  - Control-M integration para scheduling
  - Lifecycle: pods destruidos post-ejecución
```

---

## 4. Red Hat ACM - Configuración Detallada

### Hub-and-Spoke Architecture Específica

**ACM Hub Configuration**:
```yaml
Managed Clusters Expected: 6-8 inicialmente, 30+ futuro
Application Sets: 
  - Por ambiente: dev, staging, prod
  - Por función: aplicaciones, infraestructura, seguridad
  - Por criticidad: tier1, tier2, tier3

Placement Rules:
  cluster-tier: critical, standard, development
  cluster-site: pga, matriz, aws (futuro)
  cluster-function: apps, services, batch, gpu

Policy Distribution:
  - Network policies por namespace
  - Resource quotas por equipo
  - Security contexts obligatorios
  - Compliance (RBAC, certificates, encryption)
```

**GitOps Multi-Repository Pattern**:
```yaml
Repository Structure:
├── cluster-management/
│   ├── placement-rules/
│   │   ├── production/
│   │   ├── staging/
│   │   └── development/
│   ├── policies/
│   │   ├── security/
│   │   ├── networking/
│   │   └── resource-management/
│   └── applications-sets/
├── platform-config/
│   ├── operators/
│   ├── infrastructure/
│   └── day2-config/
└── applications/
    ├── namespace-per-team/
    ├── shared-services/
    └── middleware/

Synchronization Strategy:
  - Placement repository: única fuente verdad
  - Operators cluster detectan cambios automáticamente
  - Cross-repository consistency via admission controllers
```

### ArgoCD Distributed Model
**4 Instancias por Cluster**:
```yaml
ArgoCD-Infra (Platform Team):
  - Namespace: openshift-gitops-infra  
  - Scope: Day-2 cluster configuration, operators
  - Repositories: platform-config, infrastructure
  - Permissions: cluster-admin (controlado)

ArgoCD-RBAC (Security Team):
  - Namespace: openshift-gitops-rbac
  - Scope: Security policies, network policies, RBAC
  - Repositories: rbac-ops, security-policies  
  - Permissions: security-admin custom role

ArgoCD-Applications (DevOps Teams):
  - Namespace: openshift-gitops-apps
  - Scope: Business applications per squad
  - Repositories: applications per team
  - Permissions: namespace-admin per team

ArgoCD-Middleware (Platform Team):  
  - Namespace: openshift-gitops-middleware
  - Scope: API Manager, Service Mesh, shared middleware
  - Repositories: middleware-config
  - Permissions: middleware-admin custom role
```

---

## 7. Networking y Service Mesh - Implementación Técnica

### Análisis Detallado Hair-pinning Problem

**Current Flow Ineficiente**:
```
Request Path Actual:
Microservice A (namespace-1) 
  → kube-proxy nodo
  → SDN cluster  
  → consulta Infoblox DNS
  → F5 Load Balancer (external)
  → SDN cluster (re-entry)
  → kube-proxy nodo destino
  → Microservice B (namespace-2)

Total Hops: 7 hops
Latency Added: ~15-25ms per call  
Failure Points: 4 (DNS, F5, 2x SDN)
```

**Optimized Flow con Service Mesh**:
```  
Request Path Optimized:
Microservice A (namespace-1)
  → Z-tunnel (ambient mesh)
  → Microservice B (namespace-2)

Total Hops: 2 hops
Latency Added: ~2-5ms per call
Failure Points: 1 (mesh dataplane)
```

### Istio Ambient Mesh - Especificaciones Técnicas

**Componentes Deployment**:
```yaml
Z-tunnel (DaemonSet):
  - Deployment: 1 per node (120 nodos = 120 instancias)
  - Function: Layer 4 TCP/UDP proxy + mTLS
  - Resources: 100m CPU, 128Mi RAM per instance
  - Network: eBPF hooks para packet capture

Waypoint Proxies (Deployment):
  - Deployment: 1 per namespace requiring L7 features
  - Function: HTTP routing, authn/authz, rate limiting  
  - Resources: 500m CPU, 512Mi RAM per instance
  - Scaling: HPA based on request volume

East-West Gateways:
  - Deployment: 2 per cluster (HA pair)
  - Function: Inter-cluster communication
  - Resources: 2 CPU, 4GB RAM per instance
  - Network: Dedicated VLAN for cluster-to-cluster traffic
```

**Service Discovery Global**:
```yaml
Control Plane Federation:
  - Istio control planes federados cross-cluster
  - Service registry compartido via east-west gateway
  - DNS resolution: service.namespace.local automatically resolved
  - Failover: health checks + automatic endpoint removal

Authorization Policies:
  kind: AuthorizationPolicy
  metadata:
    name: microservice-access
    namespace: production
  spec:
    selector:
      matchLabels:
        app: payment-service
    rules:
    - from:
      - source:
          namespaces: ["frontend", "bff"]
      to:
      - operation:
          methods: ["GET", "POST"]
          paths: ["/api/v1/payments/*"]
```

### Network Policies Multi-Cluster
**Current Implementation**:
```yaml
Baseline Security:
  - Todo tráfico inbound bloqueado por defecto
  - Comunicación intra-namespace permitida
  - Políticas específicas para inter-namespace communication
  - Sin políticas egress (tráfico sale con IP del nodo)

Required Policies per Namespace:
  - PIMS connectivity
  - Kubernetes API access  
  - Monitoring integration (Prometheus, Alloy)
  - Ingress controller access
```

**Proposed GitOps Model**:
```yaml
Repository: network-policies-ops
Structure:
├── clusters/
│   ├── cluster-critical/
│   │   ├── namespace-a/
│   │   │   └── network-policies.yaml
│   │   └── namespace-b/
│   └── cluster-standard/
└── global-policies/
    ├── base-security.yaml
    ├── monitoring-access.yaml
    └── dns-access.yaml

Process:
  1. Team creates PR with new network policy
  2. Security team reviews + approves
  3. ArgoCD-RBAC applies automatically
  4. Audit trail maintained in Git history
```

---

## 8. API Gateway - Evaluación Técnica Detallada

### Vendor Evaluation Matrix Completa

#### Solo.io Gloo - Technical Deep Dive

**Architecture**:
```yaml
Control Plane (Gloo Management):
  - Location: Kubernetes cluster or SaaS
  - Function: Configuration management, observability
  - Database: PostgreSQL for persistence
  - API: GraphQL + REST for management

Data Plane (Gloo Gateway):  
  - Deployment: Per cluster, multiple instances
  - Technology: Envoy proxy customizado
  - Configuration: Pull from control plane
  - Persistence: Local config backup para offline operation
```

**Multi-Cluster Capabilities**:
```yaml
Hub-and-Spoke Support:
  ✅ Centralized control plane
  ✅ Distributed data planes  
  ✅ Configuration replication
  ❌ Single portal across clusters (limitation crítica)

Portal Limitations:
  - Each portal requires separate database
  - Subscriptions stored in databases (no CRDs)  
  - Multi-cluster subscriptions require custom development
  - Developer shouldn't know which cluster to subscribe to
```

**Pricing Analysis**:
```yaml
Annual Cost: $583,085 (Gateway + Mesh bundle)
Breakdown:
  - Gateway: $205,000 (6B API calls + 12 clusters)
  - Mesh: $378,085 (26 clusters + 4,000 vCPU)
  - Enterprise Support: Included (1hr SLA, 24x7, Slack dedicado)

Cost Benefits:
  - 20.98% discount con 3-year contract
  - Ramp-up pricing available (start lower first year)
  - East-west traffic no charged (mesh handles internally)
```

#### Kong Enterprise - Análisis Técnico

**Deployment Models**:
```yaml
Hybrid Model (Recomendado):
  - Control Plane: Kong Cloud (36 regions)
  - Data Plane: On-premise Kubernetes
  - Communication: Secure WebSocket (data plane initiated)
  - Offline Capability: Data plane funciona independently

On-Premise Complete:
  - Control Plane: PostgreSQL + Kong Manager
  - Data Plane: Kong Gateway instances  
  - Management: Customer responsibility (upgrades, backups)
```

**Scalability Limits**:
```yaml
Version Constraints:
  - Kong 3.x: 1000 services/routes limit per control plane
  - Kong 4.x+: Incremental updates, sin límites hard
  
Recommended Architecture:
  - Federated approach: 1 control plane per business unit
  - Multiple data planes per control plane
  - Reference: Bradesco with hundreds of gateways
```

**Integration Capabilities**:
```yaml
Native Features:
  - 90+ plugins (Canary, Circuit Breaker, Rate Limiting)
  - Service Mesh: Kong Mesh (sidecar model)
  - RBAC: Granular via Admin API
  - Portal: Developer portal con branded catalogs
  
Limitations:
  - No direct F5/Infoblox integration
  - Manual load balancer configuration required
  - Complex pricing model per API call
```

#### Red Hat Connectivity Link - Assessment

**Technical Advantages**:
```yaml
Performance:
  - 4x more efficient than 3Scale (same resources)
  - No hard route limits (vs 3Scale's 500)
  - Built on Envoy (same as Service Mesh)
  
High Availability:
  - Active-active deployment across clusters
  - DNS policy automatic failover
  - Zero downtime demonstrated
  - Hub-and-spoke configuration replication
```

**Migration Benefits**:
```yaml
3Scale Migration:
  - Tool converts 3Scale configs to Connectivity Link
  - Success rate: 6-7 of 10 cases (target: 9-10)
  - Side-by-side migration approach
  - Red Hat discount program (Q4 2025)

Enterprise Features:
  - Multi-cluster management console
  - Advanced middleware (transformations, security)  
  - CEL expressions for routing policies
  - Integration with Keycloak, multiple auth providers
```

**Limitations Identified**:
```yaml
Product Maturity:
  - Relatively new product (limited production history)
  - Limited to infrastructure traffic vs full API management
  - Cannot map external APIs as internal (critical limitation)
  - Primarily north-south focus, limited east-west capabilities
```

### Recommended Strategy

**Phase 1: Service Mesh First**:
```yaml
Rationale:
  - 80% traffic is east-west (internal)
  - Service mesh solves hair-pinning immediately  
  - 3Scale can remain for external APIs during transition
  - Lower risk, immediate performance benefits

Implementation:
  - Istio Ambient Mesh for east-west traffic
  - Keep 3Scale temporarily for north-south
  - Authorization policies replace API key authentication gradually
```

**Phase 2: Gateway Selection**:
```yaml
Decision Timeline: Post service mesh implementation
Leading Candidates:
  1. Solo.io Gloo (if multi-cluster portal resolved)
  2. Kong (if pricing model acceptable)
  3. Red Hat Connectivity Link (if maturity concerns addressed)

Evaluation Criteria:
  - Multi-cluster portal capability
  - Fixed vs per-call pricing for internal traffic
  - Migration effort from 3Scale
  - LATAM support capabilities
```

---

## 10. Observabilidad - Implementación eBPF Detallada

### Current Observability Gaps Analysis

**Blind Spots Identificados**:
```yaml
API Management Layer:
  - 3Scale acts as trace firewall
  - End-to-end correlation impossible
  - Request: DMZ → APIM → multiple APIs (traces split)
  - Development simulates with test cases (no production visibility)

Application Layer:
  - AppDynamics limited to application performance  
  - No infrastructure correlation
  - Missing HTTP request/response details
  - No service map generation capability

Infrastructure Layer:
  - HAProxy metrics disabled (resource limits)
  - Limited ingress controller observability
  - No network-level visibility inter-namespace communication
```

### eBPF Solution Architecture

**Cilium/Hubble Approach**:
```yaml
Technology: eBPF kernel-level tracing
Deployment:
  - Cilium CNI replacement for OVN-Kubernetes
  - Hubble collectors per node
  - Central Hubble UI for visualization

Capabilities:
  - Network policies Layer 7 (HTTP, gRPC, Kafka)
  - Service maps automatic generation  
  - Flow logs kernel-level capture
  - Performance metrics without application instrumentation
```

**Coroot POC Results**:
```yaml  
Implementation: Certified OpenShift operator
Capabilities Demonstrated:
  - Complete service map of cluster
  - Auto-discovery of all services and dependencies
  - Performance bottleneck identification  
  - No application code changes required

Concerns Identified:
  - Russian origin (security/compliance concern)
  - SaaS dashboards dependency  
  - Limited customization options
```

### Grafana Cloud Implementation Detail

**Current Metrics Volume**:
```yaml
Contract Details:
  - 3-year FlexSet Spread and Commit
  - 700 users/month (8,400 annual)  
  - 110TB average monthly (1,320 annual)
  - Metrics: ~1.7M series active

Cost Analysis:
  - Metrics: 0.15% contract per million series
  - Current: 2.5% allowance mensual
  - 93% total spend on metrics vs logs/traces
  - Since October: ~12-13% contract utilization
```

**Architecture Implemented**:
```yaml
Collection Pipeline:
  Alloy (per namespace) → Kafka topic → Grafana Cloud
  
Challenges:
  - Kafka scalability: 600+ connections projected (300 namespaces x2)  
  - Performance impact concerns
  - Permission issues development environment

Alternative Architectures:
  - Direct push vs pull models
  - OpenTelemetry SDK complete adoption
  - Correlation metrics-traces automatic
```

**Custom Metrics Implementation**:
```yaml
Current State: Grafana Cloud deployment complete
Architecture: 
  - Alloy collector per namespace or per node
  - Kafka buffer for reliability  
  - Prometheus metrics format converted OpenTelemetry

Challenges Identified:
  - Resistance from DevOps teams (preferred AppDynamics)
  - Kafka overhead concerns
  - Permission issues in higher environments
  - Cultural change management required
```

---

## 11. HashiCorp Vault - Configuración Técnica

### Architecture Options Evaluated

**Vault Secrets Operator (VSO)**:
```yaml
Architecture:
  - Kubernetes operator maps Vault secrets → K8s secrets
  - Secrets stored in ETCD (base64 encoded, not encrypted)
  - Applications consume via standard secret mounts
  - Transparent to existing applications

Benefits:
  - No application changes required
  - Uses existing secret consumption patterns
  - Lower infrastructure overhead
  - Compatible with current DevOps pipelines

Drawbacks:
  - Secrets persist in ETCD (security concern)
  - Limited audit trail from platform perspective
  - Any user with API/ETCD access can read secrets
```

**Vault Agent Injector**:
```yaml
Architecture:
  - Sidecar/init container per pod
  - Applications authenticate directly with Vault
  - Secrets delivered via shared memory volume
  - No persistence in Kubernetes ETCD

Benefits:
  - Enhanced audit trail (Vault logs all access)
  - Secrets never persist in cluster storage
  - Token TTL and usage limits configurable
  - Fine-grained access control per application

Drawbacks:
  - Requires annotation changes in all deployments
  - Infrastructure overhead (~22k containers vs 11.5k current)
  - Application changes may be required
  - Complexity in troubleshooting
```

### Sizing and Licensing

**HashiCorp Vault Pricing**:
```yaml
License Model: Per client/consumer
Breakdown Estimation:
  - Production: ~450 namespaces × service accounts = ~450 licenses
  - Non-Production: Free (dev, testing, QA environments)
  - Total Cost: $60,000 USD/month per 500 licenses

Comparison with Competitors:
  - HashiCorp: $684,903 vs $173,982 for clusters
  - ~20% more expensive than alternatives
  - Enterprise features justify cost differential
```

**Akeyless Alternative**:
```yaml
Licensing: No environment differentiation
  - All dev, test, QA, prod counted as single pool
  - Significant cost impact: ~700 prod + ~1000 OpenShift users
  - Platinum license: 6,000 requests/day limit

Gateway Architecture:
  - Stateless, lightweight design
  - Multiple deployment for HA (no leader election)
  - Three caching modes: proxy, active, proactive
  - Supports Docker/Podman installation OpenShift
```

### Implementation Strategy

**POC Approach**:
```yaml
Timeline: 2 weeks total
  - Week 1: VSO method evaluation
  - Week 2: Vault Agent method evaluation
  
Test Cases:
  - Existing application secret migration
  - Service account authentication
  - Secret rotation and lifecycle
  - Multi-cluster secret sync
  - Disaster recovery scenarios
```

**Production Architecture**:
```yaml
SaaS + Proxy Model:
  - HashiCorp Cloud Platform primary
  - On-premise proxy per cluster (outbound only)
  - Port 8200 communication to Vault Cloud
  - VM deployment for proxy (outside OpenShift initially)

Security Requirements Met:
  - No inbound connectivity required
  - TTL tokens with usage limits
  - Service account authentication (K8s native)
  - Audit logging centralized
  - Secrets encrypted in transit and at rest
```

---

## 14. Automation - Terraform/Ansible Implementation Details

### F5 Load Balancer Automation

**Complete Automation Achieved**:
```yaml
Development Time: 2 hours using Cursor AI
Components Automated:
  1. Virtual Server creation (API, Ingress, Generic types)
  2. Pool configuration with backend nodes  
  3. Monitor creation (TCP, HTTP health checks)
  4. Automatic cleanup (proper deletion order)

Technical Implementation:
  - Ansible roles with F5 modules
  - Variables: VIP, node IPs, service type, ports
  - Health checks: HTTP GET to /healthz, /readyz endpoints
  - Error handling and rollback procedures
```

**Three Virtual Server Types**:
```yaml
1. API Kubernetes:
   - Port: 6443
   - Backend: Master nodes
   - Monitor: HTTP GET /healthz (expect "true")
   - Pool: Round-robin algorithm

2. Ingress (Apps):  
   - Ports: 80, 443
   - Backend: Infrastructure nodes
   - Monitor: TCP health check port 8443
   - Pool: Least connections algorithm

3. Generic Gateway:
   - Ports: NodePort range (30000-32767)
   - Backend: Worker nodes  
   - Monitor: TCP port-specific
   - Pool: Based on service requirements
```

### Terraform Cloud Integration

**Infrastructure as Code Pipeline**:
```yaml
Trigger Mechanism:
  - Git repository commit triggers Terraform Cloud
  - install-config.yaml + terraform.tfvars input
  - ACM polls Terraform state for cluster readiness
  
Components Managed:
  - OpenShift cluster lifecycle (IPI deployment)
  - DNS records creation (A, CNAME, reverse)  
  - Load balancer configuration via F5 API
  - Network automation (VLAN assignment, routing)
  
Integration Points:
  - vCenter API for VM management
  - Infoblox API for DNS automation  
  - F5 API for load balancer config
  - ACM API for cluster registration
```

**Cluster Configuration Template**:
```yaml
Standard Cluster Specification:
  Masters: 3 nodes (32GB RAM, 16 cores)
  Workers: 3 nodes initial (8 vCPU, 32GB RAM)  
  Infra: 3 nodes (dedicated ingress, monitoring)
  
Network Configuration:
  Machine Network: /25 (supports 126 nodes)
  Pod Network: /16 
  Service Network: /16
  API VIP: .1 of machine network
  Ingress VIP: .2 of machine network
  
DNS Requirements:
  - api.{cluster-name}.bancogalicia.com.ar
  - *.apps.{cluster-name}.bancogalicia.com.ar  
  - Reverse DNS for all node IPs
```

### Network Automation Strategy

**Pre-provisioning Approach**:
```yaml
Problem Statement:
  - 3 weeks delay per network request
  - No standardized process for network creation
  - Manual coordination required with multiple teams
  
Solution:
  - Pre-provision network segments for 30 clusters
  - Batch processing vs individual requests
  - Standard architecture per cluster type
  - Automated IPAM integration when available
```

**F5 GTM Integration**:
```yaml
Multi-Cluster DNS Management:
  - GTM manages routing DNS automatic  
  - APIs can reside multiple clusters (active-active)
  - Health checks: GTM supervises clusters, F5 supervises node pools
  - External DNS operator integration with F5 GTM (custom development required)
```

---

## 15. Detailed Risk Analysis & Mitigation

### Technical Risks

**Hardware and Infrastructure**:
```yaml
Risk: Hardware Constraints Critical Path
Details:
  - Current: 8-year-old hardware, incompatible with new
  - Required: 14 new BMware servers by March 2026  
  - Strategy: New cluster → migrate workloads → retire old
  - Backup plan: Optimize existing resources via scheduling policies

Timeline Risk:
  - Hardware delivery delays impact entire roadmap
  - Dependencies: Network configuration, storage provisioning
  - Mitigation: Parallel workstreams, alternative vendors
```

**Migration Complexity**:
```yaml
Risk: SDN to OVN Migration Required  
Details:
  - Requires 2-3 cluster restarts
  - High risk of complete failure → full rebuild
  - Downtime window: Extended maintenance required
  
Mitigation Strategy:
  - Use as leverage for other deliveries
  - Coordinate with DRP testing
  - Practice in non-production first
  - Rollback plan to current SDN
```

### Organizational Risks

**Skills and Knowledge**:
```yaml
Risk: Team Expertise Gaps
Current Challenges:
  - Platform team: 95% time on incidents vs development
  - Limited experience with service mesh technologies  
  - No dedicated PM for coordination between teams
  - Vendor dependencies for complex implementations

Mitigation:
  - Training program for ambient mesh technologies
  - Dedicated PM assignment for multicluster project  
  - Knowledge transfer from vendors during POC phase
  - Documentation and runbooks for all procedures
```

**Cultural Resistance**:
```yaml
Risk: Organizational Change Resistance
Evidence:
  - DevOps team resistance to new observability stack
  - Security team 8 months to resolve RBAC issues
  - Multiple teams preferred existing solutions over new architecture
  
Mitigation:
  - Executive sponsorship from Diego/Germán level
  - Gradual adoption vs big-bang approach
  - Success metrics and business case communication
  - Include team members in design decisions
```

### Operational Risks

**Service Continuity**:
```yaml
Risk: Service Disruption During Migration
Critical Services:
  - 90% bank business runs on OpenShift platform  
  - APIs handle core banking transactions
  - DRP testing March 2026 (non-negotiable)
  
Mitigation Strategy:
  - Parallel deployment approach (new clusters + existing)
  - Blue-green migration at application level
  - Automated rollback procedures
  - Extensive testing in lower environments
  - 24x7 support during migration windows
```

### Technical Debt Risks

**Application Architecture**:
```yaml
Risk: Legacy Application Dependencies
Issues:
  - Applications not truly stateless
  - Hard-coded dependencies on specific infrastructure
  - Batch processes require completion in same po