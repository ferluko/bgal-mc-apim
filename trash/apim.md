# API Management Vendor Selection
## Executive Update - Banco Galicia
#### 04-11-25 9hs

---

## 1. Situación Actual y Contexto Crítico

### **Timeline No Negociable**
- **3scale End-of-Life**: Mediados 2027 - Soporte concluye
- **Decisión requerida**: Q4 2025 (próximos 60 días)
- **Go-live objetivo**: Q4 2026

### **Volumen de Negocio**
- **7.5B requests/mes** tráfico interno (East-West) - 80%
- **500M requests/mes** tráfico externo (North-South) - 20% 
- **~2,000 APIs** en producción actual

### **Impacto Estratégico**
- Comunicación crítica entre microservicios: Mejora en Resilencia y Disponibilidad​
- Habilitador para Open Banking y API-as-a-Product​
- Base para arquitectura híbrida on-premise/cloud: Journey to the Cloud​
- Reducción riesgo tecnológico: Eliminar componentes sin soporte

---

## 2. Evaluaciones Completadas y Descubrimientos

### **Vendors Evaluados (4 de 5 planificados)**
| Vendor | Status POC | Fortalezas Clave | Limitaciones Críticas |
|--------|------------|------------------|----------------------|
| **Red Hat Connectivity Link** | ✅ Demo técnico | Migración 3scale, HA nativo | Producto inmaduro (v1.0), ~~API Management~~, OCP Lock-in |
| **Kong** | ⚠️ POC completo | Arquitectura sólida, K8s nativo | Costos variables East-West, Limitaciones Hard, KIC Con problemas |
| **Apigee** | ✅ Deep dive | Google backing, enterprise ready | Latencia, vendor lock, complejidad extrema, Sin fundaciones en GCP |
| **Tyk** | 🔄 Demo comienza 5-Nov | Fixed pricing, open banking focus | Por confirmar capacidades |
| **Traefik** | ⚠️ En curso | Costo-efectivo | Soporte LATAM limitado |

### **Descubrimiento Clave: Arquitectura**
- **Separación necesaria**: Internal vs External gateways
- **Simplificación posible**: F5 → API Gateway (eliminar HAProxy para Apps)
- **HA/DR**: Activo-activo entre sites es requisito crítico
- **Data planes autónomos**: Deben funcionar independientemente si pierden conectividad con control plane.
- **Gestión federada centralizada**: Hub-and-spoke model para administrar múltiples gateways desde consola única

---

## 3. Desafíos y Decisiones Pendientes

### **Tensión Estratégica Principal**
**Continuidad vs Innovación**
- **Red Hat Connectivity Link**: Continuidad, migración asistida, roadmap unclear
- **Kong/Tyk**: Innovación, mejor arquitectura, mayor riesgo migración
- **Traefik**: Fuerte en lo comunitario. Pobre en Enterprise


### **Desafíos Técnicos Identificados**
- **Modelo de pricing**: Tráfico East-West masivo requiere costo fijo
- **Migración 3scale**: 2,000 APIs sin herramientas automáticas (excepto Red Hat)
- **Soporte local**: Capacidad técnica limitada en partners LATAM
- **Timeline apretado**: POCs vs decisión en paralelo
- **Pruebas de carga pendientes**: Validar máximos y percentiles (p95, p99) con aplicaciones compliance del banco
- **Performance baseline**: Establecer métricas comparativas vs 3scale actual bajo carga real.
- **Stress testing multicluster**: Probar failover automático con volumen productivo (25,000 RPS pico).

### **Riesgos de Negocio**
- **Delay en decisión**: Impacta timeline de migración crítico.
- **Wrong choice**: Costos operativos impredecibles o falla en producción.
- **Vendor lock-in**: Dependencia tecnológica a largo plazo.

---

## 4. Estado Actual y Recomendación
### **Contexto de Evaluación**
La evaluación ha sido realizada con recursos limitados: demos en paralelo con 5 vendors, lo que consume tiempo significativo en coordinación y reuniones. Adicionalmente, existen restricciones de infraestructura para realizar pruebas de carga exhaustivas que validarían cada solución bajo condiciones de producción real. Aunque la evaluación funcional y técnica es suficiente para la toma de decisión, un proceso de maduración más profundo con recursos dedicados y ambientes de testing completos podría aportar mayor certeza. La recomendación que sigue debe considerarse en este contexto operativo.

### **Must-Haves Definitivos (Top 5)** (🚨 revisar y acordar)

1. **HA/DR multicluster** nativo.
Alta Disponibilidad y Recuperación ante Desastres (HA/DR) multicluster nativa y probada, con soporte para despliegues activos-activos o activos-pasivos entre sitios.
2. **Soporte OpenShift** sin vendor lock.
Compatibilidad certificada con OpenShift, sin dependencias propietarias ni lock-in con el proveedor o cloud específica.
3. **Arquitectura separada** Control/Data Plane
Arquitectura desacoplada de Control Plane y Data Plane, con capacidad de escalar y actualizar de forma independiente.
4. **Fixed pricing**.
Modelo de costos predecible (fixed pricing) para al menos 7.5B requests/mes en entornos internos, sin penalización por burst o crecimiento orgánico.
5. **Migración gradual** desde 3scale sin downtime.
Migración gradual y sin downtime desde 3scale, con coexistencia temporal de ambos gateways y preservación de tokens y analíticas.

---
## 5. Pendientes
### **Ranking Final** (🚨A Completar)
| Vendor | API MGMT / API GW | Must-Haves | Score | Recomendación |
|--------|------|---------|----------|---------------|
| **Red Hat Connectivity Link** | Gw | ?/5 ✅ | **STRONG** **BACKUP** **CONSIDER** | Continuidad segura |
| **Tyk** |  Both|  ?/5 ⚠️ | ? | Validar en demo 5-Nov |
| **Kong** | Both | ?/5 🚨  | ? | Solo si fixed pricing |
| **Traefik** | Gw | ?/5| ? | |

### **Decisión Ejecutiva Requerida**
1. **¿Priorizamos continuidad operativa o capacidades técnicas superiores?**
2. **¿Aceptamos riesgo de producto inmaduro (Connectivity Link v1.0) por migración asistida?**
3. **¿Autorizamos presupuesto adicional si fixed pricing excede presupuesto actual de 3Scale?**
4. **¿Procedemos sin pruebas de carga completas dado el timeline crítico?**
5. **¿Apostamos a vendor único o mantenemos strategy multi-vendor (internal vs external)?**
6. **¿Priorizamos soporte local vs capacidades técnicas superiores de vendors globales?**
7. **¿Aceptamos período de convivencia 3scale extendido si migración es más compleja?**

### **Próximos 30 días**
- **21 Nov**: Demo final Tyk (decisión go/no-go)
- **28 Nov**: Presentación recomendación final al Comité
- **5 Dic**: Aprobación y inicio proceso contractual
- **Dec-Jan**: Setup ambiente lab para migración piloto

**🚨 Action Required**: Decisión ejecutiva en 2 semanas para mantener timeline 2026. 