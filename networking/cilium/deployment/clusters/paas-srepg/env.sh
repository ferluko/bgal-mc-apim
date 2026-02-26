#!/bin/bash
# =============================================================================
# Configuración del cluster: paas-srepg
# =============================================================================

# --- Identificación del cluster ---
export CLUSTER_NAME="paas-srepg"
export CLUSTER_ID="2"                          # Único 1-255 para Cluster Mesh
export BASE_DOMAIN="bancogalicia.com.ar"

# --- Networking (ver docs/00_subnetting_plan.md) ---
export POD_CIDR="10.128.64.0/18"               # Subred 2/16 del /14
export HOST_PREFIX="24"                         # 256 IPs por nodo
export SERVICE_CIDR="172.30.0.0/16"
export MACHINE_CIDR="10.254.120.0/21"

# --- VIPs ---
export API_VIP="10.254.124.10"
export INGRESS_VIP="10.254.124.11"

# --- vSphere ---
export VSPHERE_SERVER="vcenterocp.bancogalicia.com.ar"
export VSPHERE_DATACENTER="cpd intersite"
export VSPHERE_CLUSTER="/cpd intersite/host/ocp - lan - cluster"
export VSPHERE_DATASTORE="/cpd intersite/datastore/9500/paas-sre/ocp/vm9500-ocp-paas-sre-lun080"
export VSPHERE_NETWORK="dvPG-VMNET-VLAN145"
export VSPHERE_RESOURCE_POOL="/cpd intersite/host/ocp - lan - cluster/Resources"
export VSPHERE_USER="uoscp11m@bgcmz.bancogalicia.com.ar"

# --- Hosts (IPs estáticas) ---
export HOST_GATEWAY="10.254.123.254"
export HOST_NAMESERVERS="10.0.52.1,10.0.53.1"
export HOST_BOOTSTRAP_IP="10.254.123.10"
export HOST_MASTER_IPS="10.254.123.11,10.254.123.12,10.254.123.13"
export HOST_WORKER_IPS="10.254.123.20,10.254.123.21,10.254.123.22"

# --- Recursos de nodos ---
export MASTER_CPUS="8"
export MASTER_MEMORY_MB="32768"
export MASTER_DISK_GB="120"
export WORKER_CPUS="8"
export WORKER_MEMORY_MB="32768"
export WORKER_DISK_GB="120"
