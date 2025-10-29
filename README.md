# OpenShift and ACM Security Demo

This repository contains demo content for showcasing security features in OpenShift and Advanced Cluster Management for Kubernetes (ACM).

## Repository Structure

```
.
├── policies/                    # ACM Policy definitions
│   ├── governance/             # Governance policies
│   ├── security/               # Security policies
│   └── compliance/             # Compliance policies
├── manifests/                  # OpenShift resource manifests
│   ├── namespaces/            # Namespace definitions
│   ├── network-policies/      # NetworkPolicy resources
│   ├── scc/                   # SecurityContextConstraints
│   └── rbac/                  # Role-based access control
├── applications/              # Sample applications for demo
│   └── sample-app/           # Example application
├── docs/                     # Documentation and demo guides
└── scripts/                  # Helper scripts for demo setup
```

## Prerequisites

- OpenShift cluster (version 4.x)
- Advanced Cluster Management for Kubernetes installed
- `oc` CLI tool installed and configured
- `kubectl` CLI tool (optional, oc includes kubectl functionality)
- Cluster admin access

## Quick Start

1. Log in to your OpenShift cluster:
   ```bash
   oc login --server=<your-cluster-api> --token=<your-token>
   ```

2. Deploy the complete demo environment:
   ```bash
   ./scripts/setup-demo.sh
   ```

3. Verify the deployment:
   ```bash
   ./scripts/test-demo.sh
   ```

4. Review the demo script:
   ```bash
   cat docs/demo-script.md
   # or for presentation
   cat docs/presentation-script.md
   ```

### Manual Deployment

If you prefer step-by-step deployment:

```bash
# Create namespace
oc apply -f manifests/namespaces/

# Apply RBAC
oc apply -f manifests/rbac/

# Apply Network Policies
oc apply -f manifests/network-policies/

# Apply Security Context Constraints (requires cluster-admin)
oc apply -f manifests/scc/

# Deploy secure application
oc apply -f applications/sample-app/

# Apply ACM policies (if ACM is installed)
oc apply -f policies/security/
oc apply -f policies/compliance/
```

## Demo Topics

This demo showcases security enforcement through **both successful and failed deployments**:

- **Pod Security Standards**: Enforce security best practices (includes failure examples)
- **Security Context Constraints (SCC)**: Control pod security permissions
- **Network Policies**: Secure pod-to-pod communication with isolation testing
- **RBAC**: Role-based access control implementation
- **ACM Policies**: Governance, risk, and compliance automation
- **Defense-in-Depth**: Multiple security layers working together

### Failure Scenarios Included

The demo includes intentionally insecure examples in `applications/insecure-examples/` to demonstrate:
1. Privileged container rejection
2. Root user blocking
3. Host namespace access prevention
4. Dangerous capabilities denial
5. Network policy isolation enforcement

## Presentation Resources

Before presenting this demo:
- **Preparation**: Read `docs/pre-demo-checklist.md`
- **Delivery**: Follow `docs/presentation-script.md`
- **Technical Details**: Reference `docs/demo-script.md`
- **Troubleshooting**: Consult `docs/security-violations-guide.md`

### Demo Quality Assurance

This demo has been comprehensively reviewed and validated:
- ✅ **Technical Accuracy**: All configurations tested and verified
- ✅ **Flow & Sequencing**: Logical progression from simple to complex
- ✅ **Engagement**: Strong narrative with real security violations
- ✅ **Value Delivery**: Actionable takeaways for attendees
- ✅ **Readiness Score**: 9.5/10

See `docs/project-review-report.md` for detailed analysis.

## Additional Resources

- [OpenShift Security Documentation](https://docs.openshift.com/container-platform/latest/security/index.html)
- [ACM Policy Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/)
