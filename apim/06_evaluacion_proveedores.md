# APIM: Documento Técnico Consolidado
## Modernización de Infraestructura API - Banco Galicia

**Versión:** 1.0
**Fecha:** Enero 2026  
**Enfoque:** Técnico y Arquitectónico
**Author:** fernando.l.gonzalez@bancogalicia.com.ar

---
## 6. Evaluación de Proveedores

### Criterios de Evaluación

**Must-Haves Definitivos:**

1. **Soporte multiclúster**
   - Despliegue y administración en múltiples clusters K8s
   - Alta disponibilidad (HA) entre regiones y datacenters
   - Failover y recuperación ante desastres entre clusters
   - Replicación y sincronización de configuraciones y políticas
   - Visibilidad y monitoreo centralizado de gateways multiclúster

2. **Sin vendor Lock-in en OpenShift**
   - Compatibilidad certificada con OpenShift Container Platform
   - Sin dependencias propietarias que generen lock-in con el proveedor o cloud específica
   - Portabilidad entre entornos

3. **Fixed pricing**
   - Modelo de costos predecible y fijo
   - Sin penalización por burst o crecimiento orgánico
   - Crítico para 7.5B requests/mes en tráfico interno (East-West)

4. **Envoy Proxy Gateway**
   - Envoy como data plane del gateway: tecnología robusta y probada
   - Estándar del mercado, respaldo de una comunidad activa e innovación constante
   - Garantiza escalabilidad, observabilidad avanzada y máxima flexibilidad/integración

5. **Soporte nativo para K8s Gateway API**
   - Compatibilidad total con el estándar Gateway API de Kubernetes
   - Permite integración directa con ecosistemas cloud native
   - Facilita definiciones declarativas, separación de roles y mayor flexibilidad en escenarios multicluster

6. **Desacople de Control Plane y Data Plane**
   - Arquitectura separada entre Control Plane y Data Plane
   - Capacidad de escalar y actualizar de forma independiente
   - Data planes autónomos que funcionan independientemente si pierden conectividad con control plane
   - Depliegue Hybrid - Control Plane gestionado como SaaS o en nube pública

7. **Backends externos a Kubernetes**
   - Exposición y gestión de servicios backends ubicados fuera del clúster de Kubernetes
   - Soporte para integración con backends en redes internas o públicas, functions (ie. AWS Lambda), máquinas virtuales o servicios legacy externos

**Nice-to-Have:**
- IA Gateway Ready (capacidades para gobernanza de APIs de IA/ML)
- Developer portal avanzado
- Analytics y monetización

### Evaluación Detallada de Vendors

#### Solo.io (Gloo Mesh + Gloo Gateway) - CANDIDATO PRINCIPAL

**Fortalezas:**
- ✅ Arquitectura basada en Envoy (estándar de la industria)
- ✅ Service mesh multiclúster nativo
- ✅ Ambient mesh (reduce complejidad vs sidecars)
- ✅ Fixed pricing negociable
- ✅ Top contributor a Istio/Envoy
- ✅ Base open source (Istio/Envoy)
- ✅ Soporte para Gateway API
- ✅ Control plane híbrido (SaaS o on-premise)
- ✅ Backends externos a Kubernetes
- ✅ Fuerte en financial services

**Limitaciones:**
- ⚠️ Producto más nuevo (menor market presence que Kong)
- ⚠️ Soporte principalmente en inglés (US/Europa)
- ⚠️ Portal funcionalidad inmadura (releasing Marzo 2025)
- ⚠️ Curva de aprendizaje

**Estado:** Evaluación técnica activa, POC pendiente

#### Kong Enterprise

**Fortalezas:**
- ✅ Producto maduro con amplia comunidad
- ✅ Arquitectura sólida y moderna
- ✅ Integración nativa con Kubernetes
- ✅ Amplio ecosistema de plugins (90+)
- ✅ Referencias bancarias (Bradesco)
- ✅ Configuración declarativa vía CRDs
- ✅ Estrategia side-by-side para migración

**Limitaciones:**
- ❌ Costos variables East-West muy altos (pricing problemático)
- ❌ Limitaciones técnicas en KIC (deprecación de nginx como ingress)
- ❌ Arquitectura Hybrid consolida cambios en archivo de configuración de gran tamaño (limita escalabilidad)
- ❌ Sin built-in multi-cluster federation
- ⚠️ Soporte limitado en español
- ⚠️ Overhead de infraestructura significativo

**Estado:** POC completa, descartado por pricing

#### Red Hat Connectivity Link

**Fortalezas:**
- ✅ Integración nativa OpenShift
- ✅ HA nativo
- ✅ Envoy API GW
- ✅ Operador de K8s
- ✅ Continuidad con Red Hat
- ✅ Migración asistida desde 3scale
- ✅ 50% descuento primer año para migraciones 3scale
- ✅ Automatic DNS failover y HA

**Limitaciones:**
- ❌ Producto muy nuevo (v1.0, limitadas implementaciones en producción)
- ❌ No resuelve API Management completo
- ❌ Inadecuado para tráfico norte-sur
- ❌ Precio por API Call (problemático)
- ❌ Vendor (OpenShift) lock-in
- ❌ No puede mapear APIs externas como servicios internos
- ⚠️ Herramientas de migración automatizada en desarrollo (6-7/10 tasa de éxito actualmente)

**Estado:** POC on-premises pendiente, considerado como backup

#### Traefik Hub

**Fortalezas:**
- ✅ Gateway API native support
- ✅ Costo-efectivo
- ✅ Arquitectura moderna y cloud-native
- ✅ Fixed instance-based pricing
- ✅ Multi-cluster management console
- ✅ Integración con múltiples backends

**Limitaciones:**
- ❌ Algunas inconsistencias de configuración durante pruebas de estrés
- ❌ Observabilidad pobre (se deben desarrollar propios tableros de Grafana)
- ❌ Soporte LATAM limitado
- ❌ Pobre en capacidades Enterprise (poca experiencia con clientes enterprise)
- ❌ Certificación Red Hat incierta
- ⚠️ Herramientas de migración limitadas

**Estado:** Pruebas en curso, descartado por limitaciones enterprise

#### Tyk Enterprise

**Fortalezas:**
- ✅ Fixed pricing model
- ✅ Experiencia en open banking
- ✅ Soporte multiclúster nativo
- ✅ Operador de K8s
- ✅ Control Plane Híbrido pensado para multiclusters/multiregion

**Limitaciones:**
- ❌ Sin soporte para Gateway API (en desarrollo)
- ❌ Documentación limitada para despliegues complejos
- ❌ Integraciones con herramientas empresariales aún por validar
- ❌ Curva de aprendizaje
- ❌ Soporte en español y presencia local aún en desarrollo
- ❌ Poca madurez comprobada en implementaciones a gran escala en la región

**Estado:** Demo Enterprise pendiente, evaluación en curso

#### Cilium

**Fortalezas:**
- ✅ Certificado por Red Hat
- ✅ Super observabilidad (coroot ejemplo)
- ✅ Network Policies L7 (basado en entidades de k8s)
- ✅ Alto rendimiento - Menos saltos
- ✅ Ahora es parte de Cisco
- ✅ Service Mesh sin sidecars y networking basado en eBPF

**Limitaciones:**
- ⚠️ Evaluación como CNI y como ingress (basado en Envoy) de OpenShift
- ⚠️ No es solución completa de API Management
- ⚠️ Enfoque más en networking que en API Gateway

**Estado:** Pruebas activas en desarrollo, evaluación complementaria

### Tabla Comparativa

| Vendor | Multicluster | DR Automation | Declarative Config | Pricing Model | OpenShift Fit | 3scale Migration | Envoy Based | Gateway API | Risk Level |
|--------|-------------|---------------|-------------------|---------------|---------------|------------------|-------------|-------------|------------|
| **Solo.io/Gloo** | ✅ Native | ✅ Automated | ✅ Strong | Fixed (negociable) | ✅ Excellent | Coexistence | ✅ Yes | ✅ Yes | Medium |
| **Kong** | ⚠️ Limited | ⚠️ Manual | ✅ Strong | ❌ Variable (high) | ✅ Good | Side-by-side | ✅ Yes | ⚠️ Partial | Medium |
| **Connectivity Link** | ✅ Native | ✅ Automated | ✅ Strong | ❌ Per-call (high) | ✅ Excellent | ✅ Automated tools | ✅ Yes | ⚠️ Partial | High |
| **Traefik Hub** | ✅ Good | ⚠️ Manual | ✅ Good | ✅ Fixed | ✅ Good | ⚠️ Limited | ✅ Yes | ✅ Yes | High |
| **Tyk** | ✅ Good | ⚠️ Manual | ✅ Good | ✅ Fixed | ✅ Good | ⚠️ Manual | ❌ No | ❌ No (dev) | Medium-High |
| **Cilium** | ✅ Good | ⚠️ Manual | ✅ Good | ✅ Open Source | ✅ Excellent | ❌ N/A | ⚠️ Partial | ⚠️ Partial | Medium |

---


[← Volver al Índice](00_indice.md)
