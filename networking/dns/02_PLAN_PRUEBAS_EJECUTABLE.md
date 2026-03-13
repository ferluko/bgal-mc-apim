# Plan de pruebas ejecutable — Lab multicluster F5 LTM/GTM

Casos de prueba para validar failover y comportamiento ante caída de ingress/cluster (Fase 8).

---

## Prerrequisitos

- Dos clusters (paas-arqlab, paas-srepg) accesibles y con app de prueba desplegada.
- F5 LTM por cluster/site configurados y apuntando a los ingress de cada cluster.
- F5 GTM con wide IP que apunte a ambos LTM (o al menos a los virtual servers que representan cada cluster).
- Herramientas: `oc`, `curl` (o navegador), acceso a consola F5 (tmsh o GUI) para cambiar estado de pools/virtual servers.

---

## Caso 1: Caída ingress srepg

**Objetivo:** Comprobar que al dejar de responder el ingress del cluster srepg, el tráfico no se envía a srepg y se sirve por arqlab.

### Pasos

1. **Baseline:** Desde un cliente, resolver la wide IP (o el hostname que apunta al GTM) y verificar que se obtiene respuesta (p. ej. de la app de prueba).
2. **Identificar ingress srepg:** Anotar la IP/host del ingress del cluster paas-srepg (ej. del servicio `router-default` en `openshift-ingress`). En F5 LTM de srepg, el pool que apunta a ese ingress debe tener health check.
3. **Simular caída del ingress srepg:**
   - Opción A: Escalar a 0 el deployment del router en paas-srepg:  
     `oc -n openshift-ingress scale deployment router-default --replicas=0` (conectado a paas-srepg).
   - Opción B: En F5 LTM, deshabilitar el pool member que apunta al ingress de srepg.
4. **Comprobar:** Ejecutar varias peticiones al hostname global. Deben ser respondidas por el otro cluster (arqlab); no debe haber tráfico a srepg hasta que el monitor de F5 marque el pool como down (si aplica).
5. **Restaurar:** Volver a escalar el router a 1 o habilitar el pool member. Verificar que el tráfico vuelve a poder ir a srepg.

### Criterio de éxito

- Tras “caída” del ingress srepg, las peticiones siguen siendo respondidas (por arqlab).
- Tras restaurar, srepg vuelve a recibir tráfico según la política GTM/LTM.

---

## Caso 2: Caída cluster srepg

**Objetivo:** Comprobar que cuando todo el cluster srepg no está disponible, el tráfico se dirige solo a arqlab.

### Pasos

1. **Baseline:** Verificar que ambos clusters responden (por ejemplo, una ruta por cluster o la wide IP repartiendo).
2. **Simular caída del cluster srepg:**
   - Opción A: Apagar el cluster (o desconectar la red del cluster) según procedimiento de lab.
   - Opción B: En F5, marcar el virtual server o pool que representa srepg como “disabled” o “offline”.
3. **Comprobar:** Peticiones al hostname global deben ser respondidas solo por arqlab. No debe haber timeouts hacia srepg una vez que los health checks de GTM/LTM marquen el destino como down.
4. **Restaurar:** Volver a poner el cluster o el VS/pool en línea.

### Criterio de éxito

- Con srepg “caído”, el tráfico se sirve íntegramente por arqlab.
- Tras restaurar srepg, el tráfico puede volver a repartirse (o a incluir srepg en activo-pasivo).

---

## Caso 3: Degradación parcial

**Objetivo:** Comprobar que los health checks reflejan estado degradado (p. ej. solo parte de los miembros del pool down).

### Pasos

1. En el cluster que tenga más de un nodo o más de un replica del router/ingress, deshabilitar o aislar solo una parte (ej. un nodo, o reducir réplicas del router a 1 y luego “romper” ese nodo).
2. En F5, observar el estado del pool (miembros up/down). Si el algoritmo es round-robin o similar, el tráfico debe seguir yendo a los miembros que siguen up.
3. Restaurar y verificar que el pool vuelve a estado normal.

### Criterio de éxito

- Los monitores de F5 reflejan miembros down.
- El tráfico sigue siendo servido por los miembros que permanecen up.

---

## Caso 4: Failback controlado

**Objetivo:** Tras un failover a arqlab (por caída de srepg), restaurar srepg y comprobar que el tráfico puede volver a srepg de forma controlada.

### Pasos

1. Partir del estado “srepg caído, tráfico en arqlab” (como en Caso 2).
2. Restaurar el cluster srepg y el ingress; verificar que la app de prueba responde en srepg de forma directa (route local).
3. En F5 GTM/LTM: habilitar de nuevo el virtual server o pool de srepg (o dejar que los health checks lo marquen como up).
4. Según la política (activo-pasivo o activo-activo):
   - Activo-pasivo: opcionalmente forzar el tráfico de vuelta a srepg (cambio manual en GTM o en LTM).
   - Activo-activo: verificar que el tráfico se reparte de nuevo entre ambos.
5. Ejecutar peticiones y comprobar que no hay cortes inesperados y que ambas rutas responden según lo configurado.

### Criterio de éxito

- Tras failback, srepg vuelve a estar disponible para el tráfico.
- No hay ventanas de indisponibilidad mayores a las esperadas (TTL DNS, tiempo de health check, etc.).

---

## Resumen de ejecución

| Caso | Descripción corta | Ejecutado | Resultado |
|------|-------------------|-----------|-----------|
| 1 | Caída ingress srepg | [ ] | |
| 2 | Caída cluster srepg | [ ] | |
| 3 | Degradación parcial | [ ] | |
| 4 | Failback controlado | [ ] | |

Completar la tabla al ejecutar cada caso y guardar evidencia (capturas, logs, salida de `oc get route`, estado de pools en F5) en `output/` o en documentación del lab.
