# Spectro Cloud Demo Checklist (ACM Replacement Evaluation)

## 1) Must-Have Capabilities (Go/No-Go)

- [ ] **Single-pane fleet health view**: all clusters in one dashboard (status, version, capacity, alerts, drift, compliance).
- [ ] **Operational drill-down**: global view -> cluster -> node/add-ons, with practical troubleshooting.
- [ ] **Cluster attach/import workflow**: full live demo (not slides), including exact steps and timing.
- [ ] **Real OpenShift support**: supported versions, known limitations, and compatibility with critical operators.
- [ ] **Policy and governance at scale**: define once, enforce across all/specific cluster groups.
- [ ] **Continuous compliance**: compliance dashboard, evidence, and automated/manual remediation flows.
- [ ] **Native GitOps workflow**: Git -> approval -> deploy -> rollback -> audit trail.
- [ ] **RBAC and multi-tenancy**: clear separation between platform team and app teams.
- [ ] **Full auditability**: who changed what, when, and through which channel (UI/API/Git).

## 2) Day-2 Operational Validation

- [ ] **Cluster/add-on lifecycle**: create, register, update, and decommission.
- [ ] **Upgrades at scale**: wave/canary strategies and rollback options.
- [ ] **Placement policies**: by labels, environment, region, criticality, and compliance constraints.
- [ ] **Observability integrations**: Prometheus/Grafana/Alertmanager and ITSM/notification tools.
- [ ] **Secrets handling**: integration with Vault / External Secrets / sealed-secrets patterns.
- [ ] **API/IaC parity**: everything in UI is also available via API/Terraform.
- [ ] **Scale limits and references**: proven production scale (clusters/nodes) with customer examples.
- [ ] **Management plane resiliency**: HA/DR architecture and expected RTO/RPO.

## 3) Live Questions to Ask During the Demo

- [ ] “Please show **fleet health for all clusters** and investigate one real incident end-to-end.”
- [ ] “Please show a **new OpenShift cluster attach/import** from scratch.”
- [ ] “Please show a **GitOps change**, drift detection, and a rollback.”
- [ ] “Please apply a **global policy**, trigger non-compliance, and demonstrate remediation.”
- [ ] “What requires your SaaS control plane vs self-hosted options?”
- [ ] “What data leaves our clusters (telemetry/metadata), where is it stored, and for how long?”

## 4) POC Prerequisites (Must Be Explicitly Confirmed)

- [ ] **Network/firewall requirements**: exact FQDNs/IPs, ports, protocols, and traffic direction.
- [ ] **Connectivity model**: egress-only from clusters?.
- [ ] **Agent installation**: official Helm chart, required values, namespace, and install sequence.
- [ ] **RBAC minimum permissions**: required privileges (temporary cluster-admin vs least privilege target).
- [ ] **Registry access**: external pulls vs internal mirror requirements.
- [ ] **Supported platform matrix**: OpenShift/Kubernetes versions, OS/runtime constraints.

## 5) POC Success Criteria

- [ ] All target clusters visible in one console with reliable real-time status.
- [ ] Cluster attach within agreed SLA (e.g., <30 min per cluster).
- [ ] End-to-end GitOps workflow validated (deploy + rollback + traceability).
- [ ] Global policy enforcement with measurable compliance and remediation.
- [ ] RBAC validated across teams with no privilege leakage.
- [ ] Minimum required integrations validated (identity, observability, notifications).
- [ ] No critical blockers in network/security architecture for production rollout.
- [ ] Documented ACM gap analysis accepted by platform and security stakeholders.

## 6) Meeting Notes Template (Use During Demo)

| Topic | Expected Outcome | Evidence in Demo | Result (Pass/Fail) | Owner | Follow-up |
|---|---|---|---|---|---|
| Fleet health dashboard | Single pane for all clusters | Live dashboard + drill-down |  |  |  |
| Cluster attach/import | Repeatable process with clear prerequisites | Live attach from scratch |  |  |  |
| GitOps operations | Commit-to-deploy with rollback | Real change + rollback demo |  |  |  |
| Policy/compliance | Policy propagation + remediation | Non-compliance scenario |  |  |  |
| RBAC/multi-tenancy | Team isolation and least privilege | Role-based access test |  |  |  |
| Integrations | Works with enterprise toolchain | SSO/alerts/metrics integration |  |  |  |