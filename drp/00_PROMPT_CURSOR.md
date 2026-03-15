# Prompt para Cursor AI — DRP Evidence Framework
## OpenShift + F5 LTM Active-Active + 3scale (amp) — Banco Galicia

---

> **Cómo usar este prompt:**
> Pegá el bloque de texto del apartado "PROMPT PARA CURSOR AI" directamente en Cursor AI (chat o composer).
> Cursor va a generar código, completar scripts, detectar problemas y ampliar el framework.

---

## Arquitectura real del entorno (contexto crítico)

### Clusters OpenShift

| Nombre       | Site          | Rol en PRE/POST | Rol en DURING |
|-------------|---------------|-----------------|---------------|
| paas-prdpg  | Plaza Galicia | **ACTIVO**      | pasivo        |
| paas-prdmz  | Casa Matriz   | pasivo          | **ACTIVO**    |

### F5 LTM — Active-Active Cluster

El F5 es un **cluster Active-Active**: las mismas IPs de VIP existen en ambos sites.  
Durante el DR **no se habilitan/deshabilitan VIPs** — lo que cambia son los **pool members**.

| VIP           | Virtual Server              | Descripción              |
|---------------|-----------------------------|--------------------------|
| 10.254.50.1   | VS-PaaS-Prd-HTTP/S          | Default router (clustered, misma IP ambos sites) |
| 10.254.50.11  | VS-Appsa1-PaaS-prd-HTTP/S   | Apps shard 1             |
| 10.254.50.12  | VS-Appsa2-PaaS-prd-HTTP/S   | Apps shard 2             |
| 10.254.50.13  | VS-Appsa3-PaaS-prd-HTTP/S   | Apps shard 3             |
| 10.254.50.14  | VS-Appsa4-PaaS-prd-HTTP/S   | Apps shard 4             |
| 10.254.50.15  | VS-Appsa5-PaaS-prd-HTTP/S   | Apps shard 5             |
| 10.254.50.16  | VS-Appsa6-PaaS-prd-HTTP/S   | Apps shard 6             |

**Mecanismo DRP F5:**
- PRE/POST: pool members de PGA (Plaza) → `enabled/up`; pool members de CMZ → `disabled`
- DURING: pool members de CMZ (Matriz) → `enabled/up`; pool members de PGA → `disabled`

### DNS — estructura real

| FQDN | Tipo | PRE/POST target | DURING target |
|------|------|-----------------|---------------|
| `api.paas-prd.bancogalicia.com.ar` | CNAME agnóstico API | `api.paas-prdpg.bancogalicia.com.ar` | `api.paas-prdmz.bancogalicia.com.ar` |
| `*.paas-prd.bancogalicia.com.ar` | Wildcard apps (via F5) | `appsprdf5-1.apps.paas-prd.bancogalicia.com.ar` | `appsprdf5.apps.paas-prd.bancogalicia.com.ar` |
| `appsa1.paas-prd.bancogalicia.com.ar` | Apps1 router | apunta a VS-Appsa1 | idem |

### 3scale / APIM

- Namespace único: **`amp`**
- Componentes críticos: `apicast-production`, `apicast-staging`, `system-app`, `system-sidekiq`, `backend-listener`, `backend-worker`

---

## Framework existente — `drp/`

```
drp/
├── 00_env.sh                  ← variables (clusters, F5 VIPs/VS, DNS, amp)
├── run-dr-exercise.sh         ← orquestador + war room instructions
├── pre/precheck.sh            ← FASE PRE (PGA activo baseline)
├── during/during.sh           ← FASE DURANTE (CMZ activo, snapshots)
├── post/postcheck.sh          ← FASE POST (validación retorno PGA)
├── collectors/
│   ├── _run-all.sh            ← ejecuta todos los collectors (ambos clusters)
│   ├── cluster-health.sh      ← ClusterVersion + ClusterOperators
│   ├── nodes.sh               ← nodos, presión, taints, top
│   ├── pods.sh                ← pods, reinicios, OOMKilled
│   ├── ingress.sh             ← routers, IngressControllers, routes
│   ├── events.sh              ← eventos Warning ordenados
│   ├── apim-3scale.sh         ← ns:amp pods + APIcast + system-app logs
│   ├── audit.sh               ← audit logs (cambios manuales de squads)
│   ├── dns-check.sh           ← snapshot DNS (api.paas-prd, apps wildcard)
│   └── f5-status.sh           ← pool members estado PGA/CMZ via iControl REST
└── live/
    ├── watch-events.sh        ← TTY-2: Warning events en vivo
    ├── watch-pods.sh          ← TTY-3: pods problemáticos + reinicios
    ├── watch-ingress.sh       ← TTY-4: routers en vivo
    ├── watch-dns.sh           ← TTY-5: DNS CNAME polling (detecta switch exacto)
    ├── watch-audit.sh         ← TTY-6/7: audit log stream
    └── watch-changes.sh       ← TTY-8: watcher deploy/routes/cm
```

---

## PROMPT PARA CURSOR AI

```
You are a Senior OpenShift SRE and Platform Reliability Engineer.
You are working on the DR exercise evidence collection framework located in drp/.

Read ALL existing scripts before generating code. Do not duplicate logic.

=== PLATAFORMA ===

OpenShift clusters:
  - paas-prdpg  → Plaza Galicia (PGA) — sitio primario
  - paas-prdmz  → Casa Matriz (CMZ)   — sitio DR

F5 LTM: Active-Active cluster
  VIPs (mismas IPs en ambos sites):
  - 10.254.50.1  → VS-PaaS-Prd-HTTP/S         (default router, clustered)
  - 10.254.50.11 → VS-Appsa1-PaaS-prd-HTTP/S
  - 10.254.50.12 → VS-Appsa2-PaaS-prd-HTTP/S
  - 10.254.50.13 → VS-Appsa3-PaaS-prd-HTTP/S
  - 10.254.50.14 → VS-Appsa4-PaaS-prd-HTTP/S
  - 10.254.50.15 → VS-Appsa5-PaaS-prd-HTTP/S
  - 10.254.50.16 → VS-Appsa6-PaaS-prd-HTTP/S

F5 DRP mechanism:
  NOT enable/disable VIPs — the VIPs are always enabled.
  During DR, pool MEMBERS change: PGA members go disabled, CMZ members go enabled.

DNS structure:
  api.paas-prd.bancogalicia.com.ar
    PRE/POST: CNAME → api.paas-prdpg.bancogalicia.com.ar  (PGA)
    DURING:   CNAME → api.paas-prdmz.bancogalicia.com.ar  (CMZ)

  *.paas-prd.bancogalicia.com.ar (apps wildcard via F5)
    PRE/POST: CNAME → appsprdf5-1.apps.paas-prd.bancogalicia.com.ar  (PGA)
    DURING:   CNAME → appsprdf5.apps.paas-prd.bancogalicia.com.ar    (CMZ)

  appsa1.paas-prd.bancogalicia.com.ar → VS-Appsa1

3scale / APIM:
  Single namespace: "amp"
  Critical components: apicast-production, apicast-staging, system-app,
                       system-sidekiq, backend-listener, backend-worker

=== DR EXERCISE PHASES ===

PRE phase (normal operation):
  Active:  paas-prdpg (PGA)
  Passive: paas-prdmz (CMZ)
  DNS api.paas-prd → api.paas-prdpg (PGA)
  F5 pool members: PGA enabled, CMZ disabled

DURING phase (DR simulation):
  Active:  paas-prdmz (CMZ)
  Passive: paas-prdpg (PGA)
  DNS api.paas-prd → api.paas-prdmz (CMZ)
  F5 pool members: CMZ enabled, PGA disabled

POST phase (return to normal):
  Active:  paas-prdpg (PGA)
  Passive: paas-prdmz (CMZ)
  DNS api.paas-prd → api.paas-prdpg (PGA) — restored
  F5 pool members: PGA enabled, CMZ disabled — restored

=== TASKS ===

1. ANALYZE EXISTING CODE
   Read all scripts in drp/.
   Report bugs, missing logic, improvements.
   Focus on: f5-status.sh (pool members), dns-check.sh (CNAME detection), apim-3scale.sh (ns:amp).

2. CREATE: collectors/validate-active-cluster.sh
   Auto-detect which site is currently active based on:
   a) DNS CNAME of api.paas-prd.bancogalicia.com.ar (prdpg=PGA, prdmz=CMZ)
   b) F5 pool member state (which site has "enabled" members)
   c) OCP ingress traffic (router pods with connections)

   Output to stdout AND to $OUTDIR/active-cluster-state.env:
     ACTIVE_CLUSTER=paas-prdpg
     PASSIVE_CLUSTER=paas-prdmz
     DNS_ACTIVE_SITE=PGA
     F5_ACTIVE_SITE=PGA
     DR_STATE=NORMAL   # NORMAL | SWITCHED | INCONSISTENT

3. CREATE: collectors/f5-pool-diff.sh
   Compare F5 pool member states between two evidence folders (pre vs during, during vs post).
   Show which members changed from enabled→disabled or disabled→enabled.
   This confirms the DR switch happened correctly in F5.

4. CREATE: reports/generate-report.sh
   Input: path to a DR exercise directory (with pre/, during/, post/, timeline.txt)
   Output: a Markdown report at reports/<exercise-dir>/DR-REPORT.md

   Report must include:
   - Header with exercise date, participants, duration
   - Timeline (from timeline.txt)
   - Per-phase summary table (PRE / DURING / POST):
     | Check              | PRE | DURING | POST |
     | DNS active site    | PGA | CMZ    | PGA  |
     | F5 active site     | PGA | CMZ    | PGA  |
     | ClusterOps PGA     |  OK |   -    |  OK  |
     | ClusterOps CMZ     |  OK |  OK    |  OK  |
     | Pods PGA           |  OK |   -    |  OK  |
     | Pods CMZ           |  OK |  OK    |  OK  |
     | Routers PGA        |  OK |   -    |  OK  |
     | Routers CMZ        |  OK |  OK    |  OK  |
     | 3scale/amp PGA     |  OK |   -    |  OK  |
     | 3scale/amp CMZ     |  OK |  OK    |  OK  |
   - DNS switch log (from /tmp/drp-dns-switch-*.log if available)
   - F5 pool member diff (pre vs during)
   - Manual changes detected in audit logs (human-changes.tsv files)
   - Pod diff (pre vs post, what changed)
   - Findings section (anomalies, warnings, errors found)
   - Conclusion: PASSED / FAILED / PASSED_WITH_OBSERVATIONS

5. CREATE: setup.sh
   Pre-flight check before the exercise:
   - Verify tools: oc, jq, dig, curl, python3
   - Verify KUBECONFIG_PGA exists and oc login works (oc whoami)
   - Verify KUBECONFIG_CMZ exists and oc login works
   - Verify F5_HOST is reachable (curl -sk)
   - Verify F5 credentials work (curl the iControl REST API)
   - Resolve api.paas-prd.bancogalicia.com.ar and show current site
   - Print configuration summary
   - Exit with error code if any check fails

6. IMPROVE: collectors/f5-status.sh
   Current version queries pool members globally.
   Improve to:
   - Group members by site (PGA vs CMZ) based on IP ranges or naming convention
   - Show clear "ACTIVE SITE: PGA/CMZ" conclusion based on which members are enabled
   - Compare against expected state for the current phase (if DRP_PHASE env var is set)
   - Output: f5-active-site.env with F5_ACTIVE_SITE=PGA|CMZ

7. IMPROVE: collectors/apim-3scale.sh (namespace: amp)
   Add:
   - Check APIcast backend_url configuration (where does it point?)
   - Check if system-app readiness probe is passing
   - Grep logs for "429" rate limit responses
   - Grep logs for backend_url containing prdpg or prdmz (to confirm which cluster serves traffic)

=== STRICT RULES ===

1. Scripts must be READ-ONLY — never modify anything in clusters or F5
2. All scripts must source drp/00_env.sh
3. Use oc_cluster() wrapper for all oc commands
4. Use f5_api() helper from 00_env.sh for all F5 REST calls
5. Use color vars from 00_env.sh ($RED, $GREEN, $YELLOW, $CYAN)
6. Handle errors gracefully: warn and continue, never abort the whole run
7. All output files go to $OUTDIR — never hardcode paths
8. Timestamp all evidence
9. Compatible with bash 4+
10. 3scale namespace is ALWAYS "amp" — never "3scale" or "apim"

=== TOP 10 CRITICAL SIGNALS FOR DR ===

1. DNS CNAME of api.paas-prd.bancogalicia.com.ar (prdpg=PGA active, prdmz=CMZ active)
2. F5 pool members: which site has enabled members
3. Router pods Running in active cluster
4. IngressController Available=True in active cluster
5. ClusterOperators — none Degraded
6. Pods CrashLoopBackOff in critical namespaces (amp, openshift-ingress)
7. Manual changes in audit logs (squad interventions)
8. 3scale/amp components ready in active cluster
9. Nodes Ready — none NotReady
10. Warning Events in last 10 minutes
```

---

## Instrucciones de uso del framework

### Setup inicial

```bash
cd drp/

# Configurar variables (o exportar en shell)
export KUBECONFIG_PGA=~/.kube/kubeconfig-prdpg
export KUBECONFIG_CMZ=~/.kube/kubeconfig-prdmz
export F5_HOST=<floating-management-ip-f5>
export F5_USER=admin
export F5_PASSWORD=<password>

# Verificar todo antes del ejercicio
./setup.sh   # (a generar por Cursor)

# Ver instrucciones del war room
./run-dr-exercise.sh --war-room
```

### War Room — 8 terminales

| TTY | Comando                              | Qué muestra                          |
|-----|--------------------------------------|--------------------------------------|
| 1   | `./run-dr-exercise.sh`               | Orquestador — fases PRE/DURANTE/POST |
| 2   | `./live/watch-events.sh all`         | Warning events ambos clusters        |
| 3   | `./live/watch-pods.sh all`           | Pods problemáticos + reinicios       |
| 4   | `./live/watch-ingress.sh all`        | Routers + IngressControllers         |
| 5   | `./live/watch-dns.sh`                | DNS CNAME polling — detecta switch   |
| 6   | `./live/watch-audit.sh pga`          | Audit log PGA (cambios squads)       |
| 7   | `./live/watch-audit.sh cmz`          | Audit log CMZ (cambios squads)       |
| 8   | `./live/watch-changes.sh pga deploy` | Watcher deployments/routes           |

### Ejecución del ejercicio

```bash
# Modo interactivo completo (recomendado para ejercicios reales)
./run-dr-exercise.sh

# O por fases separadas
./run-dr-exercise.sh --pre        # baseline antes del switch
./run-dr-exercise.sh --during     # snapshot (ejecutar varias veces durante CMZ activo)
./run-dr-exercise.sh --post       # validación final + diff PRE vs POST
```

---

## Checklist de validación DRP

| Check | PRE | DURING | POST |
|-------|:---:|:------:|:----:|
| DNS api.paas-prd → PGA | ✓ | ✗ | ✓ |
| DNS api.paas-prd → CMZ | ✗ | ✓ | ✗ |
| F5 pool members PGA enabled | ✓ | ✗ | ✓ |
| F5 pool members CMZ enabled | ✗ | ✓ | ✗ |
| ClusterOperators PGA healthy | ✓ | — | ✓ |
| ClusterOperators CMZ healthy | ✓ | ✓ | ✓ |
| Routers PGA Running | ✓ | — | ✓ |
| Routers CMZ Running | ✓ | ✓ | ✓ |
| 3scale/amp PGA OK | ✓ | — | ✓ |
| 3scale/amp CMZ OK | ✓ | ✓ | ✓ |
| Sin cambios manuales no autorizados | ✓ | verificar | ✓ |
