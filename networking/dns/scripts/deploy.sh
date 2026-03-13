#!/usr/bin/env bash
# =============================================================================
# Script principal: orquesta discovery y configuración F5/DNS (estilo cilium/deployment/scripts).
# Bash orquesta; Ansible se invoca solo en el paso de configuración F5.
# Uso:
#   ./deploy.sh discovery              # 01 repo + 02 clusters + 03 F5 + 04 inventario
#   ./deploy.sh discovery --skip-f5    # sin discovery F5 (si no hay F5_HOST)
#   ./deploy.sh config-f5              # invoca ansible-playbook (playbook-config-f5.yml)
#   ./deploy.sh config-f5 --limit f5_ltm
#   ./deploy.sh discovery --skip-repo --skip-clusters  # solo 03 + 04
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
  echo -e "${CYAN}=============================================${NC}"
  echo -e "${CYAN} $1${NC}"
  echo -e "${CYAN}=============================================${NC}"
}

print_usage() {
  echo "Uso: $0 <comando> [opciones]"
  echo ""
  echo "Comandos:"
  echo "  discovery   Ejecuta discovery completo: repo, clusters, F5, genera inventario (pasos 01–04)."
  echo "  config-f5   Invoca Ansible para configuración F5 (paso 05). Requiere inventario (ej. discovery previo)."
  echo ""
  echo "Opciones para discovery:"
  echo "  --skip-repo      Omitir paso 01 (barrido repo)."
  echo "  --skip-clusters  Omitir paso 02 (discovery clusters OpenShift)."
  echo "  --skip-f5        Omitir paso 03 (discovery F5). Útil si F5_HOST no está definido."
  echo ""
  echo "Opciones para config-f5:"
  echo "  Cualquier opción de ansible-playbook (--limit, -e, etc.) tras config-f5."
  echo ""
  echo "Variables de entorno (discovery):"
  echo "  CLUSTERS, BASE_DOMAIN, REPO_ROOT, OUTPUT_DIR"
  echo "  F5_HOST, F5_USER, F5_PASSWORD  (paso 03)"
  echo "  KUBECONFIG  (paso 02, sesión oc por cluster)"
  echo ""
  echo "Variables (inventario, paso 04):"
  echo "  F5_LTM_ARQLAB_IP, F5_LTM_SREPG_IP, F5_GTM_IP"
  echo ""
  echo "Ejemplos:"
  echo "  $0 discovery"
  echo "  $0 discovery --skip-f5"
  echo "  F5_HOST=10.0.0.1 F5_USER=admin F5_PASSWORD=xxx $0 discovery"
  echo "  $0 config-f5"
  echo "  $0 config-f5 --limit f5_ltm_arqlab"
}

CMD="${1:-}"
shift || true
SKIP_REPO=""
SKIP_CLUSTERS=""
SKIP_F5=""

# Parsear opciones según comando
if [[ "$CMD" == "discovery" ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-repo)     SKIP_REPO="1"; shift ;;
      --skip-clusters) SKIP_CLUSTERS="1"; shift ;;
      --skip-f5)       SKIP_F5="1"; shift ;;
      *) echo "Opción desconocida: $1"; print_usage; exit 1 ;;
    esac
  done
fi

case "$CMD" in
  discovery)
    print_header "Discovery — repo, clusters, F5, inventario"
    mkdir -p "$OUTPUT_DIR"

    if [[ -z "$SKIP_REPO" ]]; then
      print_header "Paso 1/4: Discovery repo"
      "${SCRIPT_DIR}/01_discover_repo.sh" || true
    else
      echo -e "${YELLOW}Omitiendo paso 1 (repo)${NC}"
    fi

    if [[ -z "$SKIP_CLUSTERS" ]]; then
      print_header "Paso 2/4: Discovery clusters OpenShift"
      "${SCRIPT_DIR}/02_discover_clusters.sh" || true
    else
      echo -e "${YELLOW}Omitiendo paso 2 (clusters)${NC}"
    fi

    if [[ -z "$SKIP_F5" ]]; then
      print_header "Paso 3/4: Discovery F5 LTM/GTM"
      "${SCRIPT_DIR}/03_discover_f5.sh" || true
    else
      echo -e "${YELLOW}Omitiendo paso 3 (F5)${NC}"
    fi

    print_header "Paso 4/4: Generar inventario Ansible"
    "${SCRIPT_DIR}/04_generate_inventory.sh"

    echo ""
    echo -e "${GREEN}✓ Discovery completado. Inventario: $LATEST_INVENTORY${NC}"
    echo "  Para configurar F5: $0 config-f5"
    ;;
  config-f5)
    print_header "Configuración F5 vía Ansible"
    "${SCRIPT_DIR}/05_run_ansible.sh" config-f5 "$@"
    echo -e "${GREEN}✓ Ansible config-f5 finalizado${NC}"
    ;;
  *)
    if [[ -z "$CMD" ]] || [[ "$CMD" == "--help" ]] || [[ "$CMD" == "-h" ]]; then
      print_usage
      exit 0
    fi
    echo "ERROR: Comando desconocido: $CMD"
    print_usage
    exit 1
    ;;
esac
