# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---
## 9. Conclusiones y Próximos Pasos

### Estado Actual del Proyecto

El proyecto ha evolucionado desde un simple reemplazo de 3scale hacia una modernización arquitectónica integral. La evaluación de múltiples vendors ha revelado la necesidad de una solución que combine:

- **Service Mesh** para tráfico interno (East-West)
- **API Gateway** para tráfico externo (North-South)
- **Arquitectura multiclúster** con failover automático
- **Fixed pricing** para sostenibilidad financiera

### Decisión Arquitectónica Tomada

**Service Mesh Sidecarless (Ambient Mesh) + API Gateway** como arquitectura objetivo:

- **Service Mesh Sidecarless:** Decisión arquitectónica independiente del vendor
  - Reducción de overhead operativo vs sidecars tradicionales
  - Simplificación de gestión y despliegues
  - Mejor performance y escalabilidad
- **API Gateway:** Gloo Gateway como componente para tráfico North-South
- **Arquitectura multiclúster** con failover automático
- **Fixed pricing** para sostenibilidad financiera

### Alternativas en Evaluación

**Service Mesh Sidecarless - Candidatos:**
- **Gloo Mesh (Solo.io):** Integración natural con Gloo Gateway, fixed pricing negociable, base Istio/Envoy
- **RHOSM (Red Hat):** Integración nativa OpenShift, continuidad Red Hat, POC solicitada
- **Cilium Cluster Mesh:** Networking eBPF avanzado, certificado Red Hat, requiere complemento para L7

**Observabilidad eBPF:**
- Recomendaciones de Red Hat para OCP pendientes
- Evaluación de productos compatibles con service mesh sidecarless seleccionado

### Arquitectura Objetivo

**Tráfico North-South (3 capas):**
- DMZ → API Gateway (B2B) → Service Mesh → Backend Services

**Tráfico East-West:**
- Service Mesh directo (sin hair-pinning)

**Despliegue:**
- Gloo Gateway on-demand en namespaces que lo requieran
- Service Mesh Sidecarless desplegado en todos los clusters (candidato a definir: Gloo Mesh, RHOSM, o Cilium)

### Próximos Pasos Críticos

1. **Ejecutar POC de RHOSM multiclúster** (pendiente de Red Hat)
   - Validar capacidades de ambient mesh en RHOSM
   - Comparar con Gloo Mesh y Cilium Cluster Mesh

2. **Recibir y evaluar recomendaciones de observabilidad eBPF** (pendiente de Red Hat)
   - Productos certificados para OpenShift
   - Integración con service mesh sidecarless

3. **Finalizar evaluación técnica comparativa** (próximas 4-6 semanas)
   - Gloo Mesh vs RHOSM vs Cilium Cluster Mesh
   - Gestionar licencias demo necesarias
   - Levantar PoC comparativa
   - Validar compatibilidad con OpenShift para cada alternativa

4. **Completar POC completo de solución seleccionada** (8-12 semanas)
   - Desplegar en 2 clusters
   - Validar funcionalidad, performance, integraciones
   - Probar failover automático

5. **Pruebas de performance** (4-6 semanas, paralelo con POC)
   - Load testing a escala de producción
   - Validar métricas vs 3scale baseline

6. **Decisión ejecutiva de vendor** (Q4 2025)
   - Presentación de recomendación
   - Aprobación y proceso contractual

7. **Planificación de migración** (Q1 2026)
   - Inventario de APIs
   - Estrategia de migración detallada
   - Scripts de migración

8. **Implementación piloto** (Q2 2026)
   - Migración de subset de APIs
   - Validación y ajustes

9. **Migración gradual** (Q2-Q4 2026)
   - Migración de todas las APIs
   - Descommissioning de 3scale

### Timeline Crítico

- **Q4 2025:** Decisión de vendor
- **Q1 2026:** POC completo y pruebas de performance
- **Q2 2026:** Implementación piloto
- **Q2-Q4 2026:** Migración gradual
- **Q4 2026:** Go-live completo
- **Mediados 2027:** 3scale EOL (deadline absoluto)

---

**Documento preparado:** Febrero 2026
**Próxima revisión:** Post-evaluación de Solo.io POC

[← Volver al Índice](00_indice.md)
