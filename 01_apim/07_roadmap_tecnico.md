# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---
## 7. Pasos Necesarios: Roadmap Técnico

### Fase 1: Investigación y Evaluación (Completada)

**Estado:** Cerrada

**Actividades completadas:**
- ✅ Evaluación de múltiples vendors (Kong, Tyk, Connectivity Link, Traefik, Apigee)
- ✅ Identificación de must-haves técnicos
- ✅ Análisis de arquitectura actual (3scale)
- ✅ Identificación de pain points y limitaciones
- ✅ Cluster de pruebas desplegado (25/11)
- ✅ PoCs de Ambient Mesh multiclúster en on-prem y AWS/EC2
- ✅ Validación técnica de issue de conexiones stale en `ztunnel` con soporte vendor
- ✅ Decisión de reemplazo de Ambient Mesh por Cilium Mesh Enterprise para East-West

**Actividades pendientes:**
- ⏳ Cerrar definición contractual/licenciamiento de Cilium Mesh Enterprise (Isovalent)
- ⏳ Diseñar arquitectura detallada de integración Cilium Mesh + API Gateway
- ⏳ Desplegar aplicaciones corporativas (SPA, BFF, backend con persistencia)
- ⏳ Ejecutar PoC de hardening y performance sobre stack seleccionado

**Entregables:**
- Documento de evaluación de vendors
- Matriz comparativa técnica
- Recomendación de vendor

### Fase 2: Rediseño Arquitectónico (Pendiente)

**Objetivo:** Diseñar arquitectura objetivo detallada basada en decisión de vendor.

**Actividades:**
1. **Diseño de Arquitectura Detallada**
   - Arquitectura de 3 capas para North-South (DMZ → API GW → Mesh)
   - Arquitectura de Service Mesh para East-West
   - Modelo de despliegue on-demand de Gloo Gateway
   - Integración con infraestructura existente (F5, OpenShift, DNS)

2. **Diseño de Multiclúster**
   - Arquitectura activo-activo entre sitios
   - Sincronización de configuraciones
   - Failover automático
   - DNS automation

3. **Diseño de Seguridad**
   - Modelo de autenticación (OAuth2/JWT)
   - mTLS entre servicios
   - Network policies
   - Integración con sistemas corporativos de identidad

4. **Diseño de Observabilidad**
   - Métricas, logs, traces
   - Dashboards y alertas
   - Integración con herramientas existentes

**Entregables:**
- Documento de arquitectura detallada
- Diagramas de arquitectura
- Plan de proyecto final

**Timeline:** 4-6 semanas

### Fase 3: Proof of Concept (POC) (Pendiente)

**Objetivo:** Validar solución seleccionada en ambiente controlado.

**Ambiente de POC:**
- 2 clusters OpenShift (simulando activo-activo)
- Aplicaciones de prueba (Java, .NET, SPA, BFF)
- Integración con F5, DNS, identity providers

**Escenarios de Prueba:**

1. **Funcionalidad Básica**
   - Despliegue de Cilium Mesh Enterprise + API Gateway
   - Configuración de rutas básicas
   - Autenticación OAuth2/JWT
   - Rate limiting

2. **Multiclúster**
   - Sincronización de configuraciones entre clusters
   - Failover automático
   - Health checks y routing

3. **Performance**
   - Load testing a escala de producción
   - Latencia y throughput
   - Comparación con 3scale baseline

4. **Integración**
   - Integración con F5
   - Integración con DNS corporativo
   - Integración con identity providers
   - Integración con sistemas de observabilidad

5. **Migración**
   - Coexistencia con 3scale
   - Migración de APIs de prueba
   - Validación de funcionalidad equivalente

**Criterios de Éxito:**
- ✅ Despliegue exitoso en OpenShift
- ✅ Funcionalidad equivalente a 3scale
- ✅ Performance igual o mejor que 3scale
- ✅ Failover automático funcional
- ✅ Integración con infraestructura existente
- ✅ Migración de APIs sin downtime

**Entregables:**
- Reporte de POC
- Métricas de performance
- Recomendaciones de implementación
- Plan de migración detallado

**Timeline:** 8-12 semanas

### Fase 4: Pruebas de Performance (Pendiente)

**Objetivo:** Validar performance bajo carga de producción.

**Pruebas Requeridas:**

1. **Load Testing**
   - Volumen: 7.5B requests/mes (East-West)
   - Pico: 25,000+ RPS
   - Duración: Tests sostenidos de 24-48 horas
   - Aplicaciones compliance del banco

2. **Métricas a Validar**
   - Latencia (p50, p95, p99)
   - Throughput
   - Error rate
   - Resource utilization (CPU, memoria, red)
   - Comparación con baseline de 3scale

3. **Stress Testing Multiclúster**
   - Failover automático con volumen productivo
   - Comportamiento bajo fallos de cluster
   - Sincronización bajo carga
   - Recovery time

4. **Pruebas de Escalabilidad**
   - Escalado horizontal
   - Comportamiento con crecimiento de tráfico
   - Límites de capacidad

**Entregables:**
- Reporte de performance
- Métricas comparativas vs 3scale
- Recomendaciones de sizing
- Límites identificados

**Timeline:** 4-6 semanas (paralelo con POC)

### Fase 5: Planificación de Migración (Pendiente)

**Objetivo:** Desarrollar plan detallado de migración desde 3scale.

**Actividades:**

1. **Inventario de APIs**
   - Catalogar todas las 2,200 APIs
   - Identificar dependencias
   - Clasificar por criticidad
   - Priorizar orden de migración

2. **Estrategia de Migración**
   - Enfoque gradual (namespace por namespace)
   - Coexistencia con 3scale
   - Ventanas de migración
   - Rollback procedures

3. **Migración de Configuraciones**
   - Mapeo de configuraciones 3scale → API Gateway + Service Mesh
   - Scripts de conversión
   - Validación de equivalencia
   - Testing de configuraciones migradas

4. **Migración de Credenciales**
   - Estrategia de migración de API keys
   - Integración con sistemas de identidad
   - OAuth2/JWT migration
   - Revocación de credenciales antiguas

5. **Plan de Comunicación**
   - Notificación a equipos de desarrollo
   - Documentación para desarrolladores
   - Training y capacitación
   - Support durante migración

**Entregables:**
- Plan de migración detallado
- Scripts de migración
- Documentación para desarrolladores
- Plan de comunicación

**Timeline:** 6-8 semanas

### Fase 6: Implementación Piloto (Pendiente)

**Objetivo:** Migrar subset de APIs como prueba piloto.

**Selección de APIs Piloto:**
- APIs no críticas
- APIs con bajo volumen
- APIs con configuración simple
- Representativas de diferentes casos de uso

**Actividades:**
1. Despliegue de Cilium Mesh Enterprise + API Gateway en producción
2. Migración de APIs piloto
3. Validación de funcionalidad
4. Monitoreo y observabilidad
5. Ajustes y optimizaciones

**Criterios de Éxito:**
- ✅ APIs piloto funcionando correctamente
- ✅ Performance igual o mejor que 3scale
- ✅ Sin incidentes críticos
- ✅ Feedback positivo de equipos de desarrollo

**Timeline:** 8-12 semanas

### Fase 7: Migración Gradual (Pendiente)

**Objetivo:** Migrar todas las APIs de forma gradual.

**Estrategia:**
- Migración por namespaces
- Migración por equipos de desarrollo
- Migración por criticidad (baja → media → alta)

**Actividades:**
1. Migración continua de APIs
2. Validación y testing continuo
3. Monitoreo y observabilidad
4. Ajustes y optimizaciones
5. Descommissioning de 3scale

**Timeline:** 6-12 meses (dependiendo de volumen)

### Fase 8: Optimización y Mejora Continua (Pendiente)

**Objetivo:** Optimizar y mejorar la solución post-migración.

**Actividades:**
1. Optimización de performance
2. Ajuste de políticas y configuraciones
3. Mejora de observabilidad
4. Training continuo
5. Adopción de nuevas capacidades

**Timeline:** Continuo

---


[← Volver al Índice](00_indice.md)
