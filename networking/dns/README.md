# networking/dns — Lab multicluster F5 LTM/GTM + OpenShift (srepg, arqlab)

Contenido para descubrir y validar arquitectura multicluster con **F5 LTM** por cluster/site y **F5 GTM** global, usando los clusters **paas-srepg** y **paas-arqlab**.

**Enfoque:** orquestación en **bash** (igual que `networking/cilium/deployment/scripts`); Ansible se invoca solo para discovery o configuración F5, desde los scripts.

## Principio

**Primero observar, luego correlacionar, luego extender.** No asumir configuración inexistente.

## Estructura

| Elemento | Descripción |
|----------|-------------|
| `00_DISCOVERY_FASE1_HALLAZGOS_REPO.md` | Hallazgos del barrido del repositorio (manifiestos, DNS, F5, VIPs, srepg/arqlab). |
| `01_LAB_MULTICLUSTER_F5_GTM_LTM.md` | Guía del lab: Fases 2–9 (discovery, automatización, CIS, app de prueba, casos de prueba). |
| `02_PLAN_PRUEBAS_EJECUTABLE.md` | Plan de pruebas (caída ingress, caída cluster, degradación, failback). |
| `scripts/` | **Orquestación bash:** `deploy.sh` (entrada única), `00_env.sh`, pasos `01_`–`05_`. Ansible se invoca desde `05_run_ansible.sh`. |
| `ansible/` | Inventario (generado por paso 04) y playbooks (discovery + config-f5), invocados por bash. |
| `manifests/` | Manifiestos de app de prueba (nginx) para ambos clusters. |
| `output/` | Salida de discovery e inventario generado (no versionar credenciales). |

## Uso rápido (orquestado por bash)

Desde `networking/dns/scripts/`:

1. **Discovery completo (repo + clusters + F5 + inventario):**  
   `./deploy.sh discovery`  
   Requiere `oc` y, para F5, `F5_HOST`, `F5_USER`, `F5_PASSWORD`.

2. **Discovery sin F5 (si no hay F5 disponible):**  
   `./deploy.sh discovery --skip-f5`

3. **Solo inventario (tras discovery):**  
   El paso 04 es el último del discovery; el inventario queda en `../output/inventory.yml`.

4. **Configuración F5 vía Ansible (invocada por bash):**  
   `./deploy.sh config-f5`  
   Usa el inventario de `output/` y, si existe, `../ansible/group_vars/all.yml`. Opciones:  
   `./deploy.sh config-f5 --limit f5_ltm_arqlab`

5. **Ejecutar un paso suelto:**  
   `./01_discover_repo.sh`, `./02_discover_clusters.sh`, `./03_discover_f5.sh`, `./04_generate_inventory.sh`,  
   `./05_run_ansible.sh discovery` o `./05_run_ansible.sh config-f5`

6. **App de prueba (Fase 7):**  
   Ajustar el host del Route en `manifests/test-app-nginx.yaml` por cluster y aplicar:  
   `oc apply -f manifests/test-app-nginx.yaml`

## Pasos (deploy.sh discovery)

| Paso | Script | Descripción |
|------|--------|-------------|
| 1 | `01_discover_repo.sh` | Barrido repo (manifiestos, DNS, F5, VIPs, srepg/arqlab). |
| 2 | `02_discover_clusters.sh` | Discovery clusters OpenShift (oc). |
| 3 | `03_discover_f5.sh` | Discovery F5 LTM/GTM (iControl REST). |
| 4 | `04_generate_inventory.sh` | Genera `output/inventory.yml` para Ansible. |
| 5 | `05_run_ansible.sh` | Invocado por `deploy.sh config-f5`; ejecuta playbook-config-f5.yml. |

## Referencias en el repo

- VIPs y base domain por cluster: `../cilium/deployment/clusters/paas-arqlab/env.sh`, `paas-srepg/env.sh`.
- Arquitectura DNS/ingress objetivo: `02_multi-cluster/07_arquitectura_objetivo_plataforma/7.4_arquitectura_de_ingress_egress_y_dns_global.md`.
