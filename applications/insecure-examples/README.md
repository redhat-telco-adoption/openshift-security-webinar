# Insecure Application Examples

This directory contains intentionally insecure Kubernetes manifests designed to **demonstrate security controls in action**. These examples will be **rejected or blocked** by OpenShift security features.

## ⚠️ WARNING

**DO NOT USE THESE MANIFESTS IN PRODUCTION!**

These are educational examples that violate security best practices. They are designed to:
1. Demonstrate how security controls prevent insecure deployments
2. Show meaningful error messages from security enforcement
3. Help understand Pod Security Standards, SCCs, and admission control

## Examples Overview

| File | Violation Type | Expected Result |
|------|----------------|-----------------|
| `privileged-pod.yaml` | Privileged container | REJECTED by Pod Security Standards |
| `root-user.yaml` | Running as root (UID 0) | REJECTED by restricted profile |
| `host-access.yaml` | Host namespace access | REJECTED by SCC and PSS |
| `dangerous-capabilities.yaml` | Linux capabilities abuse | REJECTED by SCC |
| `writable-root-fs.yaml` | Missing read-only root FS | WARNING (may be accepted with audit log) |

## How to Use for Demo

### 1. Ensure Demo Environment is Set Up
```bash
# Deploy the secure environment first
./scripts/setup-demo.sh

# Verify namespace has restricted Pod Security Standards
oc get namespace security-demo -o yaml | grep pod-security
```

### 2. Attempt Insecure Deployments

Each attempt will be blocked with descriptive error messages:

```bash
# Example 1: Try to deploy privileged container
oc apply -f applications/insecure-examples/privileged-pod.yaml
# Expected: Error from server (Forbidden): pods "privileged-pod-test" is forbidden:
# violates PodSecurity "restricted:latest": privileged (container "test" must not set securityContext.privileged=true)

# Example 2: Try to run as root
oc apply -f applications/insecure-examples/root-user.yaml
# Expected: Error indicating runAsUser=0 is not allowed

# Example 3: Try to access host namespaces
oc apply -f applications/insecure-examples/host-access.yaml
# Expected: Error about hostNetwork, hostPID, hostIPC not being allowed

# Example 4: Try to add dangerous capabilities
oc apply -f applications/insecure-examples/dangerous-capabilities.yaml
# Expected: Error about capabilities and allowPrivilegeEscalation

# Example 5: Deploy without read-only root filesystem (warning only)
oc apply -f applications/insecure-examples/writable-root-fs.yaml
# Expected: May succeed but generates audit/warning events
```

### 3. View Security Enforcement Events

```bash
# Check namespace events for security rejections
oc get events -n security-demo --sort-by='.lastTimestamp'

# View audit logs (if enabled)
oc adm node-logs --role=master --path=kube-apiserver/audit.log | grep security-demo
```

### 4. Contrast with Secure Deployment

```bash
# Deploy the secure application
oc apply -f applications/sample-app/deployment.yaml

# Verify it runs successfully
oc get pods -n security-demo
oc logs -l app=secure-app -n security-demo
```

## Understanding the Errors

### Pod Security Standards Violations

When Pod Security Standards (PSS) reject a pod, you'll see errors like:
```
Error from server (Forbidden): error when creating "privileged-pod.yaml":
pods "privileged-pod-test" is forbidden: violates PodSecurity "restricted:latest":
privileged (container "test" must not set securityContext.privileged=true)
```

**Key fields in PSS errors:**
- **PodSecurity level:** `restricted:latest` (the enforcement level)
- **Specific violation:** What security control was violated
- **Affected resource:** Container or pod that triggered the violation

### SCC Violations

SecurityContextConstraints errors appear differently:
```
Error creating: pods "test-pod" is forbidden: unable to validate against any security context constraint:
[spec.securityContext.hostNetwork: Invalid value: true: Host network is not allowed to be used]
```

**SCC errors indicate:**
- No SCC allows the requested security configuration
- Specific field that violates all available SCCs
- What configuration change is needed

### Network Policy Violations

Network policy enforcement happens at runtime (not admission):
```bash
# Pod starts but connections fail
oc exec test-pod -n security-demo -- curl http://external-service
# Result: Connection timeout or refused
```

## Remediation Examples

For each violation, here's how to fix it:

### ❌ Privileged Container
```yaml
securityContext:
  privileged: true  # WRONG
```
✅ **Fix:**
```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
```

### ❌ Running as Root
```yaml
securityContext:
  runAsUser: 0  # WRONG
```
✅ **Fix:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001  # or let OpenShift assign
```

### ❌ Host Access
```yaml
hostNetwork: true  # WRONG
hostPID: true      # WRONG
```
✅ **Fix:**
```yaml
# Simply omit these fields (defaults to false)
# Or explicitly set to false
hostNetwork: false
hostPID: false
```

### ❌ Dangerous Capabilities
```yaml
capabilities:
  add:
  - SYS_ADMIN  # WRONG
```
✅ **Fix:**
```yaml
capabilities:
  drop:
  - ALL
  # Only add safe capabilities if absolutely necessary
```

## Demo Script Integration

These examples are integrated into `docs/demo-script.md` in the following sections:
- Section 2: Pod Security Standards violations
- Section 3: SCC enforcement
- Section 4: Network policy blocking
- Section 6: RHACS admission control (if deployed)

## Testing Matrix

| Security Control | Violation Example | Expected Behavior |
|------------------|-------------------|-------------------|
| Pod Security Standards (restricted) | privileged-pod.yaml | Admission rejected |
| SCC (restricted) | root-user.yaml | Admission rejected |
| Network Policy (deny-all) | External service access | Connection timeout |
| RHACS Admission Control | High severity CVE image | Admission rejected |
| Resource Limits | No limits defined | Warning or rejection based on policy |

## Additional Resources

- OpenShift Pod Security Standards: https://docs.openshift.com/container-platform/latest/authentication/understanding-and-managing-pod-security-admission.html
- SCC Reference: https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html
- Kubernetes Security Best Practices: https://kubernetes.io/docs/concepts/security/pod-security-standards/
