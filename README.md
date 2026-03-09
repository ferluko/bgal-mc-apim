# Reingenieria OpenShift Multicluster - Documentacion General

**Author:** [fernando.l.gonzalez@bancogalicia.com.ar](mailto:fernando.l.gonzalez@bancogalicia.com.ar)

## Proposito

Este repositorio concentra la documentacion estrategica y tecnica de la reingenieria de plataforma OpenShift en Banco Galicia, con foco principal en la evolucion hacia un modelo multicluster.

El objetivo es disponer de una fuente unica para:

- Entender el contexto, diagnostico y drivers de transformacion.
- Consultar la arquitectura objetivo por dominio.
- Seguir decisiones tecnicas, roadmap y riesgos.
- Facilitar comunicacion ejecutiva y alineamiento tecnico entre equipos.
- Mantener un marco comun de 8 objetivos de reingenieria (escalabilidad y segmentacion, resiliencia, seguridad integral, observabilidad end-to-end, gobernanza y automatizacion, portabilidad, migracion a nube y minimizacion de lock-in).

## Alcance

El alcance principal del material es multicluster. El frente APIM se incluye como caso modelador y antecedente de decisiones de arquitectura, seguridad, observabilidad, resiliencia y operacion.

## Ruta de lectura recomendada

- `propuesta-implementacion-ocp-multicluster.md` — Documento principal en espanol (estrategia, topologia, fases y plan de ejecucion).
- `propuesta-implementacion-ocp-multicluster.en.md` — Version completa en ingles del documento principal.
- `executive_briefs/propuesta-implementacion-ocp-multicluster.executive-summary.es.md` — Resumen ejecutivo actualizado en espanol.
- `executive_briefs/propuesta-implementacion-ocp-multicluster.executive-summary.en.md` — Executive summary actualizado en ingles.
- `implementacion-ocp-imagenes/` — Diagramas y figuras referenciadas en los documentos principales.

## Estructura principal

- `executive_briefs/`
  - Resumenes ejecutivos vigentes (espanol e ingles) para consumo de negocio y liderazgo tecnico.

- `executive_briefs/old/`
  - Versiones historicas y material previo que ya no es fuente primaria.

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

- `solution_briefs/`
  - Entregables externos y assessments de terceros (por ejemplo, evaluaciones FlightPath).

- `trash/`
  - Material historico, borradores y descartes (no usar como fuente primaria de publicacion).

## Cambios incorporados hoy (2026-03-09)

- Se incorporo `propuesta-implementacion-ocp-multicluster.en.md` como version en ingles del documento completo.
- Se agrego `solution_briefs/` para alojar evaluaciones de terceros complementarias al marco de arquitectura.

## Convenciones de uso

- Priorizar `executive_briefs/propuesta-implementacion-ocp-multicluster.executive-summary.es.md` para lectura ejecutiva en espanol.
- Usar `executive_briefs/propuesta-implementacion-ocp-multicluster.executive-summary.en.md` cuando se necesite version en ingles.
- Para profundizar, usar los links numerados `[n]` hacia documentos detallados.
- Mantener trazabilidad: cuando se agregue contenido nuevo al resumen, actualizar referencias en ES/EN.
- Evitar duplicacion de contenido: consolidar en documentos fuente y referenciar desde el resumen.

## Cómo colaborar (sin clone, push ni merge request)

Podés sumar correcciones, ideas o mejoras sin clonar el repo ni abrir un MR desde tu máquina:

1. **Sugerir un cambio concreto** *(recomendado)*  
   Seleccioná el texto que quieras cambiar y usá *Suggest change* en el comentario de un PR o en la vista de comparación. El mantenedor puede aplicar la sugerencia en un solo clic. Es la forma más sencilla de proponer correcciones sin tocar el repo.

2. **Editar en la web**  
   En GitHub: abrí el archivo, hacé clic en el ícono del lápiz (*Edit this file*). Editás, guardás y elegís *Commit directly* (si tenés permisos) o *Propose changes*: se crea un branch y un Pull Request automático desde el navegador.

3. **Abrir un Issue**  
   Si preferís no tocar el contenido: creá un Issue describiendo la corrección, la idea o el tema que falta. Podés pegar el párrafo sugerido en el cuerpo del Issue para que alguien lo incorpore.

4. **Comentar en un PR o Issue existente**  
   Cualquier comentario con feedback, preguntas o propuestas de texto cuenta como colaboración y se puede integrar después.

Para flujo clásico (clone, branch, push, MR) usá el mismo repositorio; estas opciones son para participar con el mínimo de pasos.

## Estado del documento

Documento vivo. Se actualiza en funcion de avances de arquitectura, decisiones de plataforma y validaciones tecnicas de implementacion.
