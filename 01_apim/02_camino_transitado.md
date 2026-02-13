# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---

## 2. Camino Transitado: Evolución del Proyecto

### 2.1 Fase 1: Evaluación Inicial (Reemplazo Simple de APIM)
**Período:** Agosto - Octubre 2025

**Objetivo:** Migración directa de 3scale a un API Management alternativo, enfocado en paridad funcional y mínima disrupción.

**Contexto:**
- Deadline crítico: 3scale End-of-Life mediados 2027
- Necesidad de mantener continuidad operativa sin disrupciones
- Enfoque conservador: buscar solución que replique funcionalidades actuales
- Prioridad en herramientas de migración asistida para minimizar esfuerzo

**Actividades realizadas:**
- Evaluación de vendors con capacidades de API Management tradicional completas
- Prioridad en migración asistida y continuidad operativa
- Búsqueda de solución drop-in replacement
- Validación de compatibilidad con arquitectura OpenShift existente
- Análisis de modelos de pricing y costos operativos

**Vendors evaluados en esta fase:**
- **Red Hat Connectivity Link:** 
  - Continuidad con ecosistema Red Hat/3scale
  - Herramientas de migración desde 3scale (tasa de éxito 6-7/10)
  - Integración nativa con OpenShift
  - Descuento 50% primer año para migraciones
- **Apigee (Google Cloud):**
  - Enterprise ready con amplia base de clientes
  - Capacidades avanzadas de API Management
  - Backing de Google
  - Incluso en el modelo on-premise ("hybrid"), era necesario enrutar tráfico a través de GCP, lo cual plantea un problema ya que no existen fundaciones ni presencia corporativa en esa nube pública
- **IBM API Connect:**
  - Solución legacy con experiencia en entornos bancarios
  - Evaluación rápida, descartado por arquitectura no cloud-native

**Insight crítico descubierto:** Las evaluaciones profundas de proveedores revelaron limitaciones arquitectónicas fundamentales que exigieron una visión estratégica más amplia. Se identificó que:
- Las soluciones tradicionales de API Management no optimizan para tráfico interno masivo
- El modelo de pricing por API call es inviable para 7.5B requests/mes internos
- La arquitectura actual con hair-pinning requiere rediseño, no solo reemplazo

### 2.2 Fase 2: Despertar Arquitectónico (Prioridad en API Gateway)
**Período:** Octubre - Noviembre 2025

**Objetivo:** Identificar solución de API Gateway que optimice tráfico interno masivo (7.5B requests/mes).

**Contexto:**
Las demostraciones de proveedores evidenciaron que la necesidad principal era la gestión eficiente del tráfico, más que el overhead tradicional de API Management.

**Análisis realizado:**
- Desglose detallado de patrones de tráfico: 7.5B requests/mes internos vs 500M externos
- Identificación del problema de hair-pinning y su impacto en latencia (25-50ms por salto)
- Análisis de bottlenecks de performance en arquitectura actual
- Evaluación de overhead de API Management tradicional vs necesidades reales

**Insight crítico descubierto:**
- **80% del tráfico es interno (service-to-service)**
- Requiere ruteo de alto rendimiento, no overhead de gestión
- Priorizar funcionalidades de **API Gateway** por sobre capacidades clásicas de APIM
- Separación necesaria: Internal Gateway (East-West) vs External API Manager (North-South)
- Fixed pricing es requisito no negociable para tráfico interno

**Vendors evaluados en esta fase:**
- **Kong Enterprise:**
  - Arquitectura sólida y moderna, Kubernetes-native
  - Amplio ecosistema de plugins (90+)
  - Referencias bancarias (Bradesco)
  - POC completa desplegada
  - Configuración declarativa vía CRDs
- **Traefik Hub:**
  - Costo-efectivo con fixed instance-based pricing
  - Gateway API native support
  - Arquitectura moderna y cloud-native
  - Multi-cluster management console
- **Tyk Enterprise:**
  - Fixed pricing model atractivo
  - Experiencia en open banking
  - Soporte multiclúster nativo
  - Operador de Kubernetes
  - Control Plane Híbrido para multiclusters/multiregion

**Actividades realizadas:**
- POC completa de Kong Enterprise en cluster de pruebas
- Demos técnicos de Traefik Hub y Tyk
- Pruebas de performance comparativas
- Análisis detallado de modelos de pricing
- Evaluación de integración con OpenShift
- Modelado de solución arquitectónica con integración de networking

**Problemas identificados:**
- **Kong:** 
  - Costos variables East-West muy altos (pricing problemático para 7.5B requests/mes)
  - Limitaciones técnicas en Kong Ingress Controller (KIC)
  - Deprecación de nginx como ingress
  - Arquitectura Hybrid consolida cambios en archivo de configuración de gran tamaño (limita escalabilidad)
- **Traefik:** 
  - Soporte LATAM limitado
  - Capacidades Enterprise pobres (poca experiencia con clientes enterprise)
  - Observabilidad pobre (requiere desarrollo de tableros propios de Grafana)
  - Algunas inconsistencias de configuración durante pruebas de estrés
- **Tyk:** 
  - Curva de aprendizaje significativa
  - Poca madurez comprobada en implementaciones a gran escala en la región
  - Sin soporte para Gateway API (en desarrollo)
  - Documentación limitada para despliegues complejos
  - Soporte en español y presencia local aún en desarrollo

#### **Solución Modelada: "Galicia Mesh"**

Se modeló una solución arquitectónica que requería **fuerte integración de networking** (F5, Infoblox, AppViewX) con automatización bidireccional, sincronización de configuraciones, y failover coordinado.

**Implicaciones identificadas:**
- **Inversión significativa en equipamiento** (Infoblox, F5) no contemplada en presupuesto
- **Transformación cultural y organizacional** requerida: automatización completa, colaboración inter-equipos (Networking, Seguridad, Platform, DevOps), cambio de procesos a DevOps e "infrastructure as code"
- **Complejidad de implementación:** integraciones custom, pipelines complejos, testing exhaustivo

**Conclusión:** Si bien ofrecía capacidades avanzadas, la inversión, transformación cultural y complejidad llevaron a buscar alternativas que redujeran dependencia de transformaciones profundas en networking.

#### **Insight crítico descubierto:** 
El enfoque de API Gateway puro es válido, pero se requiere una solución que combine eficiencia a través de la automatización y capacidades de gestión proactiva para el tráfico multiclúster, manteniendo un modelo de pricing sostenible. El modelado de "Galicia Mesh" reveló que la automatización compleja de networking entre múltiples sistemas es un desafío significativo que podría resolverse con tecnologías nativas de service mesh.

### 2.3 Fase 3: Priorización de Enfoque Multiclúster y Nueva Oportunidad para Service Mesh
**Período:** Noviembre 2025 - Enero 2026

**Objetivo:** Evaluar soluciones de service mesh sidecarless para tráfico East-West multiclúster y observabilidad eBPF.

**Contexto:**
Los aprendizajes del modelado de Fase 2 ("Galicia Mesh") llevaron a priorizar el **enfoque multiclúster** como requisito crítico, identificando que service discovery y automatización de networking son funcionalidades nativas de Service Mesh moderno sidecarless (en ese momento, con hipótesis inicial sobre ambient mesh).

**Actividades realizadas:**
- Evaluación de Cilium Cluster Mesh para networking multiclúster L3/L4
- Evaluación de Gloo Gateway para necesidades L7 (en paralelo)
- Análisis de observabilidad eBPF como requisito previo a multiclúster

**Alternativas evaluadas:**

**1. Cilium Cluster Mesh:**
- Service Mesh sin sidecars con CNI propia, conectividad multiclúster nativa
- Certificado por Red Hat, observabilidad eBPF avanzada
- **Hallazgos:**
- ✅ Excelente para conectividad multiclúster y networking L3/L4
- ✅ Service discovery nativo entre clusters
- ✅ Observabilidad avanzada basada en eBPF
- ✅ Alto rendimiento y bajo overhead
- ❌ **Limitación crítica:** No resuelve necesidades de L7 (API Gateway, rate limiting, transformación, etc.)
- ❌ **Gap identificado:** Requiere complemento para capacidades de API Management

**2. Solo.io Gloo Gateway:**
- Basado en Envoy, Gateway API nativo, fixed pricing negociable
- Evaluado en paralelo porque Cilium no resuelve L7
- **Hallazgos:**
- ✅ Arquitectura sólida basada en Envoy
- ✅ Fixed pricing negociable (crítico para tráfico interno)
- ✅ Soporte nativo para Gateway API
- ✅ Base open source (Envoy) reduce vendor lock-in
- ✅ Resuelve necesidades de L7 (API Gateway, rate limiting, transformación)
- ⚠️ Solo resuelve tráfico North-South
- ⚠️ **Gap identificado:** Necesita complemento para tráfico East-West multiclúster

#### **Descubrimiento Crítico de la Fase: Necesidad de eBPF antes de Multiclúster**

Durante la evaluación de Cilium Cluster Mesh, se descubrió que la **observabilidad basada en eBPF es un requisito clave antes de implementar arquitectura multiclúster**.

**Problema identificado:**
- **Deuda técnica crítica:** Falta de mapa de servicios completo y actualizado
- **Observabilidad rota:** 3scale actúa como "firewall" cortando traces completos
- **Falta de visibilidad end-to-end:** Imposible rastrear requests a través de múltiples clusters
- **Sin métricas avanzadas:** Falta de métricas de rendimiento y trazabilidad end-to-end

**Ventajas clave de Observabilidad eBPF para Multiclúster:**

**1. Observabilidad End-to-End (E2E):**
- **Visibilidad completa:** Traces completos a través de múltiples clusters sin gaps
- **Sin instrumentación de aplicaciones:** Observabilidad transparente sin modificar código
- **Captura a nivel de kernel:** Métricas y traces capturados en el kernel, no en la aplicación
- **Performance sin overhead:** Mínimo impacto en rendimiento de aplicaciones

**2. Mapa de Servicios (Deuda Técnica Crítica):**
- **Service discovery visual:** Mapa completo de servicios y dependencias entre clusters
- **Detección automática:** Descubrimiento automático de servicios sin configuración manual
- **Dependencias identificadas:** Visualización clara de relaciones entre servicios
- **Actualización en tiempo real:** Mapa siempre actualizado sin intervención manual
- **Ejemplo:** Herramientas como coroot demuestran el poder de observabilidad eBPF

**3. Capacidades Técnicas:**
- **Observabilidad a nivel de kernel:** Captura de métricas sin overhead de aplicación
- **Trazabilidad completa:** End-to-end tracing sin gaps causados por 3scale
- **Métricas avanzadas:** Latencia, throughput, errores a nivel de servicio y cluster
- **Network policies observables:** Visibilidad de políticas de red aplicadas

**4. Beneficios para Implementación Multiclúster:**
- **Validación de conectividad:** Verificar que servicios entre clusters se descubren correctamente
- **Debugging simplificado:** Identificar problemas de conectividad multiclúster rápidamente
- **Optimización de tráfico:** Identificar patrones de tráfico y optimizar rutas entre clusters
- **Monitoreo de salud:** Health checks y métricas de salud a nivel multiclúster

#### **Insight crítico descubierto:**

1. **Hipótesis de Fase:** Service discovery y automatización de networking entre clusters son funcionalidades nativas de ambient mesh, eliminando la necesidad de integraciones custom complejas requeridas en "Galicia Mesh" y reduciendo overhead operativo vs sidecars tradicionales. *(Posteriormente descartado para East-West en Fase 4 por issue reproducible.)*

2. **eBPF es Requisito Previo Crítico:** La observabilidad basada en eBPF es esencial antes de implementar arquitectura multiclúster. Resuelve la deuda técnica crítica del mapa de servicios y habilita observabilidad end-to-end necesaria para operar múltiples clusters de forma efectiva.

3. **Gap de Solución Completa (contexto de fase):** 
   - Cilium Cluster Mesh resuelve networking multiclúster L3/L4 pero no L7
   - Gloo Gateway resuelve necesidades L7 pero requiere complemento para East-West multiclúster
   - **Necesidad identificada en ese momento:** Evaluar si Gloo Mesh (service mesh ambient) puede complementar Gloo Gateway para solución completa multiclúster

### 2.4 Fase 4: PoCs de Ambient Mesh y Resolución con Vendor (Cerrada)
**Período:** Enero - Febrero 2026

**Objetivo:** Validar estabilidad multiclúster real para tráfico East-West con service mesh sidecarless y cerrar decisión de vendor.

**Contexto:**
Luego de la Fase 3 se priorizó validar una combinación completa para East-West + North-South. Se ejecutaron PoCs específicas con Solo.io/Gloo Mesh (basado en Istio Ambient) para confirmar comportamiento operativo ante cambios de endpoints en servicios globales.

**Actividades realizadas con vendor y equipos internos:**
- PoC multiclúster en OpenShift on-prem (OCP 4.18.21) con 2 clusters conectados por East-West Gateways
- Despliegue de Gloo Mesh / Istio Ambient con Gateway API (`Gateway` + `HTTPRoute`) y servicios globales (`ServiceExport`/`ServiceImport`)
- Pruebas de resiliencia sobre tráfico `cluster1 -> cluster2` con reciclado de pods backend
- Validación técnica de causa raíz en nodos usando `oc debug node`, `crictl` y `nsenter` sobre `ztunnel`
- Escalación y seguimiento con Solo.io sobre evidencia de conexiones TCP persistentes a endpoints viejos
- Segunda PoC en OpenShift sobre EC2 para descartar sesgo de infraestructura on-prem
- Ejecución de escenarios sugeridos por vendor (incluyendo failover del workshop público) para contraste de comportamiento

#### **Resultado técnico reproducible**
- En tráfico cross-cluster, al reciclar pod backend en `cluster2` (cambio de IP), las requests HTTP desde `cluster1` quedan colgadas indefinidamente.
- La causa validada fue conexión TCP `ESTABLISHED` stale en `ztunnel` hacia la IP antigua del pod remoto (`:15008` HBONE), reutilizada tras cambio de endpoint.
- Reiniciar los pods East-West (`ztunnel`) restablece el tráfico, lo que confirma workaround pero no solución de fondo.
- El problema no se reproduce en tráfico same-cluster.

#### **Validación cruzada de entorno y guía de vendor**
- La misma falla se reprodujo en on-prem y en OCP sobre AWS/EC2 con configuración por defecto.
- Los tests sugeridos por vendor y el escenario de failover del workshop no reprodujeron el problema porque no ejercen el mismo patrón de tráfico con reciclado de IP en servicio global remoto.
- Conclusión técnica: el comportamiento observado no es específico del entorno, sino del patrón `ingreso por cluster1 + rotación de IP de pod en cluster2`.

#### **Resolución de la fase**
- **Istio Ambient Mesh (incluyendo Gloo Mesh para East-West) descartado** para esta iniciativa por riesgo operativo en patrón crítico y reproducible.
- **El modelo arquitectónico no cambia** (3 capas North-South y malla East-West multiclúster activo-activo).
- **Cambio de componente:** East-West pasa a **Cilium Mesh (Isovalent Enterprise)**, manteniendo API Gateway para North-South.

**Estado actual:** Decisión de arquitectura cerrada para East-West; en ejecución el plan de implementación sobre Cilium Mesh Enterprise.

---

[← Volver al Índice](00_indice.md)
