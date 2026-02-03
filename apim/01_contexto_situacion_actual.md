# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---

## 1. Contexto y Situación Actual

### 1.1 Infraestructura Actual (3scale)

#### **Escala de Operación:**
- **Cluster monolítico:** +100 nodos, +10,000 pods, +600 namespaces
- **Volumen de tráfico:** ~8 mil millones de requests/mes
  - **East-West (interno):** 7.5B requests/mes (80%)
  - **North-South (externo):** 500M requests/mes (20%)
- **APIs en producción:** ~2,200 APIs
  - ~1,500 servicios internos reales
  - ~500 servicios batch (sin APIs)
  - ~200 external API facades/BFF

#### **Enfoque Actual de Gestión de APIs:**

El enfoque actual trata todas las APIs como si fueran APIs externas, cuando en realidad el **90% son de consumo interno**. Esto genera overhead innecesario y complejidad operativa para tráfico service-to-service que debería ser más directo y eficiente.

#### **Arquitectura de Red:**
- **Stretched network:** Red extendida para interconectar los dos sitios (PGA/CMZ)
- **Flujo de tráfico para APIs :**
    - **Expuestas a Internet:** F5/Fortinet (WAF, FW) → OCP DMZ (HAProxy → proxies reversos) → FW → F5 LB → OCP Prod (HAProxy) → 3scale Apicast → aplicaciones
    - **Consumidas internamente:** Servicio A (Namespace 1) → Sale del cluster → Load balancer (F5) → Re-entra al cluster (HAProxy) → 3scale Apicast → Servicio B (Namespace 2)
- **Hair-pinning pattern:** Servicios internos salen del cluster → load balancer → re-entran, generando latencia adicional innecesaria
- **Network policies:** Fuerzan todo el tráfico cross-namespace a través de 3scale


#### **Alta Disponibilidad y Disaster Recovery:**
- **Dos instancias independientes:** Una por sitio (Plaza/Matriz)
- **Bases de datos separadas:** Sin almacenamiento compartido
- **Sincronización manual:** Vía pipelines y scripts de automatización
- **Elementos sincronizados:**
  - Productos API y contratos
  - Certificados cliente (proceso manual)
  - Políticas de rewrite de headers
  - Backend endpoints y configuraciones
  - Credenciales de aplicación y API keys
  - ~2,500 aplicaciones con múltiples endpoints cada una

**Limitaciones Críticas de DR:**  
- Solo es posible un esquema activo/standby, ya que se requiere volcar el tráfico completo del cluster a una u otra instancia; no es posible operar en modo activo-activo ni realizar switcheo selectivo de APIs o namespaces.
- Sin capacidad declarativa (no se puede convertir a CRDs)
- Comparación manual requerida entre sitios usando toolkit
- Sincronización basada en pipelines (export/import de configuraciones)
- Riesgo de desincronización cuando el pipeline falla parcialmente
- No hay failover automatizado (requiere cambio manual de DNS)

#### **Modelo de Autenticación:**
- **API Key Authentication (problemático):**
  - Headers básicos: API keys/client IDs
  - Tokens estáticos sin expiración
  - Revocación difícil - considerado anti-patrón de seguridad
  - Sin implementación OAuth2
  - Consumo interno: JWT básico simplificado
- **Dependencia crítica de DBs externas:** Tanto Redis como la base transaccional son single points of failure

#### **Integración con Core Banking, Legacy y Terceros:**
- Alta dependencia del core bancario mainframe a traves de CIS servicers
- Integración relevante con Oracle Service Bus y VMs legacy 
- Mayoría de transacciones requieren múltiples hits a APIs bancarias
- 3scale mapea APIs externas como internas de OpenShift
- Las APIs de terceros también generan un volumen considerable de tráfico y deben ser tenidas en cuenta

#### **Procesos de Publicación y Suscripción:**

Los procesos de publicación de APIs y suscripción de aplicaciones son **complejos, lentos y de gran carga operativa**:

- **Publicación de APIs:** Proceso manual que requiere múltiples pasos, configuración en base de datos, sincronización entre sitios, y validación manual
- **Suscripción de aplicaciones:** Requiere creación manual de credenciales, configuración de políticas, y sincronización entre instancias de 3scale
- **Mantenimiento:** Actualización de configuraciones requiere procesos manuales, comparación entre sitios, y riesgo de desincronización
- **Carga operativa:** ~2,500 aplicaciones con múltiples endpoints requieren mantenimiento continuo y procesos manuales repetitivos
- **Falta de trazabilidad:** No hay capacidad declarativa ni GitOps, todo depende de procesos manuales y pipelines complejos

### 1.2 Pain Points Identificados

**Técnicos:**
- **Hair-pinning:** Crea latencia adicional de 25-50ms por salto y bottlenecks
- **Observabilidad rota y pobre:**
    - 3scale actúa como "firewall", lo que corta los traces completos
    - Falta de métricas avanzadas de rendimiento y trazabilidad end-to-end
- **Límite de escalabilidad:** 500 routes vs 2,200 APIs actuales; Apicast tarda mucho en iniciar debido a que el reload es completo y no dinámico.
- **Performance bottlenecks:** Con arquitectura actual
- **Sin capacidad declarativa:** Todo en base de datos, no GitOps

**Operacionales:**
- **Sincronización manual de DR:** Carga operativa compleja
- **Riesgo de drift de configuración:** Entre sitios
- **Failover manual:** Requiere intervención manual de DNS
- **Gestión de secrets compleja:** A través de instancias independientes
- **Overhead operativo:** Mantener dos sistemas separados

**Seguridad:**
- **Tokens estáticos:** Sin expiración, difícil revocación, facil de compartir
- **Anti-patrón regulatorio:** Observaciones en auditorías
- **Single point of failure:** Redis crítico

**Timeline Crítico:**
- **3scale End-of-Life:** Mediados 2027
- **Decisión requerida:** Q2 2026
- **Go-live objetivo:** Q4 2026

---

[← Volver al Índice](00_indice.md)
