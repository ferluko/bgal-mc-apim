## Estado Actual del Proyecto

### Situación Crítica
- **Timeline**: Decisión requerida Q4 2025 (próximos 30 días)
- **3Scale End-of-Life**: Mediados 2027
- **Go-live objetivo**: Q4 2026

### Volumen de Negocio Actual
- **7.5B requests/mes** tráfico interno (East-West) - 80%
- **500M requests/mes** tráfico externo (North-South) - 20%
- **~2,200 APIs** en producción actual
- **Sin considerar trafico adicional de canary deployments**

## Evaluaciones Completadas

### 1. Kong - Limitaciones Identificadas
- **POC completa**
- **Fortalezas identificadas**:
  - Arquitectura sólida y moderna
  - Integración nativa con Kubernetes
  - Amplio ecosistema y comunidad activa
  - Flexibilidad para despliegues on-premise y cloud
  - Buen soporte de políticas y plugins personalizables
- **Problemas críticos**: 
  - Costos variables East-West muy altos.
  - Limitaciones técnicas en KIC -  Deprecacion de nginx como ingress.
  - Modelo de pricing problemático para tráfico interno.
  - Arquitectura Hybrid consolida cambios en un archivo de configuracion de gran tamano limita la escalabilidad.

### 2. Tyk - En Evaluación Activa
- **POC Entreprise pendiente**
- **Fortalezas identificadas**:
  - Fixed pricing model
  - Experiencia en open banking
  - Soporte multicluster nativo
  - Operador de K8s
  - Control Plane Hybrido pensado para multiclusters / multiregion
- **Limitaciones críticas**:
  - Sin soporte para Gateway API (en desarrollo)
  - Documentación limitada para despliegues complejos.
  - Integraciones con herramientas empresariales aún por validar.
  - Curva de aprendizaje.
  - Soporte en español y presencia local aún en desarrollo.
  - Poca madurez comprobada en implementaciones a gran escala en la región.

### 3. Red Hat Connectivity Link
- **POC On-Premises pendiente**
- **Fortalezas**: 
  - Migración asistida desde 3scale
  - HA nativo
  - Envoy API GW
  - Operador de K8s
  - Continuidad con Red Hat
- **Limitaciones críticas**:
  - Producto inmaduro (v1.0)
  - No resuelve API Management completo
  - Inadecuado para tráfico norte-sur
  - Precio por API Call
  - Vendor (Openshift) lock-in

### 4. Apigee - Descartado
- **Limitaciones**: Latencia alta, vendor lock, complejidad extrema
- **Sin fundaciones en GCP**: Problemático para arquitectura actual

### 5. Traefik Hub - Pruebas en Curso
- **Estado**: Evaluación en curso
- **Fortalezas identificadas**:
  - Costo-efectivo
  - Arquitectura moderna y cloud-native
  - Soporte nativo para Gateway API
  - Integración con múltiples backends
- **Limitaciones críticas**:
  - Algunas incosistencias de configuracion durante pruebas de estres.
  - Observabilidad pobre. Se deben desarrollar propios tableros de Grafana.
  - Soporte LATAM limitado
  - Pobre en capacidades Enterprise: Poca experiencia con clientes enterprise.

### 6. Cilium - Pruebas en Curso
- **Estado**: Pruebas activas en desarrollo
- **Tecnología**: Service Mesh sin sidecars y networking basado en eBPF
- **Contexto**: Evaluación de Cilium como CNI y como ingress (basado en Envoy) de OpenShift. Resuelve el aislamiento y gobernanza del trafico entre namespaces.
- **Fortalezas**: 
  - Certificado por RH
  - Super Observabilidad (coroot ejemplo)
  - Network Policies L7 (basado en entidades de k8s)_
  - Alto rendimiento - Menos saltos
  - Ahora es parte de Cisco

### 7. Solo.io - Candidato a Evaluar
- **Estado**: Identificado para evaluación
- **Base tecnológica**: Envoy Proxy Gateway
- **Razón de inclusión**: Alineado con el must-have actualizado. Fuerte en MQ de Gartner.
- **Próximos pasos**: Iniciar evaluación técnica y comercial

## Decisiones Clave / Must-Haves Definitivos

### Fundamentos
- Sostenibilidad financiera a largo plazo mediante esquemas de fixed pricing o costos predecibles, evitando sorpresas presupuestarias y permitiendo escalar sin penalizaciones.
- Sostenibilidad y escalabilidad de la solución a futuro.
- Flexibilidad tecnológica para incorporar nuevas capacidades y evolucionar junto al mercado.
- Seguridad, resiliencia y portabilidad en un entorno regulado.
- Priorizar experiencia developer y eficiencia operativa.
- Habilitar integración de capacidades de Inteligencia Artificial (IA/ML) para uso actual y futuro.

### Must-Haves 

1. **Soporte multicluster**
   - Despliegue y administración en múltiples clusters K8s
   - Alta disponibilidad (HA) entre regiones y datacenters
   - Failover y recuperación ante desastres entre clusters
   - Replicación y sincronización de configuraciones y políticas
   - Visibilidad y monitoreo centralizado de gateways multicluster

2. **Sin vendor Lock-in en OpenShift**
   - Compatibilidad certificada con OpenShift Container Platform
   - Sin dependencias propietarias que generen lock-in con el proveedor o cloud específica
   - Portabilidad entre entornos

3. **Fixed pricing**
   - Modelo de costos predecible y fijo
   - Sin penalización por burst o crecimiento orgánico
   - Crítico para 7.5B requests/mes en tráfico interno (East-West)

4. **Envoy Proxy Gateway**
   - Envoy como data plane del gateway: tecnología robusta y probada.
   - Estándar del mercado, respaldo de una comunidad activa e innovación constante.
   - Garantiza escalabilidad, observabilidad avanzada y máxima flexibilidad/integración.

5. **IA Gateway Ready** No es un must
   - Capacidad nativa o integrable para exponer, monitorear y gobernar modelos y APIs de inteligencia artificial (OpenAI, Anthropic, modelos internos, etc.) sobre el gateway.
   - Gobernanza, autenticación, autorización y observabilidad aplicadas al ciclo de vida de APIs de IA y LLM.
   - Soporte para inferencias sincronas y asincronas, manejo de cuotas y monitoreo de consumo.
   - Interoperabilidad con ecosistemas de IA/ML y soporte de políticas avanzadas (rate limiting por usuario, logging enriquecido, detección de abusos, etc.).

6. **Soporte nativo para K8s Gateway API**
   - Compatibilidad total con el estándar Gateway API de Kubernetes para gestión de tráfico L4/L7.
   - Permite integración directa con ecosistemas cloud native y futuros reemplazos de Ingress.
   - Posibilita definiciones declarativas, separación de roles (admin de infra vs. aprovisionadores de rutas) y mayor flexibilidad en escenarios multicluster.
   - Facilita la interoperabilidad y evita dependencias en implementaciones propietarias.

7. **Desacople de Control Plane y Data Plane**
   - Arquitectura separada entre Control Plane y Data Plane
   - Capacidad de escalar y actualizar de forma independiente
   - Data planes autónomos que funcionan independientemente si pierden conectividad con control plane
   - Depliegue Hybrid - Control Plane gestionado como SaaS o en nube publica. 

8. **Backends externos a Kubernetes:**
    - Exposición y gestión de servicios backends ubicados fuera del clúster de Kubernetes.
    - Soporte para la integración con backends en redes internas o publicas, funtions (ie. AWS Lambda), máquinas virtuales o servicios legacy externos.
    - Mecanismos recomendados: integración mediante ServiceEntry, definición explícita de upstreams externos, conectividad híbrida L3/L4, soporte para endpoints externos, con healthchecks y service discovery fuera de Kubernetes.

## Decisiones Ejecutivas Pendientes

1. ¿Priorizamos continuidad operativa o capacidades técnicas superiores?
2. ¿Aceptamos el riesgo de producto inmaduro (Connectivity Link v1.0), considerando potencial migración asistida?
3. ¿Procedemos sin pruebas de carga completas, dados los plazos críticos?
4. ¿Apostamos a vendor único o mantenemos una estrategia multi-vendor (internal vs external)?
5. ¿Autorizamos presupuesto adicional si el fixed pricing excede el presupuesto actual de 3scale?
6. ¿Priorizamos soporte local o capacidades técnicas superiores ofrecidas por vendors globales?
7. ¿Aceptamos un período de convivencia 3scale extendido si la migración resulta más compleja?
8. ¿Definimos una estrategia clara para la sincronización y migración manual de ~2500 aplicaciones ante la falta de capacidad declarativa en 3scale?
9. ¿Exigimos demostraciones o PoC específicas sobre manejo de tráfico interno (East-West) a escala y multicluster como condición clave?
10. ¿Requerimos como criterio obligatorio la compatibilidad total con Kubernetes Gateway API y portabilidad entre entornos?
11. ¿Validamos y priorizamos opciones de AI Gateway y capacidades de gobernanza de APIs de inteligencia artificial dentro del roadmap?
12. **¿Extendemos el timeline no negociable si alguna evaluación, vendor o tarea lo exige?**


## Próximos 30 Días Críticos

- Iniciar y documentar la evaluación técnica de Solo.io Gloo Gateway:
  - Se requiere gestionar contacto comercial para poder acceder las licencias demo.
  - Comparación de funcionalidades clave (K8s Gateway API, modelo de costos, integración IA, portabilidad multi-cloud)
  - Verificar compatibilidad y facilidad de despliegue en OpenShift
  - Levantar PoC mínima en el cluster dedicado para análisis de performance, gestión de políticas y escalabilidad

- Finalizar la configuración del cluster de pruebas dedicado, cuyo despliegue se completó el 25/11.
- Desplegar aplicaciones corporativas que incluyan un Single Page Application (SPA), Backend For Frontend (BFF) y backend con persistencia.
- Asegurar que todos los candidatos estén desplegados para realizar pruebas de performance y comparativas.


## Contingencia 3Scale en Progreso

### Arquitectura de Sincronización
- **Dos enfoques evaluados**:
  - Despliegue independiente paralelo
  - Despliegue secuencial (matriz primero)
- **Prueba en breve del despliegue independiente.**
- **Elementos críticos**: Productos, certificados, políticas, backends, persistencia.