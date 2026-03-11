#!/bin/bash
# =============================================================================
# Crea los recursos en RHACM para desplegar el cluster
# Uso: CLUSTER_NAME=paas-arqlab ./03_create_acm_resources.sh
#
# NOTA: En ACM/Hive, el namespace es creado automáticamente por el 
# ClusterDeployment. Este script genera todos los YAMLs y los aplica
# en el orden correcto.
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

# Verificar archivos necesarios
if [[ ! -f "${MANIFESTS_DIR}/install-config.yaml" ]]; then
    echo "ERROR: No existe ${MANIFESTS_DIR}/install-config.yaml"
    echo "Ejecutar primero: ./02_generate_manifests.sh"
    exit 1
fi

if [[ ! -d "${CLIFE_TMP_DIR}" ]] || [[ -z "$(ls -A ${CLIFE_TMP_DIR} 2>/dev/null)" ]]; then
    echo "ERROR: No existen manifiestos CLife en ${CLIFE_TMP_DIR}"
    echo "Ejecutar primero: ./01_download_clife.sh && ./02_generate_manifests.sh"
    exit 1
fi

# -----------------------------------------------------------------------------
# Generar todos los YAMLs en un directorio
# -----------------------------------------------------------------------------
ACM_MANIFESTS_DIR="${MANIFESTS_DIR}/acm"
mkdir -p "${ACM_MANIFESTS_DIR}"

echo "Generando manifiestos ACM en ${ACM_MANIFESTS_DIR}..."

# -----------------------------------------------------------------------------
# 1. Namespace (será creado por Hive, pero lo definimos para referencia)
# -----------------------------------------------------------------------------
cat > "${ACM_MANIFESTS_DIR}/00-namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${ACM_NAMESPACE}
EOF

# -----------------------------------------------------------------------------
# 2. Pull Secret (REQUERIDO - debe existir antes del ClusterDeployment)
# -----------------------------------------------------------------------------
if [[ -f "${PULL_SECRET_FILE}" ]]; then
    PULL_SECRET_B64=$(base64 -w0 < "${PULL_SECRET_FILE}")
    cat > "${ACM_MANIFESTS_DIR}/01-pull-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-pull-secret
  namespace: ${ACM_NAMESPACE}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${PULL_SECRET_B64}
EOF
    echo "  ✓ Pull secret generado desde ${PULL_SECRET_FILE}"
else
    cat > "${ACM_MANIFESTS_DIR}/01-pull-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-pull-secret
  namespace: ${ACM_NAMESPACE}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: |
    # TODO: Reemplazar con el pull secret de Red Hat (base64)
    # Obtener de: https://console.redhat.com/openshift/install/pull-secret
    # Codificar: cat pull-secret.json | base64 -w0
EOF
    echo "  ⚠ Pull secret: REQUIERE COMPLETAR (${PULL_SECRET_FILE} no encontrado)"
fi

# -----------------------------------------------------------------------------
# 3. Secret de install-config
# -----------------------------------------------------------------------------
INSTALL_CONFIG_B64=$(base64 -w0 < "${MANIFESTS_DIR}/install-config.yaml")
cat > "${ACM_MANIFESTS_DIR}/02-install-config-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-install-config
  namespace: ${ACM_NAMESPACE}
type: Opaque
data:
  install-config.yaml: ${INSTALL_CONFIG_B64}
EOF

# -----------------------------------------------------------------------------
# 4. Secret de SSH key
# -----------------------------------------------------------------------------
if [[ -f "${SSH_PRIVATE_KEY_FILE}" ]]; then
    SSH_KEY_B64=$(base64 -w0 < "${SSH_PRIVATE_KEY_FILE}")
    cat > "${ACM_MANIFESTS_DIR}/03-ssh-key-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-ssh-private-key
  namespace: ${ACM_NAMESPACE}
type: Opaque
data:
  ssh-privatekey: ${SSH_KEY_B64}
EOF
    echo "  ✓ SSH key secret generado"
else
    cat > "${ACM_MANIFESTS_DIR}/03-ssh-key-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-ssh-private-key
  namespace: ${ACM_NAMESPACE}
type: Opaque
data:
  ssh-privatekey: |
    # TODO: Reemplazar con la SSH private key (base64)
    # Codificar: cat ~/.ssh/id_rsa | base64 -w0
EOF
    echo "  ⚠ SSH key secret: REQUIERE COMPLETAR (${SSH_PRIVATE_KEY_FILE} no encontrado)"
fi

# -----------------------------------------------------------------------------
# 5. Secret de vSphere credentials
# -----------------------------------------------------------------------------
if [[ -n "${VSPHERE_PASSWORD:-}" ]]; then
    VSPHERE_USER_B64=$(echo -n "${VSPHERE_USER}" | base64 -w0)
    VSPHERE_PASS_B64=$(echo -n "${VSPHERE_PASSWORD}" | base64 -w0)
    cat > "${ACM_MANIFESTS_DIR}/04-vsphere-creds-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-vsphere-creds
  namespace: ${ACM_NAMESPACE}
type: Opaque
data:
  username: ${VSPHERE_USER_B64}
  password: ${VSPHERE_PASS_B64}
EOF
    echo "  ✓ vSphere credentials secret generado"
else
    cat > "${ACM_MANIFESTS_DIR}/04-vsphere-creds-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-vsphere-creds
  namespace: ${ACM_NAMESPACE}
type: Opaque
data:
  username: |
    # TODO: echo -n "usuario@dominio" | base64
  password: |
    # TODO: echo -n "password" | base64
EOF
    echo "  ⚠ vSphere credentials: REQUIERE COMPLETAR (VSPHERE_PASSWORD no definida)"
fi

# -----------------------------------------------------------------------------
# 6. Secret de certificados vSphere (descargar automáticamente)
# -----------------------------------------------------------------------------
echo "Descargando certificados de vSphere (${VSPHERE_SERVER})..."
VSPHERE_CERT_FILE="${MANIFESTS_DIR}/vsphere-ca.crt"

# Intentar descargar el certificado del vCenter
if openssl s_client -connect "${VSPHERE_SERVER}:443" -showcerts </dev/null 2>/dev/null | \
   openssl x509 -outform PEM > "${VSPHERE_CERT_FILE}" 2>/dev/null && \
   [[ -s "${VSPHERE_CERT_FILE}" ]]; then
    
    VSPHERE_CERT_B64=$(base64 -w0 < "${VSPHERE_CERT_FILE}")
    cat > "${ACM_MANIFESTS_DIR}/05-vsphere-certs-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-vsphere-certs
  namespace: ${ACM_NAMESPACE}
type: Opaque
data:
  .cacert: ${VSPHERE_CERT_B64}
EOF
    echo "  ✓ Certificado vSphere descargado y codificado"
else
    echo "  ⚠ No se pudo descargar el certificado de ${VSPHERE_SERVER}"
    echo "    Intentando obtener la cadena completa de certificados..."
    
    # Intentar obtener toda la cadena de certificados
    if openssl s_client -connect "${VSPHERE_SERVER}:443" -showcerts </dev/null 2>/dev/null | \
       sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > "${VSPHERE_CERT_FILE}" 2>/dev/null && \
       [[ -s "${VSPHERE_CERT_FILE}" ]]; then
        
        VSPHERE_CERT_B64=$(base64 -w0 < "${VSPHERE_CERT_FILE}")
        cat > "${ACM_MANIFESTS_DIR}/05-vsphere-certs-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-vsphere-certs
  namespace: ${ACM_NAMESPACE}
type: Opaque
data:
  .cacert: ${VSPHERE_CERT_B64}
EOF
        echo "  ✓ Cadena de certificados vSphere descargada y codificada"
    else
        echo "  ✗ No se pudo conectar a ${VSPHERE_SERVER}:443"
        echo "    Creando secret vacío - deberás completarlo manualmente o"
        echo "    eliminar certificatesSecretRef del ClusterDeployment si no es necesario"
        
        # Crear un secret con un valor vacío válido (string vacío en base64)
        cat > "${ACM_MANIFESTS_DIR}/05-vsphere-certs-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-vsphere-certs
  namespace: ${ACM_NAMESPACE}
type: Opaque
data:
  .cacert: ""
EOF
    fi
fi

# -----------------------------------------------------------------------------
# 7. Extraer y preparar manifiestos CLife (Cilium)
# -----------------------------------------------------------------------------
echo "Preparando manifiestos CLife..."

# Directorio temporal para extraer el tarball
CLIFE_EXTRACT_DIR="${MANIFESTS_DIR}/clife-extracted"
rm -rf "${CLIFE_EXTRACT_DIR}"
mkdir -p "${CLIFE_EXTRACT_DIR}"

# Buscar el tarball de CLife
CLIFE_TARBALL="${SCRIPT_DIR}/../artifacts/clife/clife-v1.18.6.tar.gz"
if [[ ! -f "${CLIFE_TARBALL}" ]]; then
    echo "ERROR: No se encontró el tarball de CLife en ${CLIFE_TARBALL}"
    exit 1
fi

# Extraer TODOS los manifiestos del tarball (según documentación Isovalent)
echo "  Extrayendo manifiestos de CLife..."
tar -xzf "${CLIFE_TARBALL}" -C "${CLIFE_EXTRACT_DIR}"

# Verificar extracción
EXTRACTED_COUNT=$(ls "${CLIFE_EXTRACT_DIR}"/*.yaml 2>/dev/null | wc -l)
echo "  Archivos extraídos: ${EXTRACTED_COUNT}"
if [[ ${EXTRACTED_COUNT} -lt 10 ]]; then
    echo "  ERROR: Se esperaban ~16 archivos YAML, solo se encontraron ${EXTRACTED_COUNT}"
    echo "  Contenido del directorio:"
    ls -la "${CLIFE_EXTRACT_DIR}/"
    exit 1
fi

# Copiar nuestro ciliumconfig.yaml personalizado (sobrescribe el del tarball)
if [[ -f "${CLIFE_TMP_DIR}/ciliumconfig.yaml" ]]; then
    cp "${CLIFE_TMP_DIR}/ciliumconfig.yaml" "${CLIFE_EXTRACT_DIR}/ciliumconfig.yaml"
    echo "  ✓ ciliumconfig.yaml personalizado copiado"
fi

# Copiar cluster-network-02-config-local.yml
if [[ -f "${CLIFE_TMP_DIR}/cluster-network-02-config-local.yml" ]]; then
    cp "${CLIFE_TMP_DIR}/cluster-network-02-config-local.yml" "${CLIFE_EXTRACT_DIR}/"
    echo "  ✓ cluster-network-02-config-local.yml copiado"
fi

# -----------------------------------------------------------------------------
# 7b. MachineConfigs para api-int en /etc/hosts (master y worker)
# -----------------------------------------------------------------------------
# Añade la línea api-int.<cluster>.<baseDomain> -> API_VIP en /etc/hosts para
# que los nodos resuelvan el API interno durante la instalación.
API_INT_HOSTS_LINE="${API_VIP} api-int.${CLUSTER_NAME}.${BASE_DOMAIN}"
API_INT_HOSTS_B64=$(printf '%s\n' "${API_INT_HOSTS_LINE}" | base64 | tr -d '\n')

cat > "${CLIFE_EXTRACT_DIR}/99-master-add-api-int-host.yaml" << EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-master-add-api-int-host
  labels:
    machineconfiguration.openshift.io/role: master
spec:
  config:
    ignition:
      version: 3.4.0
    storage:
      files:
      - path: /etc/hosts
        mode: 0644
        overwrite: false
        append: true
        contents:
          source: data:text/plain;charset=utf-8;base64,${API_INT_HOSTS_B64}
EOF

cat > "${CLIFE_EXTRACT_DIR}/99-worker-add-api-int-host.yaml" << EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-worker-add-api-int-host
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.4.0
    storage:
      files:
      - path: /etc/hosts
        mode: 0644
        overwrite: false
        append: true
        contents:
          source: data:text/plain;charset=utf-8;base64,${API_INT_HOSTS_B64}
EOF

echo "  ✓ MachineConfigs 99-master-add-api-int-host y 99-worker-add-api-int-host generados (api-int -> ${API_VIP})"

# Configurar KUBERNETES_SERVICE_HOST/PORT para KPR
#
# Cuando KPR (Kube Proxy Replacement) está habilitado, CLife necesita saber
# cómo conectarse al API server externo ya que no habrá kube-proxy.
#
# Con ENABLE_KPR=true:
#   - KUBERNETES_SERVICE_HOST=api.${CLUSTER_NAME}.${BASE_DOMAIN}
#   - KUBERNETES_SERVICE_PORT=6443
#
# Alternativamente, se puede especificar manualmente:
#   CLIFE_API_HOST=<ip> CLIFE_API_PORT=<port> ./03_create_acm_resources.sh

if [[ "${ENABLE_KPR}" == "true" ]]; then
    KUBERNETES_SERVICE_HOST="api.${CLUSTER_NAME}.${BASE_DOMAIN}"
    KUBERNETES_SERVICE_PORT="6443"
    
    echo "  Configurando API server para KPR: ${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
    
    # Modificar el Deployment de CLife
    # Según docs.isovalent.com, las variables deben estar al INICIO del array env
    DEPLOYMENT_FILE="${CLIFE_EXTRACT_DIR}/apps_v1_deployment_clife-controller-manager.yaml"
    if [[ -f "${DEPLOYMENT_FILE}" ]]; then
        if command -v yq &>/dev/null; then
            # Insertar al INICIO del array env (prepend) según documentación Isovalent
            yq -i '(.spec.template.spec.containers[] | select(has("name")) | select(.name == "manager")).env = [{"name": "KUBERNETES_SERVICE_HOST", "value": "'"${KUBERNETES_SERVICE_HOST}"'"}, {"name": "KUBERNETES_SERVICE_PORT", "value": "'"${KUBERNETES_SERVICE_PORT}"'"}] + ((.spec.template.spec.containers[] | select(has("name")) | select(.name == "manager")).env // [])' "${DEPLOYMENT_FILE}"
            echo "  ✓ Variables KUBERNETES_SERVICE_HOST/PORT agregadas al Deployment de CLife"
        else
            echo "  ⚠ yq no disponible - agregar manualmente las variables de entorno al Deployment"
        fi
    fi
    
    # Modificar la Subscription de CLife (si existe y se va a incluir)
    SUBSCRIPTION_FILE="${CLIFE_EXTRACT_DIR}/subscription.yaml"
    if [[ -f "${SUBSCRIPTION_FILE}" ]] && [[ "${INCLUDE_OLM_MANIFESTS:-false}" == "true" ]]; then
        if command -v yq &>/dev/null; then
            # Crear .spec.config.env con las variables (subscription no tiene env por defecto)
            yq -i '.spec.config.env = [{"name": "KUBERNETES_SERVICE_HOST", "value": "'"${KUBERNETES_SERVICE_HOST}"'"}, {"name": "KUBERNETES_SERVICE_PORT", "value": "'"${KUBERNETES_SERVICE_PORT}"'"}]' "${SUBSCRIPTION_FILE}"
            echo "  ✓ Variables KUBERNETES_SERVICE_HOST/PORT agregadas a la Subscription"
        fi
    fi
elif [[ -n "${CLIFE_API_HOST:-}" ]]; then
    # Configuración manual (comportamiento anterior)
    echo "  Configurando API server personalizado para CLife..."
    DEPLOYMENT_FILE="${CLIFE_EXTRACT_DIR}/apps_v1_deployment_clife-controller-manager.yaml"
    if [[ -f "${DEPLOYMENT_FILE}" ]]; then
        if command -v yq &>/dev/null; then
            CLIFE_API_PORT="${CLIFE_API_PORT:-6443}"
            # Insertar al INICIO del array env (prepend)
            yq -i '(.spec.template.spec.containers[] | select(has("name")) | select(.name == "manager")).env = [{"name": "KUBERNETES_SERVICE_HOST", "value": "'"${CLIFE_API_HOST}"'"}, {"name": "KUBERNETES_SERVICE_PORT", "value": "'"${CLIFE_API_PORT}"'"}] + ((.spec.template.spec.containers[] | select(has("name")) | select(.name == "manager")).env // [])' "${DEPLOYMENT_FILE}"
            echo "  ✓ Variables KUBERNETES_SERVICE_HOST=${CLIFE_API_HOST}:${CLIFE_API_PORT} agregadas al Deployment"
        else
            echo "  ⚠ yq no disponible, las variables de entorno deben agregarse manualmente"
        fi
    fi
fi

# -----------------------------------------------------------------------------
# 8. ConfigMap con manifiestos CLife (Cilium)
# -----------------------------------------------------------------------------
echo "Generando ConfigMap con manifiestos CLife..."

# IMPORTANTE: Para instalaciones Day 0 (bootstrap) con RHACM/Hive, se deben
# EXCLUIR los siguientes archivos que dependen de OLM funcionando:
# - subscription.yaml: Intenta instalar CLife via OperatorHub (requiere OLM+red)
# - operatorgroup.yaml: Asociado a la Subscription de OLM
#
# El Deployment de CLife ya tiene hostNetwork: true y las imágenes embebidas
# como RELATED_IMAGE_*, por lo que funciona durante el bootstrap sin OLM.
#
# Referencia: https://docs.isovalent.com/ink/install/openshift.html
#
# Para incluir los manifiestos de OLM (Day 2 / post-bootstrap):
#   INCLUDE_OLM_MANIFESTS=true CLUSTER_NAME=xxx ./03_create_acm_resources.sh

# Lista de archivos a EXCLUIR del ConfigMap (requieren OLM funcionando)
# Si INCLUDE_OLM_MANIFESTS=true, no se excluye nada
if [[ "${INCLUDE_OLM_MANIFESTS:-false}" == "true" ]]; then
    echo "  ⚠ INCLUDE_OLM_MANIFESTS=true - Incluyendo manifiestos OLM (subscription, operatorgroup)"
    EXCLUDED_FILES=()
else
    EXCLUDED_FILES=(
        "subscription.yaml"
        "operatorgroup.yaml"
    )
fi

cat > "${ACM_MANIFESTS_DIR}/06-clife-manifests-configmap.yaml" << 'CONFIGMAP_HEADER'
apiVersion: v1
kind: ConfigMap
metadata:
CONFIGMAP_HEADER

cat >> "${ACM_MANIFESTS_DIR}/06-clife-manifests-configmap.yaml" << EOF
  name: ${CLUSTER_NAME}-clife-manifests
  namespace: ${ACM_NAMESPACE}
data:
EOF

# Agregar cada archivo como una key en el ConfigMap, excluyendo los de OLM
INCLUDED_COUNT=0
EXCLUDED_COUNT=0

echo "  Procesando archivos YAML del directorio: ${CLIFE_EXTRACT_DIR}"

for file in "${CLIFE_EXTRACT_DIR}"/*.yaml "${CLIFE_EXTRACT_DIR}"/*.yml; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        
        # Verificar si el archivo está en la lista de exclusión
        SKIP_FILE=false
        if [[ ${#EXCLUDED_FILES[@]} -gt 0 ]]; then
            for excluded in "${EXCLUDED_FILES[@]}"; do
                if [[ "$filename" == "$excluded" ]]; then
                    SKIP_FILE=true
                    echo "  ⊘ Excluyendo ${filename} (requiere OLM)"
                    EXCLUDED_COUNT=$((EXCLUDED_COUNT + 1))
                    break
                fi
            done
        fi
        
        if [[ "$SKIP_FILE" == "false" ]]; then
            echo "  + Incluyendo: ${filename}"
            echo "  ${filename}: |" >> "${ACM_MANIFESTS_DIR}/06-clife-manifests-configmap.yaml"
            # Indentar contenido con 4 espacios
            sed 's/^/    /' "$file" >> "${ACM_MANIFESTS_DIR}/06-clife-manifests-configmap.yaml"
            INCLUDED_COUNT=$((INCLUDED_COUNT + 1))
        fi
    fi
done

echo "  ✓ CLife manifests ConfigMap generado (${INCLUDED_COUNT} archivos incluidos, ${EXCLUDED_COUNT} excluidos)"

# Verificar que se incluyeron los manifiestos críticos
if [[ ${INCLUDED_COUNT} -lt 10 ]]; then
    echo "  ⚠ ADVERTENCIA: Solo se incluyeron ${INCLUDED_COUNT} archivos. Se esperaban ~14-16."
    echo "  Verificar el contenido del ConfigMap generado."
fi

# -----------------------------------------------------------------------------
# 9. ClusterDeployment
# -----------------------------------------------------------------------------
cat > "${ACM_MANIFESTS_DIR}/10-clusterdeployment.yaml" << EOF
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${ACM_NAMESPACE}
  labels:
    cloud: vsphere
    vendor: OpenShift
    cluster.open-cluster-management.io/clusterset: default
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

echo "  ✓ ClusterDeployment generado"

# -----------------------------------------------------------------------------
# 10. ManagedCluster (para que ACM gestione el cluster)
# -----------------------------------------------------------------------------
cat > "${ACM_MANIFESTS_DIR}/11-managedcluster.yaml" << EOF
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: ${CLUSTER_NAME}
  labels:
    cloud: vsphere
    vendor: OpenShift
    cluster.open-cluster-management.io/clusterset: default
    environment: ${CLUSTER_NAME}
spec:
  hubAcceptsClient: true
EOF

echo "  ✓ ManagedCluster generado"

# -----------------------------------------------------------------------------
# 11. KlusterletAddonConfig (opcional, para addons de ACM)
# -----------------------------------------------------------------------------
cat > "${ACM_MANIFESTS_DIR}/12-klusterletaddonconfig.yaml" << EOF
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${ACM_NAMESPACE}
spec:
  clusterName: ${CLUSTER_NAME}
  clusterNamespace: ${ACM_NAMESPACE}
  applicationManager:
    enabled: true
  certPolicyController:
    enabled: true
  iamPolicyController:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: true
EOF

echo "  ✓ KlusterletAddonConfig generado"

# -----------------------------------------------------------------------------
# Crear script de aplicación
# -----------------------------------------------------------------------------
cat > "${ACM_MANIFESTS_DIR}/apply.sh" << 'APPLY_SCRIPT'
#!/bin/bash
# Aplica todos los recursos ACM en orden
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Aplicando recursos ACM ==="
echo ""

# 1. Crear namespace primero
echo "[1/4] Creando namespace..."
kubectl apply -f "${SCRIPT_DIR}/00-namespace.yaml"

# Esperar que el namespace esté activo
echo "Esperando namespace..."
for i in {1..30}; do
    STATUS=$(kubectl get namespace NAMESPACE_PLACEHOLDER -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [[ "$STATUS" == "Active" ]]; then
        echo "  ✓ Namespace activo"
        break
    fi
    sleep 2
done

# 2. Crear secrets y configmaps
echo ""
echo "[2/4] Creando secrets y configmaps..."
kubectl apply -f "${SCRIPT_DIR}/01-pull-secret.yaml"
kubectl apply -f "${SCRIPT_DIR}/02-install-config-secret.yaml"
kubectl apply -f "${SCRIPT_DIR}/03-ssh-key-secret.yaml"
kubectl apply -f "${SCRIPT_DIR}/04-vsphere-creds-secret.yaml"
kubectl apply -f "${SCRIPT_DIR}/05-vsphere-certs-secret.yaml"
kubectl apply -f "${SCRIPT_DIR}/06-clife-manifests-configmap.yaml"

# 3. Crear ManagedCluster (antes del ClusterDeployment)
echo ""
echo "[3/4] Creando ManagedCluster..."
kubectl apply -f "${SCRIPT_DIR}/11-managedcluster.yaml"

# 4. Crear ClusterDeployment (esto inicia el despliegue)
echo ""
echo "[4/4] Creando ClusterDeployment..."
kubectl apply -f "${SCRIPT_DIR}/10-clusterdeployment.yaml"

# 5. Crear KlusterletAddonConfig
echo ""
echo "Creando KlusterletAddonConfig..."
kubectl apply -f "${SCRIPT_DIR}/12-klusterletaddonconfig.yaml"

echo ""
echo "=== Recursos aplicados ==="
kubectl -n NAMESPACE_PLACEHOLDER get secrets,configmaps,clusterdeployment
echo ""
echo "Monitorear instalación:"
echo "  watch 'kubectl -n NAMESPACE_PLACEHOLDER get clusterdeployment,pods'"
echo "  kubectl -n NAMESPACE_PLACEHOLDER logs -f job/CLUSTER_PLACEHOLDER-0-provision"
APPLY_SCRIPT

# Reemplazar placeholders en el script (compatible con macOS y Linux)
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/NAMESPACE_PLACEHOLDER/${ACM_NAMESPACE}/g" "${ACM_MANIFESTS_DIR}/apply.sh"
    sed -i '' "s/CLUSTER_PLACEHOLDER/${CLUSTER_NAME}/g" "${ACM_MANIFESTS_DIR}/apply.sh"
else
    sed -i "s/NAMESPACE_PLACEHOLDER/${ACM_NAMESPACE}/g" "${ACM_MANIFESTS_DIR}/apply.sh"
    sed -i "s/CLUSTER_PLACEHOLDER/${CLUSTER_NAME}/g" "${ACM_MANIFESTS_DIR}/apply.sh"
fi
chmod +x "${ACM_MANIFESTS_DIR}/apply.sh"

# -----------------------------------------------------------------------------
# Resumen
# -----------------------------------------------------------------------------
echo ""
echo "============================================="
echo "  Manifiestos ACM generados"
echo "============================================="
echo ""
echo "Directorio: ${ACM_MANIFESTS_DIR}"
echo ""
ls -la "${ACM_MANIFESTS_DIR}"
echo ""
echo "============================================="
echo "  ANTES DE APLICAR - Verificar/completar:"
echo "============================================="
echo ""
echo "1. Pull Secret de Red Hat (REQUERIDO):"
if [[ -f "${PULL_SECRET_FILE}" ]]; then
    echo "   ✓ Ya incluido desde ${PULL_SECRET_FILE}"
else
    echo "   - Obtener de: https://console.redhat.com/openshift/install/pull-secret"
    echo "   - Guardar en: ${PULL_SECRET_FILE}"
    echo "   - O editar: ${ACM_MANIFESTS_DIR}/01-pull-secret.yaml"
fi
echo ""
echo "2. SSH Private Key:"
if [[ -f "${SSH_PRIVATE_KEY_FILE}" ]]; then
    echo "   ✓ Ya incluida desde ${SSH_PRIVATE_KEY_FILE}"
else
    echo "   - Editar: ${ACM_MANIFESTS_DIR}/03-ssh-key-secret.yaml"
    echo "   - Reemplazar el TODO con: cat ~/.ssh/id_rsa | base64 -w0"
fi
echo ""
echo "3. Credenciales vSphere:"
if [[ -n "${VSPHERE_PASSWORD:-}" ]]; then
    echo "   ✓ Ya incluidas"
else
    echo "   - Editar: ${ACM_MANIFESTS_DIR}/04-vsphere-creds-secret.yaml"
    echo "   - O exportar: export VSPHERE_PASSWORD='...' y re-ejecutar"
fi
echo ""
echo "4. Certificados vSphere (si usa self-signed):"
echo "   - Editar: ${ACM_MANIFESTS_DIR}/05-vsphere-certs-secret.yaml"
echo "   - O eliminar certificatesSecretRef del ClusterDeployment"
echo ""
echo "5. ClusterImageSet (verificar que existe):"
echo "   kubectl get clusterimageset ${ACM_IMAGE_SET}"
echo ""
echo "============================================="
echo "  APLICAR RECURSOS"
echo "============================================="
echo ""
echo "Opción 1 - Script automático:"
echo "  ${ACM_MANIFESTS_DIR}/apply.sh"
echo ""
echo "Opción 2 - Manual:"
echo "  kubectl apply -f ${ACM_MANIFESTS_DIR}/"
echo ""
echo "============================================="
echo "  MONITOREAR INSTALACIÓN"
echo "============================================="
echo ""
echo "  watch 'kubectl -n ${ACM_NAMESPACE} get clusterdeployment,pods'"
echo "  kubectl -n ${ACM_NAMESPACE} logs -f job/${CLUSTER_NAME}-0-provision"
echo "  ./04_verify_install.sh"
echo ""
# Mostrar nota sobre manifiestos OLM según configuración
if [[ "${INCLUDE_OLM_MANIFESTS:-false}" == "true" ]]; then
    echo "============================================="
    echo "  NOTA: Manifiestos OLM Incluidos"
    echo "============================================="
    echo ""
    echo "Se incluyeron TODOS los manifiestos de CLife, incluyendo:"
    echo "  - subscription.yaml"
    echo "  - operatorgroup.yaml"
    echo ""
    echo "Estos manifiestos requieren OLM funcionando. Usar esta"
    echo "configuración solo para instalaciones Day 2 o cuando"
    echo "OLM ya esté operativo en el cluster."
    echo ""
    if [[ "${ENABLE_KPR}" == "true" ]]; then
        echo "Las variables KUBERNETES_SERVICE_HOST/PORT fueron agregadas a:"
        echo "  - Deployment de CLife (apps_v1_deployment_clife-controller-manager.yaml)"
        echo "  - Subscription de CLife (subscription.yaml)"
        echo ""
    fi
else
    echo "============================================="
    echo "  NOTA: Manifiestos OLM Excluidos"
    echo "============================================="
    echo ""
    echo "Los siguientes archivos fueron EXCLUIDOS del ConfigMap porque"
    echo "requieren OLM funcionando (no disponible durante bootstrap):"
    echo "  - subscription.yaml"
    echo "  - operatorgroup.yaml"
    echo ""
    echo "El operador CLife se instala directamente via Deployment con"
    echo "hostNetwork: true, lo que permite funcionar sin CNI durante"
    echo "el bootstrap del cluster."
    echo ""
    if [[ "${ENABLE_KPR}" == "true" ]]; then
        echo "Las variables KUBERNETES_SERVICE_HOST/PORT fueron agregadas al:"
        echo "  - Deployment de CLife (apps_v1_deployment_clife-controller-manager.yaml)"
        echo ""
    fi
    echo "Post-instalación (Day 2), si deseas gestionar CLife via OLM:"
    echo "  1. Los archivos excluidos están en: ${CLIFE_EXTRACT_DIR}/"
    echo "  2. Aplicar manualmente después de que el cluster esté operativo"
fi
