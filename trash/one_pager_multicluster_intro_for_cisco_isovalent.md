# Multi-Cluster Platform Transformation

One-pager intro for Cisco / Isovalent.

## Project Snapshot

Banco Galicia is running a mission-critical OpenShift platform that supports core business operations at scale. Current production runs mainly on a monolithic cluster footprint with:

- More than 100 nodes
- More than 10,000 pods
- More than 600 namespaces
- Around 2,200 production APIs
- Around 8 billion requests per month (~7.5B east-west, ~500M north-south)

The platform currently operates in a stretch topology across two data center sites (PGA and CMZ). This scale and centralization make platform decisions directly relevant for business continuity, risk, and regulatory readiness.

## Why This Transformation Now

The current model has structural limits that are no longer acceptable for 2026-2027 objectives:

- High blast radius due to concentration of critical workloads in one main cluster
- East-west hairpinning patterns that add latency and operational complexity
- Heavy manual operations for DNS, VIPs, certificates, and DR workflows
- Cross-team dependencies that slow critical changes and increase variance
- Lifecycle pressure: current OpenShift baseline (4.15-4.16) must evolve, and 3Scale reaches EOL in 2027

In parallel, the bank must sustain strict continuity and auditability requirements under regulated banking constraints.

## Target Direction (Architecture and Operating Model)

The program direction is to evolve from one monolithic platform into a segmented multi-cluster model (reference: ~30 clusters total, 7-8 production in initial target state), with clear separation of responsibilities:

- North-south traffic: API exposure and L7 governance
- East-west traffic: high-volume internal and cross-cluster service communication
- Central governance + distributed execution: policy-driven multi-cluster operations with GitOps and IaC

The selected direction for east-west is a sidecarless mesh approach centered on Cilium Mesh Enterprise, with strict validation gates before production rollout.

## Program Success Criteria

The program is successful if it delivers:

- Capacity to sustain current traffic volume with growth headroom
- Incremental gateway latency kept under agreed threshold (<10 ms)
- Lower cross-domain incident impact through segmentation and verified failover
- Day 0/1/2 declarative automation with full change traceability
- Phased migration without big-bang cutovers
- Security and audit controls demonstrably enforced in the new model

## Outcome from Feb 18 Cisco / Isovalent Session

The first vendor session is complete and produced concrete alignment:

- Primary optimization target is east-west traffic, where most current volume is concentrated.
- Cilium is positioned for evaluation as a CNI-centric path to remove unnecessary external network hops.
- A dedicated technical workshop is scheduled for Friday (3:00-5:00 PM local).
- Initial PoC focus was agreed on three tracks:
  - CNI replacement path and networking simplification
  - eBPF-based observability and service traffic visibility
  - Multi-cluster connectivity patterns for active-active readiness

The session also confirmed key risks to validate early:

- Prior negative experience with Ambient Mesh stability in critical flows
- IP exhaustion pressure in cloud environments
- Migration complexity from an external load balancer dependent model

## Agreed Next Steps (Post-Meeting)

### Immediate actions (this week)

1. Banco Galicia shares the participant list for the technical workshop.
2. Cisco / Isovalent provides access to the Cilium Enterprise repository for hands-on validation.
3. Workshop session produces:
   - Baseline architecture and migration sequence
   - Explicit PoC scope and success criteria
   - Preliminary risk controls and rollback approach

### Short execution plan (next 2-6 weeks)

Run a controlled PoC across two OpenShift clusters with measurable outcomes:

- Performance and latency under realistic east-west load
- Stability under failure and pod churn scenarios
- Practical reduction of external load balancer dependency for service-to-service traffic
- Observability quality for day-2 troubleshooting and dependency mapping
- Sizing, risk register, and a practical 90-day path to controlled production

### PoC go/no-go signals

- Green: stable cross-cluster traffic behavior under churn and failure, with reproducible operations.
- Yellow: partial target achievement with unresolved operational complexity requiring mitigation plan.
- Red: hanging requests, unstable routing behavior, or non-viable migration/rollback mechanics.
