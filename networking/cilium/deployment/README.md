# Cilium Deployment para OpenShift vía RHACM

Recursos para desplegar múltiples clusters OpenShift con Cilium como CNI usando Red Hat Advanced Cluster Management, preparados para Cluster Mesh.

## Estructura

```
networking/cilium/deployment/
├── README.md                           # Este archivo
├── artifacts/                          # Artefactos offline (descargados)
│   ├── clife/                          # CLife tar.gz
│   ├── tools/                          # yq, jq, cilium, hubble, skopeo, helm
│   ├── images/                         # Imágenes en tar.gz + lista
│   │   ├── cilium-images.tar.gz        # Imágenes de Cilium comprimidas
│   │   └── images-list.txt             # Lista de imágenes
│   ├── install-tools.sh                # Instala CLIs
│   ├── save-images.sh                  # Guarda imágenes (con internet)
│   ├── load-images.sh                  # Carga imágenes al registry
│   ├── start-local-registry.sh         # Registry local con Podman
│   └── versions.txt                    # Versiones descargadas
├── clusters/                           # Configuración por cluster
│   ├── paas-arqlab/
│   │   ├── env.sh                      # Variables del cluster
│   │   ├── manifests/                  # Manifiestos generados
│   │   └── clife-tmp/                  # CLife extraído
│   ├── paas-srepg/
│   │   └── env.sh
│   └── .../
├── scripts/
│   ├── 00_download_artifacts.sh        # Descarga artefactos (con internet)
│   ├── 00_env.sh                       # Carga configuración del cluster
│   ├── 00_get_images.sh                # Genera lista de imágenes (air-gapped)
│   ├── 01_download_clife.sh            # Prepara CLife (online/offline)
│   ├── 02_generate_manifests.sh        # Genera manifiestos (soporta air-gapped)
│   ├── 03_create_acm_resources.sh      # Crea recursos en ACM
│   ├── 04_verify_install.sh            # Verifica instalación
│   ├── 05_connectivity_test.sh         # Tests de conectividad
│   ├── deploy.sh                       # Script principal (todo en uno)
│   ├── new-cluster.sh                  # Crear config para nuevo cluster
│   └── package-offline.sh              # Crear paquete tar.gz
└── docs/
    ├── 00_subnetting_plan.md           # Plan de subredes para Cluster Mesh
    ├── 01_install_guide_acm.md         # Guía de instalación
    ├── 02_install_guide_airgapped.md   # Guía para entornos air-gapped
    └── 02_install_ocp_cilium_acm_paas-arqlab.md
```

## Quick Start

### Opción 1: Script todo-en-uno

```bash
cd scripts

# Desplegar un cluster existente
./deploy.sh paas-arqlab

# Solo generar manifiestos (dry-run)
./deploy.sh paas-srepg --dry-run
```

### Opción 2: Paso a paso

```bash
cd scripts

# Descargar CLife
CLUSTER_NAME=paas-arqlab ./01_download_clife.sh

# Generar manifiestos
CLUSTER_NAME=paas-arqlab ./02_generate_manifests.sh

# Crear recursos en ACM
oc login https://api.hub-acm.example.com:6443
CLUSTER_NAME=paas-arqlab ./03_create_acm_resources.sh

# Aplicar ClusterDeployment
kubectl apply -f ../clusters/paas-arqlab/manifests/clusterdeployment.yaml

# Verificar
CLUSTER_NAME=paas-arqlab ./04_verify_install.sh

# Tests
CLUSTER_NAME=paas-arqlab ./05_connectivity_test.sh
```

### Opción 3: Instalación Air-Gapped

Para entornos sin acceso a internet, ver la guía detallada: [docs/02_install_guide_airgapped.md](docs/02_install_guide_airgapped.md)

```bash
# === En máquina con internet ===
cd scripts
./00_download_artifacts.sh    # Descarga herramientas e imágenes

# Subir a Git
git add ../artifacts/
git commit -m "Actualizar artefactos offline"
git push

# === En servidor air-gapped ===
git clone <repo>
cd networking/cilium/deployment

# Instalar herramientas (yq, jq, skopeo, helm, etc.)
sudo ./artifacts/install-tools.sh

# Iniciar registry local con Podman
./artifacts/start-local-registry.sh

# Cargar imágenes de Cilium
./artifacts/load-images.sh localhost:5000

# Desplegar cluster
export AIR_GAPPED=true
export INTERNAL_REGISTRY="<IP-servidor>:5000"
cd scripts && ./deploy.sh paas-arqlab
```

### Crear un nuevo cluster

```bash
cd scripts

# Crear configuración para un nuevo cluster
./new-cluster.sh mi-nuevo-cluster 3

# Editar la configuración generada
vim ../clusters/mi-nuevo-cluster/env.sh

# Desplegar
./deploy.sh mi-nuevo-cluster
```

## Instalación (servidor con acceso a GitHub)

Los artefactos (CLife, CLIs) ya están incluidos en el repositorio.

### Paso 1: Clonar/actualizar repositorio

```bash
git clone <repo-url>
# o si ya existe:
git pull

cd networking/cilium/deployment
```

### Paso 2: Instalar herramientas CLI

```bash
sudo ./artifacts/install-tools.sh
```

### Paso 3: Desplegar cluster

```bash
cd scripts
./deploy.sh paas-arqlab
# o
./deploy.sh paas-srepg
```

### Artefactos incluidos

| Artefacto | Versión | Descripción |
|-----------|---------|-------------|
| CLife | 1.18.6 | Cilium Lifecycle Operator manifests |
| yq | 4.40.5 | Procesador YAML (mikefarah/yq) |
| jq | 1.7.1 | Procesador JSON |
| cilium CLI | 0.16.4 | CLI para gestión de Cilium |
| hubble CLI | 0.13.0 | CLI para observabilidad |
| skopeo | 1.18.0 | Copia/gestión de imágenes |
| helm | 3.14.0 | Gestor de paquetes Kubernetes |

> **Nota**: Para air-gapped, las imágenes de Cilium se guardan en `artifacts/images/cilium-images.tar.gz`

## Clusters configurados

| Cluster | ID | Pod CIDR | API VIP | Estado |
|---------|-----|----------|---------|--------|
| paas-arqlab | 1 | 10.128.0.0/18 | 10.254.124.35 | Configurado |
| paas-srepg | 2 | 10.128.64.0/18 | 10.254.124.10 | Configurado |

## Plan de Subnetting

Para soportar 15 clusters con Cluster Mesh, el `/14` se divide en 16 subredes `/18`:

| ID | Pod CIDR | IPs disponibles |
|----|----------|-----------------|
| 1 | 10.128.0.0/18 | 16,384 |
| 2 | 10.128.64.0/18 | 16,384 |
| 3 | 10.128.128.0/18 | 16,384 |
| 4 | 10.128.192.0/18 | 16,384 |
| 5-16 | ... | ... |

Ver [docs/00_subnetting_plan.md](docs/00_subnetting_plan.md) para el plan completo.

## Requisitos

- RHACM 2.x desplegado
- `oc` CLI configurado con acceso al hub
- `kubectl` CLI
- Acceso a vSphere (para clusters on-prem)
- Pull secret de Red Hat

## Versiones

| Componente | Versión |
|------------|---------|
| Isovalent Platform | 25.11 |
| Cilium (CLife) | 1.18.6 |
| OpenShift | 4.18.x |

## Referencias

- [Isovalent — Install on OpenShift](https://docs.isovalent.com/ink/install/openshift.html)
- [Isovalent — Air-Gapped Installation](https://docs.isovalent.com/ink/install/air-gapped.html)
- [Red Hat — Certified CNI Plug-ins](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.18/html/networking/cni-plug-in-certification-matrix)
- [Cilium Cluster Mesh](https://docs.cilium.io/en/stable/network/clustermesh/)
