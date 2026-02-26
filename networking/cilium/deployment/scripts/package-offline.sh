#!/bin/bash
# =============================================================================
# Crea un paquete tar.gz con todo lo necesario para instalación offline
# Uso: ./package-offline.sh [nombre-archivo]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Nombre del paquete
PACKAGE_NAME="${1:-cilium-deployment-offline-$(date +%Y%m%d)}"
PACKAGE_FILE="${PACKAGE_NAME}.tar.gz"

echo -e "${CYAN}=== Creando paquete offline ===${NC}"
echo ""

# Verificar que existan los artifacts
if [[ ! -d "${BASE_DIR}/artifacts" ]]; then
    echo -e "${YELLOW}WARN: No existe carpeta artifacts/${NC}"
    echo "Ejecutar primero: ./00_download_artifacts.sh"
    echo ""
    read -p "¿Continuar sin artifacts? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Crear paquete
cd "${BASE_DIR}"

echo "Incluyendo:"
echo "  - scripts/"
echo "  - clusters/"
echo "  - docs/"
echo "  - artifacts/ (si existe)"
echo "  - README.md"
echo ""

# Lista de archivos a incluir
INCLUDE_FILES=(
    "scripts"
    "clusters"
    "docs"
    "README.md"
)

# Agregar artifacts si existe
if [[ -d "artifacts" ]]; then
    INCLUDE_FILES+=("artifacts")
fi

# Crear el paquete
tar -czvf "${PACKAGE_FILE}" "${INCLUDE_FILES[@]}"

# Mostrar resultado
echo ""
echo -e "${GREEN}=== Paquete creado ===${NC}"
echo ""
ls -lh "${PACKAGE_FILE}"
echo ""
echo "Contenido del paquete:"
tar -tzvf "${PACKAGE_FILE}" | head -30
echo "..."
echo ""

# Calcular checksum
sha256sum "${PACKAGE_FILE}" > "${PACKAGE_FILE}.sha256"
echo "Checksum: ${PACKAGE_FILE}.sha256"
echo ""

echo -e "${GREEN}Para transferir al servidor destino:${NC}"
echo "  scp ${PACKAGE_FILE} user@servidor:/path/"
echo ""
echo -e "${GREEN}En el servidor destino:${NC}"
echo "  tar -xzvf ${PACKAGE_FILE}"
echo "  cd $(basename ${BASE_DIR})"
echo "  sudo ./artifacts/install-tools.sh  # Instalar herramientas CLI"
echo "  cd scripts"
echo "  ./deploy.sh <cluster-name>"
