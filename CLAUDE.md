# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains demo content for showcasing security features in Red Hat OpenShift and Advanced Cluster Management (ACM) for Kubernetes. The content is organized to demonstrate defense-in-depth security practices across multiple layers: pod security, network isolation, access control, and multi-cluster governance.

## Architecture

### Directory Structure

The repository is organized by resource type and security domain:

- **`policies/`**: ACM Policy resources that enforce governance across clusters
  - `security/`: Policies enforcing security standards (e.g., Pod Security Standards)
  - `compliance/`: Policies for compliance operators and configurations
  - `governance/`: General governance policies

- **`manifests/`**: OpenShift/Kubernetes resource definitions
  - `namespaces/`: Namespace definitions with Pod Security Admission labels
  - `network-policies/`: NetworkPolicy resources implementing zero-trust networking
  - `scc/`: SecurityContextConstraints (OpenShift-specific) for pod security
  - `rbac/`: Role and RoleBinding resources for access control

- **`applications/`**: Sample applications demonstrating secure deployment patterns
  - Each app includes hardened security contexts, resource limits, and follows least-privilege principles

- **`scripts/`**: Automation scripts for demo setup and teardown

- **`docs/`**: Demo guides and documentation

### Key Concepts

**ACM Policies**: Use the Policy, PlacementRule, and PlacementBinding pattern:
- Policy defines the desired state and compliance rules
- PlacementRule selects target clusters using label selectors
- PlacementBinding connects policies to placement rules
- Remediation can be "inform" (detect only) or "enforce" (auto-remediate)

**Security Layers**:
1. Pod Security Standards (enforced at namespace level)
2. SecurityContextConstraints (OpenShift admission control)
3. Container security contexts (runtime security settings)
4. NetworkPolicies (network isolation)
5. RBAC (access control)
6. ACM Policies (multi-cluster governance)

## Common Commands

### OpenShift CLI

**Login and context:**
```bash
# Login to OpenShift cluster
oc login --server=<cluster-api-url> --token=<token>

# Check current context
oc whoami
oc project
```

**Deploy demo:**
```bash
# Automated setup
./scripts/setup-demo.sh

# Verify deployment (runs comprehensive tests)
./scripts/test-demo.sh

# Manual setup (step by step)
oc apply -f manifests/namespaces/
oc apply -f manifests/rbac/
oc apply -f manifests/network-policies/
oc apply -f manifests/scc/
oc apply -f applications/sample-app/
oc apply -f policies/security/
oc apply -f policies/compliance/
```

**Test and validate:**
```bash
# Run full test suite
./scripts/test-demo.sh

# Test specific security enforcement
oc apply -f applications/insecure-examples/privileged-pod.yaml --dry-run=server
# Should show: Error from server (Forbidden)
```

**Clean up demo:**
```bash
./scripts/cleanup-demo.sh
```

**Verify deployment:**
```bash
# Check all resources in demo namespace
oc get all -n security-demo

# Check pod status and logs
oc get pods -n security-demo
oc logs -l app=secure-app -n security-demo

# Check network policies
oc get networkpolicies -n security-demo
oc describe networkpolicy deny-all-ingress -n security-demo

# Check SCC
oc get scc demo-restricted-scc
oc describe scc demo-restricted-scc

# Check RBAC
oc get role,rolebinding -n security-demo
```

**ACM policy management:**
```bash
# View all policies
oc get policies -A

# Check policy status
oc describe policy <policy-name> -n default

# View policy compliance
oc get policies -n default -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.compliant}{"\n"}{end}'
```

**Troubleshooting:**
```bash
# Pod won't start - check events and security violations
oc describe pod <pod-name> -n security-demo
oc get events -n security-demo --sort-by='.lastTimestamp'

# Check SCC assigned to pod
oc get pod <pod-name> -n security-demo -o yaml | grep "openshift.io/scc"

# View admission controller rejections
oc get events -A | grep "FailedCreate\|Error"

# Test network policies
oc run test-pod --image=registry.access.redhat.com/ubi9/ubi-minimal -n security-demo -- sleep infinity
oc exec test-pod -n security-demo -- curl http://secure-app:8080
```

## Development Workflow

### Adding New Security Policies

When creating new ACM policies:
1. Define the Policy in `policies/` with appropriate annotations (standards, categories, controls)
2. Set `remediationAction` carefully ("inform" for testing, "enforce" for production)
3. Create corresponding PlacementRule with appropriate cluster selectors
4. Create PlacementBinding to link them
5. Test on a non-production cluster first

### Adding New Manifests

For OpenShift resources:
1. Place in appropriate `manifests/` subdirectory
2. Always include namespace in metadata
3. For security-sensitive resources (SCC), test impact before enforcing
4. Document any cluster-admin requirements

### Adding Sample Applications

When creating demo applications:
1. Follow the security patterns in `applications/sample-app/`:
   - Non-root user (`runAsNonRoot: true`)
   - Drop all capabilities
   - Read-only root filesystem where possible
   - Define resource limits
   - Use seccomp runtime default profile
2. Include a ServiceAccount
3. Test against restricted Pod Security Standards

## File Naming Conventions

- Use lowercase with hyphens: `pod-security-policy.yaml`
- ACM policies: prefix with `policy-`
- Manifests: descriptive names matching resource purpose
- Multi-resource files: use `---` separator between resources

## Important Notes

- **Cluster-admin required**: Applying SCCs and some ACM policies requires cluster-admin privileges
- **ACM availability**: Policy application will be skipped if ACM CRDs are not detected
- **Namespace labels**: The `security-demo` namespace uses restricted Pod Security Standards - privileged pods will be rejected
- **Network policies**: Default deny strategy is applied - explicit allow rules needed for new communication patterns
- **Policy remediation**: Start with `remediationAction: inform` to test impact before switching to `enforce`

## Testing the Demo

Run through the demo script in `docs/demo-script.md` which provides:
- Step-by-step walkthrough (40-45 minutes with failure scenarios)
- Commands to demonstrate each security feature
- **5 failure scenarios** showing security enforcement in action
- Expected error messages and outcomes
- Key talking points and explanations
- Cleanup commands

The updated demo flow includes:
1. **Introduction** (2 min)
2. **Pod Security Standards with failures** (8 min) - Shows privileged pod and root user rejections
3. **SCC with failures** (7 min) - Demonstrates host access and capability blocking
4. **Network Policies with failures** (8 min) - Tests cross-namespace isolation
5. **RBAC** (5 min)
6. **ACM Policies** (8 min)
7. **Secure vs Insecure comparison** (5 min)
8. **Defense-in-Depth summary** (3 min) - Table showing all layers
9. **Conclusion** (2 min)

## Validating YAML Manifests

Before applying resources to a cluster, validate syntax:
```bash
# Dry-run to validate resources without applying
oc apply -f <file.yaml> --dry-run=client

# Server-side validation (checks against OpenAPI schema)
oc apply -f <file.yaml> --dry-run=server

# Validate all manifests in a directory
for f in manifests/**/*.yaml; do oc apply -f $f --dry-run=client; done
```

## Quick Reference: Resource Locations

When modifying or adding demo content:
- **ACM Policies**: `policies/security/pod-security-policy.yaml`, `policies/compliance/container-security-operator.yaml`
- **Demo namespace**: `manifests/namespaces/demo-namespace.yaml` (uses `security-demo` namespace)
- **Network isolation**: `manifests/network-policies/deny-all.yaml`
- **Secure app example**: `applications/sample-app/deployment.yaml`
- **Insecure examples**: `applications/insecure-examples/` (for demonstrating security violations)
- **Demo walkthrough**: `docs/demo-script.md`
- **Security troubleshooting**: `docs/security-violations-guide.md`

## Demonstrating Security Failures

This demo includes intentionally insecure examples to showcase how security controls prevent violations.

### Available Failure Scenarios

Located in `applications/insecure-examples/`:

| File | Demonstrates | Expected Result |
|------|--------------|-----------------|
| `privileged-pod.yaml` | Privileged container attempt | Rejected by Pod Security Standards |
| `root-user.yaml` | Running as root (UID 0) | Rejected by restricted profile |
| `host-access.yaml` | Host namespace access (hostNetwork, hostPID, hostIPC) | Rejected by PSS and SCC |
| `dangerous-capabilities.yaml` | Linux capabilities abuse (SYS_ADMIN, NET_ADMIN) | Rejected by SCC |
| `writable-root-fs.yaml` | Missing read-only root filesystem | Warning (may be accepted) |

### Testing Failure Scenarios

```bash
# These commands will fail - that's the point!

# Test 1: Privileged container
oc apply -f applications/insecure-examples/privileged-pod.yaml
# Expected: Error about privileged containers not allowed

# Test 2: Root user
oc apply -f applications/insecure-examples/root-user.yaml
# Expected: Error about runAsNonRoot requirement

# Test 3: Host access
oc apply -f applications/insecure-examples/host-access.yaml
# Expected: Error about host namespaces not allowed

# Test 4: Dangerous capabilities
oc apply -f applications/insecure-examples/dangerous-capabilities.yaml
# Expected: Error about capabilities and privilege escalation

# Test 5: Network policy blocking (runtime test)
oc create namespace test-namespace
oc run test-pod --image=registry.access.redhat.com/ubi9/ubi-minimal:latest -n test-namespace -- sleep infinity
oc exec test-pod -n test-namespace -- curl -m 5 http://secure-app.security-demo.svc.cluster.local:8080
# Expected: Connection timeout (network policy blocks cross-namespace traffic)
```

### Understanding Security Violations

When security controls reject a deployment, you'll see descriptive errors:

**Pod Security Standards violations:**
```
Error from server (Forbidden): pods "privileged-pod-test" is forbidden:
violates PodSecurity "restricted:latest": privileged
(container "test" must not set securityContext.privileged=true)
```

**SCC violations:**
```
Error: unable to validate against any security context constraint:
[spec.securityContext.hostNetwork: Invalid value: true: Host network is not allowed]
```

**Network Policy blocks** (at runtime):
```
curl: (28) Connection timed out after 5000 milliseconds
```

For detailed troubleshooting, see `docs/security-violations-guide.md`
