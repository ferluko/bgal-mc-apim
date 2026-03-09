# OCP MULTICLUSTER - DEFINICIONES Y ESTRATEGIA (VERSION EJECUTIVA AMPLIADA)

**Area:** Ingenieria de Plataforma  
**Version:** 2.0  
**Compania:** Banco Galicia  
**Objetivo de uso:** texto base para copiar, ajustar y corregir `doc_files/Estrategia Multicluster.pdf`

## Estructura general

Este documento conserva la estructura del PDF original y amplia su contenido para una audiencia de negocio. El foco esta en explicar el problema de impacto, la estrategia de solucion y el plan de ejecucion con trazabilidad a fuentes del repositorio.

Bloques del documento:

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
14. Conclusion y referencias.

## Objetivo del documento

El objetivo es definir una estrategia ejecutable para evolucionar OpenShift desde un esquema concentrado de alto riesgo hacia un modelo multicluster capaz de:

- reducir impacto cruzado,
- mejorar continuidad operativa,
- escalar en forma sostenible,
- y aumentar la gobernanza sobre cambios criticos. [11][14][34]

No es un ajuste puntual de un producto ni un cambio cosmetico de arquitectura. Es una decision estructural para proteger continuidad bancaria y reducir exposicion operativa sobre procesos de negocio sensibles. [11][34]

## Alcance y objetivo

El alcance cubre arquitectura, operacion y gobierno del programa multicluster, usando APIM como caso modelador para decisiones de red, seguridad, resiliencia y observabilidad. [2][6][34]

Incluye:

- entorno productivo y continuidad intersitio,
- patrones north-south y east-west,
- modelo day 0/day 1/day 2,
- seguridad integral, observabilidad y gobierno de cambios,
- roadmap de migracion por fases. [3][4][35][36][38][39][40][44]

No incluye en esta version:

- diseno de bajo nivel por cluster,
- runbooks detallados por equipo,
- tacticas especificas por aplicacion.

## Resumen ejecutivo

La plataforma actual concentra cargas criticas en una base de infraestructura exigida, con alta densidad de dependencias compartidas. Esta condicion incrementa el riesgo sistemico: una degradacion en capacidad, red, storage o configuracion puede afectar varios dominios de negocio al mismo tiempo. [3][11]

El problema principal no es solo tecnico; es de continuidad y impacto operacional:

- mayor dificultad para contener incidentes,
- ventanas operativas mas exigentes,
- alta dependencia de tareas manuales,
- y menor elasticidad real para absorber crecimiento. [12][13][14]

La estrategia objetivo propone pasar de "crecer sobre un cluster grande" a "escalar por dominios con reglas comunes", separando responsabilidades de plataforma y reduciendo blast radius. [20][34]

La ejecucion inicial se define de manera pragmatica, alineada con la reunion de trabajo:

- segmentacion inicial acotada (3-4 grandes grupos),
- continuidad activo-pasivo en primera etapa,
- GitOps + IaC como base operativa obligatoria,
- migracion por oleadas con no-go-live cuando corresponda. [34][40][41][44]

## Situacion actual

### Topologia y capacidad (as-is)

La evidencia consolidada muestra una plataforma de gran escala y alta concentracion:

- ecosistema con orden de magnitud superior a 500 nodos considerando ambientes y clusters,
- cluster productivo principal con orden de magnitud de 100+ nodos, >10.000 pods y >600 namespaces,
- volumen de referencia cercano a 8 mil millones de requests/mes,
- predominio del trafico east-west sobre north-south,
- alrededor de 2.200 APIs productivas y alta densidad en capa de exposicion. [3][6]

Operativamente:

- topologia distribuida entre Plaza (PGA) y Matriz (CMZ),
- dependencia fuerte de red, balanceo y DNS corporativo,
- presion por lifecycle tecnologico en OCP y en el frente APIM. [5][6][42][46]

### Impacto para negocio

En el estado actual, cada incremento de carga critica sobre el monolito aumenta riesgo marginal y complejidad operativa. Esto limita capacidad de respuesta, tensiona continuidad y dificulta planificar crecimiento con previsibilidad. [11][13][14]

## Limitaciones tecnicas prioritarias

### 1) Modelo operativo

- manualidad en VIPs, DNS, certificados y tareas de continuidad,
- dependencia de tickets y coordinacion interequipos para cambios sensibles,
- day 2 parcialmente definido y no totalmente estandarizado,
- variabilidad en tiempos de ejecucion para procesos similares. [4][13]

### 2) Escalabilidad

- unidad principal de escalado concentrada,
- overcommit en partes del entorno,
- rutas internas ineficientes (hair-pinning) con costo en latencia,
- restricciones operativas del modelo APIM actual para crecimiento y cambios dinamicos. [6][12]

### 3) Impacto cruzado (blast radius)

- dependencias compartidas en capacidad/red/storage/identidad,
- potencial de impacto transversal sobre canales, integraciones y procesos internos,
- mayor complejidad de contencion durante incidentes severos. [11]

### 4) Mantenimiento, lifecycle y ventanas

- secuencias de upgrade exigentes por escala y dependencias,
- riesgo de drift intersitio cuando no todo esta en modelo declarativo,
- convivencia de presion tecnica con restricciones de calendario operativo. [14][46]

## Requerimientos especificos

### Mandatorios para 2026

1. Reducir riesgo sistemico con segmentacion efectiva.
2. Ejecutar cambios criticos con GitOps + IaC.
3. Exigir baseline de seguridad y observabilidad en clusters productivos nuevos.
4. Definir criterios de avance/no-go-live por fase.
5. Migrar por oleadas con rollback controlado.
6. Sostener continuidad inicial activo-pasivo por sitio. [34][38][39][40][41][44]

### Evolutivos de consolidacion

1. Evolucion a activo-activo donde el dominio lo justifique.
2. Mayor autoservicio y productividad de equipos.
3. Observabilidad avanzada de red y dependencias con eBPF.
4. Mayor portabilidad de datos y workloads stateful. [20][49][53][60]

## Definiciones tecnicas y operativas

### Segmentacion de dominios y tipologia de clusters

El modelo objetivo separa por criticidad y funcion:

- clusters de negocio para cargas de dominio,
- clusters de servicios comunes para capacidades transversales,
- clusters de gestion para gobierno de flota y lifecycle,
- separacion explicita entre servicios criticos y no criticos. [34]

Para bajar riesgo de implementacion, la estrategia propone iniciar con una segmentacion acotada y clara (3-4 grupos), y escalar luego segun madurez operativa.

### Modelo de control plane y data plane

- control plane central para politicas y ciclo de vida,
- data planes distribuidos por cluster/sitio,
- repositorios versionados como fuente de verdad,
- ownership por dominio funcional con trazabilidad de cambios. [31][40]

### Patrones de trafico objetivo

#### North-south

- capa perimetral,
- capa APIM/API Gateway para gobierno L7,
- capa de servicios internos,
- coexistencia temporal con modelo actual durante transicion. [26][35]

#### East-west

- malla para reducir latencia y dependencia de rutas externas,
- simplificacion progresiva del trafico interno,
- pruebas cross-cluster obligatorias antes de productivizar. [27][36]

### Seguridad, observabilidad y operacion

- IAM integrado y minimo privilegio,
- RBAC/politicas/secretos declarativos con reconciliacion continua,
- OpenTelemetry + eBPF para visibilidad multi-capa,
- GitOps + IaC como estandar operativo day 0/day 1/day 2,
- operating model con roles y ownership explicitos. [38][39][40][48][54][55][60]

## Estrategia de evolucion general

La estrategia se apoya en cinco reglas de ejecucion:

1. **Riesgo primero:** priorizar reduccion de blast radius.
2. **Simplicidad al inicio:** menos cambios simultaneos, mas disciplina de fase.
3. **Evidencia para decidir:** usar datos de trafico, latencia e incidentes.
4. **Automatizacion progresiva:** no escalar topologia sin escalar operacion.
5. **Gobierno con autonomia:** control central y ejecucion distribuida por dominio. [11][13][34][40][60]

APIM se mantiene como frente relevante, pero deja de condicionar toda la estrategia. Pasa a integrarse como capacidad dentro del marco multicluster. [6][25][34]

## Lecciones sobre el analisis

1. El riesgo principal es la concentracion sistemica, no un componente aislado.
2. Escalar verticalmente el monolito no resuelve el problema estructural.
3. Continuidad real requiere arquitectura y operacion repetible.
4. Sin observabilidad de red y dependencias, el MTTR no mejora en forma sostenida.
5. La velocidad de negocio depende tambien del modelo operativo, no solo de la tecnologia. [11][12][13][14][39][60]

La principal conclusion operativa es evitar big-bang: iniciar con foco, medir, estabilizar y escalar. [41][44]

## Fases de implementacion

### Fase 1 - Fundacional

**Objetivo:** base comun sin subir riesgo.

- baseline de seguridad/observabilidad/gobierno,
- repositorio de verdad para politicas y secretos,
- ownership y RACI por dominio,
- ruta de versiones y dependencias para upgrade. [18][38][39][40][46]

### Fase 2 - Desacople de ingreso

**Objetivo:** separar rutas y habilitar transicion gradual.

- separar puntos de ingreso por funcion,
- migracion selectiva por VIP/CNAME,
- coexistencia controlada entre modelo actual y destino. [35][37][40]

### Fase 3 - Segmentacion y gobierno de flota

**Objetivo:** pasar de operacion por excepcion a operacion por dominio.

- activar control plane central y data planes distribuidos,
- automatizar politicas globales,
- ejecutar upgrades por etapas con pruebas de riesgo. [34][40][46][54]

### Fase 4 - Movimiento de cargas

**Objetivo:** descomprimir monolito sin refactor prematuro.

- priorizar workloads HA-ready,
- migrar por oleadas lift-and-reshape,
- rollback controlado por fase. [43][44]

### Fase 5 - Consolidacion de resiliencia

**Objetivo:** estabilizar continuidad verificable.

- evolucion de activo-pasivo a activo-activo donde aplique,
- RTO/RPO por dominio con drills periodicos,
- recuperacion de estado y datos en cargas stateful. [20][37][41]

## Topologia target

### Vista logica

- capa de gobierno multicluster,
- capa de ejecucion distribuida,
- capa north-south para exposicion y consumo legacy/core,
- capa east-west para comunicacion interna/intercluster. [34][35][36][40]

### Roles por tipo de cluster

- **Negocio:** servicios de dominio con objetivos propios.
- **Servicios comunes:** observabilidad, secretos y capacidades transversales.
- **Gestion:** gobierno de flota, GitOps, IaC y politicas globales.
- **Especializados:** necesidades tecnicas particulares. [34][39][40]

### Estrategia de continuidad

La continuidad inicial es activo-pasivo para minimizar riesgo de implementacion. La evolucion a activo-activo se realiza por criticidad de dominio y evidencia operativa, no como premisa universal. [20][41]

## Plan de ejecucion

### Horizonte 2026

- **Q1:** cierre de arquitectura objetivo y gobierno de ejecucion.
- **Q2:** habilitadores y validaciones tecnicas criticas.
- **Q3-Q4:** migracion por oleadas y consolidacion de dominios priorizados.
- **Meta:** avance sustancial durante 2026 y no postergar la transformacion estructural. [1][34][44]

### Entregables de control ejecutivo

- arquitectura aprobada por dominio,
- matriz de dependencias y secuenciamiento,
- criterios de avance/no-go-live,
- tablero de salud por cluster y dominio,
- plan integrado de riesgos y contingencias. [41][44][63]

### Indicadores para seguimiento de negocio

1. Reduccion de incidentes con impacto multidominio.
2. Reduccion de tiempos de recuperacion en eventos priorizados.
3. Porcentaje de cambios por flujo declarativo.
4. Porcentaje de cargas migradas en dominios priorizados.
5. Cumplimiento de baseline de seguridad y observabilidad por cluster.

## Riesgos criticos y mitigaciones del programa

1. **Inestabilidad cross-cluster:** pruebas obligatorias + no-go-live. [36][41]
2. **Complejidad de upgrades:** etapas y validaciones previas. [46]
3. **Deriva intersitio:** baseline declarativo + reconciliacion continua. [40]
4. **Sobrecarga operativa en coexistencia:** oleadas acotadas + automatizacion. [13][44]
5. **Brechas de seguridad en transicion:** migracion por dominio + trazabilidad + segregacion. [38][54][55]
6. **Brechas de observabilidad:** instrumentacion por defecto + correlacion multi-capa. [39][60][63]
7. **Bloqueos administrativos:** planificacion anticipada + seguimiento ejecutivo de dependencias. [13][14]

## Conclusion

La transformacion multicluster es una decision de negocio soportada por arquitectura. Su objetivo es reducir riesgo sistemico, sostener continuidad bancaria y permitir crecimiento con menor friccion operativa.

El resultado esperado no depende solo de tecnologia nueva. Depende de ejecutar correctamente la secuencia:

1. segmentar riesgo,
2. estandarizar operacion,
3. migrar por fases con control,
4. consolidar resiliencia sobre evidencia.

Con esta ejecucion, la plataforma evoluciona desde un modelo concentrado y reactivo hacia una arquitectura distribuida, auditable y preparada para crecimiento sostenido.

## Referencias absolutas

### Referencias web absolutas (fuente documental)

- [1] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/indice_tentativo.md>
- [2] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/vision_estrategia_multicluster.md>
- [3] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.1_topologia_actual_y_capacidad_instalada.md>
- [4] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.2_modelo_operativo_dia_0_dia_1_dia_2.md>
- [5] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md>
- [6] <https://github.bancogalicia.com.ar/ocpa/apim-doc/blob/master/02_multi-cluster/03_estado_actual_plataforma_openshift/3.4_gestion_de_apis_y_estado_de_apim.md>
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
