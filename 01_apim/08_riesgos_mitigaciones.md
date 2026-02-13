# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---
## 8. Riesgos y Mitigaciones

### Riesgos Técnicos

#### R1: Complejidad de Migración de 2,200 APIs

**Riesgo:** Migración manual de 2,200 APIs sin herramientas automatizadas puede ser muy compleja y propensa a errores.

**Probabilidad:** Alta  
**Impacto:** Alto

**Mitigación:**
- Desarrollo de scripts de migración automatizados
- Migración gradual (namespace por namespace)
- Validación exhaustiva de cada migración
- Coexistencia con 3scale durante período de transición
- Rollback procedures documentados

#### R2: Performance Inferior a 3scale

**Riesgo:** La nueva solución puede tener performance inferior a 3scale bajo carga de producción.

**Probabilidad:** Media  
**Impacto:** Alto

**Mitigación:**
- Pruebas de performance exhaustivas en POC
- Load testing a escala de producción
- Baseline de performance de 3scale documentado
- Optimización continua post-migración
- Escalado horizontal si necesario

#### R11: Inestabilidad Cross-Cluster ante Reciclado de Endpoints

**Riesgo:** Comportamiento no deseado en tráfico East-West multiclúster cuando cambia la IP de pods backend remotos (pod churn), generando requests colgadas o degradación de disponibilidad.

**Probabilidad:** Media  
**Impacto:** Alto

**Mitigación:**
- Pruebas obligatorias de "pod churn cross-cluster" en PoC, staging y preproducción
- Sondas sintéticas continuas para detectar colgado de requests entre clusters
- Validación de políticas de timeout, reconnect y drenaje de conexiones en el data plane
- Criterio de no-go-live si el escenario no pasa de forma consistente
- Runbook operativo de contingencia y rollback documentado

#### R3: Integración con Infraestructura Existente

**Riesgo:** Dificultades en integración con F5, DNS, identity providers, sistemas de observabilidad.

**Probabilidad:** Media  
**Impacto:** Medio

**Mitigación:**
- Validación de integraciones en POC
- Involucrar equipos de infraestructura temprano
- Documentación detallada de integraciones
- Testing exhaustivo de integraciones
- Plan de contingencia para cada integración

#### R4: Curva de Aprendizaje del Equipo

**Riesgo:** El equipo puede tener dificultades aprendiendo la nueva tecnología, impactando velocidad de migración.

**Probabilidad:** Alta  
**Impacto:** Medio

**Mitigación:**
- Training temprano del equipo
- Documentación completa
- Soporte de vendor durante migración
- Centro de excelencia interno
- Pair programming y knowledge sharing

### Riesgos Operacionales

#### R5: Failover Automático No Funcional

**Riesgo:** El failover automático puede no funcionar correctamente en producción, causando downtime.

**Probabilidad:** Baja  
**Impacto:** Crítico

**Mitigación:**
- Testing exhaustivo de failover en POC
- Pruebas de failover en ambiente de staging
- Monitoreo continuo de health checks
- Procedimientos manuales de failover como backup
- DR drills regulares

#### R6: Desincronización entre Clusters

**Riesgo:** Configuraciones pueden desincronizarse entre clusters, causando inconsistencias.

**Probabilidad:** Baja  
**Impacto:** Alto

**Mitigación:**
- Configuración declarativa (GitOps)
- Sincronización automática desde control plane
- Validación de configuraciones antes de aplicar
- Monitoreo de drift de configuración
- Alertas automáticas de desincronización

#### R7: Soporte y Escalación

**Riesgo:** Soporte del vendor puede ser insuficiente o lento, impactando resolución de incidentes.

**Probabilidad:** Media  
**Impacto:** Medio

**Mitigación:**
- SLA claramente definido en contrato
- Equipo interno capacitado para troubleshooting básico
- Documentación de troubleshooting común
- Escalación procedures documentados
- Vendor relationship management

### Riesgos de Negocio

#### R8: Timeline de Migración Extendido

**Riesgo:** La migración puede tomar más tiempo del planeado, acercándose al EOL de 3scale.

**Probabilidad:** Media  
**Impacto:** Alto

**Mitigación:**
- Plan de migración realista con buffers
- Priorización clara de APIs críticas
- Recursos dedicados al proyecto
- Monitoreo continuo del progreso
- Escalación temprana de problemas

#### R9: Costos Exceden Presupuesto

**Riesgo:** Costos de implementación u operación pueden exceder el presupuesto aprobado.

**Probabilidad:** Media  
**Impacto:** Medio

**Mitigación:**
- Fixed pricing negociado para tráfico interno
- Presupuesto detallado con contingencia
- Monitoreo continuo de costos
- Optimización continua de recursos
- Revisión regular de costos vs presupuesto

#### R10: Vendor Lock-in

**Riesgo:** Dependencia excesiva del vendor puede limitar opciones futuras.

**Probabilidad:** Baja  
**Impacto:** Medio

**Mitigación:**
- Base open source y estándares abiertos (Cilium/eBPF + Envoy/Gateway API)
- Configuraciones declarativas (portables)
- Gateway API como estándar (evita lock-in)
- Documentación de estrategias de salida
- Evaluación periódica de alternativas

### Matriz de Riesgos

| Riesgo | Probabilidad | Impacto | Prioridad | Mitigación |
|--------|-------------|---------|-----------|------------|
| R1: Complejidad Migración | Alta | Alto | 🔴 Crítica | Scripts automatizados, migración gradual |
| R2: Performance Inferior | Media | Alto | 🔴 Crítica | Pruebas exhaustivas, baseline documentado |
| R3: Integración Infraestructura | Media | Medio | 🟡 Alta | Validación en POC, testing exhaustivo |
| R4: Curva Aprendizaje | Alta | Medio | 🟡 Alta | Training temprano, documentación |
| R5: Failover No Funcional | Baja | Crítico | 🔴 Crítica | Testing exhaustivo, DR drills |
| R6: Desincronización | Baja | Alto | 🟡 Alta | GitOps, monitoreo de drift |
| R7: Soporte Insuficiente | Media | Medio | 🟡 Alta | SLA definido, equipo capacitado |
| R8: Timeline Extendido | Media | Alto | 🔴 Crítica | Plan realista, monitoreo continuo |
| R9: Costos Exceden | Media | Medio | 🟡 Alta | Fixed pricing, monitoreo de costos |
| R10: Vendor Lock-in | Baja | Medio | 🟢 Media | Open source, configuraciones portables |
| R11: Inestabilidad Cross-Cluster | Media | Alto | 🔴 Crítica | Pod churn tests, no-go-live, runbooks |

---


[← Volver al Índice](00_indice.md)
