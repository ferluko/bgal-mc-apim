# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---
## 5. Arquitectura Objetivo

### 5.1 Resumen Ejecutivo

Transformación desde cluster monolítico con 3scale hacia **arquitectura multiclúster activo-activo** con separación clara de responsabilidades:

**Componentes Principales:**
- **Service Mesh Sidecarless (Cilium Mesh Enterprise):** Tráfico interno East-West (7.5B requests/mes), comunicación directa pod-a-pod eliminando hair-pinning
- **API Gateway:** Tráfico externo North-South de Openshift, arquitectura de 3 capas (DMZ/Core/Legacy → API Gateway → Mesh)
- **Separación L4/L7:** Plataforma gestiona conectividad base (L4), DevOps instrumenta políticas avanzadas (L7) on-demand
- **Gobierno nativo:** Políticas del service mesh basadas en identidades Kubernetes vs API keys estáticas

**Beneficios Clave:**
- Eliminación de hair-pinning (reducción notable de latencia)
- Observabilidad end-to-end con eBPF vs trazas cortadas dificil de armar el e2e
- Failover automático sub-segundo vs 4 horas manual
- Configuración declarativa GitOps vs procesos manuales
- Autenticación moderna (mTLS, OAuth2/JWT) vs API keys estáticas

**Estado:** Arquitectura definida y stack East-West cerrado en Cilium Mesh Enterprise tras PoCs multiclúster.

### 5.2 Visión General

```text
┌──────────────────────────────────────────────────────────────--───┐
│                        TRÁFICO NORTH-SOUTH                        │
│                                                                   │
│  Internet                                                         │
│    │                                                              │
│    ▼                                                              │
│  ┌─────┐                  ┌────────┐                              │
│  │ DMZ │  (F5, Firewalls, │ Other  │  (Core Banking,              |
│  └─────┘  DDoS Protection)└────────┘  Sistemas Legados)           │
│    │                         |                                    │
│    ▼                         ▼                                    │
│  ┌─────────────────────-------─┐                                  │
│  │ API Gateway (B2B/B2C)       │  (API GW Layer -                 │
│  │       - OAuth2/JWT          │      cluster dedicado)           │
│  │       - Rate Limiting       │                                  │
│  │       - API Versioning      │                                  │
│  │       - Developer Portal    │                                  │
│  └─────────────────────-------─┘                                  │
│    │                       ▼                                      │
│    ▼                     Backend Services (NO OCP)                │
│  ┌──────────────────────┐                                         │
│  │   Service Mesh       │  (Sidecarless/Cilium Mesh)              │
│  │   - mTLS             │                                         │
│  │   - Observability    │                                         │
│  │   - L7 Policies      │                                         │
│  └──────────────────────┘                                         │
│    │                                                              │
│    ▼                                                              │
│  Backend Services (Microservices on OCP)                          │
└───────────────────────────────────────────────────────────────--──┘

┌────────────────────────────────────────────────────────────────--─┐
│                        TRÁFICO EAST-WEST                          │
│                                                                   │
│  Service A (Namespace 1)                                          │
│    │                                                              │
│    ▼                                                              │
│  ┌──────────────────────┐                                         │
│  │   Service Mesh       │  (Sidecarless - Direct Pod-to-Pod)      │
│  │   - No Hair-pinning  │                                         │
│  │   - mTLS             │                                         │
│  │   - Service Discovery│                                         │
│  └──────────────────────┘                                         │
│    │                                                              │
│    ▼                                                              │
│  Service B (Namespace 2)                                          │
└───────────────────────────────────────────────────────────────--──┘
```

### 5.3 Componentes Clave

#### A. Control Plane Centralizado

**API Gateway Management Plane:**
- Gestión centralizada de múltiples clusters
- Sincronización de políticas y configuraciones
- Observabilidad agregada
- Puede estar en nube pública (SaaS) o on-premise

**Características:**
- Hub-and-spoke model
- Data planes autónomos (funcionan sin control plane)
- Sincronización declarativa
- Multi-tenancy support

#### B. Data Planes Distribuidos

**Por Cluster/Sitio:**
- Service Mesh Sidecarless data plane (Cilium Mesh Enterprise)
- Componentes L7 on-demand por namespace cuando aplique
- East-West Gateway (east-west gw)

**Características:**
- Autónomos (funcionan sin control plane)
- Sincronización automática desde unica fuente de verdad
- Health checks y failover automático
- Observabilidad local y centralizada

#### C. Despliegue On-Demand de API Gateways

**Modelo:**
- Gateway desplegado solo en namespaces que lo requieren
- Configuración declarativa por namespace
- Integración con GitOps
- Facil instrumentacion
- Integración con la Mesh

**Namespaces típicos que requieren Gateway:**
- APIs expuestas hacia afuera de Openshift que requieran alguna autenticacion adicional, rate limits, manejo avanzado de header, etc
- Partner integrations
- Public APIs
- Terminacion mTLS

#### D. Integración con Infraestructura Existente

**F5 Load Balancers:**
- Terminación SSL/TLS inicial
- Enrutamiento hacia API Gateway
- Health checks

**OpenShift:**
- Certificación y compatibilidad nativa
- Integración con operadores de Kubernetes
- Network policies
- Service accounts y RBAC

**DNS:**
- Automatización de updates DNS corporativo
- Failover automático de DNS
- Multi-site routing

### Separación de Tráfico

#### 5.4 Tráfico North-South (Externo)

**Flujo:**
1. Internet → DMZ (F5/ Core / Legacy)
2. DMZ → Capa APIM/API Gateway robusta (Gloo o Kong, segun dominio/fase)
3. API Gateway → Service Mesh (Sidecarless)
4. Service Mesh → Backend Services

**Características:**
- Autenticación OAuth2/JWT
- Rate limiting por cliente/API
- Analytics y observabilidad
- Developer portal
- API versioning

#### Tráfico East-West (Interno)

**Flujo:**
1. Service A → Service Mesh (Cilium Mesh)
2. Service Mesh → Service B (direct pod-to-pod)

**Características:**
- Sin hair-pinning
- mTLS automático
- Service discovery
- Observabilidad end-to-end
- L7 policies (opcional, con componentes dedicados por namespace)

### Alta Disponibilidad y Disaster Recovery

**Arquitectura Multiclúster:**
- **Sitio 1 (Plaza):** Cluster activo
- **Sitio 2 (Matriz):** Cluster activo
- **Modo:** Activo-activo con distribución de carga

**Failover Automático:**
- Health checks continuos
- Failover automático sub-segundo
- DNS automático
- Sin intervención manual

**Sincronización:**
- Configuraciones declarativas (GitOps)
- Sincronización automática entre sitios
- Sin riesgo de drift
- Rollback automatizado

---


[← Volver al Índice](00_indice.md)
