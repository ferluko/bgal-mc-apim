# Fase 1 — Discovery del repositorio actual

**Fecha:** 2026-03-13  
**Alcance:** Barrido completo del repo para manifiestos OCP, DNS, F5, scripts, convenciones y evidencia de srepg/arqlab.

---

## 1. Resumen ejecutivo

- **networking/dns** y **networking/load_balancer**: carpetas presentes pero **vacías** (placeholders).
- **Clusters objetivo** (srepg, arqlab) están **declarados** en `networking/cilium/deployment/clusters/` con `env.sh` y documentación de instalación OCP/Cilium vía RHACM.
- **F5** aparece en documentación estratégica (GTM/LTM, VIPs, integración DNS) pero **no hay** playbooks, configs ni CRs de F5 en el repo.
- **Dominio base** y **VIPs** están definidos por cluster en `env.sh`; no hay manifiestos de Route/Ingress para apps en el repo.

---

## 2. Hallazgos por categoría

### 2.1 Manifiestos OpenShift existentes

| Ubicación | Tipo | Descripción |
|-----------|------|-------------|
| `networking/cilium/deployment/scripts/03_create_acm_resources.sh` | Secret, ConfigMap, MachineConfig, ClusterDeployment, ManagedCluster, AgentClusterInstall | Secrets: pull-secret, install-config, ssh-private-key, vsphere-creds, vsphere-certs. Manifiestos embebidos para RHACM (Hive/ACM). |
| `networking/cilium/deployment/docs/02_install_ocp_cilium_acm_paas-arqlab.md` | install-config, CiliumConfig, ejemplos YAML | Guía de instalación paas-arqlab con Cilium; no hay Routes ni Ingress de aplicación. |
| `networking/cilium/tests/manifests/` | Deployment, Job (k6, iperf3, netperf, target-deployment) | Manifiestos de prueba de conectividad/carga, no de exposición externa. |

**Conclusión:** No hay Routes, IngressControllers ni Ingress de aplicación versionados en el repo. La exposición externa se describe en documentación (7.4, 3.3) pero no está como YAML.

### 2.2 Configuraciones DNS

- **Documentación:** 7.4 (arquitectura ingress/egress y DNS global) define objetivo: DNS global, external-dns, GTM/F5, Infoblox.
- **Naming en repo:**
  - `api.<cluster>.bancogalicia.com.ar` (API server)
  - `*.apps.<cluster>.bancogalicia.com.ar` (wildcard apps) — citado en trash/propuesta_de_solucion_detallada.md
  - `api-int.<cluster>.bancogalicia.com.ar` (API interno)
- **networking/dns:** vacía; no hay zone files, registros ni integración external-dns versionada.

### 2.3 Scripts previos

| Script | Propósito |
|--------|-----------|
| `networking/cilium/deployment/scripts/deploy.sh` | Orquestación deploy por cluster (paas-arqlab, paas-srepg). |
| `01_download_clife.sh`, `02_generate_manifests.sh`, `03_create_acm_resources.sh` | Descarga Cilium/CLIFE, generación de manifests (incl. cluster-network-02-config-local.yml), creación recursos ACM. |
| `04_verify_install.sh`, `05_connectivity_test.sh` | Verificación post-instalación y tests de conectividad. |
| `00_env.sh`, `00_get_images.sh`, `debug_bootstrap.sh`, `new-cluster.sh`, `package-offline.sh` | Utilidades y entorno. |

Ninguno ejecuta discovery de F5 ni de estado de ingress/routes en clusters.

### 2.4 Playbooks Ansible

- **Referencias en documentación:** Terraform+Ansible para día 0/1/2, F5, DNS (vision_estrategia_multicluster, 3.2, 6.7, trash/indice2.md, propuesta_de_solucion_detallada.md).
- **Repo:** No existen archivos `*.yml`/`*.yaml` de playbooks Ansible en el árbol del proyecto (solo YAML de K8s/ACM/Cilium).
- **Conclusión:** Playbooks F5 “desarrollados” mencionados en indice2.md no están versionados en este repo.

### 2.5 Referencias a F5

- **Estratégico:** GTM/LTM, consolidación ingress sharding, modelo de tráfico (7.4, propuesta-implementacion-ocp-multicluster, 13.1, 13.5, executive briefs).
- **Operativo actual (prod):** F5 LTM — Traffic Enabled a paas-prdpg, Traffic Disabled a paas-prdmz; VIPs tipo **VS-Paas-Prd-HTTPS** con sharding por aplicación (propuesta-implementacion-ocp-multicluster.en.md).
- **Limitación:** GTM no implementado ni planificado corto plazo (6.4); alternativa transitoria de ruteo/failover.
- **Técnico (trash):** Virtual Server, Pool, Monitor, health checks, API; integración External DNS + F5 GTM como desarrollo custom.

No hay CRs de F5 CIS, ni plantillas de Virtual Server/Pool en el repo.

### 2.6 Operadores declarados

- **En uso/ref:** RHACM (ACM), Hive, Cilium (CLIFE), AgentClusterInstall.
- **Mencionados en docs:** External DNS, posible F5 BIG-IP operator (Gartner analisis).
- **Repo:** No hay manifests de suscripción a F5 CIS (Container Ingress Services) ni External DNS en este repositorio.

### 2.7 Secrets y plantillas relacionadas

- Secrets creados por `03_create_acm_resources.sh`: pull-secret, install-config, ssh-private-key, vsphere-creds, vsphere-certs (por cluster).
- No hay secrets ni plantillas para F5 (credenciales, particiones) ni para certificados de ingress en networking/dns o load_balancer.

### 2.8 Nombres de VIPs y hostnames

**Definidos en repo (env.sh por cluster):**

| Cluster     | API_VIP      | INGRESS_VIP  | Base domain           |
|------------|--------------|--------------|------------------------|
| paas-arqlab | 10.254.124.35 | 10.254.124.36 | bancogalicia.com.ar   |
| paas-srepg  | 10.254.124.10 | 10.254.124.11 | bancogalicia.com.ar   |

**Producción (solo documentación):** VS-Paas-Prd-HTTPS, múltiples VIPs con sharding por aplicación.

**Hostnames explícitos:**
- `api.paas-arqlab.bancogalicia.com.ar`, `api-int.paas-arqlab.bancogalicia.com.ar`
- `vcenterocp.bancogalicia.com.ar`, `bastionacm.bancogalicia.com.ar`
- `uoscp11m@bgcmz.bancogalicia.com.ar` (vSphere user)

### 2.9 Dominios y wildcard routes

- **Base domain:** `bancogalicia.com.ar`
- **Patrón API:** `api.<cluster>.bancogalicia.com.ar`
- **Patrón apps:** `*.apps.<cluster>.bancogalicia.com.ar` (documentado, no hay Route YAML en repo).
- No hay definición de wildcard Route ni IngressController custom en el repo.

### 2.10 Certificados e ingress

- Documentación: certificados y habilitaciones de red como dependencia manual (3.3).
- No hay Certificate (cert-manager) ni Ingress/Route de aplicación en el repo.
- Ingress principal documentado: HAProxy/OpenShift ingress controllers.

### 2.11 External DNS

- Mencionado como objetivo (7.4, 8.1, propuesta) y “External DNS operator para eliminar dependency manual Infoblox” (trash/indice2.md).
- No hay configuración ni manifests de external-dns en el repo.

### 2.12 Naming conventions

- Clusters: `paas-<nombre>` (paas-arqlab, paas-srepg, paas-prdpg, paas-prdmz).
- Cluster ID (Cilium): numérico 1–255 (arqlab=1, srepg=2).
- Dominio: `<cluster>.bancogalicia.com.ar` para API y apps.
- VIPs en env: `API_VIP`, `INGRESS_VIP` por cluster.

### 2.13 Referencias a srepg y arqlab

- **paas-srepg:** `networking/cilium/deployment/clusters/paas-srepg/env.sh`, README/deploy docs, subnetting (como cluster-02 en tabla), 7.1 (laboratory).
- **paas-arqlab:** `networking/cilium/deployment/clusters/paas-arqlab/env.sh`, 02_install_ocp_cilium_acm_paas-arqlab.md, scripts con `CLUSTER_NAME=paas-arqlab`, 7.1 (laboratory).
- Ambos: Laboratory para arquitectura y SRE; experimentación y pruebas especializadas.

### 2.14 Objetos preparados para multicluster

- Cluster Mesh Cilium: CLUSTER_ID y Pod CIDR distintos por cluster (arqlab 10.128.0.0/18, srepg 10.128.64.0/18).
- RHACM: ClusterDeployment, ManagedCluster, AgentClusterInstall por cluster.
- No hay objetos de tipo ApplicationSet, PlacementRule, o recursos F5/GTM para multicluster en el repo.

---

## 3. Gaps identificados (para lab F5 LTM/GTM + srepg/arqlab)

1. **networking/dns y load_balancer vacíos:** Hay que poblar con inventario, scripts de discovery y (opcional) zone/registros de laboratorio.
2. **Sin automatización F5 en repo:** Crear playbooks Ansible con módulos F5 y scripts de discovery LTM/GTM.
3. **Sin discovery de estado vivo:** Scripts para clusters (oc) y F5 (tmsh/iControl REST) que generen inventario consolidado.
4. **Sin F5 CIS en repo:** Añadir despliegue del operador F5 CIS y CRs de ejemplo tras validar versión OCP.
5. **Sin app de prueba versionada:** Añadir manifiestos (nginx o http-echo) y pasos para route local, LTM y GTM.
6. **Sin plan de pruebas de failover:** Documentar y automatizar casos (caída ingress, caída cluster, degradación, failback).

---

## 4. Evidencia de rutas del documento

- 7.4: `02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md`
- 3.3: `02_multi-cluster/03_estado_actual_plataforma_openshift/3.3_networking_ingress_egress_y_exposicion_de_servicios.md`
- VIPs y clusters: `networking/cilium/deployment/clusters/paas-arqlab/env.sh`, `paas-srepg/env.sh`
- Producción F5: `propuesta-implementacion-ocp-multicluster.en.md` (VS-Paas-Prd-HTTPS, LTM activo/standby)
