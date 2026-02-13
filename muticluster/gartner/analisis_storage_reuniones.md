# Profundización: Storage en tus reuniones

Análisis de **todas las reuniones** (Granola) que tocan storage, persistencia, registries y backup, cruzado con las recomendaciones del documento Gartner *Minimizing Vendor Dependence in Container Platforms* (G00841999).

---

## 1. Resumen ejecutivo storage

En tus reuniones aparece un **diagnóstico claro** de problemas de storage (ODF/SAN, LUNs, latencia, coste operativo) y una **dirección de solución** (cluster de servicios con ODF centralizado, CSI VMware, menos ODF por cluster). Hay **gaps** respecto al doc Gartner en: estándar CSI explícito, object storage/CDN para reducir PVs, registries OCI y replicación (ORAS/Skopeo/Crane), y decisión explícita entre storage comercial (NetApp, Portworx) vs open (Ceph/Rook, Longhorn) según criticidad.

---

## 2. Reuniones que tocan storage (índice)

| Reunión | Fecha | Temas storage / persistencia |
|--------|--------|------------------------------|
| [Nueva Arquitectura Clusters OCP](https://notes.granola.ai/d/9c67ae86-36f8-4766-b0c1-80034433d787) [[39]] | 28 ene 2026 | ODF/SAN, LUNs, CSI VMware, RWO/RWX, cluster ODF dedicado, Quay/registry |
| [Sync Equipo Containers](https://notes.granola.ai/d/f1924f34-f44e-4d5f-b564-e10f29d62ad0) [[2]] | 12 feb 2026 | Cluster de servicios (Registry, secrets), DR, ACM |
| [Análisis alternativas ACM](https://notes.granola.ai/d/e5fd3296-dd0d-4014-ae2a-957137250874) [[3]] | 12 feb 2026 | ODF costos excesivos, Quay migración Azure→on-prem, réplica AWS |
| [EKS](https://notes.granola.ai/d/b59ae09f-d842-4b66-bd6f-ad561026194e) [[6]] | 11 feb 2026 | Registry: Quay vs ECR, sincronización entre instancias |
| [Openshift Capacity & Release](https://notes.granola.ai/d/41a103c1-8e90-4772-b4e7-a00d1b41e7b2) [[26]] | 26 ene 2026 | ODF, local storage operator, versiones/compatibilidad |
| [Trilio - Presentación](https://notes.granola.ai/d/1e9e90da-cc31-41a6-8f75-a66c8bb67a9d) [[73]] | 4 dic 2025 | Backup K8s, Velero, NetBackup, PVs, DR cross-cloud |
| [Gloo](https://notes.granola.ai/d/ecb881b6-cd37-4aac-b238-53dc7c4688dd) [[79]] | 3 dic 2025 | Registry externa, credenciales, certificados, machine rollout |
| [BFFA a OCP - Infra dedicada](https://notes.granola.ai/d/41c508e4-0011-408d-8be5-a6cdb5fffd7f) [[52]] | 8 ene 2026 | Persistencia (MongoDB externo), registry org/tenant |

Otras reuniones (Gartner DR, Service Mesh, Terraform, ACM, RBAC) tocan storage de forma indirecta (cluster de servicios, fleet, DR).

---

## 3. Estado actual de storage (síntesis de reuniones)

### 3.1 Infraestructura y dolores

- **ODF (OpenShift Data Foundation)** [[39]]  
  - Múltiples ODF por cluster → alto coste operativo y de troubleshooting.  
  - Object Storage y File Storage **solo** vía ODF hoy.  
  - Discos “stretched” entre ambos sitios sin necesidad real (no hay movilidad de VMs entre sitios).  
  - ODF en VMs valorado como **inadecuado**; costes considerados **excesivos** para el uso actual [[3]].

- **SAN y LUNs** [[39]]  
  - Storage consumido desde **controladoras SAN**; **LUNs compartidas** con bases de datos y otros servidores de alto uso de disco.  
  - **OpenShift sensible a la latencia de disco**; otros workloads impactan al cluster.  
  - **Mala distribución**: no hay LUNs dedicadas para control plane; la alocación por MachineSet es deficiente.

- **CSI** [[39]] [[52]]  
  - **No se está usando un CSI driver para VMware** de forma efectiva; se pierde automatización nativa y consumo directo desde “cajón de discos”.

- **Compatibilidad y versiones** [[26]]  
  - ODF y **local storage operator** con dependencias; **ODF atascado en 4.15.20**, incompatible con versiones más nuevas; impacta estrategia de upgrades (mesh en 4.20, etc.).

### 3.2 Patrones de uso (RWO / RWX / object)

- **RWO (ReadWriteOnce)** [[39]]  
  - DataGrid, Redis, Prometheus, Loki; bases de datos y apps stateful; mezcla de negocio e infra.

- **RWX (ReadWriteMany)** [[39]]  
  - Varias aplicaciones con **CFFS** (file storage) para compartir archivos entre pods y “comunicar novedades” entre microservicios.

- **Object storage** [[39]]  
  - Uso actual **muy limitado**; visto como **potencial** para migrar a patrones más cloud-native y reducir dependencia de PVs.

### 3.3 Backup y DR

- **Veritas NetBackup** [[73]]: implementado pero **subutilizado** (solo backup de ETCD).  
- **Velero** [[73]]: uso **complementario** para recuperación de objetos borrados accidentalmente; no hay estrategia robusta de GitOps asociada.  
- **Trilio** [[73]]: evaluado para backup nativo de K8s (Helm, operadores, PVs, transformación en restore — storage class, hosts, configs), DR cross-cloud y migración on-prem→cloud; referenciado por Red Hat como alternativa superior a Data Foundation para backup.

### 3.4 Registry (artifacts / imágenes)

- **Registry externa** [[79]] [[6]]: configurada con credenciales por organización; certificados; **machine rollout** cuando cambian certificados de registry.  
- **Quay** [[3]] [[6]]: más capacidades que ECR; plan **migración de Azure a on-prem** y **réplica en AWS** con mirroring asincrónico; análisis de migración y documentación para marzo.  
- **Harbor** [[111]]: evaluado; ventajas en escaneo de vulnerabilidades, proxy, RBAC; usa object storage para layers de imágenes.  
- **EKS** [[6]]: debate Quay vs ECR; propuesta de **sincronización entre instancias** para latencia y consistencia.

---

## 4. Dirección de solución (reuniones)

- **Consolidación** [[39]]  
  - **Cluster dedicado de ODF** para proveer buckets y PVs a **otros clusters**.  
  - **Cluster de servicios** con ODF centralizado, observabilidad, Vault, DevOps/APIs [[2]] [[39]]; DR activo-standby para servicios críticos (Registry, secrets).

- **Configuración** [[39]]  
  - **Consumo directo desde cajón de discos** vía **CSI driver** (evitar capa VMware para storage).  
  - **Cluster ACM** nuevo: sin ODF inicial; **CSI driver de VMware** para persistencia [[39]].

- **Arquitectura** [[39]]  
  - Mejor **topología de despliegue**; separación clara entre clusters de **servicios** (storage, observabilidad, registry) y **aplicativos**.  
  - Storage classes específicas por tipo de uso; evaluación coste vs disponibilidad por criticidad (réplica entre sitios cuando haga falta).

- **ODF y coste** [[3]]  
  - ODF valorado como **costoso para uso actual**; análisis de **SpectroCloud** (entre otros) en paralelo a decisión de ACM; no hay en las reuniones una decisión explícita “sustituir ODF” por otra stack, pero sí presión por reducir coste y complejidad.

---

## 5. Gartner (doc) vs reuniones – Storage

### 5.1 Qué dice Gartner sobre storage (resumen doc)

- **CSI** como interfaz estándar para que la plataforma hable con storage de forma **vendor-neutral**.  
- **Minimizar dependencia**:  
  - Usar **object storage y CDN** cuando sea posible en lugar de colgar todo de PVs.  
  - Para persistencia necesaria: **soluciones con drivers CSI nativos/open source** (ej. Ceph/Rook, Longhorn) con LCM, modos de acceso, provisioning dinámico, snapshots.  
  - Para requisitos **avanzados** (réplica entre sitios, HA, DR): valorar **productos comerciales** (NetApp, Pure Portworx, etc.) con soporte enterprise.

- **Registries (artifact)**  
  - **OCI-conformant**; **proximidad** al lugar de ejecución; **replicación/sincronización** entre entornos (ORAS, Skopeo, Crane); workflows automatizados build/push cerca de la plataforma.

### 5.2 Comparativa

| Tema | Gartner (doc) | Tus reuniones |
|------|----------------|----------------|
| **CSI** | Priorizar estándar CSI; drivers abiertos o comerciales según necesidad. | Uso efectivo de **CSI para VMware** planeado; hoy no explotado. No se menciona CSI como “estándar a cumplir” explícitamente. |
| **Object storage / menos PVs** | Usar object storage y CDN para reducir dependencia de PVs y mejorar portabilidad. | Object storage **poco usado**; identificado como **potencial** para cloud-native. No hay plan concreto “migrar X a object” aún. |
| **Ceph/Rook, Longhorn** | Ejemplos de soluciones con CSI nativo para neutralidad. | ODF (Ceph-based) en uso pero con foco en **reducir número de ODF** y centralizar, no en “sustituir por Longhorn u otro” en las reuniones. |
| **Storage comercial (NetApp, Portworx)** | Para HA/DR avanzado, considerar productos enterprise. | Trilio evaluado para backup/DR; no hay discusión explícita de Portworx/NetApp para storage primario. |
| **Registries OCI y replicación** | OCI-conformant; replicación con ORAS, Skopeo, Crane. | **Quay** (OCI); plan **réplica Azure→on-prem, mirror AWS**; **Harbor** con object storage. No se citan ORAS/Skopeo/Crane por nombre. |
| **Proximidad registry** | Registry cerca de la plataforma de ejecución. | Cluster de servicios con **Registry** en DR; **sincronización** Quay/ECR entre instancias para EKS [[6]]: alineado con “proximidad”. |

### 5.3 Gaps y oportunidades

- **Explicitar CSI** como estándar obligatorio en toda nueva capacidad (VMware y cualquier otro backend).  
- **Plan de uso de object storage**: qué workloads pueden pasar a object/CDN para reducir PVs y alinear con Gartner.  
- **Registries**: documentar que Quay/Harbor son OCI-conformant y que la estrategia de réplica (Azure/on-prem/AWS) equivale a las prácticas que Gartner asocia a ORAS/Skopeo/Crane.  
- **Decisión explícita** para HA/DR: cuándo seguir con ODF centralizado (Ceph) vs cuándo valorar comercial (NetApp, Portworx) según criticidad, como en el doc.

---

## 6. Recomendaciones concretas (storage)

1. **Implementar y estandarizar CSI**  
   - Usar **CSI para VMware** en todos los clusters nuevos (incl. ACM) y documentar como estándar; evitar capas intermedias que no hablen por CSI.

2. **Cluster de servicios con ODF centralizado**  
   - Mantener la línea de **un cluster ODF dedicado** que sirva buckets y PVs al resto; definir **storage classes** por tipo (RWO/RWX/object) y SLA (latencia, réplica).

3. **Reducir dependencia de PVs donde aplique**  
   - Definir una short list de cargas que puedan pasar a **object storage** (y/o CDN) para contenido y datos no bloqueantes; alinear con la recomendación Gartner de “object storage para minimizar PVs”.

4. **Registries**  
   - Dejar documentado: **Quay/Harbor OCI-conformant**; estrategia de **réplica/mirror** (Azure↔on-prem↔AWS) como equivalente a buenas prácticas de distribución (ORAS/Skopeo/Crane); **proximidad** vía cluster de servicios y sincronización en EKS.

5. **Backup y DR**  
   - Avanzar la estrategia que combine **Velero** + **Trilio** (o similar) para backup de objetos y PVs con transformación en restore (storage class, cluster destino); alinear con NetBackup/ETCD donde corresponda y con GitOps cuando esté definido.

6. **ODF y versiones**  
   - Resolver **compatibilidad ODF / Local Storage Operator** con la estrategia de versiones (4.18→4.20); si el coste de ODF sigue siendo inaceptable, evaluar explícitamente **alternativas** (Ceph/Rook fuera de ODF, Longhorn, o comercial) usando el marco Gartner (neutralidad vs capacidades enterprise).

---

## 7. Referencias reuniones (storage)

- [[39]] [Nueva Arquitectura Clusters OCP](https://notes.granola.ai/d/9c67ae86-36f8-4766-b0c1-80034433d787)  
- [[2]] [Sync Equipo Containers](https://notes.granola.ai/d/f1924f34-f44e-4d5f-b564-e10f29d62ad0)  
- [[3]] [Análisis alternativas ACM](https://notes.granola.ai/d/e5fd3296-dd0d-4014-ae2a-957137250874)  
- [[6]] [EKS](https://notes.granola.ai/d/b59ae09f-d842-4b66-bd6f-ad561026194e)  
- [[26]] [Openshift Capacity & Release](https://notes.granola.ai/d/41a103c1-8e90-4772-b4e7-a00d1b41e7b2)  
- [[73]] [Trilio - Presentación](https://notes.granola.ai/d/1e9e90da-cc31-41a6-8f75-a66c8bb67a9d)  
- [[79]] [Gloo – registry](https://notes.granola.ai/d/ecb881b6-cd37-4aac-b238-53dc7c4688dd)  
- [[52]] [BFFA a OCP - Infra dedicada](https://notes.granola.ai/d/41c508e4-0011-408d-8be5-a6cdb5fffd7f)  

Doc Gartner: *Minimizing Vendor Dependence in Container Platforms*, G00841999, 27 January 2026 (secciones 1.3 Storage, 1.5 Artifact Registries, 1.6 Fleet Management).
