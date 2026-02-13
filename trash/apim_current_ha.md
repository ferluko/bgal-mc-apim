## Current 3scale Architecture - Banco Galicia

### Infrastructure Configuration
**Monolithic Cluster:**
- 100 nodes, 10,000 pods, 600 namespaces, 2,000 services
- All API traffic flows through 3scale as single layer
- Stretch cluster configuration between two sites (PGA/CMZ)

**Load Balancer Setup:**
- F5 → HAProxy → 3scale in each cluster
- NodePort services (no automatic external IP)
- Network policies force all traffic through 3scale - no direct cross-namespace communication

### Disaster Recovery Architecture
**Independent Dual Deployment:**
- **Two completely independent 3scale instances** - one per site (Plaza/Matriz)
- **Separate databases** for each instance (no shared storage)
- **Manual synchronization** via custom pipelines and automation scripts

**Synchronization Elements:**
- API products and contracts
- Client certificates (currently manual process)
- Custom header rewrite policies  
- Backend endpoints and configurations
- Application credentials and API keys
- ~2,500 applications with multiple endpoints each

**Current DR Limitations:**
- **No declarative capability** - cannot convert to CRDs
- **Manual comparison required** between sites using toolkit
- **Pipeline-based sync** - export/import of configurations
- **Risk of desynchronization** when pipeline fails partially

**DR Strategy Options Evaluated:**
- **Parallel deployment:** simultaneous publication both sites (risk of desync)
- **Sequential deployment:** Matrix first, then Plaza (safer but slower)

### Tenant Structure and Traffic Patterns
**B2C Tenant (East-West):** 80% of traffic
- 7.5 billion requests/month - internal OpenShift APIs
- Communication between microservices in different namespaces
- Hair-pinning pattern: exit cluster → load balancer → re-enter

**B2B Tenant (North-South):** 20% of traffic
- 500 million requests/month - external/third-party APIs
- External partners using mutual TLS
- Mobile/office banking

### Service Landscape
**~2,200 APIs in production total:**
- ~1,500 actual internal services
- ~500 batch processing services (no APIs)
- ~200 external API facades/BFF services

**Organization:**
- ~100 development teams, ~1,000 developers
- Three types of API exposure:
  - B2C via Galicia Office (full onboarding)
  - External services (Interbanking, Prisma)
  - Internal services automated via pipelines

### Current Authentication Model
**API Key Authentication (Problematic):**
- Basic headers: API keys/client IDs
- Static tokens without expiration
- Difficult revocation - considered security anti-pattern
- No OAuth2 implementation
- Internal consumption: simplified basic JWT

**Critical Redis Dependency:**
- When 3scale fails → Redis fails → entire bank affected
- Single point of failure

### Core Banking Integration
**Mainframe Dependency:**
- High dependency on mainframe banking core
- Most transactions require multiple hits to banking APIs
- 3scale maps external APIs as internal OpenShift APIs
- SWIFT: dedicated machine with API endpoint permissions in DMZ

### Critical Pain Points for Migration
**Critical Timeline:**
- 3scale end-of-life: mid-2027
- Decision required Q4 2025 for complete 2026 migration

**Technical Issues:**
- Hair-pinning pattern creates latency and bottlenecks
- Broken observability: 3scale acts as "firewall" cutting traces
- 500 route limit (vs 2,200 current APIs)
- Performance bottlenecks with current architecture

**DR-Specific Challenges:**
- **Manual synchronization burden** - complex pipeline maintenance
- **Risk of configuration drift** between sites
- **No automated failover** - manual DNS switching required
- **Complex secrets management** across independent instances
- **Operational overhead** maintaining two separate systems

### Target Architecture Desired
**Traffic Separation:**
- External API Manager: mobile/office banking (north-south)
- Internal API Gateway: intra-namespace/inter-cluster communication (east-west)
- External DNS: automated corporate DNS updates

**DR Requirements for New Solution:**
- **Automated synchronization** between sites
- **Declarative configuration** (Infrastructure as Code)
- **Centralized control plane** with distributed data planes
- **Automatic failover** without manual intervention
- **Unified secrets management** across all instances

### Current Migration Evaluation Status
**Vendors Being Evaluated:**
- Kong: POC deployed, solid architecture, Kubernetes-native
- ConnectivityLink: native OpenShift, federated multicluster
- Traefik: tested but limited enterprise capabilities
- Solo.io/Gloo: currently being evaluated

**Key Requirements for Replacement:**
- Fixed pricing for east-west traffic (not per-API call)
- Native OpenShift/Kubernetes support
- Multicluster architecture with centralized control
- **Automated DR with minimal manual intervention**
- Gradual migration capability from 3scale
- Built on Envoy proxy (market trend)