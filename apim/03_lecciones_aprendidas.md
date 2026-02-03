# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---

## 3. Lecciones Aprendidas

### 3.1. Redefinición de la Comunicación entre Servicios

**Visión tradicional:**
- APIs como interfaces externas con alto overhead de gestión
- Enfoque en capacidades de API Management (developer portal, analytics, monetización)

**Realidad descubierta:**
- **80% de comunicación interna** que requiere networking de alto rendimiento
- El overhead de API Management tradicional es contraproducente para tráfico interno
- Necesidad de separación clara: Internal Gateway vs External API Manager

**Impacto de negocio:**
- Ahorros anuales superiores a USD 1M mediante optimización del tráfico interno
- Reducción de latencia de 25-50ms eliminando hair-pinning
- Habilitación de comunicación directa pod-a-pod

### 3.2. Evolución del Modelo de Seguridad

**Enfoque legado:**
- Credenciales estáticas (API keys sin expiración)
- Fricción operativa alta (200+ horas mensuales de ingeniería)
- Hallazgos de auditoría regulatoria

**Estado objetivo:**
- mTLS entre servicios
- Integración dinámica JWT/OAuth con sistemas corporativos de identidad
- Gestión automatizada del ciclo de vida de credenciales
- Token expiration y revocación automática

**Mitigación de riesgo:**
- Reducción del 70% en incidentes de seguridad mediante automatización
- Cumplimiento regulatorio mejorado
- Eliminación de anti-patrones de seguridad

### 3. Transformación de la Arquitectura de Alta Disponibilidad

**Limitación actual:**
- DR activo-pasivo con failover manual
- Sincronización manual vía pipelines
- RTO superior a 4 horas
- Riesgo de desincronización entre sitios

**Estado futuro:**
- Multiclúster activo-activo con ruteo automatizado basado en salud
- Sincronización declarativa (Infrastructure as Code)
- Failover automático sub-segundo
- Control plane centralizado con data planes autónomos

**Protección de ingresos:**
- Mitigación de riesgos por más de USD 20M anuales mediante failover automático
- Eliminación de errores manuales en procesos de DR
- Reducción de RTO de 4 horas a <1 segundo

### 4. Separación de Control Plane y Data Plane

**Lección crítica:**
- Arquitectura desacoplada es esencial para escalabilidad y resiliencia
- Data planes deben funcionar independientemente si pierden conectividad con control plane
- Permite escalar y actualizar de forma independiente

**Aplicación práctica:**
- Control plane puede estar en nube pública (SaaS) o gestionado pero desacoplados (sin SPOF en común)
- Data planes distribuidos en múltiples clusters/sitios
- Modelo hub-and-spoke para gestión centralizada

### 5. Importancia del Fixed Pricing

**Problema identificado:**
- Modelos de pricing por API call son inviables para 7.5B requests/mes internos
- Costos impredecibles con crecimiento orgánico
- Burst traffic puede generar costos explosivos

**Solución requerida:**
- Fixed pricing o costos predecibles
- Sin penalización por burst o crecimiento orgánico
- Crítico para sostenibilidad financiera a largo plazo

### 6. Declarative Configuration es No Negociable

**Problema actual:**
- 3scale: Todo en base de datos, sin capacidad declarativa
- Migración manual de 2,200 APIs sin herramientas
- Imposible GitOps workflows

**Requerimiento futuro:**
- Todo debe ser declarativo (CRDs, YAML)
- GitOps workflows nativos
- Versionado y auditoría de cambios
- Sincronización automática entre sitios

### 7. Kubernetes Gateway API como Estándar

**Insight:**
- Gateway API es el futuro de Kubernetes networking
- Evita dependencias en implementaciones propietarias
- Permite interoperabilidad y portabilidad
- Facilita separación de roles (admin de infra vs aprovisionadores de rutas)

**Requerimiento:**
- Soporte nativo para K8s Gateway API es must-have
- Facilita integración con ecosistemas cloud native
- Posibilita definiciones declarativas multicluster

### 8. Ambient Mesh vs Sidecar Mesh

**Evaluación:**
- Sidecar mesh: Overhead operativo alto, complejidad de gestión
- Ambient mesh: Reduce complejidad, mantiene capacidades
- Istio ambient mesh como base para workloads container-native

**Decisión:**
- Preferencia por ambient mesh para reducir overhead
- Mantener capacidades de service mesh sin complejidad de sidecars

---

[← Volver al Índice](00_indice.md)
