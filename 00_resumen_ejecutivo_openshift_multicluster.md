# 1. Resumen ejecutivo multicluster

La transformación prioritaria de plataforma no es un reemplazo puntual de APIM, sino la evolución desde un esquema monolítico a una arquitectura multicluster gobernada por dominios. APIM sigue siendo un frente relevante, pero su análisis se integra ahora en un marco transversal de decisiones por capacidad (red, seguridad, operación, observabilidad y continuidad), evitando que un único producto condicione toda la arquitectura objetivo. [2][25][34]

El estado actual mantiene riesgo sistémico: un cluster productivo de gran escala concentra cargas críticas y opera con alta dependencia de tickets, tareas manuales e integraciones interequipos para red, DNS, certificados, continuidad y cambios operativos. Esta combinación amplifica blast radius, restringe elasticidad real y estresa ventanas operativas. [3][4][11][13]

La arquitectura objetivo define una flota segmentada por criticidad y función, con patrón diferenciado north-south vs east-west, gobierno central de flota y operación day 0/day 1/day 2 declarativa mediante GitOps + IaC + perfiles de cluster versionados. El objetivo es escalar con menor impacto cruzado, reducir drift y sostener continuidad bancaria con mayor previsibilidad. [31][34][40][44]

## 1.1 Objetivos de reingenieria (marco comun)

Marco alineado con `02_multi-cluster/01_contexto_proposito/1.2_objetivo_de_la_reingenieria_de_plataforma.md`:

1. Escalabilidad y segmentacion.
2. Resiliencia y continuidad de negocio.
3. Seguridad integral.
4. Observabilidad y trazabilidad end-to-end.
5. Gobernanza y automatizacion operativa.
6. Portabilidad de workloads.
7. Preparacion para migracion a nube.
8. Minimizacion de vendor lock-in.

## 2. Situacion actual y brechas estructurales

### 2.1 Topologia y capacidad (as-is)

- Cluster productivo principal (`PAAS-PRDPG`) con orden de magnitud ~100 nodos, >10.000 pods y >600 namespaces. [3]
- Cluster productivo pasivo (`PAAS-PRDMZ`) en esquema DR/standby, con sincronizacion intersitio aun sensible a procesos manuales/pipeline. [3][14]
- Alta densidad en capa de exposicion: ~2.200 APIs y multiples ingress controllers sobre el entorno actual. [3][6]
- Volumen transaccional aproximado de referencia: ~8 mil millones de requests/mes, con predominio east-west (~7,5B) sobre north-south (~500M). [3][6]

### 2.2 Limitaciones tecnicas prioritarias

#### Modelo operativo

- Day 0 y Day 1 mantienen dependencia de tickets para prerequisitos de red, VIPs y DNS; Day 2 no esta completamente estandarizado y persiste manualidad en procesos criticos. [4][13]
- Persisten cuellos de coordinacion entre plataforma, tecnologia y seguridad para cambios clave de despliegue/migracion. [4][13]
- Ventanas de upgrade con baja elasticidad de calendario (incluyendo fines de semana) y necesidad explicita de guardias fuera de horario habil. [14][13]
- Gobierno tecnico incompleto de metadata (criticidad, patron de HA, dependencias externas), que limita automatizacion segura y continuidad por dominio. [8][16]

#### Escalabilidad, red y datos

- Escalado principal aun concentrado en el monolito, con overcommit reportado en capacidad. [12]
- Hair-pinning en recorridos internos agrega latencia y complejidad operativa en el caso dominante east-west. [5][12]
- APIM actual presenta limites para crecimiento de rutas/APIs y procesos no plenamente dinamicos/declarativos. [6][12]
- Persisten workloads con PV local sin estrategia uniforme de desacople; esto frena portabilidad real entre clusters. [7][12]
- Se reporta drift/consistencia inestable en bases externas de APIM (Oracle/Redis) bajo replicacion/conmutacion, con impacto potencial en disponibilidad efectiva. [6]

#### Seguridad y gobernanza

- Trazabilidad parcial de cambios en objetos de seguridad (RBAC, secretos, politicas) y dependencia de ejecucion manual en varios dominios. [8][16]
- Falta de taxonomia minima obligatoria para clasificar workloads y aplicar controles por criticidad, HA y dependencias. [8][16]
- Enforcement parcial de controles automatizados cuando el tagging tecnico es incompleto/inconsistente. [8][16]

#### Observabilidad y evidencia operativa

- Cobertura incompleta de trazabilidad end-to-end en flujos que atraviesan borde, ingress, APIM y servicios internos. [15]
- Incidentes recurrentes de alto volumen (ej. OFD) sin atribucion causal concluyente por falta de evidencia tecnica correlada. [15][5]
- Necesidad de observabilidad de red no intrusiva para reconstruir path real de requests y reducir MTTR. [15][60]

### 2.3 Diagrama topologico de referencia actual

#### Datacenter y perimetro

- Dos sitios principales (Plaza y Matriz) con red extendida y dependencias fuertes de componentes corporativos de red/seguridad. [3][5]
- Capa perimetral con Fortinet/WAF/F5 y controles de borde antes del ingreso a OCP/APIM. [5]

#### Flujos

- Cadena north-south observada: Fortinet -> WAF -> F5 DMZ -> Proxy Reversos -> F5 LAN -> ingress OCP -> APIM -> servicio. [5]
- Egress concentrado en IP publica unica con validaciones corporativas por origen/destino en firewall. [5]
- East-west con recorridos que salen y reingresan por balanceadores externos en parte del path, generando overhead operativo. [5][6]

#### Componentes criticos y evolucion

- Storage compartido y dependencias transversales con potencial efecto banco-wide ante falla/degradacion. [7][11]
- Base actual en OCP 4.16 con objetivo de evolucion a 4.20.x, condicionada por compatibilidades tecnicas y secuencia de upgrade. [42][46]
- Presion de ciclo de vida: transicion del dominio APIM antes de EOL de 3scale (2027). [6][33]

## 3. Arquitectura objetivo multicluster

### 3.1 Segmentacion de dominios y tipologia de clusters

El modelo objetivo segmenta por criticidad y funcion para reducir blast radius y desacoplar crecimiento: [34][20]

- Clusters de negocio para cargas aplicativas por dominio/tribu. [34]
- Clusters de servicios comunes para capacidades transversales (observabilidad, secretos, tooling de plataforma). [34][39][55]
- Clusters de gestion para gobierno de flota, politicas globales y lifecycle. [34][40]
- Coexistencia controlada de perfiles de cluster para soportar madurez heterogenea con enforcement minimo comun. [31][34]

### 3.2 Control plane, data plane y perfiles de cluster

- Gobierno multicluster central (hub-spoke) con control declarativo de politicas y ciclo de vida. [31][40]
- Data planes distribuidos por cluster/sitio con autonomia operativa ante perdida temporal del control plane. [40]
- Cluster profiles as code para baseline, guardrails y validacion day 0/day 1/day 2 segun criticidad/dominio. [31][40]
- GitOps distribuido por dominios funcionales para escalar ownership sin perder trazabilidad. [40][48]

### 3.3 Patrones de trafico objetivo

#### North-south (ingreso y exposicion)

- Arquitectura de tres capas: perimetro (DMZ), capa APIM/API Gateway robusta para gobierno L7 y capa de servicios internos. [35][26]
- Aplicacion de politicas L7 (authn/authz, cuotas, versionado, auditoria y telemetria transaccional) sin trasladar esa carga al trafico interno. [35][26]
- Seleccion de vendor abierta entre Gloo Gateway y Kong para north-south, con cierre por PoC, operabilidad y costo total. [26][32][33]
- Coexistencia controlada por fases con plataforma actual (3scale) para evitar migracion big-bang. [26][33]

#### East-west (comunicacion interna)

- Malla sidecarless para conectividad interna/intercluster, enfocada en reducir saltos y latencia. [36][27]
- Cilium se mantiene como opcion seleccionada/en evaluacion para dominio east-west multicluster, con validaciones tecnicas obligatorias. [27][33]
- Condicion de adopcion: pruebas de pod churn cross-cluster y escenarios de falla reales antes de go-live. [36][41]

### 3.4 Ingress/egress, DNS global y balanceo

- Ingreso estandarizado por dominio con trazabilidad de cambios y guardrails declarativos. [37][40]
- Automatizacion DNS por fases (External DNS + integracion corporativa) para reducir manualidad y drift. [28][37]
- F5 GTM como capacidad de evolucion cuando aplique; no condiciona el inicio de la transicion multicluster. [28]
- Objetivo operativo: failover mas rapido y predecible entre sitios con minima intervencion manual. [37][41]

### 3.5 Seguridad integral y gobierno tecnico

- IAM integrado con identidad corporativa, principio de minimo privilegio y segregacion de funciones. [38][54]
- RBAC/politicas/secretos declarativos con reconciliacion continua y evidencia auditable. [38][40][54]
- Migracion progresiva desde credenciales estaticas hacia identidad de workload (JWT/mTLS), con pilotos acotados y KPIs de adopcion. [30][38][54]
- Taxonomia tecnica obligatoria de workloads y perfiles de cluster para enforcement consistente de controles de seguridad/continuidad. [8][16][31]

### 3.6 Observabilidad federada y confiabilidad

- Federacion de metricas, logs y trazas con lectura unificada cross-cluster. [39][59]
- OpenTelemetry + eBPF como base para visibilidad de red/servicio y correlacion multi-capa. [39][60]
- Recuperar evidencia operativa en el borde y trazabilidad de path end-to-end para incidentes de alto volumen. [15][60]
- Definir SLI/SLO por dominio y tablero unico de salud tecnica para seguimiento ejecutivo. [39][63]

### 3.7 Datos, almacenamiento y portabilidad

- Evolucion desde persistencia local no portable hacia estrategias de desacople (object storage/buckets) en workloads elegibles. [7][44]
- Evaluar ODF compartido por dominio para reducir repeticion de stacks y complejidad operativa en flota. [7]
- Inventario y remediacion de PVs por dominio como prerequisito de migracion segura entre clusters. [7][44]

### 3.8 Modelo operativo objetivo

- GitOps + IaC como estandar de cambio para infraestructura, politicas y aplicaciones. [18][40]
- Automatizacion day 0/day 1/day 2 con controles de drift y validacion contra perfil esperado. [31][40][49]
- Self-service de plataforma para provision de entornos/servicios sobre templates y guardrails preaprobados. [49][50]
- Operating model plataforma-producto con ownership claro entre Platform Engineering, Seguridad, Redes/Comunicaciones, SRE/DevOps y equipos de producto. [48][53]

## 4. Decisiones arquitectonicas mas relevantes (problema -> decision -> beneficio)

| Problema estructural | Decisión arquitectónica | Beneficio esperado |
| --- | --- | --- |
| Riesgo sistémico por cluster único | Segmentación multicluster por dominio/criticidad | Reducción de blast radius y mejor continuidad [34][20] |
| Drift entre clusters/sitios | Perfilado declarativo de clusters (cluster profiles as code) | Menor variabilidad y gobierno operativo consistente [31][40] |
| Hair-pinning y latencia en tráfico interno | Malla sidecarless east-west (Cilium) | Menor latencia y menor dependencia de rutas externas [27][36] |
| Mezcla de objetivos L7 externos e internos | Separación north-south (APIM/API Gateway) vs east-west (mesh) | Gobierno L7 donde aporta valor y eficiencia interna [26][35] |
| Cierre prematuro de vendor gateway | Evaluación abierta Gloo/Kong con coexistencia por fases | Menor riesgo técnico/comercial y mejor decisión final [32][33] |
| Manualidad operativa en red/DNS | Automatización progresiva con External DNS + integración corporativa | Menor tiempo operativo y menor drift [28][37] |
| Persistencia local con baja portabilidad | Migración selectiva a object storage y storage compartido por dominio | Mayor movilidad de cargas y menor bloqueo técnico [7][44] |
| Seguridad con enforcement parcial | Taxonomía obligatoria + controles declarativos (IAM/RBAC/secretos/políticas) | Mejor cumplimiento y trazabilidad auditable [8][16][54] |
| Observabilidad fragmentada | OTel + eBPF + correlación multi-capa end-to-end | Mejor diagnóstico, menor MTTR y decisiones basadas en evidencia [15][39][60] |

## 5. Estrategia de evolucion multicluster (detalle por fases)

### 5.1 Fase fundacional: habilitadores de plataforma

Objetivo: establecer base comun para ejecutar la migracion sin incrementar riesgo. [40][44]

- Definir baseline de seguridad, observabilidad y gobierno tecnico por cluster. [18][38]
- Definir catalogo de perfiles de cluster y proceso formal de evolucion/aprobacion por dominio. [31][40]
- Formalizar repositorio de verdad para RBAC, politicas de red, ingreso/egreso y secretos. [40][54]
- Alinear day 0/day 1/day 2 con ownership y RACI por dominio tecnico. [4][48]
- Preparar estrategia de versiones/dependencias para ruta de upgrade OCP hacia 4.20.x. [42][46]
- Levantar inventario de PVs y plan de remediacion para portabilidad de workloads stateful. [7][44]

### 5.2 Fase de desacople de ingreso y transicion APIM

Objetivo: desacoplar rutas y habilitar migracion gradual sin cortes masivos. [35][44]

- Separar puntos de ingreso por funcion y criticidad durante la transicion. [35]
- Habilitar migracion selectiva con VIPs/CNAMEs por proyecto/dominio y rollback controlado. [35][37]
- Operar coexistencia controlada entre APIM actual y capa objetivo de gateway north-south. [26][33]
- Cerrar seleccion final Gloo/Kong con criterios integrales de seguridad, operabilidad y costo total. [26][32][33]

### 5.3 Fase de segmentacion operativa y gobierno de flota

Objetivo: pasar de operacion centralizada por excepcion a operacion por dominios con guardrails. [34][40]

- Activar control plane multicluster con data planes distribuidos. [34][40]
- Automatizar politicas globales y reconciliacion continua por dominio. [40][54]
- Integrar observabilidad federada para capacidad, performance, seguridad y continuidad. [39][59]
- Ejecutar upgrades por etapas con validaciones de riesgo sobre red/CNI y componentes criticos. [12][46]

### 5.4 Fase de movimiento de proyectos y cargas

Objetivo: redistribuir capacidad y reducir presion sobre el monolito sin refactor funcional prematuro. [44][52]

- Priorizar workloads HA-ready como primera ola de migracion. [43][44]
- Aplicar enfoque lift-and-reshape por oleadas, manteniendo coexistencia temporal origen/destino. [44]
- Reorganizar namespaces/cargas por criticidad y dependencias para aislar impacto. [34][52]
- Estandarizar templates y pipelines de movimiento automatizado. [49][53]

### 5.5 Fase de consolidacion de resiliencia

Objetivo: estabilizar operacion multicluster con recuperacion verificable. [20][41]

- Adoptar patrones activo-activo o activo-pasivo segun criticidad y soporte real del negocio/servicio. [20][34]
- Consolidar DNS global, balanceo y health checks multicapa para conmutacion predecible. [37][41]
- Definir RTO/RPO por dominio y validar periodicamente con drills representativos. [41][52]
- Asegurar recuperacion de estado/datos para cargas stateful, no solo redeploy de manifiestos. [7][41]

## 6. Topologia target consolidada

### 6.1 Vista logica

- Capa de gobierno multicluster (control plane) para politicas y ciclo de vida. [34][40]
- Capa de ejecucion distribuida (data planes) en clusters por dominio. [34]
- Capa north-south para exposicion externa y consumo legacy/core. [35]
- Capa east-west para comunicacion interna/intercluster y service discovery. [27][36]

### 6.2 Roles por tipo de cluster

- **Clusters de negocio:** ejecucion de servicios de dominio con SLO/SLA propios. [34][52]
- **Clusters de servicios comunes:** observabilidad, secretos y componentes compartidos. [39][55]
- **Clusters de gestion:** gobierno de flota, GitOps/IaC y politicas globales. [31][40]
- **Clusters especializados:** casos de uso con requerimientos tecnicos particulares. [34][42]

## 7. Plan de ejecucion high-level

### 7.1 Horizonte 2026-2027

- **Q1 2026:** cierre de arquitectura objetivo, taxonomia tecnica y modelo de gobierno de flota. [1][34][31]
- **Q2 2026:** implementacion de habilitadores multicluster y PoC criticas (mesh, gateway, seguridad, observabilidad). [33][36][44]
- **Q3-Q4 2026:** migracion progresiva por oleadas (dominios, namespaces, criticidad) con coexistencia controlada. [34][44]
- **Q4 2026:** consolidacion operativa de topologia objetivo en dominios priorizados. [34][41]
- **2027:** cierre de transicion APIM antes de EOL de 3scale, con vendor north-south ya definido y estabilizado. [6][33]

### 7.2 Entregables de control ejecutivo

- Arquitectura detallada aprobada por dominio y por capacidad. [1][34]
- Catalogo de cluster profiles as code con guardrails minimos day 0/day 1/day 2. [31][40]
- Matriz de dependencias y secuenciamiento tecnico de migracion. [31][44]
- Criterios de avance/no-go-live por fase y dominio. [41][44]
- Tablero de salud tecnica unificado por cluster/dominio. [39][63]
- Plan integrado de riesgos, mitigaciones y contingencia. [14][41]

## 8. Riesgos criticos y mitigaciones del programa multicluster

**Riesgo 1: inestabilidad en patrones cross-cluster criticos**  
Mitigacion: pruebas obligatorias de pod churn cross-cluster y escenarios de falla reales, con criterio de no-go-live. [36][41]

**Riesgo 2: complejidad de upgrade de plataforma y red**  
Mitigacion: ejecucion por etapas, validaciones tecnicas previas por dominio y gestion explicita de compatibilidades. [12][46]

**Riesgo 3: deriva de configuracion entre clusters/sitios**  
Mitigacion: baseline declarativo + perfiles de cluster versionados + reconciliacion continua por GitOps. [31][40]

**Riesgo 4: sobrecarga operativa durante coexistencia de modelos**  
Mitigacion: migracion por oleadas, scope acotado por fase, automatizacion de tareas repetitivas y runbooks reforzados. [13][44]

**Riesgo 5: brechas de seguridad en transicion de identidades/secretos**  
Mitigacion: migracion por dominio con pilotos acotados, segregacion de funciones, trazabilidad de cambios y retiro progresivo de credenciales estaticas. [30][38][54][55]

**Riesgo 6: brechas de observabilidad y evidencia operativa en borde/path**  
Mitigacion: instrumentacion por defecto en clusters nuevos, observabilidad de red no intrusiva y correlacion multi-capa de señales. [15][39][60][63]

**Riesgo 7: decision tardia o incompleta de API Gateway north-south**  
Mitigacion: evaluacion abierta Gloo/Kong con criterios integrales, hitos de cierre y coexistencia controlada con 3scale. [26][32][33]

## 9. Conclusion

La decision estructural central sigue siendo multicluster: reducir riesgo sistemico, sostener continuidad bancaria y habilitar crecimiento con menor complejidad marginal. El frente APIM se integra en esa estrategia como capacidad north-south critica, ya no como unica referencia de arquitectura. [20][25][34]

El exito del programa depende de ejecutar en secuencia: segmentacion por dominios, perfilado declarativo de clusters, automatizacion operativa end-to-end, observabilidad basada en evidencia y cierre disciplinado de decisiones tecnicas abiertas (incluyendo gateway north-south). Con esa ejecucion, la plataforma puede evolucionar desde un modelo concentrado/reactivo hacia uno distribuido, auditable y preparado para escala sostenida. [31][33][40][41][44]

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
