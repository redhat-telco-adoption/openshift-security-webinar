# OpenShift and ACM Security Demo - Presentation Script

**Duration:** 60-65 minutes
**Audience:** Technical stakeholders, architects, security teams
**Goal:** Demonstrate defense-in-depth security in OpenShift with ACM

## Presentation Structure

| Section | Topic | Duration |
|---------|-------|----------|
| 1 | Introduction and Overview | 2-3 min |
| 2 | Pod Security Standards (PSS) | 10 min |
| 3 | Security Context Constraints (SCC) | 9 min |
| 4 | Network Policies | 10 min |
| 5 | RBAC Configuration | 7 min |
| 6 | ACM Governance Policies (9 policies) | 17 min |
| 7 | Secure vs Insecure Comparison | 5 min |
| 8 | Defense-in-Depth Summary | 3 min |
| 9 | Conclusion and Call to Action | 2-3 min |
| | Q&A | 5-10 min |
| **Total** | | **60-65 min** |

---

## Key Security Concepts

Before presenting, familiarize yourself with these core concepts that underpin the demo:

### Defense-in-Depth
Multiple independent security layers working together. If one layer fails or is bypassed, other layers continue to provide protection. This demo shows six layers: PSS, SCC, Network Policies, RBAC, ACM Policies, and secure workload configuration.

### Shift-Left Security
Catching security violations early in the deployment pipeline rather than discovering them in production. Admission controllers (PSS and SCC) enforce security before pods are created, not after they're running.

### Zero-Trust Networking
"Never trust, always verify." Network Policies implement default-deny rules where all traffic is blocked unless explicitly allowed. This prevents lateral movement after a breach.

### Least Privilege
Grant the minimum permissions necessary for a user or workload to function. Applied in RBAC (API access), SCCs (pod capabilities), and ACM policies (cluster-level controls).

### Admission Control vs Runtime Security
- **Admission Control**: Security checks that happen when resources are created/updated (PSS, SCC)
- **Runtime Security**: Security that operates while workloads are running (Network Policies, SELinux)

### Policy as Code
Security policies are defined declaratively as YAML/code, version-controlled, and automatically enforced. ACM policies demonstrate this at scale across cluster fleets.

### Continuous Compliance
Not a point-in-time audit, but ongoing monitoring and enforcement. ACM continuously evaluates policies and detects drift within minutes.

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

> "Here's what we'll cover in the next 60 minutes:
> - Pod Security Standards that block dangerous containers at the door
> - Security Context Constraints that enforce OpenShift-specific policies
> - Network Policies that implement zero-trust networking
> - Role-Based Access Control for API-level authorization
> - **Nine comprehensive ACM Policies** covering pod security, image security, certificate management, etcd encryption, namespace security, network governance, RBAC governance, resource quotas, and vulnerability scanning
> - And we'll see **five actual security violations** being blocked
>
> Let's dive in."

---

## Section 2: Pod Security Standards (10 minutes)

### Transition

**Say:**
> "Let's start with the first line of defense: Pod Security Standards, also known as PSS. This is Kubernetes-native admission control that operates at the namespace level.
>
> Before we dive into the demo, let me explain what Pod Security Standards actually are and why they're critical."

### Background: What are Pod Security Standards?

**Say:**
> "Pod Security Standards are a Kubernetes-native way to enforce security best practices for pod specifications. Think of them as a built-in security guard at the door of your namespace.
>
> They were introduced to replace the deprecated PodSecurityPolicy, and they work by evaluating pod specifications against predefined security profiles. If a pod doesn't meet the requirements of the profile assigned to the namespace, it's rejected before it ever gets scheduled.
>
> This is **admission control**—security happens at the API level, not at runtime. By the time a pod is running, it's already been validated against these standards."

### The Three Security Profiles

**Say:**
> "There are three profiles, each with increasing security restrictions:
>
> **Privileged**: Unrestricted—allows everything, including dangerous configurations. This is for system-level workloads like CNI plugins and storage drivers that need host access.
>
> **Baseline**: Minimally restrictive—prevents the most common privilege escalations, like privileged containers and host path mounts. This is a good starting point for most applications.
>
> **Restricted**: Heavily restricted—enforces current pod hardening best practices. This requires running as non-root, dropping all capabilities, using read-only root filesystems, and more. This is what production workloads should aim for.
>
> We're using the **restricted** profile in this demo because it represents security best practices."

### The Three Enforcement Modes

**Say:**
> "Each profile can be applied in three different modes:
>
> **Enforce**: Violations are rejected—the pod will not be created. This is active enforcement.
>
> **Audit**: Violations are allowed but logged to the audit log. This is useful for understanding what would break before enforcing.
>
> **Warn**: Violations are allowed but a warning is returned to the user. This gives immediate feedback without blocking.
>
> You can use all three modes simultaneously on a namespace. For example, you might enforce 'baseline' while auditing and warning on 'restricted' to see what would need to change to move to the stricter profile."

### Show Namespace Configuration

**Say:**
> "Now let's see this in action. First, let me show you how we've configured our demo namespace."

**Command:**
```bash
oc get namespace security-demo -o yaml | grep -A 5 labels
```

**Say:**
> "Notice these three labels here: `pod-security.kubernetes.io/enforce`, `audit`, and `warn`. These are all set to 'restricted', which is the most secure profile available.
>
> All three modes are set to 'restricted', which means:
> - Violations will be **blocked** (enforce)
> - Violations will be **logged** in the audit log (audit)
> - Users will see **warnings** in their kubectl output (warn)
>
> This gives us defense-in-depth even within the Pod Security Standards themselves."

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

## Section 3: Security Context Constraints (9 minutes)

### Transition

**Say:**
> "We've seen Pod Security Standards—the Kubernetes-native layer. Now let's talk about Security Context Constraints, or SCCs, which are OpenShift's additional layer of admission control.
>
> Let me explain what SCCs are and why OpenShift provides this extra layer."

### Background: What are Security Context Constraints?

**Say:**
> "Security Context Constraints are OpenShift's way of controlling what security-sensitive actions pods and containers can perform. They were created before Pod Security Standards existed and provide more fine-grained control than PSS.
>
> Think of SCCs as a more detailed security policy engine. While Pod Security Standards say 'you can't run privileged containers,' SCCs let you specify exactly which user IDs are allowed, which specific Linux capabilities can be used, which volume types are permitted, whether SELinux contexts are enforced, and much more.
>
> SCCs are also **admission controllers**, meaning they evaluate pod specifications before pods are created. But they work differently than PSS."

### How SCCs Work: The Selection Process

**Say:**
> "Here's how it works: When you try to create a pod, OpenShift looks at:
> 1. The service account the pod is using
> 2. All SCCs that service account has access to
> 3. The pod's security context requirements
>
> Then OpenShift picks the **most restrictive SCC** that allows the pod to run. This is important—it automatically uses the most secure option available.
>
> If no SCC matches the pod's requirements, the pod is rejected. This is the security gate in action."

### SCCs vs Pod Security Standards

**Say:**
> "You might be wondering: why have both PSS and SCCs? Great question.
>
> Pod Security Standards are **broad categories**—privileged, baseline, or restricted. They're simple and portable across any Kubernetes cluster.
>
> SCCs are **fine-grained policies**—you can create custom SCCs that say 'this specific service account can use this specific capability for this specific use case.' They're more flexible and powerful, but they're OpenShift-specific.
>
> Together, they provide **defense-in-depth**. Even if one layer has a misconfiguration, the other layer still protects you."

### Show Available SCCs

**Say:**
> "Let's look at what SCCs are available in this cluster."

**Command:**
```bash
oc get scc
```

**Say:**
> "OpenShift ships with several default SCCs:
> - **restricted**: The most secure—used for most applications
> - **restricted-v2**: The updated version aligned with PSS restricted profile
> - **nonroot**: Allows running as any non-root user
> - **hostnetwork**: Allows host network access
> - **privileged**: Allows everything—only for system workloads
>
> Now let's look at the custom restricted SCC we created for this demo."

**Command:**
```bash
oc describe scc demo-restricted-scc | head -30
```

**Say:**
> "Look at these constraints. This SCC defines:
> - **Allow Privileged**: false—no privileged containers
> - **Allow Host Network**: false—no access to host networking
> - **Allow Host PID/IPC**: false—no access to host process or IPC namespaces
> - **Allow Host Ports**: false—can't bind to host ports
> - **Allowed Capabilities**: none—no Linux capabilities allowed
> - **Run As User Strategy**: MustRunAsNonRoot—must run as non-root
> - **SELinux Context Strategy**: MustRunAs—SELinux labels enforced
> - **FSGroup Strategy**: MustRunAs—file system group IDs restricted
>
> This is a comprehensive security policy. Every aspect of pod security is explicitly controlled."

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

## Section 4: Network Policies (10 minutes)

### Transition

**Say:**
> "We've seen two layers of admission control—PSS and SCCs. These prevent insecure pods from being created in the first place. But what about runtime security? What happens after a pod is running?
>
> This is where Network Policies come in. Let me explain what they are and why they're critical for defense-in-depth."

### Background: What are Network Policies?

**Say:**
> "Network Policies are Kubernetes-native firewall rules for your pods. They control traffic flow at the IP address and port level—Layer 3 and Layer 4 in the OSI model.
>
> Think of them as distributed firewall rules that move with your workloads. Instead of configuring traditional firewalls based on IP addresses—which constantly change in Kubernetes—you define policies based on pod labels, namespaces, and CIDR blocks.
>
> This is **micro-segmentation**—fine-grained network isolation at the pod level, not just at the perimeter."

### The Default-Allow Problem

**Say:**
> "Here's a critical security fact about Kubernetes: **by default, all pods can communicate with all other pods in the cluster**. This is a 'default-allow' posture.
>
> That means if an attacker compromises a pod in your dev namespace, they can immediately start probing and attacking pods in your production namespace, your database namespace, your payment processing namespace—everything.
>
> This is called **lateral movement**, and it's how attackers expand their foothold after initial compromise. The Kubernetes default makes lateral movement trivially easy.
>
> Network Policies let us flip this to **default-deny**, which is the zero-trust approach."

### How Network Policies Work

**Say:**
> "Network Policies use label selectors to define:
> - **Which pods** the policy applies to (using `podSelector`)
> - **Which sources** can send traffic to those pods (using `ingress` rules)
> - **Which destinations** those pods can send traffic to (using `egress` rules)
>
> They're implemented by your CNI plugin—the container network interface. In OpenShift, that's OVN-Kubernetes or OpenShift SDN. The CNI plugin programs these rules into the network data plane, so enforcement happens at the Linux kernel level with minimal overhead.
>
> This is not application-layer filtering—it's network-layer enforcement, which makes it very efficient and very difficult to bypass."

### Zero-Trust Networking Strategy

**Say:**
> "Our strategy is:
> 1. **Default-deny everything**—start with a policy that blocks all ingress and egress
> 2. **Explicitly allow required traffic**—only permit the specific flows your application needs
> 3. **Apply policies consistently**—use the same patterns across all namespaces
>
> This is zero-trust networking: trust nothing by default, verify everything explicitly. Let's see this in action."

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

## Section 5: RBAC Configuration (7 minutes)

### Transition

**Say:**
> "We've secured pod admission and runtime networking. Now let's talk about controlling **who can do what** in the cluster. This is where Role-Based Access Control, or RBAC, comes in.
>
> Let me explain what RBAC is and why it's essential for multi-tenant Kubernetes environments."

### Background: What is RBAC?

**Say:**
> "RBAC—Role-Based Access Control—is Kubernetes' authorization system. It controls access to the Kubernetes API server, which is the brain of your cluster.
>
> Every action in Kubernetes—creating a pod, deleting a service, reading a secret, scaling a deployment—goes through the API server. RBAC is the gatekeeper that decides whether a user or service account is allowed to perform that action.
>
> This is **API-level authorization**. Even if you can authenticate to the cluster, RBAC determines what you're authorized to do."

### How RBAC Works: The Four Resource Types

**Say:**
> "RBAC has four core resource types that work together:
>
> **1. Role / ClusterRole**: Defines a set of permissions—what actions (verbs) are allowed on what resources. A Role is namespace-scoped, while a ClusterRole is cluster-wide.
>
> **2. RoleBinding / ClusterRoleBinding**: Connects a Role to subjects—users, groups, or service accounts. This is how you grant permissions.
>
> **3. ServiceAccount**: Represents the identity of a pod. When your pod needs to talk to the API server, it uses its service account credentials.
>
> **4. Subject**: The entity (user, group, or service account) that's being granted permissions.
>
> Think of it like a lock and key system: Roles define what doors can be opened, RoleBindings determine who gets which keys."

### The Principle of Least Privilege

**Say:**
> "The core principle of RBAC security is **least privilege**: grant users and workloads the minimum permissions they need to function, nothing more.
>
> This limits the blast radius of a compromise. If an attacker compromises a developer's credentials or a pod's service account, they should only get access to a narrow slice of the cluster—not everything.
>
> Unfortunately, overly permissive RBAC is one of the most common Kubernetes security mistakes. We've all seen the demo where someone binds `cluster-admin` to the `default` service account. That's giving every pod in that namespace full cluster control—catastrophic if any pod is compromised."

### RBAC for Multi-Tenancy

**Say:**
> "In a multi-tenant cluster—where multiple teams share the same cluster—RBAC becomes critical:
> - Dev teams should only access their namespaces
> - Operators should have cluster-wide view but limited write access
> - Automated systems should have service accounts with specific permissions
> - Admins should use separate accounts for daily tasks vs. emergency access
>
> Let's look at how we've configured RBAC for this demo."

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

## Section 6: ACM Governance Policies (17 minutes)

### Transition

**Say:**
> "Everything we've seen so far applies to a single cluster. But what about organizations running tens or hundreds of OpenShift clusters? How do you enforce consistent security policies across all of them? That's where Red Hat Advanced Cluster Management comes in.
>
> Let me explain what ACM is and how it scales security governance to enterprise fleets."

### Background: The Multi-Cluster Challenge

**Say:**
> "Modern enterprises don't run one Kubernetes cluster—they run dozens or hundreds. You might have:
> - Clusters in different data centers for geographic distribution
> - Clusters in different clouds for redundancy
> - Clusters for different environments—dev, staging, production
> - Clusters for different business units or tenants
> - Edge clusters in retail stores, factories, or cell towers
>
> Each cluster is a security boundary. And here's the problem: how do you ensure consistent security policies across all of them?
>
> If you're manually configuring each cluster, you **will** have drift. Someone forgets to enable etcd encryption on cluster 47. Someone configures the wrong Pod Security profile on cluster 89. Someone disables network policies for troubleshooting and forgets to re-enable them.
>
> This is where ACM's governance framework comes in."

### What is ACM?

**Say:**
> "Red Hat Advanced Cluster Management is a multi-cluster management platform. It provides:
> - **Cluster lifecycle management**: Create, upgrade, and destroy clusters from a central console
> - **Application lifecycle management**: Deploy applications across clusters
> - **Observability**: Unified monitoring and alerting
> - **Governance**: The feature we're focusing on today—policy-based compliance and security enforcement
>
> ACM uses a **hub-and-spoke model**: One hub cluster manages many managed clusters. The hub is your control plane for the entire fleet."

### How ACM Governance Works

**Say:**
> "ACM's governance framework uses three core concepts:
>
> **1. Policies**: Define the desired state or compliance rules. For example, 'all namespaces must have Pod Security labels' or 'etcd must be encrypted.'
>
> **2. PlacementRules**: Define which clusters receive which policies using label selectors. For example, 'apply this policy to all production clusters in us-east-1' or 'apply this to all edge clusters.'
>
> **3. PlacementBindings**: Connect policies to placement rules. This is how you bind a policy to a set of clusters.
>
> ACM continuously evaluates these policies on target clusters and reports compliance status back to the hub. This is **continuous compliance monitoring**, not a point-in-time audit."

### Inform vs. Enforce: Two Modes of Remediation

**Say:**
> "ACM policies support two remediation modes:
>
> **Inform mode**: ACM detects violations and reports them, but doesn't change anything. This is audit mode—you get visibility without risk of breaking workloads.
>
> **Enforce mode**: ACM automatically creates, updates, or deletes resources to bring clusters into compliance. This is active remediation—policy as code that self-heals your infrastructure.
>
> The best practice is to start with **inform** to understand impact, then switch to **enforce** once you're confident the policy won't break anything.
>
> We've implemented a comprehensive governance framework with nine security policies covering everything from pod security to encryption at rest. Let me walk you through them."

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

### Why This Works: The Complete Security Stack

**Say:**
> "Let me show you one more view—what makes each layer effective:

| Layer | Enforcement Point | What It Prevents | Why It's Hard to Bypass |
|-------|------------------|------------------|-------------------------|
| **Pod Security Standards** | API admission | Privileged containers, root users, host access | Kubernetes-native, evaluated before scheduling |
| **Security Context Constraints** | API admission | Specific capabilities, volume types, user IDs | OpenShift admission controller, runs after PSS |
| **Network Policies** | Network data plane | Lateral movement, unauthorized connections | CNI-enforced at kernel level, pod identity-based |
| **RBAC** | API authorization | Unauthorized API access, privilege escalation | Every API request checked, token-based auth |
| **ACM Policies** | Multi-cluster governance | Configuration drift, non-compliant clusters | Continuous evaluation, centralized enforcement |
| **Secure Workloads** | Application design | Runtime vulnerabilities, misconfigurations | Security built into the application itself |

**Say:**
> "Notice that each layer operates at a **different enforcement point**. An attacker would need to bypass:
> - The API admission layer (PSS and SCC)
> - The network enforcement layer (Network Policies)
> - The API authorization layer (RBAC)
> - The governance layer (ACM)
> - The application security layer (secure workload design)
>
> That's five different attack surfaces they need to compromise simultaneously. That's defense-in-depth."

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
- If running short: Skip RBAC section or reduce ACM to 3 key policies (Pod Security, etcd Encryption, RBAC Governance)
- If running long: Combine failure scenarios 3 & 4, skip the secure vs insecure comparison
- Always leave 5-10 minutes for Q&A
- Use the presentation structure table to track pacing throughout

### Handling Technical Questions During Demo

If asked technical questions mid-presentation:

**For Simple Questions:**
> "Great question. [Brief 1-2 sentence answer]. I'll circle back to this in the Q&A if you want more details."

**For Complex Questions:**
> "That's an excellent question that deserves a thorough answer. Let me note that down and we'll dig into it during Q&A so we can give it proper attention."

**For Off-Topic Questions:**
> "That's outside the scope of today's demo, but I'd be happy to connect you with resources or schedule a follow-up discussion about [topic]."

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
