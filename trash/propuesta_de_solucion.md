# OpenShift Multicluster – Propuesta de Solución Técnica

## Análisis Histórico: Temas Técnicos Recurrentes

### Limitaciones Críticas Actuales
- **Hardware insuficiente**: Cluster productivo al 210% overcommit, imposibilidad de crear nuevos clusters
- **Dependencias de red**: 3 semanas de demora por solicitudes a equipos de comunicaciones
- **Modelo operativo insostenible**: 95% del tiempo resolviendo incidentes vs desarrollo
- **Accesos descontrolados**: Múltiples equipos usando QB admin sin supervisión

### Drivers de Negocio Identificados
- **3Scale EOL**: Fin de soporte del API management actual fuerza migración
- **Adquisición bancaria**: Crecimiento planificado 30-40% requiere escalabilidad
- **Cumplimiento regulatorio**: Banco Central audita SLAs y contratos
- **Contingencia crítica**: Pruebas DRP obligatorias antes de marzo

---

## 1. Contexto, Alcance y Objetivos

### Contexto Organizacional
Banco Galicia opera un cluster OpenShift monolítico (100 nodos, 10,000 pods, 600 namespaces) que ha alcanzado límites operativos críticos. La estrategia multicluster busca resolver:

- **Escalabilidad**: Imposibilidad de crecimiento horizontal por limitaciones de hardware
- **Resiliencia**: Punto único de fallo en infraestructura crítica
- **Operación**: Modelo 7x24 insostenible con 95% tiempo en incidentes
- **Compliance**: Requisitos regulatorios de alta disponibilidad y auditoría

### Alcance Técnico
- **Clusters target**: 4-6 clusters especializados vs 1 monolítico
- **Cargas objetivo**: 2,000 servicios, 100 equipos de desarrollo, 1,000 desarrolladores
- **Criticidad**: Infraestructura core bancaria con SLA 99.9%+
- **Timeline**: Implementación Q2-Q4 2026

---

## 2. Principios de Arquitectura

### Principios Fundacionales
1. **Separación de responsabilidades**: Clusters especializados por función vs monolítico
2. **Automatización first**: Eliminar dependencias manuales de otros equipos
3. **Observabilidad nativa**: eBPF y métricas L4/L7 para troubleshooting
4. **Governance centralizada**: Políticas replicadas automáticamente
5. **Fallback capability**: Capacidad de rollback en cada decisión

### Trade-offs Críticos Identificados
- **Complejidad vs Resiliencia**: Multicluster añade complejidad operativa pero elimina puntos únicos de fallo
- **Automatización vs Control**: Reducir dependencias externas requiere invertir en automatización propia
- **Costo vs Disponibilidad**: Hardware adicional necesario para redundancia

---

## 3. Modelo de Arquitectura Multicluster

### 🔴 Fundacional: Topología de Clusters

**Cluster de Management (ACM)**
- **Propósito**: Orquestación y governance exclusivamente
- **Configuración**: 3+3 (masters+workers), sin ODF inicialmente
- **Acceso**: Usuario local + AD controlado, sin QB admin compartido

**Cluster de Servicios Compartidos**
- **Propósito**: ODF centralizado, observabilidad, herramientas DevOps
- **Justificación**: Consolidar servicios de infraestructura elimina cascadeo
- **Storage**: Proveedor único de PVs/buckets para clusters aplicativos

**Clusters Aplicativos Especializados**
- **Por criticidad**: Producción, staging, desarrollo
- **Por función**: APIs críticas, batch processing, laboratorio
- **Sin ODF local**: Consume storage del cluster de servicios

### Evidencia de Relevancia
- Problemas actuales con múltiples ODF: "Desgaste de tareas/troubleshooting, cada cluster requiere administración individual"
- Propuesta consolidada: "Cluster dedicado de ODF para proveer buckets y PVs a otros clusters"

---

## 4. Gestión Centralizada con Red Hat ACM

### 🔴 Fundacional: Nuevo ACM Productivo

**Problema Actual**
- ACM comprometido por accesos múltiples sin control
- Usuarios QB admin generando tokens sin supervisión
- Cualquiera con QB admin puede acceder a otros clusters

**Solución Propuesta**
- Nuevo ACM con usuario local para admin + usuarios AD controlados
- ACM actual mantenido solo para métricas de infraestructura
- Roles customizados vs cluster admin built-in

**Funcionalidades Core**
- Thanos para observabilidad centralizada de todos los clusters
- Governance y policy as code (actualmente no utilizado)
- Automation platform para orquestación

### Topología GitOps Hub-and-Spoke
- Control plane central con solo agentes en clusters destino
- 4 agentes por cluster: infra, PIM, aplicaciones, seguridad
- Separación de responsabilidades por tipo de workload

---

## 5. Estrategia GitOps

### 🟠 Altamente Recomendado: GitOps Centralizado

**Modelo Propuesto**
- Repositorios consistency: placement + aplicación
- Placement repository define dónde desplegar clusters
- Configuración global a nivel namespace
- Proceso declarativo vs manual actual

**Desafíos Identificados**
- Día 2: tareas previas en proyectos requieren proceso manual
- Creación de proyectos no declarativa actualmente
- Dependencias con otras divisiones limitan automatización

**Estrategia de Implementación**
- OpenShift GitOps modelo hub-and-spoke con CM central
- APP project objects y secrets para configuración
- Playbooks modernizados para deployment automatizado

---

## 6. Cluster de Servicios Compartidos

### 🔴 Fundacional: Consolidación de Servicios

**Justificación Técnica**
- "Cascadeo de servicios innecesario" en modelo actual
- Mala utilización de recursos con ODFs dedicados
- Costo operativo alto por mantenimiento múltiple

**Servicios Consolidados Propuestos**
- ODF centralizado como proveedor único de storage
- Observabilidad (Prometheus, Grafana, Loki)
- HashiCorp Vault corporativo
- Herramientas DevOps y APIs de infraestructura

**Benefits Operativos**
- Separación clara de responsabilidades
- Punto único para troubleshooting de infraestructura
- Clusters aplicativos dedicados solo a workloads de negocio

---

## 7. Networking Intercluster y Gestión de Tráfico

### 🟠 Altamente Recomendado: Service Mesh para East-West

**Problema Hair-pinning Crítico**
- Microservicios salen del cluster → load balancer externo → re-entran
- Patrón ineficiente identificado como limitación mayor
- 80% tráfico es east-west (B2C tenant actual de 3Scale)

**Solución Ambient Mesh**
- Istio Ambient Mesh GA en OpenShift 4.19/4.20
- Comunicación este-oeste vía egress/ingress gateways dedicados
- Eliminación completa del hairpinning pattern
- Control planes federados para service discovery global

**Arquitectura Propuesta**
- Red /24 específica para comunicación inter-cluster
- Authorization policies globales aplicadas una vez, replicadas
- Waypoints por namespace para funcionalidades L7
- East West Gateways exclusivos para tráfico inter-cluster

### Beneficios vs F5/Infoblox
- Evita dependencia de equipos de comunicaciones (3 semanas demora)
- "Service mesh propia administrada desde Kubernetes elimina dependencia de componentes externos"
- No requiere automatizaciones de red complejas

---

## 8. API Gateway y Exposición de Servicios

### 🟡 Opcional/Evolutivo: Diferenciación North-South vs East-West

**Estrategia Híbrida Identificada**
- **Consumidores internos**: Service mesh sin cargo por tráfico (80% actual)
- **Consumidores externos**: API management tradicional con monetización

**Evaluación Gloo Gateway**
- Licencia: USD $750,000 anuales para gateway+mesh
- Limitación crítica: portal no soporta multi-cluster out-of-box
- Cada portal requiere base de datos separada, no replica CRDs

**Problema 3Scale Actual**
- Método API key inseguro (Redis dependency, outages)
- Fin de soporte próximo año fuerza migración
- Actúa como firewall cortando trazas end-to-end

---

## 9. Seguridad, Aislamiento y Compliance

### 🔴 Fundacional: RBAC Multicluster

**Problema Crítico Actual**
- Usuarios shared admin sin resolución (8 meses)
- APIs sin seguridad adecuada, solo protegidas por NGINX con IPs
- Cualquiera con acceso puede modificar cluster

**Solución Propuesta**
- Perfil customizado con lifecycle para múltiples clusters
- Roles específicos por función vs cluster admin genérico
- Webhook controller para actualización automática de permisos

**Authorization Policies con Mesh**
- Namespace-based identity vs API keys estáticos
- Políticas como Kubernetes CRDs integradas con GitOps
- Layer 7 authorization (HTTP methods, paths de Swagger contracts)

---

## 10. Observabilidad y eBPF

### 🔴 Fundacional: Visibilidad End-to-End

**Problema Crítico Identificado**
- 3Scale/APIM actúa como firewall cortando trazas
- Imposibilidad de stitching entre múltiples traces
- Falta métricas L7 (HTTP requests, latency, error codes)

**Solución eBPF**
- Trabajo a nivel kernel para tracing completo
- Independiente de servicios intermedios
- Correlación entre todos los nodos del cluster
- Generación de mapa de servicios completo

**Tecnologías Evaluadas**
- Coroot: POC realizado, preocupación por origen ruso
- Service mesh nativo con OpenTelemetry integration
- "Análisis estacional y retrospectivo (42% tráfico primera semana del mes)"

---

## 11. Gestión de Imágenes y Supply Chain

### 🟡 Opcional/Evolutivo: Registry Corporativo

**Problema Actual**
- APIs se buildean sin pasar por proceso estándar
- Proceso manual e inconsistente
- Falta imagen corporativa estandarizada

**Solución con Jenkins Especializado**
- José Camacho desarrollando Jenkins para jobs de infraestructura
- Código en repo propio para testing
- Build process estándar para todos los componentes

---

## 12. Storage Persistente y Datos

### 🔴 Fundacional: ODF Centralizado

**Problemas Identificados**
- Mala utilización de recursos con discos estrechados innecesariamente
- Cajones compartidos con bases de datos impactan performance
- OpenShift sensible a latencia de disco
- Costo operativo alto por múltiples ODFs

**Propuesta de Consolidación**
- Cluster dedicado ODF provee buckets y PVs a otros clusters
- Consumo directo desde cajón de discos usando CSI driver VMware
- Separación clara entre clusters de servicios y aplicativos

**Análisis de Uso Actual**
- RWX (file storage): comunicación entre microservicios
- RWO (bloque): DataGrid, Redis, Prometheus, Loki
- Object storage: muy poco uso, potencial para cloud-native patterns

---

## 13. Backup, Restore y DR

### 🟠 Altamente Recomendado: Estrategia Multi-Site

**Contingencia Crítica**
- Pruebas DRP obligatorias antes de marzo 2026
- ACM actual: backup/restore como única estrategia
- Cluster stretch productivo con sincronización vía GitOps, no DB replication

**Arquitectura Propuesta**
- Clusters activo/standby con 120 nodos cada uno
- DNS-based failover con CNAMEs
- Validación diaria automática para evitar configuration drift

---

## 14. Automatización con Terraform y Ansible

### 🔴 Fundacional: Eliminación de Dependencies Manuales

**Problema Core**
- Dependencias de otros equipos generan demoras (3 semanas redes)
- "Playbooks de comunicaciones requieren desarrollo completo desde cero"
- Modelo manual no escala para múltiples clusters

**Solución Implementada**
- Playbook F5 automatizado completado en 2 horas con Cursor AI
- Tres tipos virtual server: API Kubernetes, Ingress, Gateway genérico
- Terraform standalone para deployment de clusters

**Terraform Cloud Integration**
- Repositorio Git como trigger automático
- TF vars contienen configuración del cluster
- Integración con Automation Platform corporativo

**F5 Automation**
- Health check HTTP/HTTPS nivel 7
- Monitores exclusivos por virtual server
- Creación automática de virtual servers, pools y monitores

---

## 15. Operación Day-2 y Troubleshooting

### 🔴 Fundacional: Modelo Operativo Sostenible

**Crisis Operativa Actual**
- Equipo no maneja producción real (8-20hs, problemas pasan a otros)
- 95% tiempo resolviendo incidentes vs roadmap
- Lifecycle y mantenimiento fuera de horario
- Falta conocimiento técnico en líderes

**Propuesta de Reestructuración**
- Separación clusters por criticidad permite especialización operativa
- Automatización Day-2 reduce carga manual
- Observabilidad eBPF mejora troubleshooting

**Políticas de Escalamiento**
- Problema réplicas estáticas en semana crítica
- Implementar operadores: CPU, memoria, tráfico, calendario
- Modalidad recomendaciones antes automatización completa

---

## 16. Riesgos, Trade-offs y Decisiones Técnicas

### Riesgos Críticos Identificados

**Migración SDN a OVN**
- "Requiere 2-3 reinicios del cluster, alto riesgo de fallo"
- Posible reconstrucción completa necesaria
- Usar como palanca para acelerar otras entregas

**Hardware Constraints**
- 14 BMware nuevos prometidos para marzo 2026
- Hardware actual 8 años antigüedad no compatible
- Estrategia: cluster nuevo → migrar → liberar viejo

**Organizational Challenges**
- Project requiere PM dedicado con conocimiento interno
- Falta sponsoreo nivel C-suite
- "Timelines propuestos totalmente irrealistas"

### Decisiones Técnicas Irreversibles

1. **Arquitectura Storage**: ODF centralizado vs distribuido
2. **Método Autenticación**: API keys vs mTLS vs namespace identity
3. **Service Mesh**: Istio Ambient vs alternativas vs no-mesh
4. **ACM Strategy**: Nuevo ACM limpio vs remediar actual

---

## 17. Roadmap Evolutivo

### Q1 2026: Fundacional
- 🔴 Hardware nuevo (14 BMware)
- 🔴 Nuevo ACM con accesos controlados
- 🔴 Cluster servicios con ODF centralizado
- 🔴 F5 automation completada

### Q2 2026: Core Functionality  
- 🟠 GitOps hub-and-spoke implementado
- 🟠 Service mesh POC en laboratorio
- 🟠 eBPF observabilidad en clusters críticos
- 🟡 Jenkins especializado para builds

### Q3 2026: Production Ready
- 🔴 Clusters aplicativos especializados
- 🟠 Service mesh en producción (este-oeste)
- 🟠 DRP testing en nueva arquitectura
- 🟡 API Gateway evaluation (north-south)

### Q4 2026: Optimization
- 🟡 Portal consolidado multi-cluster
- 🟡 Advanced policies y governance
- 🟢 Additional automation y tooling

---

## Conclusiones Técnicas

### Componentes Imprescindibles (🔴)
1. **Nuevo ACM** con accesos controlados - crítico para governance
2. **Cluster servicios consolidado** - elimina cascadeo y reduce complejidad operativa  
3. **ODF centralizado** - resuelve problemas actuales de storage y costo
4. **Automatización F5/Terraform** - elimina dependencies críticas de otros equipos
5. **Observabilidad eBPF** - visibilidad end-to-end para troubleshooting

### Componentes que Pueden Postergarse (🟡/🟢)
- Portal unificado multi-cluster (limitación vendor actual)
- API Gateway replacement (3Scale funciona hasta EOL)
- Advanced GitOps features (básico suficiente inicialmente)

### Decisiones Irreversibles
1. **Storage consolidado**: Una vez implementado, rollback complejo
2. **Service mesh adoption**: Cambio fundamental en arquitectura aplicativa
3. **Authentication method**: Impacta todas las aplicaciones simultáneamente

### Áreas que Requieren POC/Validación
- Service mesh ambient en producción bancaria
- Multi-cluster portal solutions  
- eBPF performance impact en clusters críticos
- Terraform automation completa end-to-end

La propuesta prioriza resolver las limitaciones operativas críticas actuales mientras construye fundación para escalabilidad futura, con enfoque en automatización y eliminación de dependencias externas que han demostrado ser cuellos de botella organizacionales.