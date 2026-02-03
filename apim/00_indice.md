# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---

## Resumen Ejecutivo

### Contexto

Banco Galicia opera una infraestructura crítica de API Management basada en **3scale** que alcanzará End-of-Life en mediados 2027. La infraestructura actual presenta limitaciones arquitectónicas significativas:

- **Cluster monolítico:** +100 nodos, +10,000 pods, +600 namespaces procesando ~8 mil millones de requests/mes
- **Hair-pinning:** Tráfico interno (80% del total) sale del cluster y re-entra, generando latencia adicional de 25-50ms por salto
- **Observabilidad fragmentada:** 3scale actúa como "firewall" cortando traces completos, imposibilitando visibilidad end-to-end
- **DR limitado:** Solo activo/standby con RTO de 4 horas, sin capacidad de failover automático
- **Procesos manuales:** Sincronización manual entre sitios, sin capacidad declarativa (GitOps)

### Solución Propuesta

Transformación hacia **arquitectura multiclúster activo-activo** con separación clara de responsabilidades:

- **Service Mesh Sidecarless (Ambient Mesh):** Para tráfico interno East-West (7.5B requests/mes), eliminando hair-pinning mediante comunicación directa pod-a-pod
- **API Gateway:** Para tráfico externo North-South (500M requests/mes), arquitectura de 3 capas (DMZ/Core/Legacy → API Gateway → Mesh)
- **Separación L4/L7:** Plataforma gestiona conectividad base (L4), DevOps instrumenta políticas avanzadas (L7) on-demand
- **Gobierno nativo:** Políticas del service mesh basadas en identidades Kubernetes vs API keys estáticas

### Beneficios Clave

- **Performance:** Eliminación de hair-pinning reduce latencia notablemente
- **Observabilidad:** End-to-end con eBPF vs trazas cortadas
- **Resiliencia:** Failover automático sub-segundo vs 4 horas manual
- **Operación:** Configuración declarativa GitOps vs procesos manuales
- **Seguridad:** Autenticación moderna (mTLS, OAuth2/JWT) vs API keys estáticas
- **Escalabilidad:** Modelo multiclúster vs cluster monolítico al límite

### Estado Actual

**Arquitectura definida**, evaluación técnica activa de candidatos:
- **Service Mesh:** Gloo Mesh (Solo.io), RHOSM (Red Hat), Cilium Cluster Mesh
- **API Gateway:** Preferencia por Gloo Gateway
- **POCs en curso:** RHOSM multiclúster y recomendaciones de observabilidad eBPF solicitadas a Red Hat

**Timeline crítico:**
- **Q2 2026:** Decisión de vendor requerida
- **Q4 2026:** Go-live objetivo
- **Mediados 2027:** 3scale EOL (deadline absoluto)

---

## Tabla de Contenidos

1. [Contexto y Situación Actual](01_contexto_situacion_actual.md)
2. [Camino Transitado: Evolución del Proyecto](02_camino_transitado.md)
3. [Lecciones Aprendidas](03_lecciones_aprendidas.md)
4. [Decisiones Técnicas y Arquitectónicas](04_decisiones_tecnicas.md)
5. [Arquitectura Objetivo](05_arquitectura_objetivo.md)
6. [Evaluación de Proveedores](06_evaluacion_proveedores.md)
7. [Pasos Necesarios: Roadmap Técnico](07_roadmap_tecnico.md)
8. [Riesgos y Mitigaciones](08_riesgos_mitigaciones.md)
9. [Conclusiones y Próximos Pasos](09_conclusiones.md)

---
