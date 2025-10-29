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

### 6. ACM Governance Policies (15 minutes)

**Overview of ACM Policy Framework:**

ACM (Advanced Cluster Management) provides centralized, multi-cluster security governance. Policies can be applied across hundreds of clusters from a single control plane.

**Show all ACM policies:**
```bash
oc get policies -n default
```

**Check policy compliance across clusters:**
```bash
oc get policies -A
```

**Key points to highlight:**
- Multi-cluster governance at scale (manage 100+ clusters from one place)
- Automated compliance checking and remediation
- Policy templating with Go templates for dynamic checks
- Remediation modes: "inform" (detect only) vs "enforce" (auto-remediate)
- Policy placement with cluster selectors (dev/prod, region, compliance zone)

#### 6.1 Pod Security Standards Policy

**Show Pod Security Standards enforcement policy:**
```bash
oc describe policy policy-pod-security-standards -n default
```

**Explain:**
- Ensures all target clusters enforce Pod Security Standards
- Creates/validates namespace labels automatically
- Enforces restricted profile for security-demo namespace
- Applied via PlacementRule to dev and prod clusters

#### 6.2 Image Security Policy (NEW)

**Show image security governance:**
```bash
oc describe policy policy-image-security -n default
```

**Key features demonstrated:**
- ✅ Blocks `:latest` tags in production namespaces
- ✅ Enforces trusted registries (Red Hat registries, internal registries only)
- ✅ Requires imagePullPolicy to prevent stale cached images
- ✅ Uses Go templates for dynamic policy evaluation across all pods

**Test scenario - Check for latest tags:**
```bash
# This policy detects pods using :latest tag in production
oc get policy policy-image-security -n default -o jsonpath='{.status.compliant}'
```

**Explain:**
- Prevents supply chain attacks via untrusted images
- Ensures image immutability (no `:latest` in prod)
- Enforces organizational security standards

#### 6.3 Certificate Management Policy (NEW)

**Show certificate expiration monitoring:**
```bash
oc describe policy policy-certificate-management -n default
```

**Explain:**
- Monitors API server, ingress controller, and service certificates
- Alerts on certificates expiring within 30 days (configurable)
- Ensures cert-manager is deployed for automated renewal
- Prevents production outages due to expired certificates

**Check certificate status:**
```bash
# View certificate policy compliance details
oc get policy policy-certificate-management -n default -o yaml | grep -A 10 status
```

#### 6.4 etcd Encryption Policy (NEW)

**Show data-at-rest encryption enforcement:**
```bash
oc describe policy policy-etcd-encryption -n default
```

**Key points:**
- Enforces encryption of Secrets and sensitive data in etcd database
- Critical for compliance requirements (PCI-DSS, HIPAA, SOC 2)
- Validates encryption configuration exists and is active
- Monitors encryption progress status
- Applied ONLY to production clusters via PlacementRule

**Check encryption status:**
```bash
# Production clusters should show Encrypted=True
oc get policy policy-etcd-encryption -n default -o jsonpath='{.status.status[*].clustername}'
```

**Explain:**
- Secrets are encrypted at rest using AES-CBC
- Protects against storage compromise scenarios
- Required for regulatory compliance

#### 6.5 RBAC Governance Policy (NEW)

**Show RBAC best practices enforcement:**
```bash
oc describe policy policy-rbac-governance -n default
```

**Key security controls:**
- ❌ Prevents cluster-admin binding to service accounts (except system namespaces)
- ❌ Detects wildcard (`*`) permissions in roles
- ❌ Blocks privilege escalation capabilities (escalate, bind verbs)
- ✅ Requires dedicated service accounts (not `default`)
- ✅ Disables auto-mount of service account tokens

**Explain:**
- These policies prevent common privilege escalation attacks
- Enforces least-privilege principle across all managed clusters
- Detects overly permissive roles that violate security standards
- Goes beyond Kubernetes RBAC to add governance layer

**Show violation example:**
```bash
# Check for any cluster-admin violations
oc get policy policy-rbac-governance -n default -o jsonpath='{.status.details[*].history[0].message}'
```

#### 6.6 Resource Quota Policy (NEW)

**Show resource governance:**
```bash
oc describe policy policy-resource-quotas -n default
```

**Explain:**
- Prevents resource exhaustion attacks (DoS prevention)
- Enforces CPU/memory limits at namespace level
- Requires resource requests/limits on ALL pods
- Implements priority classes for workload scheduling
- Ensures fair resource allocation across teams

**Verify quota enforcement:**
```bash
oc get resourcequota -n security-demo
oc get limitrange -n security-demo
oc describe limitrange pod-limit-range -n security-demo
```

**Key points:**
- Pods without resource limits are rejected
- Prevents "noisy neighbor" problems
- Enables cost allocation and chargeback

#### 6.7 Namespace Security Policy (NEW)

**Show namespace-level security enforcement:**
```bash
oc describe policy policy-namespace-security -n default
```

**Key features:**
- ✅ Requires Pod Security labels on ALL user namespaces
- ✅ Enforces restricted PSS for production namespaces
- ✅ Mandates default-deny NetworkPolicies
- ❌ Prevents workload deployment in `default` namespace
- ✅ Requires ownership and environment labels for governance

**Explain:**
- Ensures consistent security baseline across all clusters
- No "unprotected" namespaces can exist
- Enables multi-tenancy with strong isolation

#### 6.8 Network Policy Governance (NEW)

**Show network security enforcement:**
```bash
oc describe policy policy-network-security -n default
```

**Explain:**
- Implements zero-trust networking model
- Enforces default-deny for BOTH ingress and egress
- Allows only necessary traffic (DNS, monitoring)
- Prevents cross-namespace communication
- Restricts egress to external networks in production

**Verify network policy compliance:**
```bash
oc get networkpolicies -n security-demo
oc describe networkpolicy deny-all-ingress -n security-demo
oc describe networkpolicy deny-all-egress -n security-demo
```

**Key points:**
- Zero-trust: deny by default, allow explicitly
- Micro-segmentation at the pod level
- East-west traffic control (not just north-south)

#### 6.9 Container Security Operator Policy

**Show vulnerability scanning automation:**
```bash
oc describe policy policy-container-security-operator -n default
```

**Explain:**
- Automatically deploys container security scanning operator
- Integrates with Red Hat Quay vulnerability database
- Provides image vulnerability reports in OpenShift console
- Continuous monitoring of deployed container images
- Detects CVEs in running containers

**ACM Policy Summary:**

ACM provides a powerful governance framework that:
1. **Scales** - Manage security across 100+ clusters from one control plane
2. **Prevents** - Enforces security BEFORE violations occur
3. **Detects** - Continuously monitors for configuration drift
4. **Remediates** - Can automatically fix non-compliant resources
5. **Reports** - Provides compliance dashboards for auditors and security teams

**Policy Count:**
- 8 comprehensive policies covering:
  - Pod security, image security, certificates
  - Data encryption, RBAC, resource management
  - Namespace isolation, network segmentation
  - Vulnerability scanning

**Show multi-cluster view (if ACM UI available):**
- Navigate to ACM console → Governance → Policies
- Show policy compliance status across all clusters
- Demonstrate cluster-specific violations and auto-remediation
- Export compliance reports for audit purposes

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
