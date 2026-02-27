# Instalación de OpenShift con Cilium vía RHACM

> **NOTA**: Para instalaciones en entornos sin acceso a internet, ver [Guía Air-Gapped](./02_install_guide_airgapped.md)

## Prerrequisitos

- RHACM desplegado y configurado para vSphere
- Acceso al hub de ACM (`oc` configurado)
- Manifiestos CLife descargados
- Cluster anterior eliminado (para reutilizar recursos)
- Para air-gapped: imágenes copiadas a registry interno (ver guía específica)

## Flujo de instalación

```
1. Descargar CLife
2. Configurar manifiestos
3. Crear recursos en ACM
4. Desplegar cluster
5. Verificar instalación
```

## 1. Descargar manifiestos CLife

```bash
cd /path/to/workdir
./scripts/01_download_clife.sh
```

## 2. Configurar para el cluster específico

Editar las variables en `scripts/00_env.sh`:

```bash
export CLUSTER_NAME="paas-arqlab"
export CLUSTER_ID="1"
export POD_CIDR="10.128.0.0/18"
export HOST_PREFIX="24"
# ... etc
```

## 3. Generar manifiestos

```bash
./scripts/02_generate_manifests.sh
```

Esto genera:
- `manifests/install-config.yaml`
- `manifests/ciliumconfig.yaml`
- `manifests/cluster-network-02-config-local.yml`

## 4. Crear recursos en ACM

```bash
./scripts/03_create_acm_resources.sh
```

Esto crea:
- Namespace
- Secret de install-config
- Secret de SSH key
- ConfigMap con manifiestos CLife
- ClusterDeployment (si está habilitado)

## 5. Verificar instalación

```bash
./scripts/04_verify_install.sh
```

## Troubleshooting

### Cluster no arranca

```bash
# Ver logs del ClusterDeployment
oc -n ${CLUSTER_NAME} get clusterdeployment -o yaml
oc -n ${CLUSTER_NAME} logs -l hive.openshift.io/cluster-deployment-name=${CLUSTER_NAME}
```

### Cilium no está healthy

```bash
# Conectar al cluster
oc login https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443

# Ver pods de Cilium
oc get pods -n cilium

# Ver estado
cilium status
```

### Pod CIDR incorrecto

Verificar que `ciliumconfig.yaml` y `cluster-network-02-config-local.yml` tengan el mismo CIDR.

## Referencias

- [Isovalent — Install on OpenShift (RHACM)](https://docs.isovalent.com/ink/install/openshift.html)
- [Isovalent — Air-Gapped Installation](https://docs.isovalent.com/ink/install/air-gapped.html)
- [Plan de subnetting](./00_subnetting_plan.md)
- [Guía Air-Gapped](./02_install_guide_airgapped.md)
