#!/bin/bash
# Instala las herramientas CLI en /usr/local/bin
# Ejecutar como root o con sudo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
INSTALL_DIR="/usr/local/bin"

echo "Instalando herramientas en ${INSTALL_DIR}..."

# yq (comprimido con gzip)
if [[ -f "${TOOLS_DIR}/yq_linux_amd64.gz" ]]; then
    gunzip -c "${TOOLS_DIR}/yq_linux_amd64.gz" > "${INSTALL_DIR}/yq"
    chmod +x "${INSTALL_DIR}/yq"
    echo "✓ yq instalado"
elif [[ -f "${TOOLS_DIR}/yq_linux_amd64" ]]; then
    cp "${TOOLS_DIR}/yq_linux_amd64" "${INSTALL_DIR}/yq"
    chmod +x "${INSTALL_DIR}/yq"
    echo "✓ yq instalado"
fi

# jq (comprimido con gzip)
if [[ -f "${TOOLS_DIR}/jq-linux-amd64.gz" ]]; then
    gunzip -c "${TOOLS_DIR}/jq-linux-amd64.gz" > "${INSTALL_DIR}/jq"
    chmod +x "${INSTALL_DIR}/jq"
    echo "✓ jq instalado"
elif [[ -f "${TOOLS_DIR}/jq-linux-amd64" ]]; then
    cp "${TOOLS_DIR}/jq-linux-amd64" "${INSTALL_DIR}/jq"
    chmod +x "${INSTALL_DIR}/jq"
    echo "✓ jq instalado"
fi

# cilium (ya viene como tar.gz)
if [[ -f "${TOOLS_DIR}/cilium-linux-amd64.tar.gz" ]]; then
    tar -xzf "${TOOLS_DIR}/cilium-linux-amd64.tar.gz" -C "${INSTALL_DIR}" cilium
    chmod +x "${INSTALL_DIR}/cilium"
    echo "✓ cilium instalado"
fi

# hubble (ya viene como tar.gz)
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
