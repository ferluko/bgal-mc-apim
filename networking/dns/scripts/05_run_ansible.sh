#!/usr/bin/env bash
# =============================================================================
# Paso 5 — Invocar Ansible (discovery o configuración F5)
# Orquestado por deploy.sh; usa inventario generado por 04_generate_inventory.sh.
# Uso: ./05_run_ansible.sh [discovery|config-f5] [opciones para ansible-playbook]
#      Ejemplo: ./05_run_ansible.sh discovery
#               ./05_run_ansible.sh config-f5 --limit f5_ltm
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

ACTION="${1:-discovery}"
shift || true

# Inventario: el generado en output o el estático de ansible/
if [[ -f "$LATEST_INVENTORY" ]]; then
  INVENTORY="$LATEST_INVENTORY"
elif [[ -f "${OUTPUT_DIR}/inventory.yml" ]]; then
  INVENTORY="${OUTPUT_DIR}/inventory.yml"
else
  INVENTORY="${ANSIBLE_DIR}/inventory.yml"
  if [[ ! -f "$INVENTORY" ]]; then
    echo "ERROR: No hay inventario. Ejecutar antes: ./04_generate_inventory.sh o deploy.sh discovery"
    exit 1
  fi
fi

EXTRA_VARS=""
if [[ -f "${ANSIBLE_DIR}/group_vars/all.yml" ]]; then
  EXTRA_VARS="-e @${ANSIBLE_DIR}/group_vars/all.yml"
fi

case "$ACTION" in
  discovery)
    PLAYBOOK="${ANSIBLE_DIR}/playbook-discovery.yml"
    if [[ ! -f "$PLAYBOOK" ]]; then
      echo "ERROR: No encontrado $PLAYBOOK"
      exit 1
    fi
    echo "=== Ansible: discovery (inventario=$INVENTORY) ==="
    ansible-playbook -i "$INVENTORY" $EXTRA_VARS "$PLAYBOOK" "$@"
    ;;
  config-f5)
    PLAYBOOK="${ANSIBLE_DIR}/playbook-config-f5.yml"
    if [[ ! -f "$PLAYBOOK" ]]; then
      echo "ERROR: No encontrado $PLAYBOOK. Crear playbook-config-f5.yml para configuración F5."
      exit 1
    fi
    echo "=== Ansible: config-f5 (inventario=$INVENTORY) ==="
    ansible-playbook -i "$INVENTORY" $EXTRA_VARS "$PLAYBOOK" "$@"
    ;;
  *)
    echo "Uso: $0 discovery|config-f5 [opciones ansible-playbook]"
    echo "  discovery   — playbook-discovery.yml (solo lectura)"
    echo "  config-f5  — playbook-config-f5.yml (aplicar configuración F5)"
    exit 1
    ;;
esac
echo "=== Fin 05_run_ansible ==="
