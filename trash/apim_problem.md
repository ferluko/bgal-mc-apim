## Arquitectura Actual 3scale - Banco Galicia

### Configuración de Infraestructura
**Cluster Monolítico:**
- 100 nodos, 10,000 pods, 600 namespaces, 2,000 servicios
- Todo el tráfico API pasa por 3scale como capa única
- Configuración stretch cluster entre dos sitios (PGA/CMZ)

**Load Balancer Setup:**
- F5 → HAProxy → 3scale en cada cluster
- NodePort services (no external IP automático)
- Network policies fuerzan todo el tráfico por 3scale - no hay comunicación directa entre namespaces

### Estructura de Tenants y Tráfico
**Tenant B2C (East-West):** 80% del tráfico
- 7,500 millones requests/mes - APIs internas OpenShift
- Comunicación entre microservicios de diferentes namespaces
- Patrón hair-pinning: salir del cluster → load balancer → re-entrar

**Tenant B2B (North-South):** 20% del tráfico  
- 500 millones requests/mes - APIs externas/terceros
- Partners externos usando mutual TLS
- Mobile/office banking

### Landscape de Servicios
**~2,200 APIs en producción total:**
- ~1,500 servicios internos reales
- ~500 servicios batch (sin APIs) 
- ~200 external API facades/BFF

**Organización:**
- ~100 equipos de desarrollo, ~1,000 desarrolladores
- Tres tipos de exposición:
  - B2C vía Galicia Office (onboarding completo)
  - Servicios externos (Interbanking, Prisma)
  - Servicios internos automatizados via pipelines

### Modelo de Autenticación Actual
**API Key Authentication (Problemático):**
- Headers básicos: API keys/client IDs
- Static tokens sin expiración
- Difícil revocación - considerado anti-patrón de seguridad
- No OAuth2 implementation
- Consumo interno: JWT básico simplificado

**Dependencia Redis Crítica:**
- Cuando 3scale cae → Redis falla → todo el banco se afecta 
- Single point of failure

### Integración con Core Banking
**Mainframe Dependency:**
- Alta dependencia del core bancario mainframe
- Mayoría transacciones requieren múltiples hits a APIs bancarias
- 3scale mapea APIs externas como internas de OpenShift
- SWIFT: máquina dedicada con permisos para endpoint API en DMZ

### Pain Points Críticos para Migración
**Timeline Crítico:**
- 3scale end-of-life: mediados 2027
- Decisión requerida Q4 2025 para migración completa 2026

**Problemas Técnicos:**
- Hair-pinning pattern crea latencia y bottlenecks
- Observabilidad rota: 3scale actúa como "firewall" cortando traces
- Límite 500 routes (vs 2,200 APIs actuales)
- Performance bottlenecks con arquitectura actual

**Challenges Operacionales:**
- No capacidad declarativa - todo en base de datos
- Migración manual de 2,200 APIs sin herramientas
- Proceso de suscripción complejo
- Secrets management problemático

### Arquitectura Target Deseada
**Separación de Tráfico:**
- External API Manager: mobile/office banking (norte-sur)
- Internal API Gateway: comunicación intra-namespace/inter-cluster (este-oeste)
- External DNS: automatización de updates DNS corporativo

Esta es la arquitectura completa que 3scale maneja actualmente y que Solo.io necesitaría reemplazar.