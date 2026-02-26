#!/bin/bash
# =============================================================================
# Configuración del cluster: paas-arqlab
# =============================================================================

# --- Identificación del cluster ---
export CLUSTER_NAME="paas-arqlab"
export CLUSTER_ID="1"                          # Único 1-255 para Cluster Mesh
export BASE_DOMAIN="bancogalicia.com.ar"

# --- Networking (ver docs/00_subnetting_plan.md) ---
export POD_CIDR="10.128.0.0/18"                # Subred 1/16 del /14
export HOST_PREFIX="24"                         # 256 IPs por nodo
export SERVICE_CIDR="172.30.0.0/16"
export MACHINE_CIDR="10.254.120.0/21"

# --- VIPs ---
export API_VIP="10.254.124.35"
export INGRESS_VIP="10.254.124.36"

# --- vSphere ---
export VSPHERE_SERVER="vcenterocp.bancogalicia.com.ar"
export VSPHERE_DATACENTER="cpd intersite"
export VSPHERE_CLUSTER="/cpd intersite/host/ocp - lan - cluster"
export VSPHERE_DATASTORE="/cpd intersite/datastore/9500/paas-arqlab/infra/vm9500-ocp-paas-arqlab_lun040"
export VSPHERE_NETWORK="dvPG-VMNET-VLAN140"
export VSPHERE_RESOURCE_POOL="/cpd intersite/host/ocp - lan - cluster/Resources"
export VSPHERE_USER="uoscp11m@bgcmz.bancogalicia.com.ar"

# --- Hosts (IPs estáticas) ---
export HOST_GATEWAY="10.254.28.254"
export HOST_NAMESERVERS="10.0.52.1,10.0.53.1"
export HOST_BOOTSTRAP_IP="10.254.28.10"
export HOST_MASTER_IPS="10.254.28.11,10.254.28.12,10.254.28.13"
export HOST_WORKER_IPS="10.254.28.20,10.254.28.21,10.254.28.22"

# --- Recursos de nodos ---
export MASTER_CPUS="8"
export MASTER_MEMORY_MB="32768"
export MASTER_DISK_GB="120"
export WORKER_CPUS="8"
export WORKER_MEMORY_MB="32768"
export WORKER_DISK_GB="120"
