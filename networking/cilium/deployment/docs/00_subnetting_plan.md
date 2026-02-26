# Plan de Subnetting para Cilium Cluster Mesh

## Red padre asignada

| Parámetro | Valor |
|-----------|-------|
| Pod CIDR total | `10.128.0.0/14` |
| IPs totales | 262,144 |
| División | 16 subredes /18 |

## Requisitos

- **Clusters objetivo:** 15 (+ 1 reserva)
- **Nodos por cluster:** ~50
- **Pods por nodo:** ~250
- **Pods por cluster:** ~12,500

## Cálculo

```
IPs necesarias por cluster = 50 nodos × 256 IPs/nodo = 12,800 IPs
Subred mínima = /18 (16,384 IPs) ✓
hostPrefix = /24 (256 IPs por nodo)
```

## Asignación de subredes

| Cluster ID | Nombre | Pod CIDR | Rango | IPs |
|------------|--------|----------|-------|-----|
| 1 | paas-arqlab | `10.128.0.0/18` | 10.128.0.1 - 10.128.63.254 | 16,384 |
| 2 | cluster-02 | `10.128.64.0/18` | 10.128.64.1 - 10.128.127.254 | 16,384 |
| 3 | cluster-03 | `10.128.128.0/18` | 10.128.128.1 - 10.128.191.254 | 16,384 |
| 4 | cluster-04 | `10.128.192.0/18` | 10.128.192.1 - 10.128.255.254 | 16,384 |
| 5 | cluster-05 | `10.129.0.0/18` | 10.129.0.1 - 10.129.63.254 | 16,384 |
| 6 | cluster-06 | `10.129.64.0/18` | 10.129.64.1 - 10.129.127.254 | 16,384 |
| 7 | cluster-07 | `10.129.128.0/18` | 10.129.128.1 - 10.129.191.254 | 16,384 |
| 8 | cluster-08 | `10.129.192.0/18` | 10.129.192.1 - 10.129.255.254 | 16,384 |
| 9 | cluster-09 | `10.130.0.0/18` | 10.130.0.1 - 10.130.63.254 | 16,384 |
| 10 | cluster-10 | `10.130.64.0/18` | 10.130.64.1 - 10.130.127.254 | 16,384 |
| 11 | cluster-11 | `10.130.128.0/18` | 10.130.128.1 - 10.130.191.254 | 16,384 |
| 12 | cluster-12 | `10.130.192.0/18` | 10.130.192.1 - 10.130.255.254 | 16,384 |
| 13 | cluster-13 | `10.131.0.0/18` | 10.131.0.1 - 10.131.63.254 | 16,384 |
| 14 | cluster-14 | `10.131.64.0/18` | 10.131.64.1 - 10.131.127.254 | 16,384 |
| 15 | cluster-15 | `10.131.128.0/18` | 10.131.128.1 - 10.131.191.254 | 16,384 |
| — | (reserva) | `10.131.192.0/18` | 10.131.192.1 - 10.131.255.254 | 16,384 |

## Capacidad por cluster

| Métrica | Valor |
|---------|-------|
| Nodos máximos | 64 (16,384 ÷ 256) |
| Pods por nodo | 250 (con margen en /24) |
| Pods totales | ~16,000 |

## Requisitos para Cluster Mesh

Cada cluster debe tener:

1. **`cluster.name`** único (ej: `paas-arqlab`, `cluster-02`)
2. **`cluster.id`** único entre 1-255
3. **Pod CIDR** sin solapamiento con otros clusters
4. **Service CIDR** puede ser igual (`172.30.0.0/16`) si no hay Global Services

## Diagrama

```
10.128.0.0/14 (Total)
├── 10.128.0.0/18   → paas-arqlab (ID: 1)
├── 10.128.64.0/18  → cluster-02  (ID: 2)
├── 10.128.128.0/18 → cluster-03  (ID: 3)
├── 10.128.192.0/18 → cluster-04  (ID: 4)
├── 10.129.0.0/18   → cluster-05  (ID: 5)
├── 10.129.64.0/18  → cluster-06  (ID: 6)
├── 10.129.128.0/18 → cluster-07  (ID: 7)
├── 10.129.192.0/18 → cluster-08  (ID: 8)
├── 10.130.0.0/18   → cluster-09  (ID: 9)
├── 10.130.64.0/18  → cluster-10  (ID: 10)
├── 10.130.128.0/18 → cluster-11  (ID: 11)
├── 10.130.192.0/18 → cluster-12  (ID: 12)
├── 10.131.0.0/18   → cluster-13  (ID: 13)
├── 10.131.64.0/18  → cluster-14  (ID: 14)
├── 10.131.128.0/18 → cluster-15  (ID: 15)
└── 10.131.192.0/18 → (reserva)
```
