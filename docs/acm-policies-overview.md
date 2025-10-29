# ACM Policies Overview - Enhanced Security Governance

## Summary

This document provides an overview of the comprehensive ACM policy framework that has been implemented to showcase the security power of Advanced Cluster Management across multiple OpenShift clusters.

## What is ACM?

Red Hat Advanced Cluster Management (ACM) for Kubernetes provides:
- **Multi-cluster governance** - Manage 100+ clusters from a single control plane
- **Policy-based compliance** - Enforce security and configuration standards
- **Automated remediation** - Fix violations automatically or alert on issues
- **Compliance reporting** - Generate audit reports for regulatory requirements

## Policy Architecture

### Total Policies: 9

The policy framework is organized into three categories:

### Security Policies (6)
Located in `policies/security/`:

1. **Pod Security Standards Policy**
   - Enforces Kubernetes Pod Security Standards
   - Applies restricted profile to security-demo namespace
   - **Remediation**: enforce

2. **Image Security Policy** ⭐ NEW
   - Blocks `:latest` tags in production
   - Enforces trusted registries only
   - Validates imagePullPolicy
   - **Remediation**: inform

3. **Certificate Management Policy** ⭐ NEW
   - Monitors certificate expiration (30-day threshold)
   - Tracks API server, ingress, and service certificates
   - Ensures cert-manager deployment
   - **Remediation**: inform

4. **etcd Encryption Policy** ⭐ NEW
   - Enforces data-at-rest encryption
   - Validates AES-CBC encryption for Secrets
   - Production clusters only
   - **Remediation**: inform
   - **Compliance**: PCI-DSS, HIPAA, SOC 2

5. **Namespace Security Policy** ⭐ NEW
   - Requires Pod Security labels on all namespaces
   - Mandates default-deny NetworkPolicies
   - Prevents workloads in default namespace
   - **Remediation**: enforce

6. **Network Policy Governance** ⭐ NEW
   - Implements zero-trust networking
   - Enforces default-deny ingress/egress
   - Allows only necessary traffic (DNS, monitoring)
   - **Remediation**: enforce

### Governance Policies (2)
Located in `policies/governance/`:

7. **RBAC Governance Policy** ⭐ NEW
   - Prevents cluster-admin binding to service accounts
   - Detects wildcard permissions
   - Blocks privilege escalation verbs
   - Requires dedicated service accounts
   - **Remediation**: inform

8. **Resource Quota Policy** ⭐ NEW
   - Enforces namespace resource quotas
   - Requires pod resource limits
   - Implements priority classes
   - Prevents resource exhaustion attacks
   - **Remediation**: enforce

### Compliance Policies (1)
Located in `policies/compliance/`:

9. **Container Security Operator Policy**
   - Deploys vulnerability scanning
   - Integrates with Red Hat Quay
   - Continuous CVE monitoring
   - **Remediation**: inform

## Key Features

### 1. Multi-Cluster Placement

Two placement rules enable targeted policy deployment:

- **placement-all-clusters**: Targets dev and prod environments
- **placement-production-clusters**: Targets production only (for sensitive policies like etcd encryption)

### 2. Dynamic Policy Evaluation

Uses Go templates for runtime evaluation:
- Scans all pods across clusters
- Evaluates against policy rules
- Reports violations with context

### 3. Compliance Framework Mapping

All policies mapped to security standards:
- **NIST SP 800-53**: 12 control mappings
- **CIS Kubernetes Benchmark**: 4 control mappings
- **PCI-DSS**: 2 requirement mappings
- **HIPAA**: Data encryption requirements
- **Zero Trust Architecture**: Network segmentation

### 4. Automated Testing

New comprehensive test suite: `scripts/test-acm-policies.sh`

Tests 10 categories:
1. Policy existence
2. PlacementBinding configuration
3. PlacementRule configuration
4. Policy compliance status
5. Policy annotations
6. Remediation actions
7. Policy templates
8. Managed cluster availability
9. Policy distribution
10. YAML validation

## Security Coverage Matrix

| Security Domain | Policies | Prevention | Detection | Compliance |
|----------------|----------|------------|-----------|------------|
| Pod Security | 2 | ✅ | ✅ | NIST, CIS |
| Image Security | 1 | ✅ | ✅ | NIST |
| Network Security | 2 | ✅ | ✅ | NIST, CIS, Zero Trust |
| Access Control | 1 | ✅ | ✅ | NIST, CIS |
| Data Protection | 1 | ✅ | ✅ | PCI-DSS, HIPAA |
| Resource Management | 1 | ✅ | ✅ | NIST |
| Certificate Management | 1 | - | ✅ | NIST |
| Vulnerability Scanning | 1 | - | ✅ | NIST |

## Policy Enforcement Strategies

### Prevent (enforce mode)
- Pod Security Standards
- Namespace Security
- Network Policy defaults
- Resource Quotas

### Detect (inform mode)
- Image Security violations
- Certificate expirations
- etcd encryption status
- RBAC violations
- Container vulnerabilities

## Demo Capabilities

The enhanced ACM policies section demonstrates:

1. **Scale**: Managing security across multiple clusters from one place
2. **Prevention**: Blocking violations before they occur
3. **Detection**: Continuous monitoring for drift
4. **Remediation**: Automated fixing of non-compliant resources
5. **Reporting**: Compliance dashboards for auditors

## Real-World Use Cases

### Use Case 1: Image Supply Chain Security
**Scenario**: Prevent untrusted container images from running in production

**Policy**: Image Security Policy
- Blocks images from Docker Hub in production
- Requires Red Hat certified images
- Prevents `:latest` tag (enforces immutability)

**Result**: Supply chain attack prevention

### Use Case 2: Data Compliance
**Scenario**: Meet PCI-DSS requirement for data-at-rest encryption

**Policy**: etcd Encryption Policy
- Validates encryption is enabled
- Monitors encryption progress
- Ensures Secrets are encrypted

**Result**: Compliance with regulatory requirements

### Use Case 3: Privilege Escalation Prevention
**Scenario**: Prevent developers from gaining cluster-admin access

**Policies**:
- RBAC Governance Policy (prevents escalate/bind verbs)
- Pod Security Standards (prevents privileged containers)
- Namespace Security (enforces restricted profile)

**Result**: Defense-in-depth against privilege escalation

### Use Case 4: Zero Trust Networking
**Scenario**: Implement micro-segmentation and zero-trust

**Policies**:
- Network Policy Governance (default-deny)
- Namespace Security (requires NetworkPolicies)

**Result**: East-west traffic control, limited blast radius

### Use Case 5: Certificate Lifecycle Management
**Scenario**: Prevent production outages from expired certificates

**Policy**: Certificate Management Policy
- Monitors all certificates across clusters
- Alerts 30 days before expiration
- Validates cert-manager automation

**Result**: Proactive certificate renewal

## Integration Points

### ACM Console
- Navigate to **Governance** → **Policies**
- View compliance status across all clusters
- Export audit reports
- Drill down into violations

### OpenShift Console
- View policy status per cluster
- See policy-created resources
- Monitor compliance in real-time

### CLI Management
```bash
# View all policies
oc get policies -n default

# Check compliance
oc get policies -n default -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.compliant}{"\n"}{end}'

# Test policies
./scripts/test-acm-policies.sh
```

## Compliance Reporting

Policies annotated with:
- **Standards**: NIST SP 800-53, CIS, PCI-DSS, HIPAA
- **Categories**: Security domains (AC, SC, CM, SI)
- **Controls**: Specific control numbers

Example:
```yaml
annotations:
  policy.open-cluster-management.io/standards: NIST SP 800-53, PCI-DSS
  policy.open-cluster-management.io/categories: SC System and Communications Protection
  policy.open-cluster-management.io/controls: SC-28 Protection of Information at Rest
```

## Documentation

### Comprehensive Policy Guide
See `policies/README.md` for detailed documentation of each policy:
- Purpose and rationale
- Controls implemented
- Compliance mappings
- Configuration options
- Testing instructions
- Troubleshooting

### Demo Script
Updated `docs/demo-script.md` includes:
- 15-minute ACM policies section
- 9 sub-sections (one per policy)
- Commands to demonstrate each policy
- Talking points for presenters
- Expected outputs

### Testing
`scripts/test-acm-policies.sh` provides:
- Automated testing of all 9 policies
- Validation of PlacementRules and bindings
- Compliance status checking
- YAML syntax validation
- Pass/fail reporting with color output

## Getting Started

### 1. Review Policies
```bash
# Read comprehensive policy documentation
cat policies/README.md

# View specific policy
oc get policy policy-image-security -n default -o yaml
```

### 2. Deploy Policies
```bash
# Deploy all security policies
oc apply -f policies/security/

# Deploy all governance policies
oc apply -f policies/governance/

# Deploy compliance policies
oc apply -f policies/compliance/
```

### 3. Verify Deployment
```bash
# Run comprehensive test suite
./scripts/test-acm-policies.sh

# Check policy compliance
oc get policies -n default
```

### 4. Monitor Compliance
```bash
# View compliance status
oc get policies -n default -o wide

# Check specific policy
oc describe policy policy-rbac-governance -n default
```

## Benefits for Demo

The enhanced ACM policies showcase:

1. **Enterprise-grade governance** - Policies address real security challenges
2. **Compliance automation** - Mapped to NIST, CIS, PCI-DSS, HIPAA
3. **Defense-in-depth** - Multiple overlapping security controls
4. **Operational excellence** - Prevents outages (cert expiration)
5. **Best practices** - Follows industry security standards
6. **Scalability** - Single control plane for many clusters
7. **Flexibility** - inform vs enforce modes
8. **Visibility** - Clear reporting and dashboards

## Next Steps

1. **Customize policies** for your environment
2. **Add cluster labels** for placement targeting
3. **Adjust thresholds** (certificate expiration, resource limits)
4. **Create custom policies** following the established patterns
5. **Integrate with CI/CD** for policy-as-code
6. **Export compliance reports** for auditors

## Support

For questions or issues:
- Review `policies/README.md` for detailed documentation
- Check `docs/demo-script.md` for demo walkthrough
- Run `./scripts/test-acm-policies.sh` for validation
- See OpenShift/ACM documentation for policy syntax

---

**Total Lines of Policy Code**: ~2,000+
**Standards Covered**: 4 (NIST, CIS, PCI-DSS, HIPAA)
**Security Domains**: 8
**Compliance Controls**: 15+
**Test Coverage**: 10 categories, 50+ test cases
