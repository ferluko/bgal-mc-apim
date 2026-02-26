#!/bin/bash
# =============================================================================
# Genera los manifiestos personalizados para el cluster
# Uso: CLUSTER_NAME=paas-arqlab ./02_generate_manifests.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

echo "=== Generando manifiestos para ${CLUSTER_NAME} (ID: ${CLUSTER_ID}) ==="

mkdir -p "${MANIFESTS_DIR}"
mkdir -p "${CLIFE_TMP_DIR}"

# -----------------------------------------------------------------------------
# 1. install-config.yaml
# -----------------------------------------------------------------------------
echo "Generando install-config.yaml..."

# Leer SSH public key
if [[ -f "${SSH_PUBLIC_KEY_FILE}" ]]; then
    SSH_KEY=$(cat "${SSH_PUBLIC_KEY_FILE}")
    echo "  ✓ SSH public key cargada desde ${SSH_PUBLIC_KEY_FILE}"
else
    # Intentar ubicaciones alternativas
    for alt_key in "${HOME}/.ssh/id_rsa.pub" "${HOME}/.ssh/id_ed25519.pub" "/root/.ssh/id_rsa.pub"; do
        if [[ -f "${alt_key}" ]]; then
            SSH_KEY=$(cat "${alt_key}")
            echo "  ✓ SSH public key cargada desde ${alt_key}"
            break
        fi
    done
    
    if [[ -z "${SSH_KEY:-}" ]]; then
        echo "ERROR: No se encontró SSH public key"
        echo "  Buscado en: ${SSH_PUBLIC_KEY_FILE}"
        echo "  Alternativas: ~/.ssh/id_rsa.pub, ~/.ssh/id_ed25519.pub"
        echo ""
        echo "Opciones:"
        echo "  1. Generar una: ssh-keygen -t rsa -b 4096"
        echo "  2. Especificar ruta: export SSH_PUBLIC_KEY_FILE=/path/to/key.pub"
        exit 1
    fi
fi

# Convertir IPs a formato YAML
IFS=',' read -ra MASTER_IP_ARRAY <<< "${HOST_MASTER_IPS}"
IFS=',' read -ra WORKER_IP_ARRAY <<< "${HOST_WORKER_IPS}"
IFS=',' read -ra NS_ARRAY <<< "${HOST_NAMESERVERS}"

cat > "${MANIFESTS_DIR}/install-config.yaml" << EOF
additionalTrustBundlePolicy: Proxyonly
apiVersion: v1
baseDomain: "${BASE_DOMAIN}"
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    vsphere:
      coresPerSocket: 2
      cpus: ${WORKER_CPUS}
      memoryMB: ${WORKER_MEMORY_MB}
      osDisk:
        diskSizeGB: ${WORKER_DISK_GB}
      zones:
      - generated-failure-domain
  replicas: ${#WORKER_IP_ARRAY[@]}
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    vsphere:
      coresPerSocket: 2
      cpus: ${MASTER_CPUS}
      memoryMB: ${MASTER_MEMORY_MB}
      osDisk:
        diskSizeGB: ${MASTER_DISK_GB}
      zones:
      - generated-failure-domain
  replicas: ${#MASTER_IP_ARRAY[@]}
metadata:
  name: "${CLUSTER_NAME}"
networking:
  clusterNetwork:
  - cidr: ${POD_CIDR}
    hostPrefix: ${HOST_PREFIX}
  machineNetwork:
  - cidr: ${MACHINE_CIDR}
  networkType: Cilium
  serviceNetwork:
  - ${SERVICE_CIDR}
platform:
  vsphere:
    apiVIPs:
    - "${API_VIP}"
    failureDomains:
    - name: generated-failure-domain
      region: generated-region
      server: "${VSPHERE_SERVER}"
      topology:
        computeCluster: ${VSPHERE_CLUSTER}
        datacenter: "${VSPHERE_DATACENTER}"
        datastore: "${VSPHERE_DATASTORE}"
        networks:
        - "${VSPHERE_NETWORK}"
        resourcePool: "${VSPHERE_RESOURCE_POOL}"
      zone: generated-zone
    hosts:
    - failureDomain: ""
      networkDevice:
        gateway: ${HOST_GATEWAY}
        ipAddrs:
        - ${HOST_BOOTSTRAP_IP}/24
        nameservers:
$(for ns in "${NS_ARRAY[@]}"; do echo "        - ${ns}"; done)
      role: bootstrap
$(for ip in "${MASTER_IP_ARRAY[@]}"; do
cat << MASTER
    - failureDomain: ""
      networkDevice:
        gateway: ${HOST_GATEWAY}
        ipAddrs:
        - ${ip}/24
        nameservers:
$(for ns in "${NS_ARRAY[@]}"; do echo "        - ${ns}"; done)
      role: control-plane
MASTER
done)
$(for ip in "${WORKER_IP_ARRAY[@]}"; do
cat << WORKER
    - failureDomain: ""
      networkDevice:
        gateway: ${HOST_GATEWAY}
        ipAddrs:
        - ${ip}/24
        nameservers:
$(for ns in "${NS_ARRAY[@]}"; do echo "        - ${ns}"; done)
      role: compute
WORKER
done)
    ingressVIPs:
    - "${INGRESS_VIP}"
    loadBalancer:
      type: UserManaged
    vcenters:
    - datacenters:
      - "${VSPHERE_DATACENTER}"
      password: "\${VSPHERE_PASSWORD}"
      port: 443
      server: ${VSPHERE_SERVER}
      user: "${VSPHERE_USER}"
pullSecret: ""
sshKey: |-
  ${SSH_KEY}
EOF

echo "  ✓ install-config.yaml"

# -----------------------------------------------------------------------------
# 2. ciliumconfig.yaml
# -----------------------------------------------------------------------------
echo "Generando ciliumconfig.yaml..."

if [[ "${ENABLE_KPR}" == "true" ]]; then
    KPR_CONFIG="kubeProxyReplacement: true
  k8sServiceHost: \"api.${CLUSTER_NAME}.${BASE_DOMAIN}\"
  k8sServicePort: \"443\""
else
    KPR_CONFIG="kubeProxyReplacement: false"
fi

cat > "${CLIFE_TMP_DIR}/ciliumconfig.yaml" << EOF
apiVersion: cilium.io/v1alpha1
kind: CiliumConfig
metadata:
  labels:
    app.kubernetes.io/name: clife
  name: ciliumconfig
spec:
  cluster:
    name: ${CLUSTER_NAME}
    id: ${CLUSTER_ID}
  securityContext:
    privileged: true
  ipam:
    mode: "cluster-pool"
    operator:
      clusterPoolIPv4PodCIDRList:
      - ${POD_CIDR}
      clusterPoolIPv4MaskSize: ${HOST_PREFIX}
  cni:
    binPath: "/var/lib/cni/bin"
    confPath: "/var/run/multus/cni/net.d"
    chainingMode: portmap
    exclusive: false
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
  operator:
    prometheus:
      enabled: true
      serviceMonitor:
        enabled: true
  hubble:
    enabled: true
  ${KPR_CONFIG}
  clusterHealthPort: 9940
  tunnelPort: 4789
  enterprise:
    featureGate:
      approved:
      - CNIChainingMode
EOF

echo "  ✓ ciliumconfig.yaml"

# -----------------------------------------------------------------------------
# 3. cluster-network-02-config-local.yml
# -----------------------------------------------------------------------------
echo "Generando cluster-network-02-config-local.yml..."

if [[ "${ENABLE_KPR}" == "true" ]]; then
    DEPLOY_KUBE_PROXY="false"
else
    DEPLOY_KUBE_PROXY="true"
fi

cat > "${CLIFE_TMP_DIR}/cluster-network-02-config-local.yml" << EOF
apiVersion: operator.openshift.io/v1
kind: Network
metadata:
  name: cluster
spec:
  clusterNetwork:
  - cidr: ${POD_CIDR}
    hostPrefix: ${HOST_PREFIX}
  deployKubeProxy: ${DEPLOY_KUBE_PROXY}
  externalIP:
    policy: {}
  networkType: Cilium
  serviceNetwork:
  - ${SERVICE_CIDR}
EOF

echo "  ✓ cluster-network-02-config-local.yml"

# -----------------------------------------------------------------------------
# 4. Copiar install-config a manifests
# -----------------------------------------------------------------------------
cp "${MANIFESTS_DIR}/install-config.yaml" "${MANIFESTS_DIR}/install-config.yaml.backup"

echo ""
echo "=== Manifiestos generados ==="
echo "  ${MANIFESTS_DIR}/install-config.yaml"
echo "  ${CLIFE_TMP_DIR}/ciliumconfig.yaml"
echo "  ${CLIFE_TMP_DIR}/cluster-network-02-config-local.yml"
echo ""
echo "✓ Manifiestos generados correctamente para ${CLUSTER_NAME}"
echo "  Siguiente paso: CLUSTER_NAME=${CLUSTER_NAME} ./03_create_acm_resources.sh"
