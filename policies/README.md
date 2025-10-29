# ACM Security Policies

This directory contains Advanced Cluster Management (ACM) policies for multi-cluster security governance. These policies demonstrate the power of centralized security enforcement across OpenShift clusters.

## Overview

ACM policies enable you to:
- **Scale** security governance across 100+ clusters from a single control plane
- **Prevent** security violations before they occur through enforcement
- **Detect** configuration drift and non-compliant resources continuously
- **Remediate** violations automatically (when using `enforce` mode)
- **Report** compliance status to auditors and security teams

## Policy Structure

Each ACM policy consists of three components:

1. **Policy** - Defines the desired state and compliance rules
2. **PlacementRule** - Selects target clusters using label selectors
3. **PlacementBinding** - Connects policies to placement rules

## Remediation Modes

- **inform**: Detects violations and reports them (does not modify resources)
- **enforce**: Automatically creates or modifies resources to ensure compliance

## Available Policies

### Security Policies

Located in `security/`:

#### 1. Pod Security Standards Policy
**File**: `pod-security-policy.yaml`

Enforces Kubernetes Pod Security Standards across all managed clusters.

**Controls**:
- Creates namespaces with restricted Pod Security Admission labels
- Enforces `restricted` profile (most secure)
- Applies to `security-demo` namespace

**Compliance Mapping**:
- NIST SP 800-53: SC-4 (Information in Shared Resources)
- CIS Kubernetes Benchmark

**Remediation**: `enforce`

```bash
# View policy
oc describe policy policy-pod-security-standards -n default

# Check compliance
oc get policy policy-pod-security-standards -n default
```

---

#### 2. Image Security Policy
**File**: `image-security-policy.yaml`

Enforces container image security best practices across clusters.

**Controls**:
- Blocks images with `:latest` tag in production namespaces
- Requires images from trusted registries only (Red Hat, internal registries)
- Enforces `imagePullPolicy` to prevent stale cached images
- Uses Go templates for dynamic pod evaluation

**Why it matters**:
- Prevents supply chain attacks via untrusted images
- Ensures image immutability in production
- Enforces organizational security standards

**Compliance Mapping**:
- NIST SP 800-53: CM-5 (Access Restrictions for Change)
- Supply Chain Security

**Remediation**: `inform` (detection only)

**Trusted Registries**:
- `registry.redhat.io/*`
- `quay.io/redhat/*`
- `registry.access.redhat.com/*`
- `image-registry.openshift-image-registry.svc/*`

```bash
# View policy
oc describe policy policy-image-security -n default

# Check for violations
oc get policy policy-image-security -n default -o jsonpath='{.status.status}'
```

---

#### 3. Certificate Management Policy
**File**: `certificate-policy.yaml`

Monitors certificate expiration across clusters to prevent outages.

**Controls**:
- Monitors API server certificates (min 30 days before expiration)
- Monitors ingress controller certificates
- Monitors service serving certificates
- Ensures cert-manager is deployed for automated renewal
- Validates certificate SAN patterns

**Why it matters**:
- Prevents production outages due to expired certificates
- Enables proactive certificate renewal
- Meets compliance requirements for PKI management

**Compliance Mapping**:
- NIST SP 800-53: SC-12 (Cryptographic Key Establishment)
- PCI-DSS: Requirement 4 (Encryption)

**Remediation**: `inform` (alerts on expiration)

**Thresholds**:
- API server certs: 720 hours (30 days)
- Ingress certs: 720 hours (30 days)
- Service certs: 240 hours (10 days)
- CA certs: 8760 hours (365 days)

```bash
# View certificate status
oc describe policy policy-certificate-management -n default

# Check expiring certificates
oc get policy policy-certificate-management -n default -o yaml | grep -A 10 status
```

---

#### 4. etcd Encryption Policy
**File**: `etcd-encryption-policy.yaml`

Enforces encryption of sensitive data at rest in etcd database.

**Controls**:
- Enforces AES-CBC encryption for etcd
- Validates encryption configuration exists
- Monitors encryption progress status
- Verifies encryption is completed
- Applied ONLY to production clusters

**Why it matters**:
- Protects Secrets at rest from storage compromise
- Required for regulatory compliance (PCI-DSS, HIPAA, SOC 2)
- Defense-in-depth for sensitive data

**Compliance Mapping**:
- NIST SP 800-53: SC-28 (Protection of Information at Rest)
- PCI-DSS: Requirement 3 (Protect Stored Data)
- HIPAA: 164.312(a)(2)(iv) (Encryption)

**Remediation**: `inform` (due to complexity of encryption enablement)

**Target Clusters**: Production only (via PlacementRule)

```bash
# Check encryption status
oc get policy policy-etcd-encryption -n default

# Verify encryption on specific cluster
oc get kubeapiserver cluster -o jsonpath='{.status.conditions[?(@.type=="Encrypted")]}'
```

---

#### 5. Namespace Security Policy
**File**: `namespace-security-policy.yaml`

Enforces namespace-level security configurations.

**Controls**:
- Requires Pod Security labels on ALL user namespaces
- Enforces `restricted` PSS for production namespaces
- Mandates default-deny NetworkPolicies
- Prevents workload deployment in `default` namespace
- Requires ownership and environment labels
- Ensures ResourceQuotas exist

**Why it matters**:
- Prevents "unprotected" namespaces
- Ensures consistent security baseline
- Enables multi-tenancy with strong isolation
- Enforces governance through labeling

**Compliance Mapping**:
- NIST SP 800-53: CM-7 (Least Functionality)
- CIS Kubernetes Benchmark: 5.2 (Pod Security Policies)

**Remediation**: `enforce` for production, `inform` for others

```bash
# View policy
oc describe policy policy-namespace-security -n default

# Check namespace compliance
oc get namespaces --show-labels
```

---

#### 6. Network Policy Governance
**File**: `network-policy-governance.yaml`

Enforces zero-trust networking and network segmentation.

**Controls**:
- Requires NetworkPolicies in all application namespaces
- Enforces default-deny for ingress traffic
- Enforces default-deny for egress traffic
- Allows DNS resolution (UDP/TCP port 53)
- Allows monitoring from OpenShift monitoring stack
- Prevents cross-namespace communication
- Restricts egress to external networks in production

**Why it matters**:
- Implements zero-trust networking model
- Provides micro-segmentation at pod level
- Controls east-west traffic (not just north-south)
- Limits blast radius of compromised workloads

**Compliance Mapping**:
- NIST SP 800-53: SC-7 (Boundary Protection)
- CIS Kubernetes Benchmark: 5.3 (Network Policies)
- Zero Trust Architecture

**Remediation**: `enforce` for deny-all, `inform` for detection

```bash
# View policy
oc describe policy policy-network-security -n default

# Check network policies
oc get networkpolicies -A
```

---

### Governance Policies

Located in `governance/`:

#### 7. RBAC Governance Policy
**File**: `rbac-governance-policy.yaml`

Enforces RBAC best practices and prevents privilege escalation.

**Controls**:
- ❌ Prevents `cluster-admin` binding to service accounts (except system namespaces)
- ❌ Detects wildcard (`*`) permissions in roles
- ❌ Blocks privilege escalation verbs (`escalate`, `bind`)
- ✅ Requires dedicated service accounts (not `default`)
- ✅ Disables auto-mount of service account tokens
- ✅ Creates viewer role with read-only permissions

**Why it matters**:
- Prevents common privilege escalation attacks
- Enforces least-privilege principle
- Detects overly permissive roles
- Goes beyond Kubernetes RBAC to add governance

**Compliance Mapping**:
- NIST SP 800-53: AC-3 (Access Enforcement), AC-6 (Least Privilege)
- CIS Kubernetes Benchmark: 5.1 (RBAC)

**Remediation**: `inform` (detection of violations), `enforce` for viewer role creation

```bash
# View policy
oc describe policy policy-rbac-governance -n default

# Check for violations
oc get policy policy-rbac-governance -n default -o jsonpath='{.status.details[*].history[0].message}'
```

---

#### 8. Resource Quota Policy
**File**: `resource-quota-policy.yaml`

Enforces resource limits to prevent resource exhaustion attacks.

**Controls**:
- Enforces namespace-level resource quotas (CPU, memory, pods, services)
- Requires pod and container limit ranges
- Ensures all pods have resource requests and limits
- Implements priority classes for scheduling
- Sets default resource limits for containers

**Why it matters**:
- Prevents denial-of-service via resource exhaustion
- Enables multi-tenancy and fair resource allocation
- Prevents "noisy neighbor" problems
- Supports cost allocation and chargeback

**Compliance Mapping**:
- NIST SP 800-53: SC-6 (Resource Availability)

**Remediation**: `enforce`

**Default Limits**:
- Namespace: 10 CPU requests, 20 CPU limits, 20Gi memory requests, 40Gi memory limits
- Container: 50m CPU request, 100m CPU default, 64Mi memory request, 128Mi memory default
- Pod: Max 4 CPU, 8Gi memory

```bash
# View policy
oc describe policy policy-resource-quotas -n default

# Check quotas
oc get resourcequota,limitrange -n security-demo
```

---

### Compliance Policies

Located in `compliance/`:

#### 9. Container Security Operator Policy
**File**: `container-security-operator.yaml`

Deploys container vulnerability scanning across clusters.

**Controls**:
- Ensures Container Security Operator is installed
- Creates `openshift-container-security` namespace
- Enables automatic vulnerability scanning of images
- Integrates with Red Hat Quay vulnerability database

**Why it matters**:
- Detects CVEs in deployed container images
- Provides visibility into image vulnerabilities
- Enables proactive patching and remediation
- Continuous monitoring of container security

**Compliance Mapping**:
- NIST SP 800-53: SI-4 (Information System Monitoring)
- NIST SP 800-53: RA-5 (Vulnerability Scanning)

**Remediation**: `inform` (operator installation should be reviewed)

```bash
# View policy
oc describe policy policy-container-security-operator -n default

# Check operator status
oc get csv -n openshift-container-security
```

---

## Policy Placement

### PlacementRules

Two placement rules are defined:

#### 1. `placement-all-clusters`
Targets all available managed clusters with environment labels `dev` or `prod`.

```yaml
clusterSelector:
  matchExpressions:
    - key: environment
      operator: In
      values:
        - dev
        - prod
```

#### 2. `placement-production-clusters`
Targets ONLY production clusters (used for etcd encryption policy).

```yaml
clusterSelector:
  matchExpressions:
    - key: environment
      operator: In
      values:
        - prod
        - production
```

### Adding Cluster Labels

To apply policies to specific clusters, label your managed clusters:

```bash
# Label a cluster as production
oc label managedcluster <cluster-name> environment=prod

# Label a cluster as development
oc label managedcluster <cluster-name> environment=dev

# View cluster labels
oc get managedclusters --show-labels
```

---

## Deployment

### Deploy All Policies

```bash
# Deploy all security policies
oc apply -f policies/security/

# Deploy all governance policies
oc apply -f policies/governance/

# Deploy all compliance policies
oc apply -f policies/compliance/
```

### Deploy Individual Policy

```bash
# Example: Deploy only image security policy
oc apply -f policies/security/image-security-policy.yaml
```

### Verify Deployment

```bash
# List all policies
oc get policies -n default

# Check policy compliance
oc get policies -n default -o wide

# View policy details
oc describe policy <policy-name> -n default
```

---

## Testing

Run the comprehensive policy test suite:

```bash
./scripts/test-acm-policies.sh
```

This script tests:
- Policy existence
- PlacementBinding configuration
- PlacementRule configuration
- Policy compliance status
- Policy annotations (standards, categories, controls)
- Remediation actions
- Policy template validity
- Managed cluster availability
- Policy distribution to clusters
- YAML syntax validation

---

## Monitoring and Troubleshooting

### Check Policy Status

```bash
# View all policies and compliance status
oc get policies -A

# Check specific policy compliance
oc get policy <policy-name> -n default -o jsonpath='{.status.compliant}'

# View detailed status for each cluster
oc get policy <policy-name> -n default -o yaml | grep -A 20 status
```

### View Policy Violations

```bash
# Get violation details
oc describe policy <policy-name> -n default

# View violation history
oc get policy <policy-name> -n default -o jsonpath='{.status.status[*].compliant}'
```

### Policy Compliance States

- **Compliant**: All target clusters meet policy requirements
- **NonCompliant**: One or more clusters violate policy
- **Pending**: Policy is being evaluated
- **Unknown**: Status cannot be determined

### Troubleshooting Common Issues

#### Policy Not Being Evaluated

```bash
# Check if PlacementRule is selecting clusters
oc get placementrule <placement-name> -n default -o yaml

# Verify PlacementBinding
oc get placementbinding <binding-name> -n default -o yaml

# Check managed cluster status
oc get managedclusters
```

#### Policy Shows NonCompliant

```bash
# View detailed violation message
oc describe policy <policy-name> -n default

# Check configuration policy status
oc get configurationpolicy -A

# View related events
oc get events -n default --field-selector involvedObject.name=<policy-name>
```

#### Policy Not Distributed to Clusters

```bash
# Verify cluster labels match PlacementRule selector
oc get managedclusters --show-labels

# Check cluster conditions
oc get managedclusters -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}{"\n"}{end}'
```

---

## ACM Console

Access the ACM Governance dashboard:

1. Navigate to ACM console
2. Click **Governance** in left menu
3. View all policies and compliance status
4. Click on individual policies for details
5. Export compliance reports for auditors

---

## Customization

### Adjusting Remediation Mode

To change from `inform` (detect) to `enforce` (remediate):

```yaml
spec:
  remediationAction: enforce  # Changed from 'inform'
```

### Modifying Cluster Selection

Edit PlacementRule to target different clusters:

```yaml
spec:
  clusterSelector:
    matchExpressions:
      - key: region
        operator: In
        values:
          - us-east-1
          - us-west-2
```

### Adding Namespace Selectors

For policies that support namespace selection:

```yaml
spec:
  namespaceSelector:
    include:
      - "production"
      - "staging"
    exclude:
      - "kube-*"
      - "openshift-*"
```

---

## Compliance Mapping

All policies are annotated with compliance framework mappings:

| Policy | NIST SP 800-53 | CIS Benchmark | PCI-DSS | Other |
|--------|---------------|---------------|---------|-------|
| Pod Security Standards | SC-4 | 5.2 | - | - |
| Image Security | CM-5 | - | - | Supply Chain |
| Certificate Management | SC-12 | - | Req 4 | - |
| etcd Encryption | SC-28 | - | Req 3 | HIPAA |
| Namespace Security | CM-7 | 5.2 | - | - |
| Network Security | SC-7 | 5.3 | - | Zero Trust |
| RBAC Governance | AC-3, AC-6 | 5.1 | - | - |
| Resource Quotas | SC-6 | - | - | - |
| Container Security | SI-4, RA-5 | - | - | - |

---

## Best Practices

1. **Start with `inform` mode**: Test policies in detection mode before enforcing
2. **Label clusters appropriately**: Use consistent labeling for placement rules
3. **Monitor compliance regularly**: Review policy status weekly
4. **Update policies gradually**: Roll out policy changes to dev clusters first
5. **Document exceptions**: Create separate policies for special cases
6. **Export compliance reports**: Maintain audit trail for compliance teams
7. **Test before deploying**: Use `--dry-run=client` to validate YAML
8. **Use Go templates carefully**: Test template logic on non-production clusters
9. **Set appropriate timeouts**: Some policies may take time to evaluate
10. **Review violations promptly**: Address non-compliance quickly

---

## Additional Resources

- [ACM Policy Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.9/html/governance/governance)
- [Policy Collection](https://github.com/open-cluster-management-io/policy-collection)
- [OpenShift Security Guide](https://docs.openshift.com/container-platform/latest/security/index.html)
- [NIST SP 800-53 Controls](https://nvd.nist.gov/800-53)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)

---

## Contributing

When adding new policies:

1. Follow the naming convention: `policy-<name>.yaml`
2. Include all three components: Policy, PlacementRule, PlacementBinding
3. Add compliance annotations (standards, categories, controls)
4. Document the policy in this README
5. Add test cases to `scripts/test-acm-policies.sh`
6. Update `docs/demo-script.md` with demo instructions
7. Test in non-production environment first

---

## License

This content is part of the OpenShift/ACM security demo and is provided as-is for educational and demonstration purposes.
