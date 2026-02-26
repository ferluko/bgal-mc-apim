#!/bin/bash
# =============================================================================
# Descarga todos los artefactos necesarios para instalación offline
# Ejecutar desde una máquina con acceso a internet
# Uso: ./00_download_artifacts.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="${BASE_DIR}/artifacts"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Descargando artefactos para instalación offline ===${NC}"
echo ""

# Crear estructura de directorios
mkdir -p "${ARTIFACTS_DIR}"/{clife,tools,images}

# -----------------------------------------------------------------------------
# 1. CLife (Cilium Lifecycle Operator)
# -----------------------------------------------------------------------------
echo -e "${CYAN}[1/4] Descargando CLife...${NC}"

CLIFE_VERSION="1.18.6"
CLIFE_BASE_URL="https://docs.isovalent.com/v25.11/public/clife"

cd "${ARTIFACTS_DIR}/clife"

if [[ ! -f "clife-v${CLIFE_VERSION}.tar.gz" ]]; then
    curl -fSL -o "clife-v${CLIFE_VERSION}.tar.gz" "${CLIFE_BASE_URL}/clife-v${CLIFE_VERSION}.tar.gz"
    curl -fSL -o "clife-v${CLIFE_VERSION}.tar.gz.sha256" "${CLIFE_BASE_URL}/clife-v${CLIFE_VERSION}.tar.gz.sha256"
    
    if sha256sum -c "clife-v${CLIFE_VERSION}.tar.gz.sha256"; then
        echo -e "${GREEN}✓ CLife v${CLIFE_VERSION} descargado${NC}"
    else
        echo -e "${RED}✗ Error en checksum de CLife${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ CLife v${CLIFE_VERSION} ya existe${NC}"
fi

# -----------------------------------------------------------------------------
# 2. Herramientas CLI
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[2/4] Descargando herramientas CLI...${NC}"

cd "${ARTIFACTS_DIR}/tools"

# yq (para manipular YAML)
YQ_VERSION="4.40.5"
if [[ ! -f "yq_linux_amd64" ]]; then
    echo "Descargando yq v${YQ_VERSION}..."
    curl -fSL -o "yq_linux_amd64" "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64"
    curl -fSL -o "yq_linux_amd64.sha256" "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/checksums_hashes_order" 
    chmod +x yq_linux_amd64
    echo -e "${GREEN}✓ yq v${YQ_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ yq ya existe${NC}"
fi

# jq (para manipular JSON)
JQ_VERSION="1.7.1"
if [[ ! -f "jq-linux-amd64" ]]; then
    echo "Descargando jq v${JQ_VERSION}..."
    curl -fSL -o "jq-linux-amd64" "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64"
    chmod +x jq-linux-amd64
    echo -e "${GREEN}✓ jq v${JQ_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ jq ya existe${NC}"
fi

# cilium CLI
CILIUM_CLI_VERSION="0.16.4"
if [[ ! -f "cilium-linux-amd64.tar.gz" ]]; then
    echo "Descargando cilium CLI v${CILIUM_CLI_VERSION}..."
    curl -fSL -o "cilium-linux-amd64.tar.gz" "https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz"
    curl -fSL -o "cilium-linux-amd64.tar.gz.sha256sum" "https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz.sha256sum"
    echo -e "${GREEN}✓ cilium CLI v${CILIUM_CLI_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ cilium CLI ya existe${NC}"
fi

# hubble CLI
HUBBLE_VERSION="0.13.0"
if [[ ! -f "hubble-linux-amd64.tar.gz" ]]; then
    echo "Descargando hubble CLI v${HUBBLE_VERSION}..."
    curl -fSL -o "hubble-linux-amd64.tar.gz" "https://github.com/cilium/hubble/releases/download/v${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz"
    curl -fSL -o "hubble-linux-amd64.tar.gz.sha256sum" "https://github.com/cilium/hubble/releases/download/v${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz.sha256sum"
    echo -e "${GREEN}✓ hubble CLI v${HUBBLE_VERSION} descargado${NC}"
else
    echo -e "${GREEN}✓ hubble CLI ya existe${NC}"
fi

# -----------------------------------------------------------------------------
# 3. Imágenes de test (opcionales)
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[3/4] Preparando lista de imágenes...${NC}"

cat > "${ARTIFACTS_DIR}/images/images-list.txt" << 'EOF'
# Imágenes necesarias para connectivity tests
# Usar skopeo o docker para descargar y subir a registry interno

# Test images
docker.io/library/busybox:1.36
docker.io/library/nginx:alpine

# Cilium images (si no están en el registry interno)
# Verificar versiones en el CiliumConfig generado
quay.io/isovalent/cilium:v1.18.6
quay.io/isovalent/operator:v1.18.6
quay.io/isovalent/hubble-relay:v1.18.6
quay.io/isovalent/hubble-ui:v1.18.6
quay.io/isovalent/hubble-ui-backend:v1.18.6
EOF

echo -e "${GREEN}✓ Lista de imágenes creada en artifacts/images/images-list.txt${NC}"

# -----------------------------------------------------------------------------
# 4. Crear script de instalación de herramientas
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}[4/4] Creando scripts de instalación...${NC}"

cat > "${ARTIFACTS_DIR}/install-tools.sh" << 'EOF'
#!/bin/bash
# Instala las herramientas CLI en /usr/local/bin
# Ejecutar como root o con sudo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
INSTALL_DIR="/usr/local/bin"

echo "Instalando herramientas en ${INSTALL_DIR}..."

# yq
if [[ -f "${TOOLS_DIR}/yq_linux_amd64" ]]; then
    cp "${TOOLS_DIR}/yq_linux_amd64" "${INSTALL_DIR}/yq"
    chmod +x "${INSTALL_DIR}/yq"
    echo "✓ yq instalado"
fi

# jq
if [[ -f "${TOOLS_DIR}/jq-linux-amd64" ]]; then
    cp "${TOOLS_DIR}/jq-linux-amd64" "${INSTALL_DIR}/jq"
    chmod +x "${INSTALL_DIR}/jq"
    echo "✓ jq instalado"
fi

# cilium
if [[ -f "${TOOLS_DIR}/cilium-linux-amd64.tar.gz" ]]; then
    tar -xzf "${TOOLS_DIR}/cilium-linux-amd64.tar.gz" -C "${INSTALL_DIR}" cilium
    chmod +x "${INSTALL_DIR}/cilium"
    echo "✓ cilium instalado"
fi

# hubble
if [[ -f "${TOOLS_DIR}/hubble-linux-amd64.tar.gz" ]]; then
    tar -xzf "${TOOLS_DIR}/hubble-linux-amd64.tar.gz" -C "${INSTALL_DIR}" hubble
    chmod +x "${INSTALL_DIR}/hubble"
    echo "✓ hubble instalado"
fi

echo ""
echo "Verificando instalación:"
echo "  yq version: $(yq --version 2>/dev/null || echo 'no instalado')"
echo "  jq version: $(jq --version 2>/dev/null || echo 'no instalado')"
echo "  cilium version: $(cilium version --client 2>/dev/null || echo 'no instalado')"
echo "  hubble version: $(hubble version 2>/dev/null || echo 'no instalado')"
EOF

chmod +x "${ARTIFACTS_DIR}/install-tools.sh"

# -----------------------------------------------------------------------------
# 5. Crear archivo de versiones
# -----------------------------------------------------------------------------
cat > "${ARTIFACTS_DIR}/versions.txt" << EOF
# Versiones de artefactos descargados
# Fecha: $(date -Iseconds)

CLife (Cilium Lifecycle Operator): ${CLIFE_VERSION}
yq: ${YQ_VERSION}
jq: ${JQ_VERSION}
cilium CLI: ${CILIUM_CLI_VERSION}
hubble CLI: ${HUBBLE_VERSION}

# URLs de descarga
CLife: ${CLIFE_BASE_URL}/clife-v${CLIFE_VERSION}.tar.gz
yq: https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64
jq: https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64
cilium: https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
hubble: https://github.com/cilium/hubble/releases/download/v${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz
EOF

# -----------------------------------------------------------------------------
# Resumen
# -----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}=== Descarga completada ===${NC}"
echo ""
echo "Artefactos descargados en: ${ARTIFACTS_DIR}"
echo ""
ls -la "${ARTIFACTS_DIR}"
echo ""
echo "Contenido:"
du -sh "${ARTIFACTS_DIR}"/*
echo ""
echo -e "${GREEN}Para crear paquete offline:${NC}"
echo "  cd $(dirname ${ARTIFACTS_DIR})"
echo "  tar -czvf cilium-deployment-offline.tar.gz artifacts/ clusters/ scripts/ docs/ README.md"
echo ""
echo -e "${GREEN}Para transferir al servidor sin internet:${NC}"
echo "  scp cilium-deployment-offline.tar.gz user@servidor:/path/"
echo ""
echo -e "${GREEN}En el servidor destino:${NC}"
echo "  tar -xzvf cilium-deployment-offline.tar.gz"
echo "  sudo ./artifacts/install-tools.sh"
echo "  cd scripts && ./deploy.sh <cluster-name>"
