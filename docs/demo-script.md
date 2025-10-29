# Security Demo Script

This guide provides a step-by-step walkthrough for demonstrating OpenShift and ACM security features.

## Demo Flow

### 1. Introduction (2 minutes)
- Explain the security challenges in Kubernetes environments
- Introduce OpenShift and ACM security capabilities
- Overview of what will be demonstrated

### 2. Pod Security Standards (8 minutes)

**Show the namespace configuration:**
```bash
oc get namespace security-demo -o yaml | grep -A 5 labels
```

**Key points to highlight:**
- Pod Security Admission labels (enforce, audit, warn)
- Restricted profile enforcement at namespace level
- Three modes: enforce (blocks), audit (logs), warn (notifies)

**FAILURE SCENARIO 1: Attempt to deploy privileged pod**
```bash
# This WILL FAIL - demonstrating Pod Security Standards enforcement
oc apply -f applications/insecure-examples/privileged-pod.yaml
```

**Expected Error:**
```
Error from server (Forbidden): pods "privileged-pod-test" is forbidden:
violates PodSecurity "restricted:latest": privileged
(container "test" must not set securityContext.privileged=true)
```

**Explain:**
- Pod Security Standards blocked the privileged container at admission time
- The "restricted" profile is the most secure, preventing privileged escalation
- Error message clearly identifies the violation

**FAILURE SCENARIO 2: Attempt to run as root user**
```bash
# This WILL FAIL - root user not allowed in restricted profile
oc apply -f applications/insecure-examples/root-user.yaml
```

**Expected Error:**
```
Error: pods "root-user-attack-xxx" is forbidden: violates PodSecurity "restricted:latest":
runAsNonRoot != true (container "attacker" must not set securityContext.runAsNonRoot=false)
```

**Contrast with secure deployment:**
```bash
# This WILL SUCCEED - properly configured security context
oc get deployment secure-app -n security-demo -o yaml | grep -A 10 securityContext
```

### 3. Security Context Constraints (7 minutes)

**Show available SCCs:**
```bash
oc get scc
```

**Examine the demo restricted SCC:**
```bash
oc describe scc demo-restricted-scc
```

**Key points to highlight:**
- SCCs are OpenShift-specific admission control (layer 2 after PSS)
- Controls: user IDs, capabilities, volumes, host access
- Service accounts are bound to SCCs

**FAILURE SCENARIO 3: Attempt to access host namespaces**
```bash
# This WILL FAIL - SCC prevents host access
oc apply -f applications/insecure-examples/host-access.yaml
```

**Expected Error:**
```
Error from server (Forbidden): error when creating: pods is forbidden:
violates PodSecurity "restricted:latest": host namespaces
(hostNetwork=true, hostPID=true, hostIPC=true)
```

**Explain:**
- Even if PSS allowed it, SCC provides another layer of defense
- Host namespace access could compromise the entire node
- Both controls work together for defense-in-depth

**FAILURE SCENARIO 4: Attempt dangerous Linux capabilities**
```bash
# This WILL FAIL - capabilities like SYS_ADMIN are prohibited
oc apply -f applications/insecure-examples/dangerous-capabilities.yaml
```

**Expected Error:**
```
Error: pods is forbidden: violates PodSecurity "restricted:latest":
allowPrivilegeEscalation != false
unrestricted capabilities (containers "attacker" must not include "SYS_ADMIN", "NET_ADMIN" in securityContext.capabilities.add)
```

**Show what capabilities are allowed:**
```bash
oc describe scc restricted | grep -A 5 "Allowed Capabilities"
```

### 4. Network Policies (8 minutes)

**Show network policies:**
```bash
oc get networkpolicies -n security-demo
oc describe networkpolicy deny-all-ingress -n security-demo
oc describe networkpolicy allow-same-namespace -n security-demo
```

**Key points to highlight:**
- Default deny approach (zero-trust networking)
- Explicit allow rules for permitted traffic
- Namespace-level network segmentation
- Prevents lateral movement in case of compromise

**FAILURE SCENARIO 5: Attempt cross-namespace communication**
```bash
# Deploy a test pod in different namespace
oc create namespace test-namespace
oc run test-pod --image=registry.access.redhat.com/ubi9/ubi-minimal:latest -n test-namespace -- sleep infinity

# Wait for pod to be ready
oc wait --for=condition=ready pod/test-pod -n test-namespace --timeout=60s

# This WILL FAIL - network policy blocks cross-namespace traffic
echo "Attempting to access secure-app from test-namespace..."
oc exec test-pod -n test-namespace -- curl -m 5 http://secure-app.security-demo.svc.cluster.local:8080
```

**Expected Result:**
```
curl: (28) Connection timed out after 5000 milliseconds
command terminated with exit code 28
```

**Explain:**
- The deny-all-ingress policy blocks all traffic by default
- Only same-namespace traffic is allowed via the second policy
- This prevents compromised pods from accessing other namespaces

**SUCCESS SCENARIO: Same-namespace communication works**
```bash
# Deploy a test pod in security-demo namespace
oc run test-internal --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
  -n security-demo -- sleep infinity

# Wait for pod
oc wait --for=condition=ready pod/test-internal -n security-demo --timeout=60s

# This WILL SUCCEED - same namespace communication is allowed
echo "Attempting to access secure-app from within security-demo namespace..."
oc exec test-internal -n security-demo -- curl -m 5 http://secure-app:8080
```

**Expected Result:**
```
(Connection succeeds or returns empty response - no timeout)
```

**Cleanup test resources:**
```bash
oc delete pod test-internal -n security-demo
oc delete pod test-pod -n test-namespace
oc delete namespace test-namespace
```

### 5. RBAC Configuration (5 minutes)

**Show role and role binding:**
```bash
oc describe role developer-role -n security-demo
oc describe rolebinding developer-binding -n security-demo
```

**Key points to highlight:**
- Least privilege principle
- Resource-level permissions
- Verb restrictions

### 6. ACM Governance Policies (8 minutes)

**Show ACM policies:**
```bash
oc get policies -n default
oc describe policy policy-pod-security-standards -n default
```

**Check policy compliance:**
```bash
oc get policies -A
```

**Key points to highlight:**
- Multi-cluster governance
- Automated compliance checking
- Remediation capabilities (inform vs enforce)
- Policy placement across clusters

**Show Container Security Operator policy:**
```bash
oc describe policy policy-container-security-operator -n default
```

### 7. Secure Application Deployment (5 minutes)

**Examine the secure application:**
```bash
oc get deployment secure-app -n security-demo -o yaml | grep -A 30 securityContext
```

**Key security features to highlight:**
- ✅ Non-root user (runAsNonRoot: true)
- ✅ Read-only root filesystem (prevents file modifications)
- ✅ All capabilities dropped (minimal privileges)
- ✅ No privilege escalation allowed
- ✅ Security context at both pod and container level
- ✅ Resource limits defined (prevents resource exhaustion)
- ✅ Seccomp runtime/default profile (syscall filtering)

**Check application is running successfully:**
```bash
oc get pods -n security-demo
oc logs -l app=secure-app -n security-demo --tail=10
```

**Compare: Secure vs Insecure**
```bash
# Show side-by-side comparison
echo "=== INSECURE (REJECTED) ==="
cat applications/insecure-examples/privileged-pod.yaml | grep -A 5 securityContext

echo "=== SECURE (ACCEPTED) ==="
oc get deployment secure-app -n security-demo -o yaml | grep -A 15 "securityContext:"
```

### 8. Defense-in-Depth Summary (3 minutes)

**Recap the security layers demonstrated:**

| Layer | Control | Failure Demo | Result |
|-------|---------|--------------|--------|
| 1. Pod Security Standards | Namespace-level admission | Privileged pod, root user | ❌ REJECTED |
| 2. Security Context Constraints | OpenShift admission control | Host access, capabilities | ❌ REJECTED |
| 3. Network Policies | Runtime network enforcement | Cross-namespace access | ❌ BLOCKED |
| 4. RBAC | API access control | Developer permissions | ✅ ENFORCED |
| 5. ACM Policies | Multi-cluster governance | Compliance standards | ✅ MONITORED |
| 6. Secure Workload | Best practices | Properly configured app | ✅ RUNNING |

**Key Takeaways:**
1. **Multiple layers** - If one control fails, others provide backup
2. **Fail secure** - Violations are blocked, not just logged
3. **Clear feedback** - Error messages guide developers to fix issues
4. **Shift left** - Security enforced at deployment, not just runtime

### 9. Conclusion (2 minutes)
- Security is enforced automatically, not optional
- Developers get immediate feedback on security violations
- Defense-in-depth prevents single points of failure
- Q&A

## Common Demo Troubleshooting

### Pod fails to start
```bash
oc describe pod <pod-name> -n security-demo
oc logs <pod-name> -n security-demo
```

### Policy not compliant
```bash
oc get policy <policy-name> -n default -o yaml
oc describe policy <policy-name> -n default
```

### Network policy testing
```bash
# Create temporary test pods
oc run test-source -n security-demo --image=registry.access.redhat.com/ubi9/ubi-minimal -- sleep infinity
oc run test-external -n default --image=registry.access.redhat.com/ubi9/ubi-minimal -- sleep infinity
```

## Additional Resources
- Demo recording checklist in `docs/recording-checklist.md`
- Troubleshooting guide in `docs/troubleshooting.md`
