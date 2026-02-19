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

La **arquitectura objetivo no cambia en su modelo**, pero sí en el componente East-West seleccionado:

- **Service Mesh Sidecarless East-West:** **Cilium Mesh (Isovalent Enterprise)**
- **API Gateway North-South:** capa APIM robusta entre DMZ y workloads, con Gloo Gateway y Kong como candidatos principales
- **Arquitectura multiclúster** con failover automático
- **Fixed pricing** para sostenibilidad financiera

### Camino Transitado con Vendor para Cerrar la Decisión

- Se ejecutaron PoCs de Ambient Mesh multiclúster en OpenShift on-prem y luego en OpenShift sobre EC2 para descartar sesgo de entorno.
- En ambos casos se reprodujo la misma falla: tráfico `cluster1 -> cluster2` queda colgado cuando se recicla el pod backend remoto y cambia su IP.
- La causa raíz validada fue reutilización de conexión TCP stale en `ztunnel` (HBONE `:15008`) hacia IP antigua del pod.
- Se aplicó el workaround de reinicio de East-West gateway (`ztunnel`), confirmando recuperación temporal pero no solución de fondo.
- Se ejecutaron además escenarios sugeridos por vendor (incluyendo failover del workshop público) y no reprodujeron la falla, por tratarse de un patrón de tráfico distinto.
- Conclusión: el issue no es dependiente del entorno (on-prem/AWS), sino del patrón de tráfico cross-cluster con rotación de endpoints.

### Estado de Alternativas

- **Istio Ambient Mesh (Solo.io / RHOSM):** Descartado para el dominio East-West de esta iniciativa.
- **Cilium Mesh (Isovalent Enterprise):** Seleccionado para East-West multiclúster.
- **API Gateway North-South:** Decision final abierta entre Gloo/Kong, con cierre por PoC, operabilidad y costo total.

### Arquitectura Objetivo

**Tráfico North-South (3 capas):**
- DMZ → API Gateway (B2B) → Service Mesh → Backend Services

**Tráfico East-West:**
- Service Mesh directo (sin hair-pinning)

**Despliegue:**
- Capa APIM/API Gateway on-demand en namespaces que lo requieran (coexistencia con 3Scale controlada durante la transicion)
- Service Mesh Sidecarless desplegado en todos los clusters (Cilium Mesh Enterprise para East-West)

### Próximos Pasos Críticos

1. **Cerrar frente contractual y soporte enterprise de Cilium Mesh (Isovalent)**
   - Licenciamiento, soporte y modelo operativo
   - Definición de ownership entre Platform, Networking y DevOps

2. **Diseñar arquitectura detallada de implementación**
   - Integración Cilium Mesh East-West + API Gateway North-South
   - Runbooks de operación y contingencia
   - Guardrails de seguridad y observabilidad

3. **Ejecutar PoC de hardening y performance sobre stack seleccionado**
   - Desplegar en 2 clusters
   - Validar funcionalidad, performance e integraciones
   - Incluir pruebas obligatorias de pod churn cross-cluster

4. **Planificación de migración**
   - Inventario y priorización de APIs
   - Estrategia detallada de transición desde 3scale
   - Automatización de migración y validación

5. **Implementación piloto y migración gradual**
   - Migración de subset inicial
   - Ajustes operativos
   - Escalamiento progresivo al resto de APIs

### Timeline Crítico

- **Q1 2026:** Cierre contractual y diseño detallado
- **Q2 2026:** PoC de hardening/performance e implementación piloto
- **Q3-Q4 2026:** Migración gradual
- **Q4 2026:** Go-live completo
- **Mediados 2027:** 3scale EOL (deadline absoluto)

---

**Documento preparado:** Febrero 2026
**Próxima revisión:** Post-PoC de hardening de Cilium Mesh Enterprise

[← Volver al Índice](00_indice.md)
