# Banco Galicia x Cisco / Isovalent

Email-ready follow-up after Feb 18 session.

## Suggested subject line

Banco Galicia x Cisco/Isovalent - Multi-Cluster Follow-Up and PoC Next Steps

## Email body (copy/paste)

Hi team,

Thank you for today's session. We aligned on a practical path to validate Cilium for Banco Galicia's multi-cluster transformation.

As context, our current OpenShift platform is mission-critical and highly centralized (>100 nodes, >10,000 pods, >600 namespaces, ~2,200 production APIs, ~8B requests/month). Most volume is east-west traffic, and this is where we need to reduce latency and operational risk first.

From today's discussion, we aligned on:

- East-west optimization as the primary target
- Cilium evaluation with a CNI-centric approach to reduce external network hops
- A technical workshop on Friday (3:00 PM local)
- PoC focus on three tracks:
  - CNI replacement and networking simplification
  - eBPF-based observability and service traffic visibility
  - Multi-cluster connectivity patterns for active-active readiness

Key risks we want to validate early:

- Stability under pod churn and failure scenarios (critical go/no-go criterion)
- Migration complexity from current load balancer dependent patterns
- Cloud IP exhaustion constraints

## Agreed immediate actions

- Banco Galicia: share workshop participant list (this week)
- Cisco/Isovalent: provide access to Cilium Enterprise repository (this week)
- Joint output from Friday workshop:
  - Baseline architecture and migration sequence
  - Explicit PoC scope and measurable success criteria
  - Initial rollback and risk-control approach

## Proposed PoC window (2-6 weeks)

Run a controlled PoC across two OpenShift clusters with measurable outcomes:

- Performance and latency under realistic east-west load
- Stability under pod churn and failure
- Reduction of dependency on external load balancers for service-to-service flows
- Day-2 observability quality for troubleshooting and dependency mapping
- Sizing guidance, risk register, and a practical 90-day path to controlled production

## Decision gates

- Green: stable cross-cluster behavior under churn/failure with reproducible operations
- Yellow: partial results with manageable gaps and explicit mitigation plan
- Red: hanging requests, unstable routing behavior, or non-viable rollback mechanics

If this summary reflects your understanding, we can use it as the baseline for Friday's technical workshop.

Best regards,  
Fernando
