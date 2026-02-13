---
ESTRUCTURA GENERAL

OBJETIVO DEL DOCUMENTO

El objetivo del presente documento es describir la situación actual del Banco Galicia en el uso y operación de la plataforma OpenShift. Mediante este análisis se identifican una serie de definiciones relacionadas a la evolución de esta tecnología y soportadas sobre las pruebas realizadas por el equipo en la investigación y desarrollo de nuevos paradigmas de uso y ejecución de microservicios. Como resultado final se detalla un plan de alto nivel de ejecución de iniciativas que permitirán alcanzar el objetivo final.

ALCANCE Y OBJETIVO

La reingeniería de nuestra plataforma OpenShift (OCP) tiene como objetivo rediseñar, modernizar y optimizar la arquitectura, los componentes y los procesos operativos que sostienen la estructura de contenedores del Banco Galicia. Esta iniciativa busca asegurar la escalabilidad futura para cubrir las necesidades de la organización, soportando el crecimiento de cargas críticas, los modelos multicluster y los requisitos de disponibilidad y resiliencia exigidos por la industria financiera.

El objetivo principal es evolucionar la plataforma desde su estado actual hacia un modelo que garantice 7 aspectos:

Mayor eficiencia operativa mediante automatización, estandarización y uso de un stack de tecnologías que construyan un framework.

Escalabilidad y elasticidad para soportar múltiples dominios de negocio y picos de transaccionalidad/demanda.

Alta disponibilidad y resiliencia mediante topologías multicluster y prácticas estándares de mercado que minimicen el impacto cruzado de fallas.

Reducir la complejidad técnica y eliminar componentes legacy sin evolución y con proyección de tecnologías fuera de soporte.

Mejorar la experiencia del desarrollo habilitando esquemas de seguridad y comunicación más controlados que permitan darle mejor trazabilidad al consumo de servicios internos como externos.

Fortalecer la postura de ciberseguridad bajo estándares de la industria bancaria.

Implementar capacidades de observabilidad integral para una operación más proactiva.
---

## 1. Resumen ejecutivo multicluster

La transformación prioritaria de plataforma no es el reemplazo puntual de APIM, sino la evolución desde un esquema monolítico hacia una arquitectura multicluster con gobierno central y operación desacoplada por dominios. APIM se utiliza como caso modelador para validar decisiones de red, seguridad, resiliencia y operación, que luego se extienden al resto de OpenShift. [2][34]

La situación actual concentra riesgo sistémico: un cluster productivo de gran escala soporta cargas críticas de múltiples líneas de negocio, con alto volumen transaccional y fuerte dependencia de procesos manuales para red, DNS, certificados, sincronización intersitio y continuidad. Este diseño amplifica blast radius, extiende ventanas de mantenimiento y limita la elasticidad real. [3][11][13]

La estrategia objetivo define una flota de clusters con responsabilidades claras, segmentación por criticidad y tipo de servicio, patrones diferenciados para tráfico north-south y east-west, y un modelo operativo GitOps + IaC para ciclo day 0/day 1/day 2. El beneficio esperado es reducir impacto cruzado, mejorar continuidad operativa y sostener crecimiento sin incrementar proporcionalmente la complejidad. [34][40][44]

## 2. Situación actual y brechas estructurales

### 2.1 Topología y capacidad (as-is)

- Cluster OpenShift monolítico de referencia: mas de 100 nodos, mas de 10.000 pods y mas de 600 namespaces. [3]
- Volumen transaccional aproximado: ~8 mil millones de requests/mes, con predominio east-west (~7,5B) sobre north-south (~500M). [3][6]
- Topología stretch entre Plaza (PGA) y Matriz (CMZ), con contingencia APIM en esquema activo-standby. [3][14]
- Alta densidad de exposición en capa de ingreso y APIM: reportes de múltiples ingress controllers y ~2.200 APIs productivas. [3][6]

### 2.2 Limitaciones técnicas prioritarias

#### Modelo operativo

- Alta manualidad en tareas recurrentes: alta/modificación de VIPs, DNS, certificados, sincronización entre sitios, DR y cambios de red. [4][13]
- Dependencia de tickets y coordinación interequipos para cambios críticos, con variabilidad en tiempos de ejecución. [4][13]
- Coexistencia de automatización parcial con procedimientos manuales en procesos de alto impacto. [4][13]

#### Escalabilidad

- Unidad principal de escalado concentrada en un cluster monolítico, con sobrecompromiso reportado en partes del entorno. [12]
- Limitaciones operativas de APIM actual para crecimiento de rutas/APIs y recargas no dinámicas. [6][12]
- Hair-pinning en tráfico interno que agrega latencia y penaliza escalabilidad transaccional. [5][12]

#### Impacto cruzado (blast radius)

- La falla de capacidad, red, storage o configuración puede propagarse en forma transversal a múltiples dominios. [11]
- Dependencias compartidas (balanceo, DNS, storage, identidad, APIM) elevan el impacto simultáneo en canales e integraciones. [11]
- Mayor complejidad de contención durante incidentes por concentración de cargas críticas en la misma base de plataforma. [11][13]

#### Mantenimiento, lifecycle y ventanas

- Ventanas de mantenimiento extensas por tamaño de cluster y secuencias de actualización por etapas. [12]
- Riesgo de deriva de configuración intersitio cuando la sincronización no es completamente declarativa. [13]
- Presión de ciclo de vida: OpenShift en rango 4.15-4.16 y objetivo de evolución a 4.20.x; 3scale con EOL en 2027. [6][46]

### 2.3 Diagrama topológico de referencia actual

#### Datacenter

- Dos sitios principales (Plaza y Matriz) con red extendida. [3][5]
- Capa perimetral con F5/Fortinet y componentes de seguridad de borde. [5]

#### Flujos

- North-south: Internet/partners/core/legacy -> DMZ -> ingreso OpenShift/APIM -> servicios. [5][6]
- East-west: en varios recorridos internos el tráfico sale y reingresa por balanceadores externos para resolver autorización/ruteo. [5][6]

#### Hardware y componentes críticos

- Dependencias de storage compartido y componentes transversales con efecto banco-wide ante falla. [7][11]
- Integración fuerte con componentes de red corporativa (DNS, balanceo, certificados). [5][13]

#### Versiones y evolución

- Base actual en 4.15-4.16, con objetivo de evolución de plataforma y CNI hacia 4.20.x. [42][46]
- Dependencias de compatibilidad (incluyendo storage) condicionan secuencia de upgrade. [7][46]

## 3. Arquitectura objetivo multicluster

### 3.1 Segmentación de dominios y tipología de clusters

El modelo objetivo propone segmentar por criticidad y función para reducir blast radius y desacoplar crecimiento: [34][20]

- Clusters de negocio para cargas aplicativas por tribu/dominio. [34]
- Cluster de servicios comunes para capacidades transversales (observabilidad, secretos, herramientas de plataforma). [34]
- Clusters de gestión y gobierno para operación multicluster, políticas globales y ciclo de vida. [34]
- Separación explícita entre servicios críticos y no críticos. [34]

Como referencia de escala, se plantea evolución desde el cluster monolítico hacia una flota cercana a 30 clusters totales, con 7-8 productivos según madurez del programa. [34][42]

### 3.2 Modelo de control plane y data plane

- Gobierno central multicluster en topología hub-spoke (por ejemplo ACM), con políticas y ciclo de vida controlados desde repositorios versionados. [40][31]
- Data planes distribuidos por cluster/sitio con autonomía operativa ante pérdida temporal de conectividad al control plane. [40]
- Distribución de GitOps por dominios funcionales (infra, seguridad/RBAC, aplicaciones, middleware/APIs) para escalar ownership sin perder control. [40][48]

### 3.3 Patrones de tráfico objetivo

#### North-south (ingreso y exposición)

- Arquitectura de tres capas: perímetro (DMZ), API Gateway para gobierno L7 y capa de servicios internos. [35]
- Considera como north-south también consumo desde legacy/core hacia APIs alojadas en OpenShift. [35][26]
- Capacidades esperadas: OAuth2/JWT, mTLS, rate limiting, cuotas, versionado, telemetría transaccional y auditoría. [35][26]

#### East-west (comunicación interna)

- Malla sidecarless para comunicación interna e intercluster. [36][27]
- Decisión vigente: Cilium Mesh para dominio east-west multicluster. [36][33]
- Beneficios esperados: eliminación de hair-pinning, menor latencia, menor complejidad de red, mejor troubleshooting y mayor aislamiento de fallas. [36]
- Condición de adopción: pruebas obligatorias de pod churn cross-cluster antes de go-live. [36][41]

### 3.4 Ingress/egress, DNS global y balanceo

- Ingreso estandarizado por entorno y dominio; egress con políticas explícitas y trazabilidad. [37]
- DNS global con health checks para distribución de tráfico entre clusters. [37]
- Automatización de actualizaciones DNS (por ejemplo external-dns) e integración con balanceo global (F5/Infoblox). [37][28]
- Objetivo operativo: conmutación rápida entre sitios con mínima intervención manual. [37][41]

### 3.5 Seguridad integral multicluster

- IAM integrado con identidad corporativa y principio de mínimo privilegio. [38][54]
- RBAC declarativo por repositorio, reconciliación continua y segregación de funciones. [38][54]
- Migración desde credenciales estáticas hacia mecanismos con expiración y revocación (OAuth2/JWT + mTLS). [38][54]
- Vault como backend de secretos con sincronización controlada en Kubernetes. [38][55]
- Políticas de red por defecto deny, controles explícitos de comunicación y egress. [38][56]

### 3.6 Observabilidad federada y confiabilidad

- Federación de métricas, logs y trazas para lectura unificada cross-cluster. [39][59]
- OpenTelemetry como patrón transversal y eBPF para visibilidad de red/mesh y mapeo de dependencias reales. [39][60]
- Definición de SLI/SLO por servicio y dominio, con umbrales y ownership explícitos. [39][63]
- Integración de alertado, incident response y postmortems en una misma disciplina operativa. [39][62]

### 3.7 Modelo operativo objetivo

- GitOps + IaC como estándar de cambio para infraestructura, políticas y aplicaciones. [40][18]
- Automatización day 0/day 1/day 2 para reducir tareas manuales recurrentes y drift. [40][49]
- Self-service con templates de plataforma para provisión de entornos, onboarding técnico y despliegue con guardrails. [49][50]
- Operating model de plataforma-producto con roles claros: Platform Engineering, Seguridad, Redes/Comunicaciones, SRE/DevOps y equipos de producto. [48][53]

## 4. Decisiones arquitectónicas más relevantes (problema -> decisión -> beneficio)

| Problema estructural | Decisión arquitectónica | Beneficio esperado |
| --- | --- | --- |
| Concentración de riesgo en cluster único | Segmentación multicluster por dominio/criticidad | Reducción de blast radius y mejor continuidad [34][20] |
| Hair-pinning y latencia en tráfico interno | Malla sidecarless east-west (Cilium Mesh) | Menor latencia y menor dependencia de red legacy [36][27] |
| Mezcla de necesidades externas e internas en APIM | Separación north-south (API Gateway) vs east-west (mesh) | Gobierno L7 donde aporta valor, eficiencia en tráfico interno [35][26] |
| Manualidad operativa y drift entre sitios | GitOps + IaC + control multicluster centralizado | Cambios auditables, repetibles y con rollback [40][18] |
| Seguridad basada en credenciales estáticas | Identidad de workload, RBAC declarativo, Vault, mTLS | Mejor cumplimiento, revocación efectiva y trazabilidad [38][54][55] |
| Observabilidad fragmentada | Observabilidad federada con OTel + eBPF | Diagnóstico end-to-end y reducción de MTTR [39][29][60] |
| DR con alta intervención manual | DNS global + health checks + runbooks/drills + automatización progresiva | Mejor RTO efectivo y menor variabilidad operativa [41][37] |

## 5. Estrategia de evolución multicluster (detalle por fases)

### 5.1 Fase fundacional: habilitadores de plataforma

Objetivo: establecer base común para ejecutar la migración sin incrementar riesgo. [44][40]

- Definir baseline de seguridad, observabilidad y gobierno técnico por cluster. [18][38]
- Formalizar repositorio de verdad para RBAC, políticas de red, configuración de ingreso/egreso y secretos. [40][54]
- Alinear modelo day 0/day 1/day 2 con ownership y RACI por dominio. [48][40]
- Preparar estrategia de versiones y dependencias para ruta de upgrade OCP hacia 4.20.x. [46][42]

### 5.2 Fase de sharding de ingreso y desacople de flujos

Objetivo: desacoplar rutas y permitir transición gradual sin cortes masivos. [35][44]

- Separar puntos de ingreso por función durante transición (gestión OCP, rutas actuales, gateway interno, API management externo). [35]
- Habilitar migración selectiva con VIPs/CNAMEs por proyecto, evitando switcheo total. [35][37]
- Mantener coexistencia controlada entre modelo actual y destino, con validación automática para evitar drift. [40][44]

### 5.3 Fase de segmentación operativa y gobierno

Objetivo: pasar de operación centralizada por excepción a operación por dominios con guardrails. [34][40]

- Activar control plane central multicluster con data planes distribuidos. [34][40]
- Estandarizar APIM/API Gateway como capacidad north-south multitenant por necesidad de dominio. [35][26]
- Automatizar RBAC y políticas globales con reconciliación continua. [54][40]
- Ejecutar upgrades por etapas (control plane/componentes core y luego pools de cómputo), con pruebas de riesgo sobre migraciones de red/CNI. [46][12]
- Fortalecer continuidad con ejercicios DRP periódicos, runbooks y criterios de no-go-live. [41][14]

### 5.4 Fase de movimiento de proyectos y cargas

Objetivo: redistribuir capacidad y reducir presión sobre el monolito sin refactor funcional prematuro. [44][52]

- Identificar aplicaciones HA-ready como primera ola de migración. [44][43]
- Aplicar enfoque lift-and-reshape por dominios y oleadas, con coexistencia temporal origen/destino. [44]
- Reorganizar namespaces y cargas por criticidad/función para aislar impacto. [34][52]
- Estandarizar templates de aplicación y pipelines de movimiento automatizado. [53][49]
- Ejecutar switcheo progresivo de tráfico con rollback controlado. [44][37]

### 5.5 Fase de consolidación de patrones de alta disponibilidad

Objetivo: estabilizar operación multicluster con capacidad de recuperación verificable. [41][20]

- Adoptar modelos activo-activo o activo-pasivo según criticidad y naturaleza del servicio. [41]
- Integrar DNS global, balanceo y health checks multicapa para conmutación controlada. [37][41]
- Definir RTO/RPO por dominio de negocio y validar con drills representativos. [41][52]
- Asegurar recuperación de estado y datos para cargas stateful, no solo redeploy de manifiestos. [41][7]

## 6. Topología target consolidada

### 6.1 Vista lógica

- Capa de gobierno multicluster (control plane) para políticas y ciclo de vida. [34][40]
- Capa de ejecución distribuida (data planes) en clusters por dominio. [34]
- Capa de ingreso north-south para exposición externa y canales/core/legacy. [35]
- Capa de comunicación east-west para tráfico interno/intercluster. [36]

### 6.2 Roles por tipo de cluster

- **Clusters de negocio:** ejecución de servicios de dominio con SLO/SLA propios. [34][52]
- **Clusters de servicios comunes:** observabilidad, secretos, componentes compartidos. [39][55]
- **Clusters de gestión:** gobierno de flota, GitOps/IaC, políticas globales. [40][31]
- **Clusters especializados:** casos de uso específicos con requisitos técnicos particulares. [34][42]

## 7. Plan de ejecución high-level

### 7.1 Horizonte 2026-2027

- **Q1 2026:** cierre de definiciones de arquitectura objetivo y gobierno de ejecución. [1][34]
- **Q2 2026:** implementación de habilitadores multicluster, POC de hardening/performance y validación de escenarios críticos. [44][36][33]
- **Q3-Q4 2026:** migración progresiva por oleadas (dominios, namespaces, criticidad), con pilotos y expansión controlada. [44][34]
- **Q4 2026:** consolidación operativa de la nueva topología para dominios priorizados. [34][41]
- **2027:** cierre de transición del dominio APIM antes de EOL de 3scale. [6][33]

### 7.2 Entregables de control ejecutivo

- Arquitectura detallada aprobada por dominio. [1][34]
- Matriz de dependencias y secuenciamiento técnico. [44][31]
- Criterios de avance/no-go-live por fase. [41][44]
- Tablero de salud técnica por cluster y dominio. [63][39]
- Plan integrado de riesgos, mitigaciones y contingencia. [14][41]

## 8. Riesgos críticos y mitigaciones del programa multicluster

**Riesgo 1: inestabilidad en patrones cross-cluster críticos**  
Mitigación: pruebas obligatorias de pod churn cross-cluster en POC/staging/preproducción, más criterio de no-go-live si no hay estabilidad consistente. [36][41]

**Riesgo 2: complejidad de upgrade de plataforma y red**  
Mitigación: ejecución por etapas, validaciones técnicas previas por dominio, gestión explícita de dependencias de compatibilidad. [46][12]

**Riesgo 3: deriva de configuración entre clusters/sitios**  
Mitigación: baseline declarativo, reconciliación continua por GitOps y controles de drift como parte del monitoreo operativo. [40][18]

**Riesgo 4: sobrecarga operativa durante coexistencia de modelos**  
Mitigación: migración por oleadas, scope limitado por fase, automatización de tareas repetitivas y reforzamiento de runbooks. [44][13]

**Riesgo 5: brechas de seguridad en transición de identidades/secretos**  
Mitigación: plan de migración por dominio, separación de funciones, trazabilidad de cambios y eliminación gradual de credenciales estáticas. [38][54][55]

**Riesgo 6: brechas de observabilidad en operación federada**  
Mitigación: instrumentación por defecto en clusters nuevos, catálogo único de indicadores y correlación de señales de aplicación/plataforma/red. [39][59][60][63]

## 9. Conclusión

La transformación multicluster es la decisión estructural central para sostener continuidad bancaria, escalar capacidades y reducir riesgo sistémico. El reemplazo de APIM es un frente relevante dentro de esa transformación, pero no su objetivo final. [34][20]

El éxito depende de ejecutar en secuencia: segmentación por dominios, automatización operativa end-to-end, gobierno técnico central con autonomía de data planes, y validación estricta de resiliencia en escenarios reales. Este enfoque permite pasar de una plataforma concentrada y reactiva a una arquitectura distribuida, auditable y preparada para crecimiento sostenido. [40][41][44]

## 10. Referencias a documentación detallada (@arquitectura)

### 10.1 Índice y visión general

- [1] [Índice estratégico de reingeniería](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/indice_tentativo.md)
- [2] [Visión y estrategia multicluster](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md)

### 10.2 Estado actual y diagnóstico (as-is)

- [3] [3.1 Topología actual y capacidad instalada](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md)
- [4] [3.2 Modelo operativo (día 0, día 1, día 2)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md)
- [5] [3.3 Networking, ingress/egress y exposición de servicios](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md)
- [6] [3.4 Gestión de APIs y estado de APIM](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md)
- [7] [3.5 Almacenamiento y servicios de datos](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.5_almacenamiento_y_servicios_de_datos.md)
- [8] [3.6 Seguridad actual (IAM/RBAC, secretos, cifrado, políticas)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.6_seguridad_actual_iam_rbac_secretos_cifrado_politicas.md)
- [9] [3.7 Observabilidad y monitoreo actual](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.7_observabilidad_y_monitoreo_actual.md)
- [10] [3.8 Costos operativos y de licenciamiento actuales](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.8_costos_operativos_y_de_licenciamiento_actuales.md)
- [11] [4.1 Riesgo sistémico y blast radius](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md)
- [12] [4.2 Límites de escalabilidad y elasticidad](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.2_limites_de_escalabilidad_y_elasticidad.md)
- [13] [4.3 Complejidad operativa y tareas manuales](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md)
- [14] [4.4 Brechas de resiliencia y recuperación ante desastres](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md)
- [15] [4.5 Brechas de observabilidad y trazabilidad end-to-end](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.5_brechas_de_observabilidad_y_trazabilidad_end_to_end.md)
- [16] [4.6 Brechas de seguridad y gobierno técnico](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.6_brechas_de_seguridad_y_gobierno_tecnico.md)
- [17] [4.7 Complejidad heredada y fricción para equipos](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.7_complejidad_heredada_legacy_y_friccion_para_equipos_de_desarrollo.md)

### 10.3 Arquitectura objetivo y decisiones

- [18] [5.1 Estandarización y automatización por defecto](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.1_estandarizacion_y_automatizacion_por_defecto.md)
- [19] [5.2 Escalabilidad horizontal y elasticidad](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.2_escalabilidad_horizontal_y_elasticidad.md)
- [20] [5.3 Resiliencia multicluster y alta disponibilidad](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md)
- [21] [5.4 Seguridad by design y zero trust](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.4_seguridad_by_design_y_zero_trust.md)
- [22] [5.5 Observabilidad integral y operabilidad](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.5_observabilidad_integral_y_operabilidad.md)
- [23] [5.6 Portabilidad, desacople y minimización de vendor lock-in](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.6_portabilidad_desacople_y_minimizacion_de_vendor_lock_in.md)
- [24] [5.7 Simplicidad operativa y reducción de complejidad técnica](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.7_simplicidad_operativa_y_reduccion_de_complejidad_tecnica.md)
- [25] [6.1 Marco de evaluación y criterios comparativos](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.1_marco_de_evaluacion_y_criterios_comparativos.md)
- [26] [6.2 Alternativas de API Management y API Gateway](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.2_alternativas_de_api_management_y_api_gateway.md)
- [27] [6.3 Alternativas de service mesh para tráfico este-oeste](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.3_alternativas_de_service_mesh_para_trafico_este_oeste.md)
- [28] [6.4 Alternativas de networking y service discovery](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.4_alternativas_de_networking_y_service_discovery.md)
- [29] [6.5 Alternativas de observabilidad (métricas, logs, trazas, eBPF)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.5_alternativas_de_observabilidad_metricas_logs_trazas_ebpf.md)
- [30] [6.6 Alternativas de gestión de secretos e identidad](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.6_alternativas_de_gestion_de_secretos_e_identidad.md)
- [31] [6.7 Alternativas de operación multicluster y gobierno de flota](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.7_alternativas_de_operacion_multicluster_y_gobierno_de_flota.md)
- [32] [6.8 Evaluación de trade-offs técnicos/operativos/económicos/riesgo](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.8_evaluacion_de_trade_offs_tecnicos_operativos_economicos_riesgo.md)
- [33] [6.9 Recomendación tecnológica por dominio](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.9_recomendacion_tecnologica_por_dominio.md)
- [34] [7.1 Modelo multicluster objetivo y segmentación de dominios](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md)
- [35] [7.2 Patrón norte-sur (ingreso, exposición y gobierno de APIs)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md)
- [36] [7.3 Patrón este-oeste (malla y seguridad de comunicación)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.3_patron_este_oeste_malla_de_servicios_y_seguridad_de_comunicacion.md)
- [37] [7.4 Arquitectura de ingress/egress y DNS global](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md)
- [38] [7.5 Modelo de seguridad integral](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.5_modelo_de_seguridad_integral_iam_rbac_secretos_cifrado_politicas.md)
- [39] [7.6 Observabilidad federada multicluster](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md)
- [40] [7.7 Modelo operativo GitOps + IaC](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md)
- [41] [7.8 Patrones de resiliencia, failover y continuidad](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md)

### 10.4 Evolución, operación y ejecución

- [42] [8.1 Estrategia híbrida on-premise + cloud](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.1_estrategia_hibrida_on_premise_cloud.md)
- [43] [8.2 Criterios de elegibilidad y priorización de workloads](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.2_criterios_de_elegibilidad_y_priorizacion_de_workloads.md)
- [44] [8.3 Enfoque de migración progresiva con mínimo refactor](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md)
- [45] [8.4 Interoperabilidad entre plataformas y entornos](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.4_interoperabilidad_entre_plataformas_y_entornos.md)
- [46] [8.5 Dependencias críticas para adopción cloud](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.5_dependencias_criticas_para_adopcion_cloud.md)
- [47] [8.6 Estrategia de salida y reemplazabilidad tecnológica](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.6_estrategia_de_salida_y_reemplazabilidad_tecnologica.md)
- [48] [9.1 Operating model de plataforma](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md)
- [49] [9.2 Self-service y automatización de provision](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.2_self_service_y_automatizacion_de_provision.md)
- [50] [9.3 Framework tecnológico estandarizado para equipos](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.3_framework_tecnologico_estandarizado_para_equipos.md)
- [51] [9.4 Prácticas de entrega segura (CI/CD y gobernanza)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.4_practicas_de_entrega_segura_cicd_controles_gobernanza.md)
- [52] [9.5 Gestión de capacidad, SLO/SLA y operación continua](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.5_gestion_de_capacidad_slo_sla_y_operacion_continua.md)
- [53] [9.6 Mejora de developer experience y productividad](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.6_mejora_de_developer_experience_y_productividad.md)

### 10.5 Seguridad, cumplimiento y observabilidad

- [54] [10.1 Gobierno de identidades y accesos multicluster](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.1_gobierno_de_identidades_y_accesos_multicluster.md)
- [55] [10.2 Gestión de secretos y credenciales](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.2_gestion_de_secretos_y_credenciales.md)
- [56] [10.3 Hardening de plataforma y seguridad de red](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.3_hardening_de_plataforma_y_seguridad_de_red.md)
- [57] [10.4 Trazabilidad, auditoría y evidencias regulatorias](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.4_trazabilidad_auditoria_y_evidencias_regulatorias.md)
- [58] [10.5 Gestión de vulnerabilidades y seguridad de cadena de suministro](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.5_gestion_de_vulnerabilidades_y_seguridad_de_cadena_de_suministro.md)
- [59] [11.1 Arquitectura de telemetría (métricas, logs, trazas, eventos)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.1_arquitectura_de_telemetria_metricas_logs_trazas_eventos.md)
- [60] [11.2 Observabilidad de red y servicios (incluyendo eBPF)](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.2_observabilidad_de_red_y_servicios_incluyendo_ebpf.md)
- [61] [11.3 Monitoreo de experiencia de aplicación y dependencias](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.3_monitoreo_de_experiencia_de_aplicacion_y_dependencias.md)
- [62] [11.4 Alertado, respuesta a incidentes y postmortems](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.4_alertado_respuesta_a_incidentes_y_postmortems.md)
- [63] [11.5 Indicadores de salud técnica por cluster y dominio](https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.5_indicadores_de_salud_tecnica_por_cluster_y_por_dominio.md)

[1]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/indice_tentativo.md
[2]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md
[3]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md
[4]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md
[5]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md
[6]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md
[7]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.5_almacenamiento_y_servicios_de_datos.md
[8]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.6_seguridad_actual_iam_rbac_secretos_cifrado_politicas.md
[9]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.7_observabilidad_y_monitoreo_actual.md
[10]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.8_costos_operativos_y_de_licenciamiento_actuales.md
[11]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md
[12]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.2_limites_de_escalabilidad_y_elasticidad.md
[13]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md
[14]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md
[15]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.5_brechas_de_observabilidad_y_trazabilidad_end_to_end.md
[16]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.6_brechas_de_seguridad_y_gobierno_tecnico.md
[17]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.7_complejidad_heredada_legacy_y_friccion_para_equipos_de_desarrollo.md
[18]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.1_estandarizacion_y_automatizacion_por_defecto.md
[19]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.2_escalabilidad_horizontal_y_elasticidad.md
[20]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md
[21]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.4_seguridad_by_design_y_zero_trust.md
[22]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.5_observabilidad_integral_y_operabilidad.md
[23]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.6_portabilidad_desacople_y_minimizacion_de_vendor_lock_in.md
[24]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.7_simplicidad_operativa_y_reduccion_de_complejidad_tecnica.md
[25]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.1_marco_de_evaluacion_y_criterios_comparativos.md
[26]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.2_alternativas_de_api_management_y_api_gateway.md
[27]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.3_alternativas_de_service_mesh_para_trafico_este_oeste.md
[28]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.4_alternativas_de_networking_y_service_discovery.md
[29]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.5_alternativas_de_observabilidad_metricas_logs_trazas_ebpf.md
[30]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.6_alternativas_de_gestion_de_secretos_e_identidad.md
[31]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.7_alternativas_de_operacion_multicluster_y_gobierno_de_flota.md
[32]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.8_evaluacion_de_trade_offs_tecnicos_operativos_economicos_riesgo.md
[33]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.9_recomendacion_tecnologica_por_dominio.md
[34]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md
[35]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md
[36]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.3_patron_este_oeste_malla_de_servicios_y_seguridad_de_comunicacion.md
[37]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md
[38]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.5_modelo_de_seguridad_integral_iam_rbac_secretos_cifrado_politicas.md
[39]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md
[40]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md
[41]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md
[42]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.1_estrategia_hibrida_on_premise_cloud.md
[43]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.2_criterios_de_elegibilidad_y_priorizacion_de_workloads.md
[44]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md
[45]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.4_interoperabilidad_entre_plataformas_y_entornos.md
[46]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.5_dependencias_criticas_para_adopcion_cloud.md
[47]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.6_estrategia_de_salida_y_reemplazabilidad_tecnologica.md
[48]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md
[49]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.2_self_service_y_automatizacion_de_provision.md
[50]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.3_framework_tecnologico_estandarizado_para_equipos.md
[51]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.4_practicas_de_entrega_segura_cicd_controles_gobernanza.md
[52]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.5_gestion_de_capacidad_slo_sla_y_operacion_continua.md
[53]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.6_mejora_de_developer_experience_y_productividad.md
[54]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.1_gobierno_de_identidades_y_accesos_multicluster.md
[55]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.2_gestion_de_secretos_y_credenciales.md
[56]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.3_hardening_de_plataforma_y_seguridad_de_red.md
[57]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.4_trazabilidad_auditoria_y_evidencias_regulatorias.md
[58]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.5_gestion_de_vulnerabilidades_y_seguridad_de_cadena_de_suministro.md
[59]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.1_arquitectura_de_telemetria_metricas_logs_trazas_eventos.md
[60]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.2_observabilidad_de_red_y_servicios_incluyendo_ebpf.md
[61]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.3_monitoreo_de_experiencia_de_aplicacion_y_dependencias.md
[62]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.4_alertado_respuesta_a_incidentes_y_postmortems.md
[63]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.5_indicadores_de_salud_tecnica_por_cluster_y_por_dominio.md
