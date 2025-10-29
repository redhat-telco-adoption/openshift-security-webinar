# OpenShift and ACM Security Demo - Presentation Script

**Duration:** 50-55 minutes
**Audience:** Technical stakeholders, architects, security teams
**Goal:** Demonstrate defense-in-depth security in OpenShift with ACM

---

## Before You Begin

### Pre-Demo Checklist
- [ ] Logged into OpenShift cluster as admin
- [ ] Demo namespace deployed: `oc get namespace security-demo`
- [ ] Secure app is running: `oc get pods -n security-demo`
- [ ] Terminal font size is readable for audience
- [ ] Browser tabs prepared (if showing console)

### Terminal Setup
```bash
# Verify connectivity
oc whoami
oc cluster-info

# Set up demo environment
./scripts/setup-demo.sh

# Verify secure app is running
oc get pods -n security-demo
```

---

## Section 1: Introduction (2-3 minutes)

### Opening Statement

> "Good [morning/afternoon], everyone. Today I'm going to demonstrate how Red Hat OpenShift and Advanced Cluster Management provide comprehensive, defense-in-depth security for your containerized applications.
>
> In traditional Kubernetes environments, security is often treated as an afterthought or a checklist item. But what happens when developers accidentally—or intentionally—try to deploy insecure configurations? Today, I'll show you how OpenShift doesn't just warn about security issues—it actively prevents them.
>
> We'll demonstrate six layers of security working together, and more importantly, we'll show what happens when someone tries to bypass these controls. You'll see real security violations being blocked in real-time."

### Set Expectations

> "Here's what we'll cover in the next 50 minutes:
> - Pod Security Standards that block dangerous containers at the door
> - Security Context Constraints that enforce OpenShift-specific policies
> - Network Policies that implement zero-trust networking
> - Role-Based Access Control for API-level authorization
> - **Nine comprehensive ACM Policies** covering pod security, image security, certificate management, etcd encryption, namespace security, network governance, RBAC governance, resource quotas, and vulnerability scanning
> - And we'll see **five actual security violations** being blocked
>
> Let's dive in."

---

## Section 2: Pod Security Standards (8 minutes)

### Transition

> "Let's start with the first line of defense: Pod Security Standards, also known as PSS. This is Kubernetes-native admission control that operates at the namespace level."

### Show Namespace Configuration

**Say:**
> "First, let me show you how we've configured our demo namespace. I'm going to look at the namespace labels."

**Command:**
```bash
oc get namespace security-demo -o yaml | grep -A 5 labels
```

**Say:**
> "Notice these three labels here: `pod-security.kubernetes.io/enforce`, `audit`, and `warn`. These are all set to 'restricted', which is the most secure profile available.
>
> There are three profiles—privileged, baseline, and restricted. We're using restricted, which means this namespace will reject any pod that doesn't meet strict security requirements. The 'enforce' mode means violations are blocked, not just logged."

### FAILURE SCENARIO 1: Privileged Container

**Say:**
> "Now, let me show you what happens when someone tries to deploy a privileged container. Privileged containers can access host resources and essentially bypass container isolation—they're extremely dangerous in production. Let's try to deploy one."

**Command:**
```bash
oc apply -f applications/insecure-examples/privileged-pod.yaml
```

**Expected Output:**
```
Error from server (Forbidden): pods "privileged-pod-test" is forbidden:
violates PodSecurity "restricted:latest": privileged
(container "test" must not set securityContext.privileged=true)
```

**Say:**
> "There it is—immediate rejection. The pod never made it into the cluster. The error message is very clear: 'privileged containers are not allowed.' This isn't a warning, this isn't logged for later review—the deployment is blocked at admission time.
>
> This is critical because it means a developer can't accidentally—or maliciously—deploy a privileged container in this namespace. The security policy is enforced automatically."

### FAILURE SCENARIO 2: Root User

**Say:**
> "Let's try another common security violation: running as the root user. Running containers as root increases the attack surface and violates the principle of least privilege. Let's see what happens."

**Command:**
```bash
oc apply -f applications/insecure-examples/root-user.yaml
```

**Expected Output:**
```
Error: pods "root-user-attack-xxx" is forbidden: violates PodSecurity "restricted:latest":
runAsNonRoot != true (container "attacker" must not set securityContext.runAsNonRoot=false)
```

**Say:**
> "Again, immediate rejection. The system detected that we're trying to run as UID 0—the root user—and blocked it. The restricted profile requires `runAsNonRoot: true` for all containers.
>
> Notice how the error messages are descriptive. They tell developers exactly what's wrong and what needs to be fixed. This is security with good developer experience."

### Contrast with Secure Deployment

**Say:**
> "Now let's see what a properly configured security context looks like."

**Command:**
```bash
oc get deployment secure-app -n security-demo -o yaml | grep -A 10 securityContext
```

**Say:**
> "Here's our secure application. Notice: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, all capabilities dropped. This is how containers should be configured. And because it meets the security requirements, it's running successfully in the cluster."

### Key Takeaway

**Say:**
> "So far we've seen Pod Security Standards in action. This is the first layer of defense—namespace-level admission control that's built into Kubernetes. But OpenShift doesn't stop there. Let's look at the second layer."

---

## Section 3: Security Context Constraints (7 minutes)

### Transition

**Say:**
> "Security Context Constraints, or SCCs, are OpenShift's additional layer of admission control. While Pod Security Standards are Kubernetes-native, SCCs are specific to OpenShift and provide more granular control over security policies."

### Show Available SCCs

**Command:**
```bash
oc get scc
```

**Say:**
> "OpenShift ships with several SCCs by default. Let's look at the restricted SCC we created for this demo."

**Command:**
```bash
oc describe scc demo-restricted-scc | head -30
```

**Say:**
> "This SCC defines very specific constraints: which user IDs are allowed, what Linux capabilities can be used, which volume types are permitted, and whether host access is allowed. Notice that `allowHostNetwork: false`, `allowPrivilegedContainer: false`. These policies are enforced at the API level."

### FAILURE SCENARIO 3: Host Access

**Say:**
> "Let's test this. I'm going to try to deploy a pod that attempts to access the host network, host PID namespace, and host IPC namespace. These are classic container escape techniques—if an attacker compromises a container with host access, they've essentially compromised the entire node. Let's see what happens."

**Command:**
```bash
oc apply -f applications/insecure-examples/host-access.yaml
```

**Expected Output:**
```
Error from server (Forbidden): error when creating: pods is forbidden:
violates PodSecurity "restricted:latest": host namespaces
(hostNetwork=true, hostPID=true, hostIPC=true)
```

**Say:**
> "Blocked immediately. Even if Pod Security Standards somehow missed this—which they didn't—the SCC would provide a second layer of defense. This is defense-in-depth in action. Multiple independent security controls working together."

### FAILURE SCENARIO 4: Dangerous Capabilities

**Say:**
> "Let's try one more SCC violation: adding dangerous Linux capabilities. Capabilities like SYS_ADMIN give containers near-root-level privileges. Let's try to add SYS_ADMIN and NET_ADMIN."

**Command:**
```bash
oc apply -f applications/insecure-examples/dangerous-capabilities.yaml
```

**Expected Output:**
```
Error: pods is forbidden: violates PodSecurity "restricted:latest":
allowPrivilegeEscalation != false
unrestricted capabilities (containers "attacker" must not include "SYS_ADMIN", "NET_ADMIN")
```

**Say:**
> "Again, rejected. The system identified that we're trying to add capabilities that could be used for privilege escalation. In a properly secured OpenShift environment, containers should drop ALL capabilities and only add back the bare minimum they need—if any."

### Show Allowed Capabilities

**Command:**
```bash
oc describe scc restricted | grep -A 5 "Allowed Capabilities"
```

**Say:**
> "As you can see, the restricted SCC allows no additional capabilities. This is the secure default—deny everything, explicitly allow only what's necessary."

### Key Takeaway

**Say:**
> "So we've now seen two layers of admission control: Pod Security Standards and Security Context Constraints. Both operate at the API level, before pods are even scheduled. But security doesn't stop at admission. Let's look at runtime network security."

---

## Section 4: Network Policies (8 minutes)

### Transition

**Say:**
> "Even if a pod gets deployed with proper security contexts, we need to control how it communicates on the network. This is where Network Policies come in. Let's examine the network isolation we've configured."

### Show Network Policies

**Command:**
```bash
oc get networkpolicies -n security-demo
```

**Say:**
> "We have two policies here. Let me show you what they do."

**Command:**
```bash
oc describe networkpolicy deny-all-ingress -n security-demo
```

**Say:**
> "This is a default-deny policy. It blocks ALL incoming traffic to pods in this namespace. This is a zero-trust approach—nothing is allowed unless explicitly permitted."

**Command:**
```bash
oc describe networkpolicy allow-same-namespace -n security-demo
```

**Say:**
> "And this policy explicitly allows traffic between pods in the same namespace. So pods can talk to each other within the namespace, but nothing from outside can reach them. Let's test this."

### FAILURE SCENARIO 5: Cross-Namespace Communication

**Say:**
> "I'm going to deploy a pod in a different namespace and try to access our secure application. In an environment without network policies, this would work. Let's see what happens here."

**Command:**
```bash
oc create namespace test-namespace
oc run test-pod --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
  -n test-namespace -- sleep infinity
```

**Say:**
> "Now I'll wait for the pod to be ready..."

**Command:**
```bash
oc wait --for=condition=ready pod/test-pod -n test-namespace --timeout=60s
```

**Say:**
> "Pod is running. Now let's try to access our secure-app service from this external pod. I'll set a 5-second timeout."

**Command:**
```bash
echo "Attempting cross-namespace access..."
oc exec test-pod -n test-namespace -- curl -m 5 http://secure-app.security-demo.svc.cluster.local:8080
```

**Expected Output:**
```
curl: (28) Connection timed out after 5000 milliseconds
command terminated with exit code 28
```

**Say:**
> "Connection timeout. The network policy blocked this traffic at the network layer. The pod exists, it's running, but it cannot communicate with our secure application. This prevents lateral movement—if an attacker compromises a pod in one namespace, they can't easily pivot to other namespaces."

### SUCCESS SCENARIO: Same-Namespace Communication

**Say:**
> "But pods within the same namespace should be able to communicate. Let me show you."

**Command:**
```bash
oc run test-internal --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
  -n security-demo -- sleep infinity

oc wait --for=condition=ready pod/test-internal -n security-demo --timeout=60s

echo "Attempting same-namespace access..."
oc exec test-internal -n security-demo -- curl -m 5 http://secure-app:8080
```

**Say:**
> "Notice there's no timeout—the connection works. The network policy allows traffic within the namespace but blocks external access. This is micro-segmentation in action."

### Cleanup

**Command:**
```bash
oc delete pod test-internal -n security-demo
oc delete pod test-pod -n test-namespace
oc delete namespace test-namespace
```

**Say:**
> "Let me clean up these test resources."

### Key Takeaway

**Say:**
> "Network Policies provide runtime network isolation. Even if someone manages to deploy a compromised pod, these policies limit what that pod can do on the network. This is critical for containing breaches and preventing lateral movement."

---

## Section 5: RBAC Configuration (5 minutes)

### Transition

**Say:**
> "Now let's talk about who can do what in the cluster. This is where Role-Based Access Control, or RBAC, comes in. RBAC controls access to the Kubernetes API—who can create pods, delete services, view secrets, and so on."

### Show Role

**Command:**
```bash
oc describe role developer-role -n security-demo
```

**Say:**
> "This is a role we've defined for developers. Notice what it allows: get, list, watch, create, update, and patch on specific resources like pods, deployments, and configmaps. But notice what it doesn't allow—no delete on critical resources, no access to secrets in production, no cluster-level permissions.
>
> This follows the principle of least privilege—developers get exactly what they need to do their job, nothing more."

### Show Role Binding

**Command:**
```bash
oc describe rolebinding developer-binding -n security-demo
```

**Say:**
> "This RoleBinding connects the role to a group called 'developers'. Any user in that group inherits these permissions, but only in this namespace. If they try to access resources in another namespace, they'll be denied."

### Key Takeaway

**Say:**
> "RBAC is essential for multi-tenant environments and defense-in-depth. Even if an attacker gets access to a developer's credentials, they're limited to specific namespaces and specific actions. This limits the blast radius of a compromise."

---

## Section 6: ACM Governance Policies (15 minutes)

### Transition

**Say:**
> "Everything we've seen so far applies to a single cluster. But what about organizations running tens or hundreds of OpenShift clusters? How do you enforce consistent security policies across all of them? That's where Red Hat Advanced Cluster Management comes in.
>
> We've implemented a comprehensive governance framework with nine security policies covering everything from pod security to encryption at rest. Let me show you how this scales security governance across your entire infrastructure."

### Show ACM Policies Overview

**Command:**
```bash
oc get policies -n default
```

**Say:**
> "Here are all nine policies in our governance framework. Each one enforces a specific security domain, and together they provide defense-in-depth at the multi-cluster level. Let me walk you through the most critical ones."

### Policy 1: Pod Security Standards

**Say:**
> "First, let's look at how we enforce Pod Security Standards across all clusters."

**Command:**
```bash
oc describe policy policy-pod-security-standards -n default | head -40
```

**Say:**
> "This policy ensures that Pod Security Standards are enforced across all managed clusters. Notice the `remediationAction: enforce`—ACM will automatically create the namespace labels we showed earlier on all target clusters. This means every new cluster in your fleet automatically gets the same security baseline we demonstrated earlier."

### Policy 2: Image Security

**Say:**
> "Next is image security—one of the most critical supply chain controls. Let me show you."

**Command:**
```bash
oc describe policy policy-image-security -n default | head -50
```

**Say:**
> "This policy has three enforcement rules:
>
> First, it blocks container images with the `:latest` tag in production namespaces. Why? Because 'latest' is mutable—someone could push a malicious image and your pods would pull it on restart. Production needs immutability.
>
> Second, it enforces trusted registries. Only images from Red Hat registries or your internal registry are allowed. This prevents supply chain attacks via compromised public images.
>
> Third, it enforces proper `imagePullPolicy` to prevent stale cached images.
>
> Notice this uses Go templates to dynamically evaluate running pods across all clusters. This is continuous compliance monitoring, not a one-time check."

### Policy 3: Certificate Management

**Say:**
> "Expired certificates cause production outages. Let's see how ACM prevents this."

**Command:**
```bash
oc describe policy policy-certificate-management -n default | grep -A 20 "spec:"
```

**Say:**
> "This policy monitors certificate expiration across all clusters:
> - API server certificates: Must have at least 30 days before expiration
> - Ingress certificates: Must have at least 30 days
> - Service certificates: Must have at least 10 days
> - CA certificates: Must have at least 365 days
>
> If a certificate is approaching expiration, the policy goes non-compliant and alerts your team. This is proactive certificate management—you find out before your customers do."

### Policy 4: etcd Encryption (Critical for Compliance)

**Say:**
> "Now let's look at one of the most important compliance controls: encryption at rest for etcd. This is where all your Kubernetes secrets are stored."

**Command:**
```bash
oc describe policy policy-etcd-encryption -n default
```

**Say:**
> "This policy has four checks:
>
> First, it verifies that AES-CBC encryption is enabled in the APIServer configuration.
>
> Second, it ensures the encryption configuration secret exists in `openshift-config`.
>
> Third, it monitors the encryption progress status—encryption is a background process that can take time.
>
> Fourth, it verifies that encryption is completed and active.
>
> This is critical for compliance frameworks like PCI-DSS, HIPAA, and SOC 2. Notice that this policy only targets production clusters—we use placement rules to apply policies selectively."

**Command:**
```bash
oc get placementrule placement-production-clusters -n default -o yaml
```

**Say:**
> "See this placement rule? It only selects clusters labeled with `environment=prod` or `environment=production`. Development clusters don't get this policy—they don't need the overhead. This is intelligent, context-aware governance."

### Policy 5: RBAC Governance

**Say:**
> "RBAC misconfigurations are a common attack vector. Let me show you how we prevent them at scale."

**Command:**
```bash
oc describe policy policy-rbac-governance -n default | head -60
```

**Say:**
> "This policy has six RBAC controls, and they're all about preventing privilege escalation:
>
> Control 1: Prevents `cluster-admin` from being bound to service accounts outside of system namespaces. If an attacker compromises a pod, they shouldn't automatically get cluster-admin.
>
> Control 2: Detects wildcard permissions in roles—things like `verbs: ['*']` or `resources: ['*']`. These are overly permissive and violate least-privilege.
>
> Control 3: Detects privilege escalation verbs like `escalate` and `bind` on RBAC resources. These allow users to grant themselves more permissions.
>
> Control 4: Requires all pods to use dedicated service accounts, not the default service account.
>
> Control 5: Disables `automountServiceAccountToken` unless explicitly needed—reduces API credential exposure.
>
> Control 6: Automatically creates read-only viewer roles in production namespaces.
>
> Notice the use of Go templates to dynamically scan all ClusterRoleBindings and Roles. This isn't static policy—it's continuous detection of misconfigurations."

### Policy 6: Network Policy Governance

**Say:**
> "We demonstrated Network Policies earlier at the single-cluster level. Let's see how ACM ensures they're deployed everywhere."

**Command:**
```bash
oc describe policy policy-network-security -n default | grep -A 15 "deny-all"
```

**Say:**
> "This policy enforces zero-trust networking at scale:
> - Default-deny ingress in all application namespaces
> - Default-deny egress in production namespaces
> - Explicit allow rules for DNS resolution
> - Explicit allow rules for monitoring
> - No cross-namespace communication without explicit policy
>
> If a cluster admin forgets to deploy network policies in a new namespace, ACM detects it and either alerts or auto-remediates. You get consistent micro-segmentation across your entire fleet."

### Policy 7: Resource Quotas (DoS Prevention)

**Say:**
> "Resource exhaustion is a denial-of-service attack. Let's see how we prevent it."

**Command:**
```bash
oc describe policy policy-resource-quotas -n default | grep -A 10 "ResourceQuota"
```

**Say:**
> "This policy enforces resource limits at the namespace level:
> - Namespace quotas: Maximum CPU and memory per namespace
> - Pod limits: Maximum resources per pod
> - Container limits: Default CPU and memory for containers
> - Priority classes: Scheduling priorities for critical workloads
>
> This prevents a single namespace or pod from consuming all cluster resources. It enables fair multi-tenancy and prevents noisy neighbor problems."

### Policy 8: Namespace Security Baseline

**Say:**
> "Let me show you a policy that ties multiple controls together."

**Command:**
```bash
oc describe policy policy-namespace-security -n default | head -50
```

**Say:**
> "This policy ensures that ALL user namespaces have a security baseline:
> - Pod Security labels must be set (restricted for production)
> - NetworkPolicies must exist (default-deny)
> - ResourceQuotas must exist
> - Workloads cannot be deployed in the `default` namespace
> - Ownership and environment labels are required
>
> This is namespace-level governance. It prevents 'unprotected' namespaces from being created. Every namespace automatically gets a security baseline."

### Policy 9: Container Security Operator

**Say:**
> "Finally, let's look at vulnerability scanning."

**Command:**
```bash
oc describe policy policy-container-security-operator -n default
```

**Say:**
> "This policy ensures the Container Security Operator is deployed on all clusters. This operator:
> - Scans container images for CVEs
> - Integrates with Red Hat's vulnerability database
> - Reports vulnerabilities in the OpenShift console
> - Enables proactive patching
>
> The policy verifies the operator namespace exists and the operator is running. If someone accidentally uninstalls it, ACM detects the drift and alerts."

### Show Policy Compliance Dashboard

**Command:**
```bash
oc get policies -n default -o custom-columns=NAME:.metadata.name,COMPLIANT:.status.compliant
```

**Say:**
> "Here's the compliance dashboard. Each policy shows whether clusters are compliant or not. In a real multi-cluster environment, you'd see which specific clusters are violating which policies.
>
> ACM continuously monitors compliance. If a cluster drifts out of compliance—someone manually changes a setting, disables a control, or misconfigures a namespace—ACM detects it within minutes and either alerts you or automatically remediates it."

### Show Placement Strategy

**Command:**
```bash
oc get placementrule -n default
```

**Say:**
> "We use two placement strategies:
>
> `placement-all-clusters`: Applies to all managed clusters with dev or prod labels. Used for policies like Pod Security Standards, RBAC governance, and network policies.
>
> `placement-production-clusters`: Applies only to production clusters. Used for policies like etcd encryption that have performance or complexity implications.
>
> This gives you fine-grained control—different security postures for different environments, all managed centrally."

### Compliance Mapping

**Say:**
> "These nine policies map to multiple compliance frameworks:"

**Command:**
```bash
oc get policies -n default -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.policy\.open-cluster-management\.io/standards}{"\n"}{end}' | column -t
```

**Say:**
> "You can see annotations for NIST SP 800-53, CIS Kubernetes Benchmark, PCI-DSS, HIPAA. These aren't just security controls—they're compliance evidence. When auditors ask 'How do you enforce encryption at rest?' you show them the etcd encryption policy. When they ask 'How do you prevent privilege escalation?' you show them the RBAC governance policy.
>
> ACM provides automated compliance reporting. You can export policy status for SOC 2 audits, PCI-DSS assessments, or HIPAA reviews."

### Key Takeaway

**Say:**
> "ACM Policies are how you scale security governance:
>
> **Define once, enforce everywhere**: Write a policy once, apply it to 100 clusters.
>
> **Continuous compliance**: Not a point-in-time audit, but continuous monitoring and drift detection.
>
> **Intelligent targeting**: Different policies for different environments using placement rules.
>
> **Automated remediation**: Policies can detect violations or automatically fix them.
>
> **Compliance as code**: Map policies to NIST, CIS, PCI-DSS, HIPAA—compliance becomes automated.
>
> This is the difference between securing one cluster manually and securing an entire fleet programmatically. This is governance at scale."

---

## Section 7: Secure vs Insecure Comparison (5 minutes)

### Transition

**Say:**
> "We've seen multiple security violations being blocked. Now let's contrast those insecure examples with a properly configured application. Let me show you what security best practices look like in production."

### Show Secure Application Security Context

**Command:**
```bash
oc get deployment secure-app -n security-demo -o yaml | grep -A 30 securityContext
```

**Say while scrolling:**
> "Look at this security context. This is how every production container should be configured:
>
> - `runAsNonRoot: true` — Never run as root
> - `readOnlyRootFilesystem: true` — Prevents attackers from modifying binaries
> - `allowPrivilegeEscalation: false` — Blocks privilege escalation attempts
> - `capabilities.drop: ALL` — Drops all Linux capabilities, zero privileges
> - `seccompProfile: RuntimeDefault` — Enables system call filtering
>
> And notice these are set at both the pod level AND the container level. Defense-in-depth applies here too."

### Check Application Status

**Command:**
```bash
oc get pods -n security-demo
oc logs -l app=secure-app -n security-demo --tail=10
```

**Say:**
> "And this application is running successfully. It's secure AND functional. Security doesn't mean sacrificing functionality—it means doing things the right way from the start."

### Side-by-Side Comparison

**Say:**
> "Let me show you a direct comparison."

**Command:**
```bash
echo "=== INSECURE (REJECTED) ==="
cat applications/insecure-examples/privileged-pod.yaml | grep -A 5 securityContext

echo ""
echo "=== SECURE (ACCEPTED) ==="
oc get deployment secure-app -n security-demo -o yaml | grep -A 15 "securityContext:"
```

**Say:**
> "One has `privileged: true`—blocked. The other follows best practices—running in production. The difference is clear."

---

## Section 8: Defense-in-Depth Summary (3 minutes)

### Transition

**Say:**
> "Let me summarize what we've seen today. I'm going to pull up a table that shows all six security layers and the violations we demonstrated."

### Show Summary Table

**Say:**
> "Here's the complete picture of defense-in-depth:

| Layer | What It Does | What We Blocked/Enforced |
|-------|-------------|-------------------------|
| **Pod Security Standards** | Namespace-level admission control | Privileged containers, root users |
| **Security Context Constraints** | OpenShift admission control | Host access, dangerous capabilities |
| **Network Policies** | Runtime network isolation | Cross-namespace communication |
| **RBAC** | API access control | Enforced developer permissions |
| **ACM Policies (9 policies)** | Multi-cluster governance | Pod security, image security, certificates, etcd encryption, namespace security, network policies, RBAC governance, resource quotas, vulnerability scanning |
| **Secure Workloads** | Application best practices | Properly configured, running in prod |

**Say:**
> "Every one of these layers is independent. If one somehow fails, the others still protect you. That's defense-in-depth.
>
> Notice what happens when an attacker tries to deploy a malicious workload:
> - Layer 1 blocks it at admission (Pod Security Standards)
> - Layer 2 blocks it at admission (SCC)
> - Layer 3 isolates it on the network (Network Policies)
> - Layer 4 limits API access (RBAC)
> - Layer 5 detects policy violations (ACM)
> - Layer 6 shows what security should look like (Secure workload)
>
> The attacker has to defeat ALL six layers. We only need one to succeed."

### Key Principles

**Say:**
> "Four key principles we demonstrated today:
>
> 1. **Multiple Independent Layers** — No single point of failure
> 2. **Fail Secure** — Violations are blocked, not just logged
> 3. **Clear Feedback** — Error messages tell developers how to fix issues
> 4. **Shift Left** — Security is enforced at deployment time, not discovered in production
>
> This is security by default, not security as an afterthought."

---

## Section 9: Conclusion (2-3 minutes)

### Summary

**Say:**
> "Let me wrap up what we've seen today.
>
> We demonstrated how Red Hat OpenShift and Advanced Cluster Management provide comprehensive, automated security enforcement. You saw five real security violations blocked in real-time—not warnings, not alerts for later review, but immediate rejection at the API level.
>
> Beyond that, you saw nine ACM governance policies that scale these controls across entire fleets of clusters—from pod security to encryption at rest, from RBAC governance to certificate management. This is security at enterprise scale.
>
> This security is:
> - **Automatic** — It's enforced by the platform, not dependent on developers remembering to follow guidelines
> - **Defense-in-Depth** — Multiple independent layers working together
> - **Scalable** — ACM brings this to fleets of clusters with centralized governance
> - **Developer-Friendly** — Clear error messages guide developers to secure configurations
>
> The result is a platform where secure deployments work, insecure deployments are blocked, and your security team can sleep at night."

### Call to Action

**Say:**
> "If you're running Kubernetes in production, you need these controls. If you're evaluating container platforms, this is the level of security you should expect.
>
> All the manifests and policies I demonstrated today are available in the demo repository. You can deploy this in your own environment and test these security controls yourself."

### Open for Questions

**Say:**
> "I'd be happy to take questions now. And if you want to see any specific security scenario in more detail, I can dive deeper into any of these layers."

---

## Q&A Preparation

### Common Questions and Answers

**Q: "What about performance impact of all these security controls?"**

A: "Great question. The admission controls—Pod Security Standards and SCCs—operate at the API level before scheduling, so there's no runtime performance impact. Network Policies are implemented by the CNI plugin and the overhead is minimal—typically sub-millisecond. ACM policy evaluation happens on the hub cluster, not on the managed clusters. The bottom line is that security done right shouldn't noticeably impact application performance."

**Q: "Can developers override these policies in an emergency?"**

A: "That depends on your organization's governance model. Some options:
- Create a separate namespace with more permissive policies for specific use cases
- Use ACM's 'inform' mode to alert without blocking during testing
- Implement a break-glass procedure where cluster admins can temporarily relax constraints
But the key is that this should be an explicit, audited decision—not the default."

**Q: "How do you handle legacy applications that require privileged access?"**

A: "You have a few options:
- Use a less restrictive namespace with the 'privileged' or 'baseline' Pod Security profile
- Grant specific service accounts access to less restrictive SCCs
- Work with the application vendor to eliminate the need for privileged access
- Use Red Hat's migration tools to identify why the app needs privileges and remediate
The goal is to minimize the number of privileged workloads and isolate them when necessary."

**Q: "Does this work with other Kubernetes distributions?"**

A: "Pod Security Standards and Network Policies are Kubernetes-native, so they work everywhere. Security Context Constraints are OpenShift-specific—they predate Pod Security Standards and provide more granular control. ACM works with any CNCF-conformant Kubernetes distribution. So while the exact implementation varies, the principles of defense-in-depth security apply to any Kubernetes platform."

**Q: "How do you handle compliance requirements like PCI-DSS or HIPAA?"**

A: "ACM includes pre-built policy sets for common compliance frameworks—PCI-DSS, HIPAA, NIST 800-53, CIS benchmarks. You can deploy these policies across your fleet and get continuous compliance reporting. For example, the Pod Security Standards we showed map directly to CIS Kubernetes benchmark controls. Red Hat also provides the Compliance Operator which runs OpenSCAP scans on cluster nodes. The nine policies we demonstrated today are all annotated with compliance mappings—when auditors ask how you enforce specific controls, you show them the ACM policy status dashboard."

**Q: "Which of the nine ACM policies should we implement first?"**

A: "Start with these three in order:
1. **Pod Security Standards policy**: This is foundational—it blocks the most common container security violations like privileged containers and root users. Set it to 'enforce' mode.
2. **Network Policy Governance**: Implement default-deny network policies to prevent lateral movement. Start with 'inform' mode to see what breaks, then switch to 'enforce'.
3. **RBAC Governance policy**: This detects privilege escalation risks and overly permissive roles. Run it in 'inform' mode initially to identify issues without blocking operations.

Once those are stable, add the others based on your compliance requirements. For example, if you're subject to PCI-DSS or HIPAA, the etcd encryption policy becomes critical."

**Q: "What about container image scanning?"**

A: "Red Hat Advanced Cluster Security—which can integrate with ACM—provides comprehensive image scanning. It scans for CVEs, misconfigurations, secrets in images, and policy violations. You can configure admission control to block images with critical vulnerabilities or prevent images from untrusted registries. RHACS integrates with your CI/CD pipeline to shift security left even further."

---

## Post-Demo Actions

### Cleanup (if needed)
```bash
# Clean up demo resources
./scripts/cleanup-demo.sh

# Verify cleanup
oc get namespace security-demo
# Should show: NotFound or Terminating
```

### Provide Resources

**Say:**
> "I'll share these resources with you:
> - Demo repository with all manifests: [your repo URL]
> - OpenShift security documentation
> - ACM policy examples and governance documentation
> - Red Hat's security best practices guide"

---

## Presentation Tips

### Pacing
- **Speak slowly** when showing errors—let the audience read and understand
- **Pause after blocking a violation** to let the impact sink in
- **Use transitions** to connect sections logically

### Emphasis Points
- When security blocks something: "**Immediate rejection**"
- When comparing layers: "**Defense-in-depth**"
- When showing secure app: "**This is how it should be done**"

### Body Language
- Lean forward when showing violations
- Gesture toward the screen when highlighting errors
- Make eye contact when delivering key takeaways

### Technical Tips
- Increase terminal font size: `Cmd +` or `Ctrl +`
- Use clear terminal colors (white text on dark background)
- Close unnecessary applications
- Disable notifications
- Have a backup plan if cluster is unavailable

### Time Management
- If running short: Skip RBAC section or shorten ACM section
- If running long: Combine failure scenarios 3 & 4
- Always leave 5 minutes for Q&A

---

## Emergency Scenarios

### If a command fails unexpectedly:

**Say:**
> "Interesting—that's not the expected behavior. Let me check what's happening here..."

```bash
oc get events -n security-demo --sort-by='.lastTimestamp' | head -10
```

**Say:**
> "In a real demo environment, we'd troubleshoot this, but in the interest of time, the key point is [restate the principle]."

### If the cluster is unavailable:

**Say:**
> "It looks like we're having cluster connectivity issues. Rather than troubleshoot live, let me show you the expected output and walk through what would happen..."

Then narrate through the demo showing the YAML files and explaining outcomes.

### If demo takes longer than expected:

**Say:**
> "I see we're running close on time. Let me jump to the defense-in-depth summary where we'll see all these layers working together, and then we'll have time for your questions."

---

**End of Presentation Script**
