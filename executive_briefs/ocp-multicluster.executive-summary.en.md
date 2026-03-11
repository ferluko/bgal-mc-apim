# OCP Multicluster Implementation Strategy

## Executive Summary

**Date:** 2026-03-09

---

## 1. Context and Problem

Banco Galicia currently operates a large-scale OpenShift platform:

- **9 clusters** managed with ACM
- **+500 nodes**, **+15,000 applications**, and **+40,000 containers**
- **~2,200 production APIs** and **~8 billion requests/month**

Although there is a fleet of clusters, critical production workloads are concentrated in an **active-passive** setup (`paas-prdpg` / `paas-prdmz`) that operates as a single logical unit for risk and scaling. This concentration exposes structural limitations:

- **High blast radius** in the event of network, storage, or configuration failures
- **High operational manual effort** (VIPs, DNS, certificates, DR, synchronization)
- **Scalability and elasticity limits** of the monolithic model
- **Hair-pinning in part of internal traffic**, with latency impact
- **Extended maintenance windows** and risk of *configuration drift* across sites

An additional urgency factor exists: **3scale (current APIM) reaches end of life in 2027**, requiring an orderly, non-reactive transition.

---

## 2. Initiative Objective

The initiative does not aim only to replace APIM; it aims to evolve the platform holistically toward a governed, scalable, and auditable multicluster model.

Concrete objectives:

- Reduce systemic risk through segmentation by domain and criticality
- Sustain operational continuity with multicluster resilience patterns
- Enable horizontal scaling and growth by business waves
- Standardize operations with **GitOps + IaC** (day 0 / day 1 / day 2)
- Strengthen security by design (**Zero Trust, declarative RBAC, Vault, mTLS**)
- Consolidate federated observability (**OpenTelemetry + eBPF**)
- Improve the experience of platform and development teams with guardrails and self-service

The expected outcome is to transform the current platform into a standardized, governable technology foundation prepared to scale the bank's digital growth.

---

## 3. Proposed Architecture

The target architecture defines an estimated fleet of **21 clusters** distributed by environment and domain:

- **Governance** ACM Hub
  - 1 cluster
- **API Management (N/S)** Production and DR
  - 2 clusters
- **Production Workload clusters** QA and Prod with DR by domain groups
  - 10 clusters
- **Non-Production Workload clusters** Dev and Stg
  - 2 clusters
- **Shared Services/Storage** Prod and Non-Prod with DR
  - 4 clusters
- **Lab and SRE clusters**
  - 2 clusters

### Main Components

**1. Central multicluster governance (Hub-Spoke)**  
Central control plane with ACM for policy, lifecycle, compliance, and fleet operations.

**2. Distributed data planes by domain and site**  
Execution clusters with separated responsibilities to contain incidents and decouple growth.

**3. Ingress and exposure with sharding + global DNS**  
Ingress architecture with F5 GTM/LTM, integration with corporate DNS, and progressive automation for failover and cross-site traffic control.

**4. North-south and east-west traffic patterns**  
Explicit separation between API L7 governance (north-south) and internal service-to-service communication (east-west). In H1, north-south stability is prioritized; in H2, east-west mesh evolution is consolidated.

**5. Declarative operations and end-to-end security**  
GitOps + IaC as the change standard, declarative policies, auditable traceability, workload identity, and secret management with Vault.

---

## 4. Key Benefits for the Organization

### 1. Systemic Risk Reduction

Segmenting clusters by domain and criticality reduces blast radius and limits cross-incident impact.

### 2. Operational Continuity and Resilience

The program incorporates HA/DR patterns with global DNS, multi-layer health checks, runbooks, and recovery exercises with no-go-live criteria.

### 3. Sustainable Scalability

The approach shifts from monolithic scaling to growth by domains and waves, aligned with real business demand.

### 4. Operational Efficiency and Less Manual Work

GitOps/IaC, day 0 / day 1 / day 2 automation, and central governance reduce manual tasks, errors, and configuration drift.

### 5. Improved Security and Compliance

A Zero Trust model, least privilege, declarative RBAC, mTLS, and traceability strengthen regulatory compliance and auditability.

### 6. Evolutionary Technology Foundation

The focus on standards and portability reduces lock-in and prepares the platform for on-prem and multicloud evolution.

---

## 5. Strategic Impact

The initiative directly impacts business and technology priorities:

**Banking business continuity**  
Mitigates highly critical operational risks and improves incident recovery capability.

**Scale for digital growth**  
Enables support for higher volumes of applications, APIs, and transactions without multiplying complexity at the same rate.

**Controlled technology execution**  
Establishes a phased transition, with progression criteria and executive governance, avoiding forced migrations due to obsolescence (3scale EOL 2027).

**Platform as a strategic enabler**  
Transforms the platform from a reactive, concentrated setup into a distributed, governed model prepared for new initiatives.

---

## 6. Implementation Approach

The program is executed in **two steps and six phases**, with progressive adoption and risk mitigation.

### Step 1 (H1 2026): Foundations, enablers, and operational governance

- Phase 5.1: governance, security, observability, and operating standard baseline
- Phase 5.2: consolidation of ingress sharding, GTM/LTM, and initial flow decoupling
- Phase 5.3: operational segmentation and multicluster governance; shared services clusters and operator rollout; observability delegation.
- Phase 5.4: consolidation and maturity of the wave-based workload movement process

Key H1 deliverables:

- PAAS/IaaS base topology by site
- day 0 / day 1 / day 2 automation
- Operational segmentation and domains of responsibility with active governance
- Shared services clusters with operators in place; delegated observability and federated telemetry per site
- Maturity of the wave-based workload movement process
- End-to-end observability with eBPF
- Stabilized active-passive HA setup with foundations for evolution

### Step 2 (H2 2026): APIM and operational consolidation

- Phase 5.5: implementation and migration to the new APIM
- Phase 5.6: consolidation of high-availability and continuity patterns

Key H2 deliverables:

- Consolidation of north-south/east-west patterns
- Controlled implementation and migration to the new APIM/API Gateway
- Consolidation of domain-based operations in the target topology
- Progressive reduction of production monolith risk
- Progress of the APIM track before 3scale EOL

---

## 7. Risks and Considerations

The program identifies critical risks and mitigations from the outset, including both internal and third-party risks.

Highest-priority risks:

- Instability in critical cross-cluster patterns
- Complexity of platform/network upgrades and technical dependencies
- Configuration drift across clusters and sites
- Gaps in identity and secrets transition
- Third-party delays (hardware, networking, licenses, vendor support)
- Operational overload during coexistence of current and target models

Mitigation lines:

- Phased execution with explicit no-go-live criteria
- Mandatory technical validations in POC, staging, and preproduction
- Declarative baseline with continuous reconciliation (GitOps)
- Early management of contractual and supply dependencies
- Runbooks, continuity drills, and executive risk control

---

## 8. Conclusion

The evolution to OCP multicluster is a strategic decision for continuity and scalability, not an incremental infrastructure improvement.

This initiative aligns architecture, operations, and governance to reduce systemic risk, sustain the bank's growth, and improve technology response capacity.

Replacing APIM is an important workstream within the program, but the intended outcome is broader: a distributed, secure, auditable platform prepared for sustained growth.
