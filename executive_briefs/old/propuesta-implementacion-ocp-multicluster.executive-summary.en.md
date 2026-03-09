# OCP Multicluster Implementation

## Executive Summary (Maximum 2 Pages)

| Metadata       | Value                                 |
| -------------- | ------------------------------------- |
| Version        | 1.0                                   |
| Date           | March 2026                            |
| Owner          | Platform Engineering                  |
| Audience       | Executive Leadership / Program Sponsors |
| Classification | Confidential                          |

---

## 1) Why This Program Is Critical Now

Banco Galicia currently runs critical digital workloads in a highly concentrated OpenShift production model. While this architecture enabled growth to date, it now creates material business risk:

- **High blast radius:** A partial infrastructure, network, or storage issue can affect multiple business domains at once.
- **Limited elasticity:** Monolithic scaling increases cost and operational complexity as demand grows.
- **Lifecycle pressure:** 3scale reaches end of life in 2027, requiring controlled transition before deadlines become disruptive.
- **Manual dependency:** Key continuity and failover actions still depend on manual coordination across teams.

This is not only an APIM replacement initiative. It is a **platform risk-reduction and continuity program** to evolve from a concentrated model to a domain-segmented multicluster operating model.

---

## 2) Target Outcome

The target state is a **multicluster OpenShift fleet (estimated ~21 clusters)** with centralized governance and domain-level operational autonomy:

- **Central control plane + distributed data planes** (hub-spoke governance).
- **Domain segmentation by criticality and workload profile** to contain incidents.
- **Explicit traffic model separation:**
  - **North-south:** API exposure and external governance (DMZ -> APIM -> services).
  - **East-west:** internal service communication, progressive evolution toward mesh-based patterns.
- **GitOps + IaC as mandatory operational standard** (day 0 / day 1 / day 2 automation).
- **Federated observability (OTel + eBPF)** for cross-cluster visibility and faster incident diagnosis.

Expected result: **lower systemic risk, better continuity, and scalable growth without proportional increase in operational overhead**.

---

## 3) Transformation Strategy (Two-Step Plan in 2026)

| Step          | Timeline     | Strategic Scope                                                                                                                                                                                             | Executive Deliverable                                                                                                         |
| ------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **Step 1 (H1)** | Mar-Jun 2026 | Foundation and enablers: governance baseline, ingress sharding consolidation, DNS/GTM-LTM patterns, site-oriented IaaS foundations, observability deployment (incl. eBPF), controlled coexistence with current model | Approved target architecture baseline, operational guardrails, validated critical scenarios, no-go-live criteria per phase   |
| **Step 2 (H2)** | Sep-Dec 2026 | Operational segmentation by domain, progressive workload movement in waves, APIM/workload traffic pattern consolidation, resilience pattern hardening (HA/DR)                                              | Stable multicluster operating model, measurable risk reduction, APIM transition progress before 3scale EOL                  |

**Execution principle:** sequence over speed. The program prioritizes controlled transition, rollback capability, and objective no-go-live gates.

---

## 4) Executive-Level Decisions Already Framed

1. **Shift from monolithic risk concentration to domain-segmented multicluster topology.**
2. **Establish GitOps + IaC as the default change model** for infra, policy, and platform operations.
3. **Separate external API governance from internal service communication** (north-south vs east-west).
4. **Use phased migration waves with eligibility criteria** (cloud-ready / cloud-compatible / on-prem-bound workloads).
5. **Adopt security-by-design controls** (workload identity, declarative RBAC, least privilege, Vault-backed secret strategy).

These decisions reduce forced, reactive migration risk and improve program control under banking-grade continuity constraints.

---

## 5) Key Program Risks and Mitigation Focus

| Risk                                          | Priority | Mitigation Focus                                                                           |
| --------------------------------------------- | -------- | ------------------------------------------------------------------------------------------ |
| Cross-cluster instability in critical patterns | High     | Mandatory staged testing (POC -> staging -> preprod) and hard no-go-live gates            |
| Platform/network upgrade complexity            | High     | Domain-based sequencing, compatibility dependency control, phased upgrades                  |
| Config drift across clusters/sites             | High     | Declarative baselines + continuous GitOps reconciliation                                   |
| Security gaps during identity/secret transition | High     | Phased migration by domain, separation of duties, auditable change flow                    |
| Third-party delivery/contract constraints      | High     | Early procurement, explicit vendor governance, timeline buffers, alternatives              |

Program governance should track these as board-visible risks with clear owners and closure criteria.

---

## 6) What Executive Sponsors Should Track Monthly

Recommended KPI set for executive steering:

- **Risk containment:** number of incidents with cross-domain impact (trend down).
- **Operational maturity:** % of platform changes delivered via GitOps/IaC (trend up).
- **Migration progress:** workloads moved per wave vs plan (on-time delivery).
- **Reliability:** service-level continuity indicators, failover drill success rate, effective RTO/RPO trend.
- **Observability coverage:** % of target clusters onboarded to federated telemetry and eBPF visibility.

---

## 7) Immediate Executive Ask

To protect continuity while accelerating modernization, the program requires:

1. **Formal endorsement of phased multicluster strategy** (not point solution replacement).
2. **Priority governance for dependencies** (network, security, infrastructure, procurement, vendor management).
3. **Strict enforcement of no-go-live criteria** to avoid schedule-driven risk acceptance.
4. **Cross-domain accountability model** with explicit ownership for each migration wave.

With these conditions, Banco Galicia can transition from a concentrated and reactive platform to a resilient, auditable, and growth-ready architecture.
