# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---
## 4. Decisiones Técnicas y Arquitectónicas

### Decisión 1: Service Mesh Sidecarless + API Gateway (Stack Definido)

**Decisión:** Implementar **Service Mesh Sidecarless (Cilium Mesh Enterprise) + API Gateway** como solución principal.

**Justificación técnica:**
- **Service mesh sidecarless:** Elimina overhead operativo y complejidad de gestión vs sidecars tradicionales
- **Service mesh multiclúster nativo:** Elimina hair-pinning mediante comunicación directa pod-a-pod
- **Arquitectura cloud-native abierta:** Basada en estándares Kubernetes (Gateway API), eBPF y componentes open source
- **Modelo de pricing fijo:** Evita explosión de costos por volumen de tráfico interno
- **Riesgo técnico validado en PoC:** Istio Ambient Mesh fue descartado por falla reproducible de conexiones stale cross-cluster tras reciclado de pods
- **Base open source:** Cilium/eBPF + Gateway API minimizan lock-in

**Stack seleccionado:**
- **Service Mesh East-West:** Cilium Mesh (Isovalent Enterprise)
- **API Gateway North-South:** Gloo Gateway (preferencia actual)

**Componentes:**
- **Service Mesh Sidecarless:** Para tráfico East-West (Cilium Mesh Enterprise)
- **API Gateway:** Para tráfico North-South y gestión de APIs externas (preferencia por Gloo Gateway).

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
- Gateway desplegado como operador de Kubernetes en namespaces que requieran capacidades L7 avanzadas
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
- **Componente:** Cilium Mesh (Isovalent Enterprise)
- **Responsabilidades:**
  - Service discovery y routing interno via E/W Gateways
  - mTLS entre servicios
  - Observabilidad end-to-end (tracing, metrics, logs de infra)
  - Políticas de seguridad L4
  - Políticas L7 on-demand mediante componentes dedicados donde aplique
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

### Decisión 10: Descarte de Istio Ambient para East-West y Adopción de Cilium Mesh

**Decisión:** Descartar **Istio Ambient Mesh** para tráfico East-West multiclúster de esta iniciativa y adoptar **Cilium Mesh (Isovalent Enterprise)**.

**Justificación:**
- PoCs reproducibles mostraron cuelgue de tráfico cross-cluster tras reciclado de pod backend remoto
- Causa raíz validada: conexión TCP stale en `ztunnel` hacia IP vieja del endpoint (`:15008` HBONE)
- Reproducido en on-prem y en OpenShift sobre EC2, descartando sesgo de infraestructura
- Workaround existente (reinicio de East-West gateway) no es aceptable como estrategia operativa
- El riesgo de disponibilidad para patrón crítico de negocio es alto

**Implementación:**
- Mantener arquitectura sidecarless y modelo multiclúster activo-activo
- Reemplazar componente East-West por Cilium Mesh Enterprise
- Mantener API Gateway para North-South y capacidades L7
- Incluir pruebas de "pod churn cross-cluster" como criterio obligatorio de pase a producción

---


[← Volver al Índice](00_indice.md)
