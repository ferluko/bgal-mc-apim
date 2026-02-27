#!/bin/bash
# =============================================================================
# Fix: Regenerar ConfigMap de CLife con todos los manifiestos
#
# Uso: CLUSTER_NAME=paas-arqlab ./fix_clife_configmap.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar configuración
if [[ -z "${CLUSTER_NAME:-}" ]]; then
    echo "ERROR: CLUSTER_NAME no definido"
    echo "Uso: CLUSTER_NAME=paas-arqlab ./fix_clife_configmap.sh"
    exit 1
fi

source "${SCRIPT_DIR}/00_env.sh"

CLIFE_TARBALL="${SCRIPT_DIR}/../artifacts/clife/clife-v1.18.6.tar.gz"
EXTRACT_DIR="/tmp/clife-fix-$$"
CONFIGMAP_FILE="/tmp/clife-configmap-fix-$$.yaml"

echo "============================================="
echo "  FIX: Regenerar ConfigMap de CLife"
echo "============================================="
echo ""
echo "Cluster: ${CLUSTER_NAME}"
echo "Namespace: ${ACM_NAMESPACE}"
echo ""

# Verificar tarball
if [[ ! -f "${CLIFE_TARBALL}" ]]; then
    echo "ERROR: No se encontró ${CLIFE_TARBALL}"
    exit 1
fi

# Extraer
echo "1. Extrayendo manifiestos de CLife..."
rm -rf "${EXTRACT_DIR}"
mkdir -p "${EXTRACT_DIR}"
tar -xzf "${CLIFE_TARBALL}" -C "${EXTRACT_DIR}"

echo "   Archivos extraídos:"
ls -1 "${EXTRACT_DIR}"/*.yaml | while read f; do echo "     - $(basename $f)"; done

TOTAL=$(ls "${EXTRACT_DIR}"/*.yaml | wc -l)
echo "   Total: ${TOTAL} archivos"

if [[ ${TOTAL} -lt 10 ]]; then
    echo "ERROR: Extracción incompleta"
    exit 1
fi

# Copiar ciliumconfig personalizado si existe
if [[ -f "${CLIFE_TMP_DIR}/ciliumconfig.yaml" ]]; then
    cp "${CLIFE_TMP_DIR}/ciliumconfig.yaml" "${EXTRACT_DIR}/ciliumconfig.yaml"
    echo "   ✓ ciliumconfig.yaml personalizado copiado"
fi

# Generar ConfigMap
echo ""
echo "2. Generando ConfigMap..."

cat > "${CONFIGMAP_FILE}" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${CLUSTER_NAME}-clife-manifests
  namespace: ${ACM_NAMESPACE}
data:
EOF

INCLUDED=0
EXCLUDED=0
EXCLUDED_FILES=("subscription.yaml" "operatorgroup.yaml")

for file in "${EXTRACT_DIR}"/*.yaml; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        
        SKIP=false
        for excl in "${EXCLUDED_FILES[@]}"; do
            if [[ "$filename" == "$excl" ]]; then
                SKIP=true
                echo "   ⊘ Excluyendo: ${filename} (requiere OLM)"
                ((EXCLUDED++))
                break
            fi
        done
        
        if [[ "$SKIP" == "false" ]]; then
            echo "   + Incluyendo: ${filename}"
            echo "  ${filename}: |" >> "${CONFIGMAP_FILE}"
            sed 's/^/    /' "$file" >> "${CONFIGMAP_FILE}"
            ((INCLUDED++))
        fi
    fi
done

echo ""
echo "   ConfigMap generado: ${INCLUDED} archivos incluidos, ${EXCLUDED} excluidos"

# Mostrar resumen
echo ""
echo "3. Verificando ConfigMap generado..."
echo "   Claves en el ConfigMap:"
grep "^  [a-z].*: |$" "${CONFIGMAP_FILE}" | sed 's/: |$//' | while read key; do
    echo "     - ${key}"
done

# Aplicar
echo ""
echo "============================================="
echo "  APLICAR CAMBIOS"
echo "============================================="
echo ""
echo "Para aplicar el ConfigMap corregido:"
echo ""
echo "  kubectl apply -f ${CONFIGMAP_FILE}"
echo ""
echo "Luego, eliminar el ClusterDeployment para que Hive lo re-provisione:"
echo ""
echo "  kubectl delete clusterdeployment ${CLUSTER_NAME} -n ${ACM_NAMESPACE}"
echo "  kubectl apply -f ${MANIFESTS_DIR}/acm/10-clusterdeployment.yaml"
echo ""
echo "O si prefieres aplicar directamente ahora:"
read -p "¿Aplicar ConfigMap ahora? (y/N): " APPLY

if [[ "${APPLY}" =~ ^[Yy]$ ]]; then
    kubectl apply -f "${CONFIGMAP_FILE}"
    echo ""
    echo "✓ ConfigMap aplicado"
    echo ""
    echo "IMPORTANTE: El ClusterDeployment existente NO usará el nuevo ConfigMap."
    echo "Debes eliminar y recrear el ClusterDeployment para que tome efecto."
fi

# Cleanup
rm -rf "${EXTRACT_DIR}"
echo ""
echo "ConfigMap guardado en: ${CONFIGMAP_FILE}"
