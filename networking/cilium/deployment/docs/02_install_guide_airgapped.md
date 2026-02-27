# Instalación Air-Gapped de Cilium en OpenShift vía RHACM

Esta guía documenta el proceso completo para instalar Isovalent Networking for Kubernetes (Cilium) en entornos **sin acceso a internet**, incluyendo:

- Descarga de artefactos y herramientas
- Imágenes guardadas en tar.gz
- Registry local con Podman
- Despliegue via RHACM

## Cambios en Cilium 1.17+

A partir de Cilium 1.17, Isovalent cambió la forma de distribuir los artefactos:

| Antes (1.16 y anteriores) | Ahora (1.17+) |
|---------------------------|---------------|
| Tarball con imágenes incluidas | CLife operator + Helm charts |
| Descarga única | Helm repository de Isovalent |
| Imágenes en el tarball | Imágenes en quay.io/isovalent |

## Referencias

- [Isovalent Air-Gapped Installation](https://docs.isovalent.com/ink/install/air-gapped.html)
- [Isovalent OpenShift with RHACM](https://docs.isovalent.com/ink/install/openshift.html)

## Arquitectura Air-Gapped

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     MÁQUINA CON INTERNET (Bastion)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. Ejecutar: ./scripts/00_download_artifacts.sh                            │
│     - Descarga CLife, herramientas CLI (yq, jq, skopeo, helm, etc.)         │
│     - Descarga imágenes de Cilium y las guarda en tar.gz                    │
│                                                                             │
│  2. Subir a Git o crear tar.gz para transferir                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                     (Git clone o scp de tar.gz)
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     SERVIDOR AIR-GAPPED                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  3. sudo ./artifacts/install-tools.sh                                       │
│     - Instala yq, jq, skopeo, helm, cilium, hubble en /usr/local/bin        │
│                                                                             │
│  4. ./artifacts/start-local-registry.sh                                     │
│     - Inicia registry local con Podman en puerto 5000                       │
│                                                                             │
│  5. ./artifacts/load-images.sh localhost:5000                               │
│     - Carga imágenes desde tar.gz y las sube al registry                    │
│                                                                             │
│  6. Desplegar cluster con AIR_GAPPED=true INTERNAL_REGISTRY=<IP>:5000       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Herramientas Incluidas

| Herramienta | Versión | Descripción |
|-------------|---------|-------------|
| yq | 4.40.5 | Procesador YAML (mikefarah/yq) |
| jq | 1.7.1 | Procesador JSON |
| cilium | 0.16.4 | CLI de Cilium |
| hubble | 0.13.0 | CLI de observabilidad |
| skopeo | 1.18.0 | Copia/gestión de imágenes de contenedores |
| helm | 3.14.0 | Gestor de paquetes Kubernetes |

## Paso 1: Descargar Artefactos (Máquina con Internet)

### 1.1 Clonar repositorio

```bash
git clone <url-del-repositorio>
cd networking/cilium/deployment
```

### 1.2 Ejecutar script de descarga

```bash
cd scripts
./00_download_artifacts.sh
```

Este script descarga:
- **CLife** (Cilium Lifecycle Operator) v1.18.6
- **Herramientas CLI**: yq, jq, cilium, hubble, skopeo, helm
- **Imágenes de Cilium**: Guardadas en `artifacts/images/cilium-images.tar.gz`

### 1.3 (Opcional) Descargar solo herramientas

Si ya tienes las imágenes o quieres descargarlas después:

```bash
./00_download_artifacts.sh --skip-images
```

Luego descargar imágenes manualmente:

```bash
cd ../artifacts
./save-images.sh
```

### 1.4 Subir a Git

```bash
# Agregar artefactos al repositorio
git add artifacts/
git commit -m "Actualizar artefactos air-gapped"
git push
```

> **Nota**: El archivo `cilium-images.tar.gz` puede ser grande (~500MB+). Considera usar Git LFS o transferir por scp.

### 1.5 Alternativa: Crear tar.gz

```bash
cd networking/cilium/deployment
tar -czvf cilium-deployment-offline.tar.gz \
    artifacts/ clusters/ scripts/ docs/ README.md
```

## Paso 2: Preparar Servidor Air-Gapped

### 2.1 Obtener artefactos

```bash
# Opción A: Git
git clone <url-del-repositorio>
cd networking/cilium/deployment

# Opción B: Desde tar.gz
scp cilium-deployment-offline.tar.gz user@servidor:/path/
ssh user@servidor
tar -xzvf cilium-deployment-offline.tar.gz
cd cilium-deployment
```

### 2.2 Instalar herramientas

```bash
sudo ./artifacts/install-tools.sh
```

Verifica la instalación:
```bash
yq --version
skopeo --version
helm version --short
```

## Paso 3: Iniciar Registry Local con Podman

### 3.1 Iniciar registry

```bash
./artifacts/start-local-registry.sh
```

El script:
- Crea un contenedor `local-registry` con la imagen `registry:2`
- Expone el puerto 5000
- Almacena datos en `artifacts/registry-data/`

### 3.2 Verificar registry

```bash
curl -s http://localhost:5000/v2/_catalog
# Debe retornar: {"repositories":[]}
```

### 3.3 Cargar imágenes

```bash
./artifacts/load-images.sh localhost:5000
```

Esto:
1. Carga las imágenes desde `cilium-images.tar.gz` en Podman local
2. Re-taggea cada imagen para el registry local
3. Hace push al registry

### 3.4 Verificar imágenes

```bash
curl -s http://localhost:5000/v2/_catalog | jq
```

Debe mostrar las imágenes de Cilium:
```json
{
  "repositories": [
    "cilium",
    "cilium-envoy",
    "hubble-relay",
    "hubble-ui-enterprise",
    "hubble-ui-enterprise-backend",
    "operator-generic"
  ]
}
```

## Paso 4: Configurar IP del Registry

El registry corre en `localhost:5000`, pero los nodos del cluster necesitan acceder por IP.

### 4.1 Obtener IP del servidor

```bash
IP=$(hostname -I | awk '{print $1}')
echo "Registry URL: ${IP}:5000"
```

### 4.2 (Opcional) Configurar TLS

Para producción, configura el registry con TLS. Ver documentación de Podman.

### 4.3 Configurar nodos para registry inseguro

Si usas HTTP (sin TLS), los nodos necesitan configurar el registry como inseguro.

En OpenShift, agregar al `install-config.yaml`:

```yaml
imageContentSources:
- mirrors:
  - <IP>:5000
  source: quay.io/isovalent
```

## Paso 5: Desplegar Cluster con Cilium

### 5.1 Configurar variables

```bash
export CLUSTER_NAME="paas-arqlab"
export AIR_GAPPED="true"
export INTERNAL_REGISTRY="<IP>:5000"  # IP del servidor con registry
export VSPHERE_PASSWORD="xxx"
```

### 5.2 Preparar CLife

```bash
cd scripts
CLUSTER_NAME=${CLUSTER_NAME} ./01_download_clife.sh
```

### 5.3 Generar manifiestos

```bash
CLUSTER_NAME=${CLUSTER_NAME} ./02_generate_manifests.sh
```

El script detecta `AIR_GAPPED=true` y agrega automáticamente la configuración de registry interno al `ciliumconfig.yaml`:

```yaml
spec:
  image:
    repository: "<IP>:5000/cilium"
  operator:
    image:
      repository: "<IP>:5000/operator"
  envoy:
    image:
      repository: "<IP>:5000/cilium-envoy"
  hubble:
    relay:
      image:
        repository: "<IP>:5000/hubble-relay"
    ui:
      frontend:
        image:
          repository: "<IP>:5000/hubble-ui-enterprise"
      backend:
        image:
          repository: "<IP>:5000/hubble-ui-enterprise-backend"
```

### 5.4 Crear recursos en ACM

```bash
CLUSTER_NAME=${CLUSTER_NAME} ./03_create_acm_resources.sh
```

### 5.5 Desplegar cluster

Aplicar el ClusterDeployment en RHACM.

## Paso 6: Verificación

### 6.1 Verificar pods de Cilium

```bash
oc get pods -n cilium
```

### 6.2 Verificar imágenes usadas

```bash
oc get pods -n cilium -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u
```

Todas deben apuntar al registry interno (`<IP>:5000/...`).

### 6.3 Verificar estado de Cilium

```bash
cilium status
```

## Troubleshooting

### Pods en ImagePullBackOff

**Causa**: Los nodos no pueden acceder al registry.

**Solución**:
```bash
# Verificar conectividad desde un nodo
ssh core@<nodo-ip>
curl -s http://<registry-ip>:5000/v2/_catalog

# Si es problema de firewall
firewall-cmd --add-port=5000/tcp --permanent
firewall-cmd --reload
```

### Error "certificate signed by unknown authority"

**Causa**: Registry con HTTPS pero sin certificado confiable.

**Soluciones**:
1. Usar HTTP (registry inseguro) - solo para desarrollo
2. Agregar certificado CA a los nodos
3. Configurar `imageContentSources` en install-config

### Imagen no encontrada en registry

**Causa**: Las imágenes no se cargaron correctamente.

**Solución**:
```bash
# Verificar imágenes en registry
curl -s http://localhost:5000/v2/_catalog | jq

# Verificar tags de una imagen
curl -s http://localhost:5000/v2/cilium/tags/list | jq

# Re-cargar imágenes
./artifacts/load-images.sh localhost:5000
```

### skopeo: command not found

**Causa**: Herramientas no instaladas.

**Solución**:
```bash
sudo ./artifacts/install-tools.sh
```

## Scripts de Referencia

| Script | Descripción | Dónde ejecutar |
|--------|-------------|----------------|
| `scripts/00_download_artifacts.sh` | Descarga todo para offline | Con internet |
| `artifacts/save-images.sh` | Guarda imágenes en tar.gz | Con internet |
| `artifacts/install-tools.sh` | Instala CLIs | Air-gapped |
| `artifacts/start-local-registry.sh` | Inicia registry Podman | Air-gapped |
| `artifacts/load-images.sh` | Carga imágenes al registry | Air-gapped |

## Estructura de Archivos

```
artifacts/
├── clife/
│   └── clife-v1.18.6.tar.gz
├── tools/
│   ├── yq_linux_amd64
│   ├── jq-linux-amd64
│   ├── skopeo-linux-amd64
│   ├── helm-linux-amd64.tar.gz
│   ├── cilium-linux-amd64.tar.gz
│   └── hubble-linux-amd64.tar.gz
├── images/
│   ├── images-list.txt
│   └── cilium-images.tar.gz
├── install-tools.sh
├── save-images.sh
├── load-images.sh
├── start-local-registry.sh
└── versions.txt
```
