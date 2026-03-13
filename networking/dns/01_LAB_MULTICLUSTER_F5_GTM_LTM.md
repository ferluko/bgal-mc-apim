# Lab multicluster OpenShift + F5 LTM/GTM — srepg y arqlab

Escenario de laboratorio para validar arquitectura multicluster con **F5 LTM local por cluster/site**, **F5 GTM global** y dos clusters OpenShift ya desplegados: **srepg** y **arqlab**.

**Principio rector:** Primero descubrir el estado real (repo, clusters, F5); luego correlacionar; luego extender. No asumir configuración inexistente.

---

## Estado del repositorio (Fase 1)

- Hallazgos detallados: **[00_DISCOVERY_FASE1_HALLAZGOS_REPO.md](00_DISCOVERY_FASE1_HALLAZGOS_REPO.md)**.
- Resumen: `networking/dns` y `networking/load_balancer` estaban vacíos; clusters paas-arqlab y paas-srepg definidos en `networking/cilium/deployment/clusters/` con VIPs y base domain; referencias F5/GTM en documentación estratégica sin playbooks ni CRs en repo.

---

## Fase 2 — Discovery clusters OpenShift

**Objetivo:** Descubrir automáticamente srepg y arqlab (versión, ingress, routes, certificados, operadores, endpoints LTM).

### Cómo ejecutar

1. Tener `oc` en PATH y sesión contra cada cluster (o KUBECONFIG con contextos).
2. Orquestado por bash (recomendado):
   ```bash
   cd networking/dns/scripts
   ./deploy.sh discovery
   ```
   (incluye repo, clusters, F5 e inventario). Solo clusters: usar el paso 02 suelto:
   ```bash
   source 00_env.sh
   ./02_discover_clusters.sh
   ```
   o con clusters explícitos: `CLUSTERS="paas-arqlab paas-srepg" ./02_discover_clusters.sh`
3. Salida en `networking/dns/output/discovery-cluster-<nombre>-<timestamp>.txt`.

### Qué validar

- Versión OpenShift (compatibilidad con F5 CIS).
- IngressControllers (default, dominio wildcard).
- Routes existentes y dominios reales expuestos.
- Certificados en `openshift-ingress`.
- Namespaces y operadores (presencia o no de F5 CIS).
- Servicio de ingress (LoadBalancer/NodePort) como **endpoints candidatos para LTM**.

---

## Fase 3 — Discovery F5 LTM

**Objetivo:** Los LTM ya existen; no recrearlos. Descubrir virtual servers, pools, pool members, monitors, partitions, SSL profiles, SNAT, iRules, device groups, HA. Mapear qué objetos corresponden a srepg y a arqlab.

### Cómo ejecutar

Orquestado por bash (un F5 por ejecución; para varios F5, ejecutar 03 dos veces o configurar en deploy):
```bash
cd networking/dns/scripts
F5_HOST=<ip_ltm_arqlab> F5_USER=admin F5_PASSWORD=xxx ./03_discover_f5.sh
# Para LTM srepg (otro equipo):
F5_HOST=<ip_ltm_srepg> F5_USER=admin F5_PASSWORD=xxx ./03_discover_f5.sh
```
O en el discovery completo: `F5_HOST=... F5_USER=... F5_PASSWORD=... ./deploy.sh discovery` (descubre un F5; para varios, ejecutar 03 a mano después).

Salida en `output/`: `discovery-f5-virtual-*.json`, `discovery-f5-pools-*.json`, `discovery-f5-monitors-*.json`, etc.

### Mapeo srepg / arqlab

- Correlacionar nombres de virtual server y pool con documentación (ej. convención VS-Paas-* por cluster/site).
- Anotar en inventario qué VIP/pool pertenecen a paas-arqlab y cuáles a paas-srepg.

---

## Fase 4 — Discovery GTM

**Objetivo:** Validar si hay licencia GTM; descubrir wide IPs, GTM pools, data centers, servers, global monitors.

### Cómo ejecutar

- El paso 03 (`03_discover_f5.sh`) consulta `/mgmt/tm/gtm/wideip` si el host tiene módulo GTM.
- Ejecutar contra el F5 que tenga GTM:
  ```bash
  F5_HOST=<ip_gtm> F5_USER=admin F5_PASSWORD=xxx ./03_discover_f5.sh
  ```
- Revisar `output/discovery-f5-wideip-*.json` y `discovery-f5-gtm-*.json`.

---

## Fase 5 — Automatización

- **Bash orquesta todo** (estilo `networking/cilium/deployment/scripts`):
  - `deploy.sh discovery` — ejecuta pasos 01 a 04 (repo, clusters, F5, inventario).
  - `deploy.sh config-f5` — invoca Ansible (paso 05) para configuración F5.
  - Scripts en `networking/dns/scripts/`: `00_env.sh`, `01_discover_repo.sh`, `02_discover_clusters.sh`, `03_discover_f5.sh`, `04_generate_inventory.sh`, `05_run_ansible.sh`.
- **Ansible** se invoca solo desde bash (`05_run_ansible.sh`):
  - Inventario generado en `output/inventory.yml` por el paso 04.
  - `ansible/playbook-discovery.yml` — discovery (lectura).
  - `ansible/playbook-config-f5.yml` — configuración F5 (invocado por `deploy.sh config-f5`).
  - `group_vars/all.yml` — copiar desde `all.yml.example` y completar IPs/credenciales.
- Instalar colecciones (una vez):
  ```bash
  ansible-galaxy collection install community.kubernetes
  ansible-galaxy collection install f5networks.f5_modules
  ```
- Flujo recomendado:
  ```bash
  cd networking/dns/scripts
  ./deploy.sh discovery                    # 01–04, genera output/inventory.yml
  # Opcional: editar ansible/group_vars/all.yml
  ./deploy.sh config-f5                    # 05: ansible-playbook config-f5
  ```

---

## Fase 6 — Integración OpenShift + F5 (F5 CIS)

- **Desplegar el operador oficial F5 BIG-IP CIS (Container Ingress Services)** solo después de haber ejecutado el discovery (Fases 2–4).
- Validar compatibilidad con la versión actual de OpenShift (matriz de compatibilidad F5/Red Hat).
- Pasos típicos:
  1. Crear namespace para el operador (ej. `kube-system` o `f5-cis`).
  2. Instalar operador F5 CIS (OLM o manifests).
  3. Crear Secret con credenciales BIG-IP.
  4. Crear CR `IngressLink` o `VirtualServer` que apunte al LTM correspondiente (arqlab o srepg) y al ingress del cluster.
- Documentar en este repo la versión de CIS y los CRs de ejemplo una vez validado.

---

## Fase 7 — Aplicación de prueba

- Desplegar una aplicación simple (nginx o http-echo) en **ambos** clusters (srepg y arqlab).
- Validar:
  1. **Route local:** que la app sea accesible vía route OpenShift dentro del cluster.
  2. **Publicación LTM:** que el LTM del site tenga un virtual server/pool apuntando al ingress del cluster (o al servicio de la app) y que el tráfico llegue.
  3. **Asociación GTM:** que una wide IP en GTM apunte a los LTM de ambos clusters y que el tráfico se reparta o conmute según salud.

Manifiestos de ejemplo de app de prueba: ver carpeta `manifests/` (si se añaden) o usar `oc new-app`/deployment+service+route estándar.

---

## Fase 8 — Casos de prueba

| Caso | Acción | Resultado esperado |
|------|--------|---------------------|
| Caída ingress srepg | Deshabilitar o simular fallo en ingress del cluster srepg | GTM/LTM deja de enviar tráfico a srepg; usuarios siguen siendo servidos por arqlab (o el otro sitio). |
| Caída cluster srepg | Apagar o aislar el cluster srepg | GTM marca el pool/LTM de srepg como down; todo el tráfico va a arqlab. |
| Degradación parcial | Degradar solo parte de los nodos o del ingress de un cluster | Health checks reflejan estado; posible reparto parcial o failover según configuración. |
| Failback controlado | Restaurar srepg y habilitar de nuevo en LTM/GTM | Tráfico vuelve a repartirse o a incluir srepg según política (activo-pasivo o activo-activo). |

Ejecutar y documentar resultados en `output/` o en un runbook en este mismo directorio.

---

## Fase 9 — Resultado esperado

Entregables:

1. **Inventario descubierto:** generado por scripts y/o Ansible en `output/`.
2. **Mapa de arquitectura real actual:** diagrama o documento que refleje clusters, VIPs, LTM por site, GTM y flujo de tráfico según lo descubierto.
3. **Gaps encontrados:** lista (iniciada en 00_DISCOVERY_FASE1_HALLAZGOS_REPO.md) actualizada con lo que falte para producción (certificados, DNS automático, CIS, etc.).
4. **Scripts bash:** en `networking/dns/scripts/`.
5. **Playbooks Ansible:** en `networking/dns/ansible/` (discovery; extensibles a configuración F5 y despliegue CIS/app).
6. **Plan de pruebas ejecutable:** Fase 8 documentado y, si se desea, pasos automatizados (scripts o playbooks) para reproducir caída/failback.

---

## Restricción crítica

Primero observar (Fases 1–4). Luego correlacionar (inventario, mapa). Luego extender (CIS, app de prueba, casos de prueba). No asumir configuración que no exista en clusters o en F5.
