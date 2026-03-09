# Propuesta de Implementación OCP Multicluster

## Resumen Ejecutivo

**Fecha:** 2026-03-09

---

## 1. Contexto y Problema

Banco Galicia opera hoy una plataforma OpenShift de gran escala:

- **9 clusters** administrados con ACM
- **+500 nodos**, **+15.000 aplicaciones** y **+40.000 contenedores**
- **~2.200 APIs productivas** y **~8.000 millones de requests/mes**

Aunque existe una flota de clusters, la carga crítica de producción se concentra en un esquema **activo-pasivo** (`paas-prdpg` / `paas-prdmz`) que funciona como unidad lógica de riesgo y escalado. Esta concentración expone limitaciones estructurales:

- **Blast radius elevado** ante fallas de red, storage o configuración
- **Alta manualidad operativa** (VIPs, DNS, certificados, DR, sincronización)
- **Límites de escalabilidad y elasticidad** del modelo monolítico
- **Hair-pinning en parte del tráfico interno**, con impacto en latencia
- **Ventanas de mantenimiento extensas** y riesgo de *configuration drift* entre sitios

Se suma un factor de urgencia: **3scale (APIM actual) tiene fin de vida en 2027**, lo que obliga a ejecutar una transición ordenada y no reactiva.

---

## 2. Objetivo de la Iniciativa

La iniciativa no busca solo reemplazar APIM; busca evolucionar integralmente la plataforma hacia un modelo multicluster gobernado, escalable y auditable.

Objetivos concretos:

- Reducir riesgo sistémico mediante segmentación por dominios y criticidad
- Sostener continuidad operativa con patrones de resiliencia multicluster
- Habilitar escalado horizontal y crecimiento por oleadas de negocio
- Estandarizar operación con **GitOps + IaC** (day 0 / day 1 / day 2)
- Fortalecer seguridad by design (**Zero Trust, RBAC declarativo, Vault, mTLS**)
- Consolidar observabilidad federada (**OpenTelemetry + eBPF**)
- Mejorar la experiencia de equipos de plataforma y desarrollo con guardrails y self-service

El resultado buscado es transformar la plataforma actual en una base tecnológica estandarizada, gobernable y preparada para escalar el crecimiento digital del banco.

---

## 3. Arquitectura Propuesta

La arquitectura objetivo define una flota estimada de **21 clusters** distribuidos por entorno y dominio:

- **Governance** Hub ACM
    - 1 cluster
- **API Management (N/S)** Producción y DR
    - 2 clusters
- **Production Workload clusters** QA  y Prod con DR por grupos de dominio
    - 10 clusters
- **Non-Production Workload clusters** Dev y Stg
    - 2 clusters
- **Shared Services/Storage** Prod y Non-Prod con DR
    - 4 clusters
- **Clusters de laboratorio y SRE**
    - 2 clusters

### Componentes principales

**1. Gobierno central multicluster (Hub-Spoke)**  
Control plane central con ACM para políticas, ciclo de vida, cumplimiento y operación de flota.

**2. Data planes distribuidos por dominio y sitio**  
Clusters de ejecución con responsabilidades separadas para contener incidentes y desacoplar el crecimiento.

**3. Ingreso y exposición con sharding + DNS global**  
Arquitectura de ingreso con F5 GTM/LTM, integración con DNS corporativo y automatización progresiva para failover y control de tráfico entre sitios.

**4. Patrones de tráfico north-south y east-west**  
Separación explícita entre gobierno L7 de APIs (north-south) y comunicación interna service-to-service (east-west). En H1 se prioriza estabilidad north-south y en H2 se consolida la evolución de malla east-west.

**5. Operación declarativa y seguridad integral**  
GitOps + IaC como estándar de cambio, políticas declarativas, trazabilidad auditable, identidad de workload y gestión de secretos con Vault.

---

## 4. Beneficios Clave para la Organización

### 1. Reducción del Riesgo Sistémico

Segmentar clusters por dominio y criticidad reduce blast radius y limita impacto cruzado de incidentes.

### 2. Continuidad Operativa y Resiliencia

El programa incorpora patrones de HA/DR con DNS global, health checks multicapa, runbooks y ejercicios de recuperación con criterios de no-go-live.

### 3. Escalabilidad Sostenible

Se pasa de un escalado monolítico a crecimiento por dominios y oleadas, alineado a demanda real de negocio.

### 4. Eficiencia Operativa y Menor Manualidad

GitOps/IaC, automatización day 0 / day 1 / day 2 y gobierno central disminuyen tareas manuales, errores y deriva de configuración.

### 5. Seguridad y Cumplimiento Mejorada

Modelo Zero Trust, mínimo privilegio, RBAC declarativo, mTLS y trazabilidad fortalecen cumplimiento regulatorio y auditoría.

### 6. Base Tecnológica Evolutiva

El enfoque en estándares y portabilidad reduce lock-in y prepara la plataforma para evolución on-prem y multinube.

---

## 5. Impacto Estratégico

La iniciativa impacta directamente en prioridades de negocio y tecnología:

**Continuidad del negocio bancario**  
Mitiga riesgos operativos de alta criticidad y mejora la capacidad de recuperación ante incidentes.

**Escala para crecimiento digital**  
Permite sostener mayor volumen de aplicaciones, APIs y transaccionalidad sin multiplicar complejidad en la misma proporción.

**Ejecución tecnológica con control**  
Establece una transición por fases, con criterios de avance y gobierno ejecutivo, evitando migraciones forzadas por obsolescencia (EOL 3scale 2027).

**Plataforma como habilitador estratégico**  
Convierte la plataforma de un esquema reactivo y concentrado a un modelo distribuido, gobernado y preparado para nuevas iniciativas.

---

## 6. Enfoque de Implementación

El programa se ejecuta en **dos steps y cinco fases**, con adopción progresiva y mitigación de riesgo.

### Step 1 (H1 2026): Fundaciones, habilitadores y gobierno operativo

- Fase 5.1: base de gobierno, seguridad, observabilidad y estándar operativo
- Fase 5.2: consolidación de ingress sharding, GTM/LTM y desacople inicial de flujos
- Fase 5.3: segmentación operativa y gobierno multicluster, primer movimiento de cargas.

Entregables clave de H1:

- Topología base PAAS/IaaS por sitio
- Automatización day 0 / day 1 / day 2
- Segmentación operativa y dominios de responsabilidad con gobierno activo
- Observabilidad e2e con eBPF
- Esquema HA activo-pasivo estabilizado con bases para evolución

### Step 2 (H2 2026): Movimiento y consolidación operativa

- Fase 5.4: consolidación y madurez del proceso de movimiento de cargas por oleadas
- Fase 5.5: consolidación de patrones de alta disponibilidad y continuidad

Entregables clave de H2:

- Madurez del proceso de movimiento de cargas y de patrones north-south/east-west
- Consolidación de la operación por dominios en la topología objetivo
- Reducción progresiva del riesgo del monolito productivo
- Avance del frente APIM antes del EOL de 3scale

---

## 7. Riesgos y Consideraciones

El programa identifica riesgos críticos y mitigaciones desde el inicio, incluyendo riesgos propios y de terceros.

Riesgos de mayor prioridad:

- Inestabilidad en patrones cross-cluster críticos
- Complejidad de upgrades de plataforma/red y dependencias técnicas
- Desvío de configuración entre clusters y sitios
- Brechas en la transición de identidades y secretos
- Demoras de terceros (hardware, networking, licencias, soporte vendor)
- Sobrecarga operativa durante coexistencia de modelo actual y objetivo

Líneas de mitigación:

- Ejecución por fases con criterios explícitos de no-go-live
- Validaciones técnicas obligatorias en POC, staging y preproducción
- Baseline declarativo con reconciliación continua (GitOps)
- Gestión temprana de dependencias contractuales y de supply
- Runbooks, drills de continuidad y control ejecutivo de riesgos

---

## 8. Conclusión

La evolución a OCP multicluster es una decisión estratégica de continuidad y escalabilidad, no una mejora incremental de infraestructura.

La propuesta alinea arquitectura, operación y gobierno para reducir riesgo sistémico, sostener el crecimiento del banco y mejorar la capacidad de respuesta tecnológica.

El reemplazo de APIM es un frente importante dentro del programa, pero el resultado buscado es mayor: una plataforma distribuida, segura, auditable y preparada para crecimiento sostenido.
