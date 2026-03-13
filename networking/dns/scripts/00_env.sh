# =============================================================================
# Configuración global para scripts de discovery y configuración F5/DNS
# No requiere CLUSTER_NAME (se usa para discovery multi-cluster y luego Ansible).
# Cargar con: source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"
# O desde deploy.sh, que ya exporta todo.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
OUTPUT_DIR="${OUTPUT_DIR:-$BASE_DIR/output}"
ANSIBLE_DIR="${ANSIBLE_DIR:-$BASE_DIR/ansible}"

# Clusters del lab (srepg, arqlab)
CLUSTERS="${CLUSTERS:-paas-arqlab paas-srepg}"
BASE_DOMAIN="${BASE_DOMAIN:-bancogalicia.com.ar}"

# Inventario generado por 04_generate_inventory.sh (deploy.sh discovery)
LATEST_INVENTORY="${LATEST_INVENTORY:-$OUTPUT_DIR/inventory.yml}"

export SCRIPT_DIR BASE_DIR REPO_ROOT OUTPUT_DIR ANSIBLE_DIR
export CLUSTERS BASE_DOMAIN LATEST_INVENTORY
