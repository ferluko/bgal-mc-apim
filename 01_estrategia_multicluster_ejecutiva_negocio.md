# OCP MULTICLUSTER - DEFINICIONES Y ESTRATEGIA (VERSION EJECUTIVA AMPLIADA)

**Area:** Ingenieria de Plataforma  
**Version:** 2.0  
**Compania:** Banco Galicia  
**Objetivo de uso:** texto base para copiar, ajustar y corregir `doc_files/Estrategia Multicluster.pdf`

## Estructura general

Este documento mantiene la estructura narrativa del PDF original, pero la reescribe para una audiencia de negocio con mayor profundidad en impacto, riesgos, decisiones y plan de ejecucion.

Se organiza en las mismas piezas logicas:

1. Objetivo del documento.
2. Alcance y objetivo.
3. Resumen ejecutivo.
4. Situacion actual.
5. Limitaciones tecnicas prioritarias.
6. Requerimientos especificos.
7. Definiciones tecnicas y operativas.
8. Estrategia de evolucion general.
9. Lecciones sobre el analisis.
10. Fases de implementacion.
11. Topologia target.
12. Plan de ejecucion.
13. Riesgos criticos y mitigaciones.
14. Conclusiones y referencias.

## Objetivo del documento

El objetivo es presentar una estrategia ejecutable para evolucionar OpenShift desde una operacion concentrada de alto riesgo hacia un modelo multicluster que reduzca impacto cruzado, mejore continuidad y habilite crecimiento sostenido.

No se trata de una actualizacion tecnica incremental ni de un cambio puntual de producto. Se trata de una decision estructural para proteger continuidad bancaria, reducir exposicion operativa y ganar previsibilidad en la operacion de servicios criticos. [11][14][34]

El documento busca alinear tres dimensiones en una misma hoja de ruta:

- **Continuidad de negocio:** menor probabilidad de impacto transversal ante incidentes.
- **Capacidad de crecimiento:** escalar por dominios sin amplificar complejidad.
- **Control y cumplimiento:** operar con mayor trazabilidad, automatizacion y evidencia. [13][40][54]

## Alcance y objetivo

El alcance cubre arquitectura, operacion y gobierno de la plataforma OCP multicluster, con APIM como frente modelador para decisiones de red, seguridad, resiliencia y observabilidad. [2][6][34]

Este alcance incluye:

- Entorno productivo y su continuidad entre sitios.
- Patrones de trafico north-south y east-west.
- Modelo operativo day 0/day 1/day 2.
- Seguridad integral, observabilidad federada y gobierno de cambios.
- Fases de migracion y esquema de control ejecutivo. [3][4][35][36][38][39][40]

No incluye en esta version:

- Diseno detallado de bajo nivel por producto o cluster.
- Procedimientos tecnicos por equipo.
- Especificaciones de implementacion por aplicacion.

## Resumen ejecutivo

La plataforma actual concentra una parte critica de la operacion bancaria sobre una base de infraestructura con alta densidad de cargas y dependencias compartidas. Esta condicion incrementa el riesgo sistemico: una degradacion de capacidad, red, storage o configuracion puede afectar multiples dominios de negocio al mismo tiempo. [3][11]

El problema no es solo tecnologico. Es de impacto operativo y continuidad:

- Mayor dificultad para aislar incidentes.
- Ventanas de mantenimiento mas exigentes.
- Mayor dependencia de coordinacion manual entre equipos.
- Menor elasticidad real para absorber crecimiento de demanda. [12][13][14]

La estrategia propuesta es evolucionar a un modelo multicluster por dominios, con separacion de responsabilidades, patrones de trafico diferenciados y operacion declarativa basada en GitOps + IaC.

El enfoque acordado para iniciar es pragmatica:

- Segmentacion inicial acotada (3-4 grupos de cluster) para evitar sobrecomplejidad temprana.
- Continuidad activo-pasivo en primera etapa para bajar riesgo de ejecucion.
- Criterios de produccion obligatorios antes de mover cargas (seguridad, observabilidad, cumplimiento, runbooks, no-go-live).
- Migracion por oleadas y sin big-bang. [34][40][41][44]

La ganancia esperada para negocio es concreta: menor impacto cruzado, mejor continuidad, mejor capacidad de respuesta ante incidentes y una base de crecimiento mas segura para canales e integraciones.

## Situacion actual

### Topologia y capacidad (as-is)

La evidencia consolidada describe una plataforma de alta escala y alta concentracion:

- Ecosistema con orden de magnitud superior a 500 nodos y miles de cargas distribuidas.
- Cluster productivo principal de referencia con orden de magnitud de 100+ nodos, mas de 10.000 pods y mas de 600 namespaces.
- Volumen aproximado de 8 mil millones de requests por mes, con predominio east-west sobre north-south.
- Alrededor de 2.200 APIs productivas y alta densidad en capa de exposicion. [3][6]

Adicionalmente:

- Topologia entre dos sitios principales (Plaza y Matriz).
- Dependencia de componentes corporativos de red/balanceo/DNS.
- Presion por ciclo de vida tecnologico (OCP 4.15/4.16 a 4.20.x y frente APIM con horizonte EOL). [5][6][42][46]

### Implicancias de negocio de la situacion actual

La plataforma puede seguir operando en el corto plazo, pero lo hace con una exposicion creciente:

- El impacto potencial de una falla deja de ser local y puede volverse banco-wide.
- Cada nueva carga critica aumenta costo y riesgo marginal sobre una base ya exigida.
- La velocidad de cambio depende de ventanas y coordinacion manual, no de un flujo repetible y predecible.
- La recuperacion ante eventos no siempre tiene tiempos estables por depender de tareas no completamente automatizadas. [11][13][14]

## Limitaciones tecnicas prioritarias

### 1) Modelo operativo

- Persisten tareas manuales para VIPs, DNS, certificados y pasos de continuidad.
- Existen dependencias de tickets y coordinacion interequipos para cambios criticos.
- Day 2 no esta completamente estandarizado y convive con automatizacion parcial.
- Hay variabilidad en tiempos de ejecucion para actividades similares. [4][13]

### 2) Escalabilidad

- La principal unidad de escalado sigue concentrada en un cluster de gran tamano.
- Se reporta overcommit en partes del entorno.
- El trafico interno aun sufre recorridos ineficientes (hair-pinning) que agregan latencia.
- APIM actual presenta restricciones operativas para crecimiento de rutas/APIs y dinamismo de cambio. [6][12]

### 3) Impacto cruzado (blast radius)

- Capacidad, red, storage y configuracion comparten dominios de impacto.
- Una incidencia de infraestructura puede propagarse entre canales, integraciones y servicios internos.
- La contencion de incidentes es mas compleja por concentracion y dependencias transversales.
- Incidente observado (nov-2025): caida de storage (OFD) que afecto nodos y capacidad de escritura, con impacto operativo transversal.
- Incidente observado: degradacion de storage con perdida temporal de metricas (~20 minutos), afectando visibilidad y tiempos de diagnostico.
- Incidente observado (feb-2026): falla en F5/load balancer con impacto en operacion de infraestructura y necesidad de intervencion adicional.
- Incidente observado (feb-2026): en APIM, publicacion correcta pero falla de suscripcion entre clusters, generando inconsistencias post-deployment.
- Estos eventos refuerzan que el riesgo no es teorico: ya existen antecedentes de impacto multidominio y de recuperacion compleja. [11][13][14]

### 4) Mantenimiento, lifecycle y ventanas

- Upgrades y cambios mayores requieren ventanas exigentes por escala y secuencia.
- La deriva de configuracion intersitio sigue siendo un riesgo cuando no todo es declarativo.
- La presion de roadmap tecnico convive con restricciones de calendario operativo del negocio. [14][46]

## Requerimientos especificos

Para que la estrategia sea viable para negocio, se definen requerimientos en dos horizontes.

### Mandatorios para ejecucion 2026

1. Reducir riesgo sistemico mediante segmentacion inicial efectiva.
2. Implementar control de cambios declarativo (GitOps + IaC) para dominios criticos.
3. Exigir baseline de seguridad y observabilidad para todo cluster productivo nuevo.
4. Asegurar trazabilidad de decisiones y criterios de no-go-live por fase.
5. Ejecutar migracion progresiva por oleadas con rollback controlado.
6. Operar continuidad inicial en esquema activo-pasivo por sitio. [34][38][39][40][41][44]

### Evolutivos (fase de consolidacion)

1. Avanzar a patrones activo-activo en dominios donde aplique por criticidad/costo-beneficio.
2. Optimizar modelo de autoservicio y productividad de equipos.
3. Consolidar observabilidad avanzada de red y dependencias con eBPF.
4. Profundizar portabilidad y desacople de datos stateful. [20][49][53][60]

## Definiciones tecnicas y operativas

### Segmentacion de dominios y tipologia de clusters

La segmentacion objetivo reduce impacto cruzado y desacopla crecimiento:

- Clusters de negocio para cargas de dominio.
- Clusters de servicios comunes para capacidades transversales.
- Clusters de gestion para gobierno de flota, politicas y ciclo de vida.
- Separacion explicita entre servicios criticos y no criticos.

Como criterio de arranque, se prioriza una segmentacion inicial acotada y clara (3-4 grandes grupos), evitando multiplicacion prematura de clusters sin capacidad operativa para sostenerlos. [34]

### Modelo de control plane y data plane

- Gobierno central de politicas y ciclo de vida (control plane).
- Ejecucion distribuida por cluster/sitio (data planes).
- Repositorios versionados como fuente de verdad para cambios.
- Ownership distribuido por dominio funcional sin perder trazabilidad. [31][40]

### Patrones de trafico objetivo

#### North-south (ingreso y exposicion)

- Capa de perimetro y seguridad.
- Capa de API Gateway/APIM para gobierno L7 donde agrega valor.
- Capa de servicios internos.
- Coexistencia temporal entre modelo actual y destino para evitar cambios de alto riesgo. [26][35]

#### East-west (comunicacion interna)

- En esta etapa se mantiene la filosofia north-south para el trafico intra-cluster e inter-cluster, priorizando estabilidad operativa y menor riesgo de transicion.
- En paralelo, se establecen las bases tecnico-operativas para una evolucion futura del dominio east-west (observabilidad, seguridad, gobierno de ruteo y pruebas controladas).
- Esta definicion marca una secuencia de implementacion, no una limitacion estrategica: deja abierto un reacomodo posterior segun evidencia tecnica y necesidades del negocio. [27][36]

### Seguridad integral multicluster

- IAM integrado con identidad corporativa y minimo privilegio.
- RBAC, politicas y secretos en modo declarativo con reconciliacion continua.
- Migracion progresiva desde credenciales estaticas a identidad de workload.
- Segregacion de funciones y trazabilidad auditable por cambio. [38][54][55]

### Observabilidad federada y confiabilidad

- Federacion de metricas, logs y trazas para vista unificada cross-cluster.
- OpenTelemetry + eBPF para mejorar visibilidad de red y dependencias reales.
- SLI/SLO por dominio con ownership explicito.
- Integracion de alertado, incident response y postmortems en ciclo unico. [39][60][63]

### Modelo operativo objetivo

- GitOps + IaC como estandar de cambio.
- Automatizacion day 0/day 1/day 2 con guardrails.
- Plantillas de plataforma para provison y onboarding con menor variabilidad.
- Operating model con roles claros entre Platform Engineering, Seguridad, Redes, SRE/DevOps y equipos de producto. [40][48][49]

## Estrategia de evolucion general

La estrategia se apoya en principios de ejecucion para reducir riesgo y acelerar valor:

1. **Riesgo primero:** priorizar acciones que reduzcan blast radius antes que optimizaciones cosmeticas.
2. **Simplicidad operativa:** empezar con menos cambios simultaneos y mayor disciplina de ejecucion.
3. **Evidencia tecnica:** usar datos de trafico, latencia e incidentes para decisiones de segmentacion.
4. **Automatizacion progresiva:** no escalar topologia sin escalar antes el modelo operativo.
5. **Gobierno con autonomia:** control central de politicas y autonomia de ejecucion por dominio. [11][13][34][40][60]

En esta estrategia, APIM no desaparece del problema, pero deja de ser el centro de gravedad de toda la reingenieria. Pasa a ser una capacidad dentro de un marco multicluster mas amplio. [6][25][34]

## Lecciones sobre el analisis

El analisis tecnico-operativo deja aprendizajes que explican por que la estrategia cambia:

1. La principal amenaza no es un componente puntual; es la concentracion sistemica.
2. No alcanza con "agregar capacidad" en el modelo actual; se necesita desacople estructural.
3. La continuidad no mejora solo con infraestructura duplicada; mejora con procesos repetibles y declarativos.
4. La observabilidad tradicional no alcanza para resolver incidentes complejos de red y dependencias.
5. La velocidad de negocio depende tanto de arquitectura como de modelo operativo. [11][12][13][14][39][60]

Tambien se confirma que una estrategia de alto volumen de cambios en paralelo aumenta riesgo de ejecucion. Por eso se recomienda inicio acotado, con hitos duros de calidad por fase y expansion gradual. [41][44]

## Fases de implementacion

### Fase 1 - Fundacional (habilitadores de plataforma)

**Objetivo:** construir base comun sin aumentar riesgo operativo.

- Baseline de seguridad, observabilidad y gobierno por cluster.
- Repositorio de verdad para RBAC, politicas, secretos e ingreso/egreso.
- Definicion de ownership y RACI por dominio.
- Estrategia de versiones y dependencias para ruta de upgrade. [18][38][39][40][46]

**Salida esperada para negocio:** plataforma base confiable para iniciar migraciones sin degradar continuidad.

### Fase 2 - Sharding de ingreso y desacople de flujos

**Objetivo:** separar rutas criticas y habilitar transicion gradual.

- Separacion de puntos de ingreso por funcion.
- Migracion selectiva con VIPs/CNAMEs por proyecto.
- Coexistencia controlada entre modelo actual y destino.
- Validacion automatizada para minimizar drift. [35][37][40]

**Salida esperada para negocio:** reduccion de riesgo de corte masivo durante la transicion.

### Fase 3 - Segmentacion operativa y gobierno

**Objetivo:** pasar de operacion centralizada por excepcion a operacion por dominios.

- Activacion de control plane central y data planes distribuidos.
- Estandarizacion de capacidad north-south para dominios que lo requieran.
- Politicas globales automatizadas con reconciliacion continua.
- Ejecucion de upgrades por etapas con pruebas de riesgo. [34][35][40][46][54]

**Salida esperada para negocio:** mayor control de riesgo con menor dependencia de respuestas manuales.

### Fase 4 - Movimiento de proyectos y cargas

**Objetivo:** redistribuir capacidad sin forzar refactor prematuro.

- Priorizacion de workloads HA-ready.
- Oleadas lift-and-reshape por dominio.
- Reorganizacion de namespaces por criticidad.
- Switcheo progresivo de trafico con rollback controlado. [43][44]

**Salida esperada para negocio:** descompresion del monolito y mejora tangible de continuidad.

### Fase 5 - Consolidacion de alta disponibilidad

**Objetivo:** estabilizar operacion multicluster con recuperacion verificable.

- Evolucion de activo-pasivo a activo-activo donde aplique.
- DNS global y health checks multicapa para conmutacion controlada.
- RTO/RPO por dominio y drills periodicos.
- Recuperacion de estado y datos en cargas stateful. [20][37][41]

**Salida esperada para negocio:** continuidad mas predecible y menor variabilidad ante incidentes mayores.

## Topologia target

### Vista logica

- Capa de gobierno multicluster para politicas y ciclo de vida.
- Capa de ejecucion distribuida por dominios.
- Capa north-south para exposicion y consumo legacy/core.
- Capa east-west para comunicacion interna/intercluster. [34][35][36][40]

### Roles por tipo de cluster

- **Clusters de negocio:** ejecutan servicios de dominio con objetivos de servicio propios.
- **Clusters de servicios comunes:** concentran capacidades transversales (observabilidad, secretos, toolchain de plataforma).
- **Clusters de gestion:** sostienen gobierno de flota, GitOps e IaC.
- **Clusters especializados:** atienden casos con requerimientos tecnicos especificos. [34][39][40]

### Escala y continuidad

Se mantiene como referencia una evolucion progresiva de la flota en funcion de madurez operativa, con foco en:

- menor impacto cruzado,
- mayor aislamiento,
- y mejor recuperacion por dominio.

La continuidad inicial se apoya en activo-pasivo para reducir riesgo de implementacion. La evolucion a activo-activo se decide por criticidad y evidencia operativa, no por default. [20][41]

## Plan de ejecucion

### Horizonte sugerido 2026

- **Q1 2026:** cierre de definiciones de arquitectura objetivo y gobierno de ejecucion.
- **Q2 2026:** implementacion de habilitadores y validaciones tecnicas criticas.
- **Q3-Q4 2026:** migracion progresiva por oleadas y consolidacion de dominios priorizados.
- **Meta de programa:** no diferir la transformacion estructural a 2027; ejecutar avance sustancial durante 2026. [1][34][44]

### Entregables de control ejecutivo

- Arquitectura por dominio aprobada.
- Matriz de dependencias y secuenciamiento.
- Criterios de avance/no-go-live por fase.
- Tablero de salud por cluster y dominio.
- Plan integrado de riesgos y contingencias. [41][44][63]

### Indicadores de seguimiento para negocio

1. Reduccion de incidentes con impacto multidominio.
2. Reduccion de tiempo de recuperacion en eventos priorizados.
3. Porcentaje de cambios ejecutados via flujo declarativo.
4. Porcentaje de cargas migradas en dominios priorizados.
5. Grado de cumplimiento de baseline de seguridad/observabilidad por cluster.

## Riesgos criticos y mitigaciones del programa multicluster

1. **Inestabilidad en patrones cross-cluster criticos**  
   Mitigacion: pruebas obligatorias de pod churn y escenarios de falla reales con no-go-live. [36][41]

2. **Complejidad de upgrade de plataforma y red**  
   Mitigacion: ejecucion por etapas y validaciones tecnicas previas por dominio. [46]

3. **Deriva de configuracion entre clusters/sitios**  
   Mitigacion: baseline declarativo y reconciliacion continua por GitOps. [40]

4. **Sobrecarga operativa durante coexistencia de modelos**  
   Mitigacion: oleadas acotadas, automatizacion priorizada y runbooks reforzados. [13][44]

5. **Brechas de seguridad en transicion de identidades/secretos**  
   Mitigacion: migracion por dominio, segregacion de funciones, trazabilidad de cambios y retiro progresivo de credenciales estaticas. [38][54][55]

6. **Brechas de observabilidad en operacion federada**  
   Mitigacion: instrumentacion por defecto, catalogo unico de indicadores y correlacion multi-capa con eBPF. [39][60][63]

7. **Dependencias administrativas que ralentizan hitos**  
   Mitigacion: planificacion anticipada interequipos, SLA operativo para prerequisitos de red y seguimiento ejecutivo quincenal de bloqueos. [13][14]

## Conclusion

La transformacion multicluster es una decision de negocio soportada por arquitectura. Busca reducir riesgo sistemico, sostener continuidad y permitir crecimiento sin que la complejidad operativa crezca en forma desproporcionada.

El valor de esta estrategia no depende solo de tecnologia nueva. Depende de ejecutar una secuencia correcta:

1. segmentar riesgo,
2. estandarizar operacion,
3. migrar por fases con control,
4. y consolidar resiliencia sobre evidencia.

Con este enfoque, el banco pasa de una plataforma concentrada y reactiva a una arquitectura distribuida, auditable y preparada para demanda sostenida.

## Referencias absolutas

### Referencias web absolutas (fuente documental)

- [1] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/indice_tentativo.md>
- [2] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md>
- [3] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md>
- [4] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md>
- [5] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md>
- [6] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md>
- [7] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.5_almacenamiento_y_servicios_de_datos.md>
- [8] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.6_seguridad_actual_iam_rbac_secretos_cifrado_politicas.md>
- [11] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md>
- [12] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.2_limites_de_escalabilidad_y_elasticidad.md>
- [13] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md>
- [14] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md>
- [15] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.5_brechas_de_observabilidad_y_trazabilidad_end_to_end.md>
- [18] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.1_estandarizacion_y_automatizacion_por_defecto.md>
- [20] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md>
- [25] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.1_marco_de_evaluacion_y_criterios_comparativos.md>
- [26] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.2_alternativas_de_api_management_y_api_gateway.md>
- [27] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.3_alternativas_de_service_mesh_para_trafico_este_oeste.md>
- [31] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.7_alternativas_de_operacion_multicluster_y_gobierno_de_flota.md>
- [34] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md>
- [35] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md>
- [36] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.3_patron_este_oeste_malla_de_servicios_y_seguridad_de_comunicacion.md>
- [37] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md>
- [38] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.5_modelo_de_seguridad_integral_iam_rbac_secretos_cifrado_politicas.md>
- [39] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md>
- [40] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md>
- [41] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md>
- [42] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.1_estrategia_hibrida_on_premise_cloud.md>
- [43] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.2_criterios_de_elegibilidad_y_priorizacion_de_workloads.md>
- [44] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md>
- [46] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.5_dependencias_criticas_para_adopcion_cloud.md>
- [48] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md>
- [49] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.2_self_service_y_automatizacion_de_provision.md>
- [53] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.6_mejora_de_developer_experience_y_productividad.md>
- [54] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.1_gobierno_de_identidades_y_accesos_multicluster.md>
- [55] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.2_gestion_de_secretos_y_credenciales.md>
- [60] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.2_observabilidad_de_red_y_servicios_incluyendo_ebpf.md>
- [63] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.5_indicadores_de_salud_tecnica_por_cluster_y_por_dominio.md>

### Referencias locales absolutas (workspace)

- /Users/ferluko/Documents/Galicia/mc/doc/doc_files/Estrategia Multicluster.pdf
- /Users/ferluko/Documents/Galicia/mc/doc/00_resumen_ejecutivo_openshift_multicluster.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/vision_estrategia_multicluster.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.2_observabilidad_de_red_y_servicios_incluyendo_ebpf.md

[1]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/indice_tentativo.md
[2]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md
[3]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md
[4]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md
[5]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md
[6]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md
[7]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.5_almacenamiento_y_servicios_de_datos.md
[8]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.6_seguridad_actual_iam_rbac_secretos_cifrado_politicas.md
[11]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md
[12]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.2_limites_de_escalabilidad_y_elasticidad.md
[13]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md
[14]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md
[15]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.5_brechas_de_observabilidad_y_trazabilidad_end_to_end.md
[18]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.1_estandarizacion_y_automatizacion_por_defecto.md
[20]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md
[25]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.1_marco_de_evaluacion_y_criterios_comparativos.md
[26]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.2_alternativas_de_api_management_y_api_gateway.md
[27]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.3_alternativas_de_service_mesh_para_trafico_este_oeste.md
[31]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.7_alternativas_de_operacion_multicluster_y_gobierno_de_flota.md
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
[46]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.5_dependencias_criticas_para_adopcion_cloud.md
[48]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.1_operating_model_de_plataforma_roles_ownership_capacidades.md
[49]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.2_self_service_y_automatizacion_de_provision.md
[53]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/09_modelo_operativo_experiencia_desarrollo/9.6_mejora_de_developer_experience_y_productividad.md
[54]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.1_gobierno_de_identidades_y_accesos_multicluster.md
[55]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.2_gestion_de_secretos_y_credenciales.md
[60]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.2_observabilidad_de_red_y_servicios_incluyendo_ebpf.md
[63]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.5_indicadores_de_salud_tecnica_por_cluster_y_por_dominio.md
# OCP MULTICLUSTER - ESTRATEGIA EJECUTIVA PARA NEGOCIO

**Area:** Ingenieria de Plataforma  
**Version:** 1.0  
**Compania:** Banco Galicia  
**Estado:** Documento de presentacion para audiencia de negocio

## 1. Estructura general

### 1.1 Objetivo del documento

Este documento presenta, en lenguaje de negocio, la estrategia para evolucionar la plataforma OpenShift hacia un modelo multicluster. El foco es resolver un problema de alto impacto: el riesgo sistemico generado por la concentracion de cargas criticas en un esquema monolitico. [11]

### 1.2 Alcance y objetivo

El alcance cubre continuidad, escalabilidad, seguridad y gobierno operativo de la plataforma, tomando APIM como caso modelador dentro de una estrategia mas amplia de reingenieria. [2][34]

### 1.3 Resumen ejecutivo

La plataforma actual soporta procesos criticos del banco con alta concentracion de riesgo. Esta condicion aumenta la probabilidad de impacto transversal sobre canales, integraciones y procesos internos cuando ocurre una degradacion o incidente. [3][11][14]

La estrategia propuesta cambia el enfoque de "crecer sobre un cluster grande" a "distribuir por dominios con reglas comunes", para reducir blast radius, mejorar continuidad y permitir crecimiento sostenible. [20][34]

La implementacion se plantea por fases, con una primera etapa operativamente pragmatica:

- Segmentacion inicial acotada (3-4 dominios de cluster).
- Continuidad activo-pasivo en arranque para bajar riesgo de ejecucion.
- Estandar de cambios declarativos con GitOps + IaC.
- Migracion progresiva de cargas, sin big-bang. [40][44]

## 2. Situacion actual

La situacion de partida combina volumen, complejidad y dependencia operativa:

- Alta concentracion de cargas y trafico critico en la base actual. [3][11]
- Dependencia de tareas manuales y coordinacion interequipos para cambios sensibles. [4][13]
- Ventanas de cambio restringidas y recuperacion con variabilidad operativa. [14]
- Brechas de observabilidad para decisiones basadas en evidencia en incidentes complejos. [15][60]

## 3. Limitaciones tecnicas prioritarias (vista negocio)

1. **Riesgo de continuidad:** una falla relevante puede impactar mas de un dominio de negocio al mismo tiempo. [11][14]
2. **Escalabilidad con friccion:** crecer en un modelo concentrado incrementa costos operativos y no elimina riesgo estructural. [12]
3. **Tiempo de respuesta operativo:** la manualidad reduce velocidad y previsibilidad de cambios y recuperaciones. [13]
4. **Trazabilidad y control:** sin mayor automatizacion declarativa, aumenta riesgo de drift y auditoria incompleta. [40][54]

## 4. Definiciones tecnicas y operativas (nivel ejecutivo)

Para simplificar la toma de decisiones, el programa se apoya en cuatro definiciones:

1. **Segmentacion por dominio y criticidad** para aislar impacto.
2. **Separacion de patrones de trafico**: north-south para exposicion/gobierno de APIs y east-west para comunicacion interna.
3. **Gobierno central con operacion distribuida** para mantener control sin bloquear autonomia.
4. **Estandar operativo unico** con GitOps + IaC como base de ejecucion. [34][35][36][40]

## 5. Estrategia de evolucion general

La estrategia busca resolver el riesgo actual sin agregar complejidad innecesaria en la primera etapa:

- **Prioridad 1:** bajar el riesgo de concentracion y blast radius.
- **Prioridad 2:** construir una base operativa repetible (seguridad, observabilidad, compliance).
- **Prioridad 3:** habilitar migracion progresiva de cargas con control de riesgo.
- **Prioridad 4:** consolidar resiliencia multicluster y eficiencia operativa. [20][38][39][41][44]

## 6. Fases de implementacion

### Fase 1 - Base habilitadora

- Baseline comun de seguridad, observabilidad y gobierno.
- Repositorios fuente de verdad para politicas y configuracion.
- Preparacion operativa de clusters production-ready. [38][39][40]

### Fase 2 - Desacople de ingreso y control de transicion

- Separacion de rutas de ingreso por funcion y criticidad.
- Coexistencia controlada para evitar migraciones de alto riesgo. [35][37]

### Fase 3 - Segmentacion y gobierno de flota

- Activacion del modelo multicluster con control central y ejecucion distribuida.
- Aplicacion de guardrails comunes por dominio. [34][40]

### Fase 4 - Movimiento progresivo de cargas

- Oleadas de migracion por criticidad y preparacion.
- Rollback controlado y criterio de no-go-live cuando aplique. [41][44]

### Fase 5 - Consolidacion de continuidad

- Fortalecimiento de failover, RTO/RPO y recuperacion validada.
- Evolucion de patrones de alta disponibilidad segun criticidad de negocio. [20][41]

## 7. Topologia target (vision ejecutiva)

La topologia objetivo organiza la plataforma en capas y dominios claros:

- **Clusters de negocio:** procesamiento de capacidades por dominio.
- **Clusters de servicios comunes:** observabilidad, secretos y servicios transversales.
- **Clusters de gestion:** gobierno de flota y ciclo de vida.
- **Modelo de continuidad inicial:** activo-pasivo por sitio para reducir riesgo de implementacion.
- **Evolucion posterior:** activo-activo donde exista justificacion tecnica y de negocio. [34][39][40][41]

## 8. Plan de ejecucion

### Horizonte sugerido para 2026

- **Hasta fin de marzo:** definicion final de arquitectura objetivo y preparacion de clusters base.
- **Abril:** alistamiento operativo y validaciones criticas.
- **Mayo-junio:** inicio de migraciones por oleadas en dominios priorizados.
- **Segundo semestre:** consolidacion de dominios, ajuste operativo y ampliacion controlada. [44]

### Entregables para comite ejecutivo

- Arquitectura objetivo aprobada por dominio.
- Matriz de riesgos y mitigaciones por fase.
- Criterios de avance y no-go-live.
- Tablero de salud por cluster y dominio.
- Estado de avance de migracion y continuidad. [41][63]

## 9. Riesgos criticos y mitigaciones

1. **Riesgo de inestabilidad en transicion:** mitigado con pruebas por fase y criterio de corte.
2. **Riesgo de sobrecarga operativa:** mitigado con alcance acotado y automatizacion progresiva.
3. **Riesgo de deriva entre sitios/clusters:** mitigado con configuracion declarativa y reconciliacion continua.
4. **Riesgo de brechas de seguridad/observabilidad:** mitigado con baseline obligatorio previo a escalar. [38][39][40][41]

## 10. Conclusion

La decision multicluster no responde a una preferencia tecnologica: responde a un riesgo de negocio concreto. El objetivo es proteger continuidad bancaria, reducir impacto cruzado y sostener crecimiento con menor exposicion operacional.

La recomendacion arquitectonica es ejecutar una transicion pragmatica, por etapas y con control de riesgo, priorizando resultados de continuidad y estabilidad antes de expandir complejidad tecnica.

## 11. Referencias absolutas

### 11.1 Referencias web absolutas (fuente documental)

- [2] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md>
- [3] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md>
- [4] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md>
- [11] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md>
- [12] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.2_limites_de_escalabilidad_y_elasticidad.md>
- [13] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md>
- [14] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md>
- [15] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.5_brechas_de_observabilidad_y_trazabilidad_end_to_end.md>
- [20] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md>
- [34] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md>
- [35] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md>
- [36] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.3_patron_este_oeste_malla_de_servicios_y_seguridad_de_comunicacion.md>
- [37] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md>
- [38] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.5_modelo_de_seguridad_integral_iam_rbac_secretos_cifrado_politicas.md>
- [39] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md>
- [40] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md>
- [41] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md>
- [44] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md>
- [54] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.1_gobierno_de_identidades_y_accesos_multicluster.md>
- [60] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.2_observabilidad_de_red_y_servicios_incluyendo_ebpf.md>
- [63] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.5_indicadores_de_salud_tecnica_por_cluster_y_por_dominio.md>

### 11.2 Referencias locales absolutas (workspace)

- /Users/ferluko/Documents/Galicia/mc/doc/00_resumen_ejecutivo_openshift_multicluster.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/vision_estrategia_multicluster.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md
- /Users/ferluko/Documents/Galicia/mc/doc/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md

[2]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md
[3]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md
[4]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md
[11]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.1_riesgo_sistemico_y_blast_radius.md
[12]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.2_limites_de_escalabilidad_y_elasticidad.md
[13]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md
[14]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md
[15]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.5_brechas_de_observabilidad_y_trazabilidad_end_to_end.md
[20]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md
[34]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.1_modelo_multicluster_objetivo_y_segmentacion_de_dominios.md
[35]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.2_patron_norte_sur_ingreso_exposicion_y_gobierno_de_apis.md
[36]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.3_patron_este_oeste_malla_de_servicios_y_seguridad_de_comunicacion.md
[37]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md
[38]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.5_modelo_de_seguridad_integral_iam_rbac_secretos_cifrado_politicas.md
[39]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.6_observabilidad_federada_multicluster.md
[40]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.7_modelo_operativo_gitops_iac.md
[41]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md
[44]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/08_estrategia_portabilidad_evolucion_nube/8.3_enfoque_de_migracion_progresiva_con_minimo_refactor.md
[54]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/10_seguridad_ciberseguridad_cumplimiento/10.1_gobierno_de_identidades_y_accesos_multicluster.md
[60]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.2_observabilidad_de_red_y_servicios_incluyendo_ebpf.md
[63]: https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/11_observabilidad_integral_confiabilidad/11.5_indicadores_de_salud_tecnica_por_cluster_y_por_dominio.md
