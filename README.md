# Reingenieria OpenShift Multicluster - Documentacion General

**Author:** [fernando.l.gonzalez@bancogalicia.com.ar](mailto:fernando.l.gonzalez@bancogalicia.com.ar)

## Proposito

Este repositorio concentra la documentacion estrategica y tecnica de la reingenieria de plataforma OpenShift en Banco Galicia, con foco principal en la evolucion hacia un modelo multicluster.

El objetivo es disponer de una fuente unica para:

- Entender el contexto, diagnostico y drivers de transformacion.
- Consultar la arquitectura objetivo por dominio.
- Seguir decisiones tecnicas, roadmap y riesgos.
- Facilitar comunicacion ejecutiva y alineamiento tecnico entre equipos.

## Alcance

El alcance principal del material es multicluster. El frente APIM se incluye como caso modelador y antecedente de decisiones de arquitectura, seguridad, observabilidad, resiliencia y operacion.

## Ruta de lectura recomendada

1. Documento ejecutivo consolidado:
   - `00_resumen_ejecutivo_openshift_multicluster.md`
2. Estructura completa por dominios:
   - `02_multi-cluster/indice_tentativo.md`
3. Vision estrategica complementaria:
   - `02_multi-cluster/vision_estrategia_multicluster.md`
4. Detalle tecnico por tema (arquitectura, seguridad, observabilidad, operacion, roadmap):
   - `02_multi-cluster/`

## Estructura principal

- `00_resumen_ejecutivo_openshift_multicluster.md`
  - Resumen ejecutivo consolidado con referencias numeradas.

- `01_apim/`
  - Documentacion detallada del frente APIM (contexto, lecciones, decisiones, arquitectura, roadmap, riesgos y conclusiones).

- `02_multi-cluster/`
  - Cuerpo principal de arquitectura y estrategia multicluster:
    - `01_contexto_proposito/`
    - `02_contexto_negocio_continuidad_regulacion/`
    - `03_estado_actual_plataforma_openshift/`
    - `04_diagnostico_problemas_deuda_tecnica/`
    - `05_principios_arquitectura_criterios_diseno/`
    - `06_alternativas_tecnologicas_evaluadas/`
    - `07_arquitectura_objetivo_plataforma/`
    - `08_estrategia_portabilidad_evolucion_nube/`
    - `09_modelo_operativo_experiencia_desarrollo/`
    - `10_seguridad_ciberseguridad_cumplimiento/`
    - `11_observabilidad_integral_confiabilidad/`

- `muticluster/`
  - Analisis complementario (incluye material de referencia Gartner).

- `ebpf/`
  - Analisis y material de observabilidad eBPF.

- `trash/`
  - Material historico, borradores y descartes (no usar como fuente primaria de publicacion).

## Convenciones de uso

- Priorizar siempre `00_resumen_ejecutivo_openshift_multicluster.md` para lectura ejecutiva.
- Para profundizar, usar los links numerados `[n]` hacia documentos detallados.
- Mantener trazabilidad: cuando se agregue contenido nuevo al resumen, actualizar sus referencias.
- Evitar duplicacion de contenido: consolidar en documentos fuente y referenciar desde el resumen.

## Estado del documento

Documento vivo. Se actualiza en funcion de avances de arquitectura, decisiones de plataforma y validaciones tecnicas de implementacion.
