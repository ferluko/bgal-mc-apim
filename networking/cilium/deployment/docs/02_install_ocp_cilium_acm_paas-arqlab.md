# Instalación OCP con Cilium vía RHACM — paas-arqlab

Instrucciones para reemplazar un clúster existente por uno nuevo con Cilium, reutilizando DNS, redes, VIPs, LUNs, llaves SSH y demás recursos del `install-config.yaml` de referencia.

**Fuente:** [Isovalent — Install Networking for Kubernetes on OpenShift (RHACM)](https://docs.isovalent.com/ink/install/openshift.html)  
**Versión Isovalent:** 25.11 | Cilium 1.18.6

---

## Resumen de recursos reutilizados

| Recurso            | Valor / Uso                                              |
|--------------------|-----------------------------------------------------------|
| baseDomain         | bancogalicia.com.ar                                      |
| clusterNetwork     | 10.128.0.0/18 (subred 1 de 16), hostPrefix 24            |
| serviceNetwork     | 172.30.0.0/16                                            |
| machineNetwork     | 10.254.120.0/21                                          |
| apiVIP / ingressVIP | 10.254.124.35, 10.254.124.36                            |
| vSphere            | vcenterocp, datacenter, datastore, LUNs, networks        |
| hosts (IPs)        | bootstrap + 3 masters + 3 workers (IPs estáticas)       |
| nameservers        | 10.0.52.1, 10.0.53.1                                     |
| sshKey             | Reutilizada                                              |
| pullSecret         | Inyectado por Hive/ACM                                   |

---

## 1. Prerrequisitos

- RHACM desplegado y configurado para vSphere
- Acceso al hub de ACM
- `install-config.yaml` de referencia listo para modificar

---

## 2. Descargar manifiestos CLife (Cilium Lifecycle Operator)

```bash
# Crear directorio de trabajo
mkdir -p ~/paas-arqlab-cilium && cd ~/paas-arqlab-cilium

# Descargar manifiestos (ajustar URL si cambia la versión)
CLIFE_URL="https://docs.isovalent.com/v25.11/public/clife/clife-v1.18.6.tar.gz"
wget -O clife-v1.18.6.tar.gz "$CLIFE_URL"
wget -O clife-v1.18.6.tar.gz.sha256 "${CLIFE_URL}.sha256"
sha256sum -c clife-v1.18.6.tar.gz.sha256

# Extraer
mkdir -p clife-tmp && tar -xzf clife-v1.18.6.tar.gz -C clife-tmp
```

---

## 3. Adaptar install-config.yaml para Cilium

Cambiar `networkType` de `OVNKubernetes` a `Cilium`:

```bash
# A partir del install-config de referencia
cp install-config-original.yaml install-config.yaml
sed -i 's/OVNKubernetes/Cilium/' install-config.yaml
```

O editar manualmente:

```yaml
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/18       # <-- subred 1/16 del /14 original (para Cluster Mesh)
    hostPrefix: 24            # <-- 256 IPs por nodo (~250 pods)
  machineNetwork:
  - cidr: 10.254.120.0/21
  networkType: Cilium         # <-- cambiar desde OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
```

---

## 4. Configurar CiliumConfig (IPAM)

Editar `clife-tmp/ciliumconfig.yaml` para que coincida con las redes del clúster.

```yaml
apiVersion: cilium.io/v1alpha1
kind: CiliumConfig
metadata:
  labels:
    app.kubernetes.io/name: clife
  name: ciliumconfig
spec:
  cluster:
    name: paas-arqlab         # <-- nombre único para Cluster Mesh
    id: 1                     # <-- ID único (1-255) para Cluster Mesh
  securityContext:
    privileged: true
  ipam:
    mode: "cluster-pool"
    operator:
      clusterPoolIPv4PodCIDRList:
      - 10.128.0.0/18         # <-- subred exclusiva de este cluster
      clusterPoolIPv4MaskSize: 24
  # ... resto de la config por defecto (cni, prometheus, hubble, etc.)
```

### Valores clave para paas-arqlab

| Parámetro                 | Valor          | Notas                                  |
|--------------------------|----------------|----------------------------------------|
| cluster.name             | paas-arqlab    | Identificador único para Cluster Mesh  |
| cluster.id               | 1              | ID numérico único (1-255)              |
| clusterPoolIPv4PodCIDRList | 10.128.0.0/18 | Subred 1 de 16 dentro del /14         |
| clusterPoolIPv4MaskSize  | 24             | 256 IPs por nodo (~250 pods)           |

### Plan de subnetting para 15 clusters (Cluster Mesh ready)

| Cluster ID | Nombre | Pod CIDR | IPs | Capacidad |
|------------|--------|----------|-----|-----------|
| 1 | paas-arqlab | 10.128.0.0/18 | 16,384 | ~65 nodos × 250 pods |
| 2 | cluster-02 | 10.128.64.0/18 | 16,384 | ~65 nodos × 250 pods |
| 3 | cluster-03 | 10.128.128.0/18 | 16,384 | ~65 nodos × 250 pods |
| 4 | cluster-04 | 10.128.192.0/18 | 16,384 | ~65 nodos × 250 pods |
| 5 | cluster-05 | 10.129.0.0/18 | 16,384 | ~65 nodos × 250 pods |
| 6 | cluster-06 | 10.129.64.0/18 | 16,384 | ~65 nodos × 250 pods |
| 7 | cluster-07 | 10.129.128.0/18 | 16,384 | ~65 nodos × 250 pods |
| 8 | cluster-08 | 10.129.192.0/18 | 16,384 | ~65 nodos × 250 pods |
| 9 | cluster-09 | 10.130.0.0/18 | 16,384 | ~65 nodos × 250 pods |
| 10 | cluster-10 | 10.130.64.0/18 | 16,384 | ~65 nodos × 250 pods |
| 11 | cluster-11 | 10.130.128.0/18 | 16,384 | ~65 nodos × 250 pods |
| 12 | cluster-12 | 10.130.192.0/18 | 16,384 | ~65 nodos × 250 pods |
| 13 | cluster-13 | 10.131.0.0/18 | 16,384 | ~65 nodos × 250 pods |
| 14 | cluster-14 | 10.131.64.0/18 | 16,384 | ~65 nodos × 250 pods |
| 15 | cluster-15 | 10.131.128.0/18 | 16,384 | ~65 nodos × 250 pods |
| — | (reserva) | 10.131.192.0/18 | 16,384 | Expansión futura |

> **Importante para Cluster Mesh:** Cada cluster debe tener un `cluster.name` y `cluster.id` únicos, y sus Pod CIDRs **no deben solaparse**.

---

## 5. Crear cluster-network-02-config-local.yml (RHACM)

En RHACM los manifiestos extra van en un ConfigMap. Crear en `clife-tmp` el archivo `cluster-network-02-config-local.yml`:

```yaml
apiVersion: operator.openshift.io/v1
kind: Network
metadata:
  name: cluster
spec:
  clusterNetwork:
  - cidr: 10.128.0.0/18      # <-- subred exclusiva de paas-arqlab
    hostPrefix: 24
  deployKubeProxy: false
  externalIP:
    policy: {}
  networkType: Cilium
  serviceNetwork:
  - 172.30.0.0/16
```

> Si habilitás Kube Proxy Replacement (KPR), es obligatorio `deployKubeProxy: false`.

---

## 6. (Opcional) Kube Proxy Replacement (KPR)

Si querés usar KPR:

1. Configurar en `CiliumConfig`:

   ```yaml
   spec:
     kubeProxyReplacement: true
     k8sServiceHost: "api.paas-arqlab.bancogalicia.com.ar"
     k8sServicePort: "443"
   ```

2. Añadir variables de entorno en el Deployment del operador CLife:

   ```yaml
   env:
   - name: KUBERNETES_SERVICE_HOST
     value: "api.paas-arqlab.bancogalicia.com.ar"
   - name: KUBERNETES_SERVICE_PORT
     value: "443"
   ```

3. Mantener `deployKubeProxy: false` en el Network (ya incluido en el paso anterior).

> Algunos componentes (Service Mesh, Virtualization, Sandboxed Containers) pueden requerir no usar KPR. Consultar la documentación de Red Hat.

---

## 7. Crear install-config.yaml adaptado

Archivo `install-config.yaml` base para paas-arqlab con Cilium (reutilizando recursos del clúster anterior):

```yaml
additionalTrustBundlePolicy: Proxyonly
apiVersion: v1
baseDomain: "bancogalicia.com.ar"
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    vsphere:
      coresPerSocket: 2
      cpus: 8
      memoryMB: 32768
      osDisk:
        diskSizeGB: 120
      zones:
      - generated-failure-domain
  replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    vsphere:
      coresPerSocket: 2
      cpus: 8
      memoryMB: 32768
      osDisk:
        diskSizeGB: 120
      zones:
      - generated-failure-domain
  replicas: 3
metadata:
  name: "paas-arqlab"
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/18       # <-- subred 1/16 del /14 (Cluster Mesh ready)
    hostPrefix: 24            # <-- 256 IPs por nodo (~250 pods)
  machineNetwork:
  - cidr: 10.254.120.0/21
  networkType: Cilium
  serviceNetwork:
  - 172.30.0.0/16
platform:
  vsphere:
    apiVIPs:
    - "10.254.124.35"
    failureDomains:
    - name: generated-failure-domain
      region: generated-region
      server: "vcenterocp.bancogalicia.com.ar"
      topology:
        computeCluster: /cpd intersite/host/ocp - lan - cluster
        datacenter: "cpd intersite"
        datastore: "/cpd intersite/datastore/9500/paas-arqlab/infra/vm9500-ocp-paas-arqlab_lun040"
        networks:
        - "dvPG-VMNET-VLAN140"
        resourcePool: "/cpd intersite/host/ocp - lan - cluster/Resources"
      zone: generated-zone
    hosts:
    - failureDomain: ""
      networkDevice:
        gateway: 10.254.28.254
        ipAddrs:
        - 10.254.28.10/24
        nameservers:
        - 10.0.52.1
        - 10.0.53.1
      role: bootstrap
    - failureDomain: ""
      networkDevice:
        gateway: 10.254.28.254
        ipAddrs:
        - 10.254.28.11/24
        nameservers:
        - 10.0.52.1
        - 10.0.53.1
      role: control-plane
    - failureDomain: ""
      networkDevice:
        gateway: 10.254.28.254
        ipAddrs:
        - 10.254.28.12/24
        nameservers:
        - 10.0.52.1
        - 10.0.53.1
      role: control-plane
    - failureDomain: ""
      networkDevice:
        gateway: 10.254.28.254
        ipAddrs:
        - 10.254.28.13/24
        nameservers:
        - 10.0.52.1
        - 10.0.53.1
      role: control-plane
    - failureDomain: ""
      networkDevice:
        gateway: 10.254.28.254
        ipAddrs:
        - 10.254.28.21/24
        nameservers:
        - 10.0.52.1
        - 10.0.53.1
      role: compute
    - failureDomain: ""
      networkDevice:
        gateway: 10.254.28.254
        ipAddrs:
        - 10.254.28.22/24
        nameservers:
        - 10.0.52.1
        - 10.0.53.1
      role: compute
    - failureDomain: ""
      networkDevice:
        gateway: 10.254.28.254
        ipAddrs:
        - 10.254.28.20/24
        nameservers:
        - 10.0.52.1
        - 10.0.53.1
      role: compute
    ingressVIPs:
    - "10.254.124.36"
    loadBalancer:
      type: UserManaged
    vcenters:
    - datacenters:
      - "cpd intersite"
      password: "REDACTAR_O_USAR_SECRET"
      port: 443
      server: vcenterocp.bancogalicia.com.ar
      user: "uoscp11m@bgcmz.bancogalicia.com.ar"
pullSecret: ""
sshKey: |-
  ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDCyUMeGTqR1D7PnJhELlvQxxp/SueDW/LyWcI1YpSd5rzeqOtXlaqsUzfCa/HNz0LDSh2Sg1q93mLSCmeVKR7qmmD6ZyVNq43Wsrlb998790TKwxevuYVpa3sjtbMf5EqxhYRvfSZ70ms/lGLoasQcg+FhQieANCtXt6qS0KeSlTeq4qWz0PNzX7pWwlI5nYsPLKYW/9PEzmp0ph4MbIbIz0OBXGF6jFhtVy7Jwkni0MmeizJRvz//3FVMVIwRh9f5kpZHuzFWA2id5DPVB505iyWfkKH+R4fci09PN8uR9QE7TGURUc0AgE9JrJ1AiVKcXwzi8JAovwb8Lf5fHPUPusxUedUov4VEpWwE32rXpnDWWZYjERcUp8vUoEXg/233I69w95uyntCt4O/yuCa4i8V+YFz5906gmyjUJZe6QMfVt497CMXqXP1VhNz7nZpJbOxYnxTZtuY+aqP0Ss2CnkWje86nAAWXUxeQr96ng4Mq1/5iSarTZOTgIuU5Y9U= root@bastionacm.bancogalicia.com.ar
```

> **Seguridad:** Guardar la contraseña de vSphere en un Secret gestionado por ACM; no versionar credenciales en Git.

---

## 8. Desplegar en RHACM

### 8.1 Namespace

```bash
kubectl create ns acm-paas-arqlab --dry-run=client -o yaml | kubectl apply -f -
```

### 8.2 Secret install-config

```bash
kubectl -n acm-paas-arqlab create secret generic acm-paas-arqlab-install-config \
  --from-file=install-config.yaml=install-config.yaml \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 8.3 Secret SSH key (si ACM no lo inyecta desde Hive)

```bash
# Extraer la clave privada y crear el secret
kubectl -n acm-paas-arqlab create secret generic acm-paas-arqlab-ssh-private-key \
  --from-file=ssh-privatekey=/path/to/id_rsa \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 8.4 ConfigMap con manifiestos CLife

```bash
kubectl -n acm-paas-arqlab create configmap acm-paas-arqlab-clife-manifest \
  --from-file=clife-tmp \
  --dry-run=client -o yaml | kubectl apply -f -
```

> Verificar que `clife-tmp` incluya `cluster-network-02-config-local.yml` y el `ciliumconfig.yaml` editado.

### 8.5 ClusterDeployment

Asegurarse de que el `ClusterDeployment` referencie:

- `installConfigSecretRef`: `acm-paas-arqlab-install-config`
- `sshPrivateKeySecretRef`: `acm-paas-arqlab-ssh-private-key` (o el nombre del secret que use ACM)
- `manifestsConfigMapRef`: `acm-paas-arqlab-clife-manifest`
- `imageSetRef`: imagen OpenShift adecuada (p. ej. 4.18.x)

Ejemplo de bloque `provisioning`:

```yaml
spec:
  provisioning:
    installConfigSecretRef:
      name: acm-paas-arqlab-install-config
    sshPrivateKeySecretRef:
      name: acm-paas-arqlab-ssh-private-key
    manifestsConfigMapRef:
      name: acm-paas-arqlab-clife-manifest
    imageSetRef:
      name: img4.18.18-multi-appsub  # ajustar a tu ImageSet
```

---

## 9. Checklist antes de crear el clúster

- [ ] Clúster anterior eliminado (o no habrá conflicto de IPs/VIPs/LUNs)
- [ ] `networkType: Cilium` en install-config.yaml
- [ ] `ciliumconfig.yaml` con `clusterPoolIPv4PodCIDRList` y `clusterPoolIPv4MaskSize` correctos
- [ ] `cluster-network-02-config-local.yml` en clife-tmp con `deployKubeProxy: false`
- [ ] ConfigMap creado desde el directorio clife-tmp completo
- [ ] Secret de install-config con la config correcta
- [ ] ClusterDeployment apuntando a install-config, SSH key y ConfigMap de manifests
- [ ] Imagen OpenShift compatible con Cilium según [matriz Red Hat](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.18/html/networking/cni-plug-in-certification-matrix)

---

## 10. Verificación post-instalación

```bash
# Conectar al clúster
oc login https://api.paas-arqlab.bancogalicia.com.ar:6443 -u kubeadmin

# Verificar CNI
oc get network cluster -o yaml

# Cilium
oc get pods -n openshift-cilium
cilium status

# Conectividad
cilium connectivity test
```

---

## Referencias

- [Isovalent — Install on OpenShift (RHACM)](https://docs.isovalent.com/ink/install/openshift.html)
- [Red Hat — Certified CNI Plug-ins (Cilium compatibility)](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.18/html/networking/cni-plug-in-certification-matrix)
