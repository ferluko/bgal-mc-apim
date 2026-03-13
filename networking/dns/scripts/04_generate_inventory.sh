#!/usr/bin/env bash
# =============================================================================
# Paso 4 — Generar inventario Ansible desde discovery
# Escribe OUTPUT_DIR/inventory.yml para uso por 05_run_ansible.sh.
# Opcional: incorporar IPs descubiertas si existen en output (parsing básico).
# Uso: desde deploy.sh o ./04_generate_inventory.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
mkdir -p "$OUTPUT_DIR"

TS=$(date +%Y%m%d-%H%M%S)
INVENTORY="${OUTPUT_DIR}/inventory.yml"

# Variables F5 (desde env o group_vars); se pasan a Ansible como extra vars si existen
F5_LTM_ARQLAB_IP="${F5_LTM_ARQLAB_IP:-10.0.0.1}"
F5_LTM_SREPG_IP="${F5_LTM_SREPG_IP:-10.0.0.2}"
F5_GTM_IP="${F5_GTM_IP:-10.0.0.0}"

# VIPs conocidos del repo (env.sh de cada cluster)
API_ARQLAB="10.254.124.35"
INGRESS_ARQLAB="10.254.124.36"
API_SREPG="10.254.124.10"
INGRESS_SREPG="10.254.124.11"

cat > "$INVENTORY" << EOF
# Inventario generado por 04_generate_inventory.sh ($TS)
# Usado por deploy.sh config-f5 -> 05_run_ansible.sh
# Completar group_vars/all.yml con credenciales F5 (f5_user, f5_password).

all:
  children:
    clusters:
      hosts:
        paas_arqlab:
          ansible_host: api.paas-arqlab.${BASE_DOMAIN}
          cluster_name: paas-arqlab
          api_vip: ${API_ARQLAB}
          ingress_vip: ${INGRESS_ARQLAB}
          base_domain: ${BASE_DOMAIN}
        paas_srepg:
          ansible_host: api.paas-srepg.${BASE_DOMAIN}
          cluster_name: paas-srepg
          api_vip: ${API_SREPG}
          ingress_vip: ${INGRESS_SREPG}
          base_domain: ${BASE_DOMAIN}
      vars:
        ansible_connection: local

    f5_ltm:
      hosts:
        f5_ltm_arqlab:
          f5_host: ${F5_LTM_ARQLAB_IP}
          f5_partition: Common
          cluster_ref: paas-arqlab
        f5_ltm_srepg:
          f5_host: ${F5_LTM_SREPG_IP}
          f5_partition: Common
          cluster_ref: paas-srepg
      vars:
        ansible_connection: local

    f5_gtm:
      hosts:
        f5_gtm_global:
          f5_host: ${F5_GTM_IP}
      vars:
        ansible_connection: local
EOF

export LATEST_INVENTORY="$INVENTORY"
echo "Inventario: $INVENTORY"
echo "=== Fin 04_generate_inventory ==="
