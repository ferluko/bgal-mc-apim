#Granola

## Estrategia Multi-Cluster

**7 clusters de producción planificados**:
- **Especificaciones estándar**: 64GB RAM, 32 cores por nodo
- **Configuración por cluster**: 3 masters + 3 nodos infra + 3 nodos login + 3 workers dedicados
- **Versión objetivo**: OpenShift 4.20.12

## Nueva Topología de Clusters

### 1. **Cluster ACM Dedicado**
- Configuración 3+3+3 (master, infra, worker)
- Sin OpenShift Data Foundation (ODF) inicialmente
- Uso de CSI driver de VMware para persistencia
- **Propósito**: Orquestación pura de clusters, sin aplicaciones

### 2. **Cluster de Servicios Centralizados**
- **Servicios consolidados**:
  - ODF centralizado para proveer buckets y PVs a otros clusters
  - Observabilidad (Prometheus, Grafana)
  - HashiCorp Vault corporativo
  - Herramientas DevOps y APIs
- **Beneficio**: Separación clara entre infraestructura y aplicaciones de negocio

### 3. **Clusters Aplicativos**
- **2 clusters para servicios** (uno por site)
- **5 clusters aplicativos** restantes
- Especializados por dominio/funcional

## Mejoras de Storage y Networking

### Storage Consolidado
- **Problema actual**: Múltiples ODF individuales con alto costo operativo
- **Solución propuesta**: 
  - Cluster dedicado ODF sirviendo a múltiples clusters aplicativos
  - Consumo directo desde cajón de discos usando CSI driver
  - Eliminación de storage compartido que afecta rendimiento

### Service Mesh Integration
- **Arquitectura de tres capas**:
  1. **Capa DMZ/Legacy/Mainframe**
  2. **Capa API Gateway dedicado** - Rate limits, autenticación externa
  3. **Capa Service Mesh** - Comunicación interna service-to-service, MTLS, observabilidad

## Automatización e Infraestructura

### Automatización F5
- Playbooks Ansible para creación automática de virtual servers
- Monitores health check capa 7 (HTTP/HTTPS)
- Integración con Terraform Cloud para despliegue end-to-end

### Networking y Conectividad
- Nueva IP de salida al exterior para clusters nuevos
- Reglas de egress por microservicio/namespace
- Plan de contingencia con gateway anterior como backup

## Observabilidad y Service Mesh

### Ambient Mesh (Istio)
- **Casos de uso prioritarios**:
  - Authorization policies globales
  - Service discovery global entre clusters
  - Observabilidad completa con eBPF
  - Análisis de patrones de tráfico
- **Tecnología**: Sidecar-less, CNI-based, waypoints para L7

Esta arquitectura busca **reducir el blast radius** del cluster monolítico actual (100 nodos), **mejorar la eficiencia operativa** mediante consolidación de servicios, y **habilitar comunicación multi-cluster** sin dependencia de load balancers externos.