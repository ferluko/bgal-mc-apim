# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---
## 4. Decisiones Técnicas y Arquitectónicas

### Decisión 1: Service Mesh Sidecarless (Ambient Mesh) + API Gateway

**Decisión:** Implementar **Service Mesh Sidecarless (Ambient Mesh) + API Gateway** como solución principal.

**Justificación técnica:**
- **Service mesh sidecarless:** Elimina overhead operativo y complejidad de gestión vs sidecars tradicionales
- **Service mesh multiclúster nativo:** Elimina hair-pinning mediante comunicación directa pod-a-pod
- **Arquitectura basada en Envoy/Istio:** Alineada con estándares de la industria y evolución Kubernetes
- **Modelo de pricing fijo:** Evita explosión de costos por volumen de tráfico interno
- **Base open source:** Istio/Envoy evita vendor lock-in completo

**Candidatos en Evaluación:**
- **Gloo Mesh (Solo.io):** Service mesh ambient multiclúster, integración natural con Gloo Gateway, fixed pricing negociable
- **RHOSM (Red Hat):** Integración nativa OpenShift, continuidad Red Hat, POC solicitada
- **Cilium Cluster Mesh (Isovalent/Cisco):** Networking eBPF avanzado, certificado Red Hat, requiere complemento para L7

**Componentes:**
- **Service Mesh Sidecarless:** Para tráfico East-West (candidato a definir: Gloo Mesh, RHOSM, o Cilium)
- **API Gateway:** Para tráfico North-South y gestión de APIs externas. Candidato a definir. preferencia por Gloo Gateway.

### Decisión 2: Despliegue On-Demand de capacidades avanzadas de L7

**Decisión:** Desplegar **API Gateway on-demand en namespaces que lo requieran**.

**Justificación:**
- No todos los namespaces requieren capacidades de API Gateway
- Reducción de overhead operativo y de recursos
- Modelo de despliegue granular y eficiente
- Permite migración gradual namespace por namespace
- Facilita testing y validación incremental
- Facil instrumentacion
- Gestionado por DevOps teams

**Implementación:**
- Gateway desplegado como operador de Kubernetes o por instrumentacion de Istiod (Waypoints)
- Configuración declarativa por namespace
- Integración con GitOps workflows
- Observabilidad auto instrumentada

### Decisión 3: Arquitectura de 3 Capas para Tráfico North-South

**Decisión:** Implementar arquitectura de **3 capas para tráfico North-South: DMZ → API GW (B2B) → Mesh**.

**Capa 1: DMZ (Demilitarized Zone)**
- **Función:** Punto de entrada externo, protección perimetral
- **Componentes:** F5 load balancers, firewalls, DDoS protection, Proxy Reversos
- **Responsabilidades:**
  - Terminación SSL/TLS inicial
  - Autenticacion contra APIs de 3eros (Partners)
  - Filtrado de tráfico malicioso
  - Rate limiting básico
  - Enrutamiento inicial hacia API Gateway

> **IMPORTANTE**: El proveniente de sistemas Legacy, Core Bancario o cualquier otro componente que consuma APIs alojadas en Openshift se considerar trafico Norte/Sur

**Capa 2: API Gateway (B2B / B2C)**
- **Función:** Gestión de APIs externas a Openshift, autenticación B2B, políticas de negocio
- **Componente:** API Gateway desplegado en namespace dedicado o cluster dedicado (En Analisis)
- **Responsabilidades:**
  - Autenticación y autorización (OAuth2, JWT, mTLS)
  - Rate limiting y throttling por cliente/API
  - Transformación de requests/responses
  - Analytics y observabilidad de APIs externas
  - Developer portal para partners externos
  - Gestión de versionado de APIs
  - Políticas de negocio (quota management, monetización)

**Capa 3: Service Mesh**
- **Función:** Comunicación interna, service-to-service, tráfico East-West
- **Componente:** Istio ambient mesh (Gloo Mesh / RHOSM)
- **Responsabilidades:**
  - Service discovery y routing interno via E/W Gateways
  - mTLS entre servicios
  - Observabilidad end-to-end (tracing, metrics, logs de infra)
  - Políticas de seguridad L4
  - Waypoints on demand para politicas L7
  - Circuit breakers y retry policies
  - Canary deployments y traffic splitting

**Beneficios:**
- **Separación de responsabilidades:** Cada capa tiene un propósito claro
- **Seguridad en profundidad:** Múltiples capas de protección
- **Escalabilidad independiente:** Cada capa escala según necesidad
- **Observabilidad granular:** Métricas y traces por capa
- **Flexibilidad:** Cambios en una capa no afectan otras

### Decisión 4: Multiclúster Activo-Activo

**Decisión:** Implementar arquitectura **multiclúster activo-activo** con failover automático.

**Justificación:**
- Eliminación de RTO manual (4 horas → <1 segundo)
- Distribución de carga entre sitios
- Resiliencia ante fallos de sitio completo
- Sincronización automática de configuraciones

**Implementación:**
- Control plane centralizado (hub-and-spoke)
- Data planes autónomos en cada cluster
- Sincronización declarativa vía GitOps
- Failover automático basado en health checks
- DNS automático para routing

### Decisión 5: Separación de Responsabilidades L4/L7 en Service Mesh

**Decisión:** La plataforma provee capacidades completas de capa 4 (L4) de forma centralizada, mientras que las capacidades avanzadas de capa 7 (L7) serán instrumentadas por DevOps según necesidad específica.

**Justificación:**
- Reduce complejidad operativa eliminando la implementacion dentro de la aplicación
- Permite adopción gradual de funcionalidades avanzadas
- Minimiza overhead de infraestructura
- Delega control granular a equipos que mejor conocen sus aplicaciones
- Mantiene rendimiento óptimo para servicios que no requieren L7

**Implementación:**
- **Plataforma (L4):** Agente por nodo manejando conectibidad TCP/UDP, mTLS automático, service discovery global, comunicación inter-cluster
- **DevOps (L7):** Proxys por namespace para HTTP routing, autenticación específica, rate limiting, canary deployment, circuit breakers
- **Control:** Plataforma gestiona conectividad base, DevOps instrumenta políticas de aplicación
- **Escalabilidad:** Modelo "a pedido" - solo despliega L7 donde es necesario

### Decisión 6: Gobierno de APIs mediante Políticas Nativas del Service Mesh

**Decisión:** Mantener el gobierno de APIs (control de quién consume qué) utilizando authentication policies nativas del service mesh, eliminando network policies restrictivas y aprovechando la observabilidad completa integrada.

**Justificación:**
- Eliminación del hair-pinning actual (evitar modificar el flujo/trafico para autenticar comunicaciones internas entre servicios)
- Observabilidad end-to-end nativa vs trazas cortadas por API gateway
- Políticas declarativas replicadas automáticamente entre clusters
- Autenticación a nivel de identidades de k8s (ej: service account) vs API keys estáticas
- Reducción de latencia eliminando saltos innecesarios por load balancer

**Implementación:**
- **Authentication Policies:** Basadas en service accounts por namespace, eliminando API keys estáticas
- **Suscripción declarativa por CRD:** Trazabilidad por git y de fácil integración con actual proceso de suscripción
- **Observabilidad Nativa:** Métricas L4/L7, mapeo de servicios con eBPF, análisis estacional de tráfico
- **Políticas Globales:** Control planes federados distribuyendo authorization policies a todos los clusters
- **Service Discovery:** Comunicación directa intra-cluster eliminando dependencia del DNS corporativo
- **Auditoría:** Trazabilidad completa de suscripciones y accesos por namespace

### Decisión 7: Fixed Pricing como Requisito

**Decisión:** **Fixed pricing** es requisito no negociable para tráfico interno.

**Justificación:**
- 7.5B requests/mes hacen inviable pricing por API call
- Costos predecibles para planificación financiera
- Sin penalización por crecimiento orgánico
- Sostenibilidad a largo plazo

**Negociación:**
- Fixed pricing para tráfico East-West (interno)
- Pricing negociable para tráfico North-South (externo)
- Modelo híbrido aceptable si se mantiene predictibilidad

### Decisión 8: Kubernetes Gateway API como Estándar

**Decisión:** **Soporte nativo para Kubernetes Gateway API** es must-have.

**Justificación:**
- Estándar emergente de la industria
- Evita vendor lock-in
- Facilita portabilidad entre entornos
- Permite separación de roles (infra vs developers)

**Implementación:**
- Todas las rutas definidas usando Gateway API CRDs
- Compatibilidad con estándar Gateway API v1.2+
- Integración con ecosistemas cloud native

### Decisión 9: Declarative Configuration (GitOps)

**Decisión:** Toda la configuración debe ser **declarativa y gestionada vía GitOps**.

**Justificación:**
- Versionado y auditoría de cambios
- Sincronización automática entre sitios
- Rollback automatizado
- Eliminación de drift de configuración

**Implementación:**
- CRDs para todas las configuraciones
- GitOps workflows (ArgoCD)
- CI/CD pipelines para validación
- Automated testing de configuraciones

### Decisión 10: Service Mesh Sidecarless (Ambient Mesh)

**Decisión:** Implementar **service mesh sidecarless (ambient mesh)** en lugar de sidecar mesh tradicional.

**Justificación:**
- Reducción de overhead operativo (no requiere sidecars por pod)
- Menor consumo de recursos (waypoint proxies compartidos)
- Simplificación de gestión y despliegues
- Mantiene capacidades de service mesh (mTLS, observabilidad, políticas L7)
- Compatibilidad con aplicaciones legacy sin instrumentación

**Implementación:**
- Ambient mesh como arquitectura base (Istio ambient mesh o equivalente)
- Waypoint proxies para workloads que requieren políticas L7
- Zero-trust networking sin sidecars para tráfico básico
- **Candidatos:** Gloo Mesh, RHOSM ambient mesh, o Cilium Cluster Mesh

---


[← Volver al Índice](00_indice.md)
