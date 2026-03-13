# Speech técnico: F5 GTM mandatorio para la solución multicluster

**Objetivo:** Defender la implementación de F5 GTM como **condición necesaria** (no opcional) para lograr la solución multicluster frente a equipos de producto y mantenimiento.

---

## 1. Contexto: qué exige la solución multicluster

La arquitectura objetivo contempla:

- **~21 clusters** repartidos entre Plaza Galicia y Casa Matriz.
- **Tráfico north-south:** entrada desde Internet, core, legacy y partners hacia APIs en OpenShift, con capas DMZ → APIM → mesh/backends.
- **Objetivo de resiliencia:** conmutación entre sitios/clusters con **mínima intervención manual**, **failover más rápido y predecible** y **escalado multicluster sin rediseñar la exposición** en cada cambio.

Referencias: `7.4_arquitectura_de_ingress_egress_y_dns_global.md`, `propuesta-implementacion-ocp-multicluster.en.md` (secciones 3, 6.5).

---

## 2. Estado actual: por qué lo que tenemos no alcanza

Hoy:

- **Un solo F5 LTM** decide qué cluster está activo (Traffic Enabled/Disabled por sitio).
- **Failover es manual:** cambio de Traffic Enabled/Disabled en F5 LTM, sin decisión basada en salud de forma automática.
- **Comportamiento “agnóstico a DNS”:** no hay capa global que resuelva *a qué sitio/cluster* enviar el tráfico según salud o política.
- **Alta manualidad operativa:** gestión de VIPs, DNS corporativo, certificados y coordinación con redes dependen de tickets y ventanas.
- **Riesgo ya materializado:** incidente Feb-2026 por falla F5/load balancer con impacto en operación del cluster; dependencias compartidas (balanceo, DNS, storage, identidad, APIM) amplían el blast radius.

Documentación: `3.3_networking_ingress_egress_y_exposicion_de_servicios.md`, `4.3_complejidad_operativa_y_tareas_manuales.md`, `4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md`, tabla de limitaciones en `propuesta-implementacion-ocp-multicluster.en.md` (blast radius, F5).

Con **solo LTM** y procesos manuales, no se puede cumplir el objetivo de “conmutación transparente entre sitios con mínima intervención manual” ni escalar a 21 clusters sin multiplicar tickets y errores.

---

## 3. Por qué GTM es mandatorio (no “evolución cuando aplique”)

### 3.1 La arquitectura objetivo lo define como parte del plano operativo

- En **7.4** se establece: *“Integración de capacidades GTM/F5 e infraestructura DNS corporativa (por ejemplo Infoblox) como parte del plano operativo”*.
- El resultado esperado incluye: *“Menor dependencia de tickets manuales de networking”*, *“Menor tiempo de recuperación ante caída de cluster o sitio”*, *“Escalado multicluster sin rediseñar la exposición pública en cada cambio”*.

Eso solo es viable con una capa **global** de decisión de tráfico (DNS + salud + sitios). Esa capa en el stack corporativo es GTM.

### 3.2 Resiliencia y continuidad exigen failover automatizable

- **7.8** (patrones de resiliencia): *“Failover por DNS/balanceo global con criterios de salud definidos”*, *“Meta de reducción de RTO respecto del esquema manual actual, con automatización de conmutación como objetivo de diseño”*.
- **4.4** (brechas DR): *“Failover no plenamente automatizado”*, *“La manualidad y dependencia interequipos aumentan dispersión entre RTO objetivo y RTO efectivo”*.

Sin GTM no hay “balanceo global” ni “DNS con criterios de salud”. Se sigue dependiendo de cambios manuales en LTM y de TTL/caché de DNS, con RTO variable y alto riesgo operativo.

### 3.3 La decisión arquitectónica explícita liga GTM/LTM al beneficio

En la tabla problema → decisión → beneficio (`propuesta-implementacion-ocp-multicluster.en.md`, sección 4):

| Problema | Decisión | Beneficio |
|----------|----------|-----------|
| Exposición y consumo de servicios acoplados a ubicación física, con alta intervención manual de ingress | Ingress/egress con **DNS global, GTM/LTM**, sharding por función y **automatización de actualizaciones DNS** | **Failover rápido**, menor dependencia de tickets de red, **escalado multicluster sin rediseñar la exposición en cada cambio** |

Si GTM no se implementa, esa decisión no se cumple y el beneficio no se materializa.

### 3.4 H1 incluye el “nuevo modelo de tráfico” con F5 GTM

- En la propuesta, el **Step 1 (H1)** incluye de forma explícita: *“Nuevo modelo de tráfico con F5 GTM”*, *“Consolidación de ingress sharding (F5 GTM/LTM, DNS)”*, *“Desplegar y configurar F5 GTM para distribución global de tráfico y LTMs por sitio/cluster; integrar con DNS corporativo (Infoblox) y automatizar actualizaciones”*.

Tratarlo como opcional contradice el alcance acordado de H1 y deja sin soporte la distribución de tráfico entre múltiples clusters y sitios.

### 3.5 Alternativas evaluadas: GTM cierra la brecha actual

En **6.4** (alternativas de networking):

- Se indica que **F5 GTM con automatización** sirve para *“enrutar tráfico inter-sitio con health checks y conmutación controlada”* y da *“continuidad con el stack corporativo existente”*.
- Se señala como limitación que *“GTM no está implementado ni planificado a corto plazo”*, lo que obligaba a *“alternativa transitoria de ruteo/failover”*.

Declarar GTM **mandatorio** es justamente superar esa limitación: sin GTM no hay solución de ruteo/failover global acorde al objetivo multicluster.

### 3.6 Detalle técnico de la integración (propuesta detallada)

En `trash/propuesta_de_solucion_detallada.md` se describe la integración F5 GTM:

- **GTM gestiona el enrutamiento DNS de forma automática.**
- **APIs pueden vivir en múltiples clusters (activo-activo).**
- **Health checks:** GTM supervisa clusters; F5 (LTM) supervisa node pools.
- Integración con **External DNS operator + F5 GTM** (desarrollo a medida donde haga falta).

Sin GTM no hay esta separación de responsabilidades (global vs local) ni la posibilidad de activo-activo con health checks a nivel de cluster/sitio.

---

## 4. Respuesta al argumento “GTM como evolución cuando aplique”

En un resumen ejecutivo anterior se dijo: *“F5 GTM como capacidad de evolución cuando aplique; no condiciona el inicio de la transición multicluster.”*

Desde la documentación técnica actual:

1. **Inicio vs éxito:** Puede iniciarse trabajo de fundacionales y segmentación sin GTM, pero la **solución multicluster** (distribución de tráfico entre sitios/clusters, failover automatizado, escalado sin rediseñar exposición) **sí está condicionada** a tener una capa global de tráfico. Esa capa, en el stack definido, es GTM.
2. **Riesgo operativo:** Seguir con solo LTM y procesos manuales mantiene la dispersión de RTO, la dependencia de tickets y el riesgo de incidentes como el de Feb-2026. No es solo “evolución”, es **requisito para resiliencia y operación sostenible**.
3. **Consistencia con H1:** El plan de implementación ya incluye GTM en H1 (nuevo modelo de tráfico, consolidación ingress, integración DNS). Considerarlo opcional deja el alcance de H1 incompleto y sin soporte técnico para lo prometido.

Por tanto: **GTM sí condiciona la entrega de la solución multicluster** (no necesariamente el “día uno” de todos los trabajos, pero sí el resultado de tráfico, failover y escalado). Es mandatorio para cumplir los objetivos de arquitectura y resiliencia.

---

## 5. Beneficios que solo GTM habilita (resumen para producto/mantenimiento)

- **Failover rápido y predecible** entre sitios/clusters, con health checks y sin depender solo de TTL ni de cambios manuales en LTM.
- **Menor dependencia de tickets** de redes y balanceo para cada cambio de exposición o contingencia.
- **Escalado multicluster** sin rediseñar la exposición pública en cada nuevo cluster o dominio.
- **RTO más bajo y estable**, alineado con patrones de resiliencia (7.8) y reducción de brechas de DR (4.4).
- **Encaje con el stack actual:** F5 e Infoblox ya están en el perímetro; GTM completa la capa global sin introducir un vendor nuevo en el borde.

---

## 6. Frase de cierre para la defensa

**“F5 GTM es mandatorio porque es la única forma de tener distribución de tráfico automática y basada en salud entre 21 clusters y 2 sitios, con failover rápido y sin multiplicar la carga manual de redes y mantenimiento. Sin GTM, seguimos con el modelo actual: un solo punto de decisión manual en LTM, RTO variable y alto riesgo operativo. La arquitectura objetivo y el plan H1 ya lo contemplan como parte del plano operativo; implementarlo es condición para cumplir la solución multicluster.”**

---

## Referencias de documentos recorridos

| Tema | Documento |
|------|------------|
| Ingress/egress y DNS global | `02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md` |
| Resiliencia y failover | `02_multi-cluster/07_arquitectura_objetivo_plataforma/7.8_patrones_de_resiliencia_failover_y_continuidad_de_servicio.md` |
| Estado actual de red e ingress | `02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md` |
| Complejidad operativa y manualidad | `02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.3_complejidad_operativa_y_tareas_manuales.md` |
| Brechas de resiliencia y DR | `02_multi-cluster/04_diagnostico_problemas_deuda_tecnica/4.4_brechas_de_resiliencia_y_recuperacion_ante_desastres.md` |
| Alternativas de networking (GTM) | `02_multi-cluster/06_alternativas_tecnologicas_evaluadas/6.4_alternativas_de_networking_y_service_discovery.md` |
| Principio de resiliencia multicluster | `02_multi-cluster/05_principios_arquitectura_criterios_diseno/5.3_resiliencia_multicluster_y_alta_disponibilidad.md` |
| Propuesta de implementación (EN) | `propuesta-implementacion-ocp-multicluster.en.md` |
| Implementación (EN) | `implementacion-ocp-multicluster.en.md` |
| Integración F5 GTM (detalle) | `trash/propuesta_de_solucion_detallada.md` |
| Resumen ejecutivo antiguo (GTM opcional) | `executive_briefs/old/00_resumen_ejecutivo_openshift_multicluster.md` |
