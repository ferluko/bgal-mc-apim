#!/bin/bash
# =============================================================================
# FIX DIRECTO: Regenerar ConfigMap de CLife
# 
# Este script genera el ConfigMap directamente sin depender de 00_env.sh
# =============================================================================
set -euo pipefail

CLUSTER_NAME="${1:-paas-arqlab}"
NAMESPACE="${CLUSTER_NAME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIFE_TARBALL="${SCRIPT_DIR}/../artifacts/clife/clife-v1.18.6.tar.gz"
EXTRACT_DIR="${SCRIPT_DIR}/../clusters/${CLUSTER_NAME}/manifests/clife-extracted"
OUTPUT_FILE="${SCRIPT_DIR}/../clusters/${CLUSTER_NAME}/manifests/acm/06-clife-manifests-configmap.yaml"

# También buscar ciliumconfig personalizado
CILIUMCONFIG_CUSTOM="${SCRIPT_DIR}/../clusters/${CLUSTER_NAME}/clife-tmp/ciliumconfig.yaml"

echo "============================================="
echo "  FIX DIRECTO: ConfigMap CLife"
echo "============================================="
echo ""
echo "Cluster:     ${CLUSTER_NAME}"
echo "Tarball:     ${CLIFE_TARBALL}"
echo "Extract dir: ${EXTRACT_DIR}"
echo "Output:      ${OUTPUT_FILE}"
echo ""

# Verificar tarball
if [[ ! -f "${CLIFE_TARBALL}" ]]; then
    echo "ERROR: No existe ${CLIFE_TARBALL}"
    exit 1
fi

# Limpiar y extraer
echo "1. Extrayendo tarball..."
rm -rf "${EXTRACT_DIR}"
mkdir -p "${EXTRACT_DIR}"
tar -xzf "${CLIFE_TARBALL}" -C "${EXTRACT_DIR}"

echo "   Contenido extraído:"
ls -1 "${EXTRACT_DIR}"

YAML_COUNT=$(ls -1 "${EXTRACT_DIR}"/*.yaml 2>/dev/null | wc -l)
echo ""
echo "   Total archivos YAML: ${YAML_COUNT}"

if [[ ${YAML_COUNT} -lt 10 ]]; then
    echo "ERROR: Extracción incompleta"
    exit 1
fi

# Copiar ciliumconfig personalizado si existe
if [[ -f "${CILIUMCONFIG_CUSTOM}" ]]; then
    echo ""
    echo "2. Copiando ciliumconfig.yaml personalizado..."
    cp "${CILIUMCONFIG_CUSTOM}" "${EXTRACT_DIR}/ciliumconfig.yaml"
fi

# Generar ConfigMap
echo ""
echo "3. Generando ConfigMap..."

# Crear directorio de salida si no existe
mkdir -p "$(dirname "${OUTPUT_FILE}")"

# Header del ConfigMap
cat > "${OUTPUT_FILE}" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${CLUSTER_NAME}-clife-manifests
  namespace: ${NAMESPACE}
data:
EOF

# Archivos a excluir (requieren OLM)
EXCLUDED=("subscription.yaml" "operatorgroup.yaml")

INCLUDED_COUNT=0
EXCLUDED_COUNT=0

# Procesar cada archivo YAML
for file in "${EXTRACT_DIR}"/*.yaml; do
    if [[ ! -f "$file" ]]; then
        continue
    fi
    
    filename=$(basename "$file")
    
    # Verificar si está excluido
    SKIP=false
    for excl in "${EXCLUDED[@]}"; do
        if [[ "$filename" == "$excl" ]]; then
            SKIP=true
            echo "   ⊘ Excluido: ${filename}"
            ((EXCLUDED_COUNT++))
            break
        fi
    done
    
    if [[ "$SKIP" == "false" ]]; then
        echo "   + Incluido: ${filename}"
        
        # Agregar al ConfigMap con indentación correcta
        echo "  ${filename}: |" >> "${OUTPUT_FILE}"
        sed 's/^/    /' "$file" >> "${OUTPUT_FILE}"
        
        ((INCLUDED_COUNT++))
    fi
done

echo ""
echo "============================================="
echo "  RESULTADO"
echo "============================================="
echo ""
echo "Archivos incluidos: ${INCLUDED_COUNT}"
echo "Archivos excluidos: ${EXCLUDED_COUNT}"
echo ""
echo "ConfigMap generado: ${OUTPUT_FILE}"
echo "Tamaño: $(wc -c < "${OUTPUT_FILE}") bytes"
echo ""

# Verificar contenido
echo "Claves en el ConfigMap:"
grep "^  [a-zA-Z].*: |$" "${OUTPUT_FILE}" | sed 's/: |$//' | sed 's/^  /   - /'

echo ""
echo "============================================="
echo "  SIGUIENTE PASO"
echo "============================================="
echo ""
echo "Aplicar el ConfigMap:"
echo "  oc apply -f ${OUTPUT_FILE}"
echo ""
echo "Verificar:"
echo "  oc get configmap ${CLUSTER_NAME}-clife-manifests -n ${NAMESPACE} -o jsonpath='{.data}' | jq -r 'keys[]'"
echo ""
