#!/bin/bash
# =============================================================================
# Crea los recursos en RHACM para desplegar el cluster
# Uso: CLUSTER_NAME=paas-arqlab ./03_create_acm_resources.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

echo "=== Creando recursos ACM para ${CLUSTER_NAME} (ID: ${CLUSTER_ID}) ==="

# Verificar conexión al hub
if ! oc whoami &>/dev/null; then
    echo "ERROR: No hay sesión activa de oc. Ejecutar 'oc login' primero."
    exit 1
fi

KUBECTL_CMD="kubectl"
if [[ "${DRY_RUN}" == "true" ]]; then
    echo "MODO DRY-RUN: Solo se generarán los YAMLs, no se aplicarán"
    KUBECTL_CMD="kubectl --dry-run=client -o yaml"
fi

# -----------------------------------------------------------------------------
# 1. Namespace
# -----------------------------------------------------------------------------
echo "Creando namespace ${ACM_NAMESPACE}..."
cat << EOF | ${KUBECTL_CMD} apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${ACM_NAMESPACE}
  labels:
    cluster.open-cluster-management.io/managedCluster: ${CLUSTER_NAME}
EOF

# -----------------------------------------------------------------------------
# 2. Secret de install-config
# -----------------------------------------------------------------------------
echo "Creando secret de install-config..."
kubectl -n ${ACM_NAMESPACE} create secret generic ${CLUSTER_NAME}-install-config \
    --from-file=install-config.yaml="${MANIFESTS_DIR}/install-config.yaml" \
    --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -

# -----------------------------------------------------------------------------
# 3. Secret de SSH key
# -----------------------------------------------------------------------------
if [[ -f "${SSH_PRIVATE_KEY_FILE}" ]]; then
    echo "Creando secret de SSH key..."
    kubectl -n ${ACM_NAMESPACE} create secret generic ${CLUSTER_NAME}-ssh-private-key \
        --from-file=ssh-privatekey="${SSH_PRIVATE_KEY_FILE}" \
        --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
else
    echo "WARN: No se encontró ${SSH_PRIVATE_KEY_FILE}, omitiendo secret de SSH"
fi

# -----------------------------------------------------------------------------
# 4. Secret de vSphere credentials (si existe la variable)
# -----------------------------------------------------------------------------
if [[ -n "${VSPHERE_PASSWORD:-}" ]]; then
    echo "Creando secret de credenciales vSphere..."
    kubectl -n ${ACM_NAMESPACE} create secret generic ${CLUSTER_NAME}-vsphere-creds \
        --from-literal=username="${VSPHERE_USER}" \
        --from-literal=password="${VSPHERE_PASSWORD}" \
        --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -
else
    echo "WARN: VSPHERE_PASSWORD no definida, crear secret manualmente"
fi

# -----------------------------------------------------------------------------
# 5. ConfigMap con manifiestos CLife
# -----------------------------------------------------------------------------
echo "Creando ConfigMap con manifiestos CLife..."
kubectl -n ${ACM_NAMESPACE} create configmap ${CLUSTER_NAME}-clife-manifests \
    --from-file="${CLIFE_TMP_DIR}" \
    --dry-run=client -o yaml | ${KUBECTL_CMD} apply -f -

# -----------------------------------------------------------------------------
# 6. Generar ClusterDeployment (solo template, no aplicar automáticamente)
# -----------------------------------------------------------------------------
echo "Generando template de ClusterDeployment..."
cat > "${MANIFESTS_DIR}/clusterdeployment.yaml" << EOF
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${ACM_NAMESPACE}
  labels:
    cloud: vsphere
    vendor: OpenShift
spec:
  baseDomain: ${BASE_DOMAIN}
  clusterName: ${CLUSTER_NAME}
  platform:
    vsphere:
      certificatesSecretRef:
        name: ${CLUSTER_NAME}-vsphere-certs
      credentialsSecretRef:
        name: ${CLUSTER_NAME}-vsphere-creds
      vCenter: ${VSPHERE_SERVER}
      datacenter: "${VSPHERE_DATACENTER}"
      defaultDatastore: "${VSPHERE_DATASTORE}"
      cluster: "${VSPHERE_CLUSTER}"
      network: "${VSPHERE_NETWORK}"
  provisioning:
    installConfigSecretRef:
      name: ${CLUSTER_NAME}-install-config
    sshPrivateKeySecretRef:
      name: ${CLUSTER_NAME}-ssh-private-key
    manifestsConfigMapRef:
      name: ${CLUSTER_NAME}-clife-manifests
    imageSetRef:
      name: ${ACM_IMAGE_SET}
  pullSecretRef:
    name: ${CLUSTER_NAME}-pull-secret
EOF

echo "  ✓ ClusterDeployment template: ${MANIFESTS_DIR}/clusterdeployment.yaml"

echo ""
echo "=== Recursos creados ==="
echo ""
kubectl -n ${ACM_NAMESPACE} get secrets,configmaps 2>/dev/null || true
echo ""
echo "=== Próximos pasos ==="
echo "1. Verificar/crear secrets faltantes:"
echo "   - ${CLUSTER_NAME}-pull-secret (pull secret de Red Hat)"
echo "   - ${CLUSTER_NAME}-vsphere-certs (certificados vSphere si aplica)"
echo "   - ${CLUSTER_NAME}-vsphere-creds (si no se creó automáticamente)"
echo ""
echo "2. Revisar y aplicar ClusterDeployment:"
echo "   kubectl apply -f ${MANIFESTS_DIR}/clusterdeployment.yaml"
echo ""
echo "3. Monitorear instalación:"
echo "   ./04_verify_install.sh"
