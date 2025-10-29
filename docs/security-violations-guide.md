# Security Violations Troubleshooting Guide

This guide helps identify, understand, and resolve common security violations in OpenShift and Kubernetes environments.

## Table of Contents
1. [Pod Security Standards Violations](#pod-security-standards-violations)
2. [Security Context Constraint Violations](#security-context-constraint-violations)
3. [Network Policy Blocks](#network-policy-blocks)
4. [RBAC Permission Denials](#rbac-permission-denials)
5. [Image Security Issues](#image-security-issues)

---

## Pod Security Standards Violations

### Symptom
```
Error from server (Forbidden): pods "my-pod" is forbidden:
violates PodSecurity "restricted:latest": <violation details>
```

### Common Violations

#### 1. Privileged Container
**Error:**
```
violates PodSecurity "restricted:latest": privileged
(container "myapp" must not set securityContext.privileged=true)
```

**Root Cause:** Container attempts to run in privileged mode

**Fix:**
```yaml
# WRONG
securityContext:
  privileged: true

# CORRECT
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
```

#### 2. Running as Root
**Error:**
```
violates PodSecurity "restricted:latest": runAsNonRoot != true
(container "myapp" must set securityContext.runAsNonRoot=true)
```

**Root Cause:** Container runs as root user (UID 0)

**Fix:**
```yaml
# WRONG
securityContext:
  runAsUser: 0

# CORRECT
securityContext:
  runAsNonRoot: true
  runAsUser: 1001  # Non-root UID
```

**Alternative Fix:** Let OpenShift assign a UID
```yaml
securityContext:
  runAsNonRoot: true
  # Don't specify runAsUser - let OpenShift assign from project range
```

#### 3. Host Namespace Access
**Error:**
```
violates PodSecurity "restricted:latest": host namespaces
(hostNetwork=true, hostPID=true, hostIPC=true)
```

**Root Cause:** Pod tries to access host networking, PID, or IPC namespaces

**Fix:**
```yaml
# WRONG
spec:
  hostNetwork: true
  hostPID: true
  hostIPC: true

# CORRECT - simply omit these fields (default is false)
spec:
  # No host namespace fields
```

#### 4. Dangerous Capabilities
**Error:**
```
violates PodSecurity "restricted:latest": unrestricted capabilities
(containers must not include "SYS_ADMIN", "NET_ADMIN" in securityContext.capabilities.add)
```

**Root Cause:** Container requests powerful Linux capabilities

**Fix:**
```yaml
# WRONG
securityContext:
  capabilities:
    add:
    - SYS_ADMIN
    - NET_ADMIN

# CORRECT
securityContext:
  capabilities:
    drop:
    - ALL
    # Only add safe capabilities if absolutely needed
```

#### 5. Host Path Volumes
**Error:**
```
violates PodSecurity "restricted:latest": hostPath volumes
(volume "myvolume" uses a hostPath volume)
```

**Root Cause:** Pod mounts host filesystem

**Fix:**
```yaml
# WRONG
volumes:
- name: myvolume
  hostPath:
    path: /var/data

# CORRECT - use appropriate volume types
volumes:
- name: myvolume
  emptyDir: {}
# or
- name: myvolume
  persistentVolumeClaim:
    claimName: my-pvc
```

### Debugging PSS Violations

**Check namespace PSS labels:**
```bash
oc get namespace <namespace> -o yaml | grep pod-security
```

**View PSS violations in events:**
```bash
oc get events -n <namespace> --field-selector reason=FailedCreate
```

**Test manifest without applying:**
```bash
oc apply -f myapp.yaml --dry-run=server
```

---

## Security Context Constraint Violations

### Symptom
```
Error creating: pods "my-pod" is forbidden: unable to validate against any security context constraint
```

### Common Violations

#### 1. No Suitable SCC Available
**Error:**
```
unable to validate against any security context constraint:
[spec.containers[0].securityContext.privileged: Invalid value: true: Privileged containers are not allowed]
```

**Root Cause:** Requested security settings don't match any available SCC

**Debugging:**
```bash
# Check which SCCs exist
oc get scc

# Check which SCC the service account can use
oc describe scc | grep -A 20 "Name:"

# Check service account SCC access
oc policy who-can use scc <scc-name>
```

**Fix:** Either:
1. Modify pod spec to meet existing SCC requirements
2. Create custom SCC (requires cluster-admin)
3. Grant service account access to appropriate SCC

#### 2. User ID Range Violation
**Error:**
```
unable to validate against any security context constraint:
[spec.containers[0].securityContext.runAsUser: Invalid value: 0: must be in the ranges: [1000730000, 1000739999]]
```

**Root Cause:** Requested UID outside allowed range

**Fix:**
```yaml
# WRONG
securityContext:
  runAsUser: 0

# CORRECT - use allowed range or omit
securityContext:
  runAsNonRoot: true
  # Let OpenShift assign UID from project range
```

**Check project UID range:**
```bash
oc describe namespace <namespace> | grep openshift.io/sa.scc
```

#### 3. Volume Type Not Allowed
**Error:**
```
unable to validate against any security context constraint:
[spec.volumes[0]: Invalid value: "hostPath": hostPath volumes are not allowed to be used]
```

**Root Cause:** Volume type not permitted by any SCC

**Fix:** Use allowed volume types:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret

### Debugging SCC Issues

**Check which SCC was assigned to a running pod:**
```bash
oc get pod <pod-name> -o jsonpath='{.metadata.annotations.openshift\.io/scc}'
```

**View SCC details:**
```bash
oc describe scc <scc-name>
```

**Check SCC priority:**
```bash
oc get scc -o custom-columns=NAME:.metadata.name,PRIORITY:.priority
```

---

## Network Policy Blocks

### Symptom
- Connection timeouts
- "Connection refused" errors at runtime
- Pods start successfully but can't communicate

### Diagnosis

**Check network policies:**
```bash
oc get networkpolicies -n <namespace>
oc describe networkpolicy <policy-name> -n <namespace>
```

**Test connectivity:**
```bash
# From pod A to service B
oc exec <pod-a> -n <namespace-a> -- curl -v -m 5 http://<service-b>.<namespace-b>.svc.cluster.local:<port>
```

**View effective network policies:**
```bash
# Check all policies affecting a namespace
oc get networkpolicies -n <namespace> -o yaml
```

### Common Scenarios

#### 1. Cross-Namespace Communication Blocked
**Symptom:** Timeout when accessing service in different namespace

**Cause:** Default deny policy blocks all ingress

**Fix:** Create allow rule for specific namespace
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-namespace-x
  namespace: target-namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: source-namespace
```

#### 2. External Traffic Blocked
**Symptom:** Can't reach external services (internet, databases)

**Cause:** Default deny egress policy

**Fix:** Create egress allow rule
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external
  namespace: my-namespace
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector: {}  # Allow pod-to-pod in namespace
  - to:
    - namespaceSelector: {}  # Allow to other namespaces
  - ports:  # Allow DNS
    - protocol: UDP
      port: 53
```

#### 3. Ingress Controller Can't Reach Pods
**Symptom:** Routes return 503 errors

**Cause:** NetworkPolicy blocks ingress from router namespace

**Fix:** Allow ingress from openshift-ingress namespace
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-openshift-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          network.openshift.io/policy-group: ingress
```

### Debugging Network Policies

**Test with temporary allow-all policy:**
```bash
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-test
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
EOF
```

**Remove test policy when done:**
```bash
oc delete networkpolicy allow-all-test -n <namespace>
```

---

## RBAC Permission Denials

### Symptom
```
Error from server (Forbidden): <resource> is forbidden:
User "developer" cannot <verb> resource "<resource>" in API group "<group>" in namespace "<namespace>"
```

### Diagnosis

**Check user permissions:**
```bash
oc auth can-i <verb> <resource> -n <namespace>
oc auth can-i --list -n <namespace>
```

**Check service account permissions:**
```bash
oc policy can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<sa-name>
```

**View roles and bindings:**
```bash
oc get role,rolebinding -n <namespace>
oc describe rolebinding <binding-name> -n <namespace>
```

### Common Issues

#### 1. Missing Verb Permission
**Error:** `User "developer" cannot delete pods`

**Fix:** Add verb to role
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "delete"]  # Added delete
```

#### 2. Service Account Can't Access Resource
**Error:** Service account lacks permissions for API calls

**Fix:** Create role and binding
```bash
oc create role pod-reader --verb=get,list,watch --resource=pods -n <namespace>
oc create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=<namespace>:<sa-name> -n <namespace>
```

---

## Image Security Issues

### RHACS Admission Control Violations

**Symptom:**
```
Error creating: admission webhook "policyeval.stackrox.io" denied the request:
The attempted operation violated 1 enforced policy
```

**Common Causes:**
1. Image contains critical/high severity CVEs
2. Image uses disallowed registry
3. Image doesn't meet security policy requirements

**Debugging:**
```bash
# Check RHACS policies
oc get policies -n stackrox

# View admission control logs
oc logs -n rhacs-operator -l app=admission-control

# Check image scan results (requires RHACS console access)
```

**Temporary Bypass (NOT RECOMMENDED):**
```yaml
metadata:
  annotations:
    admission.stackrox.io/break-glass: "true"
```

### Image Pull Errors

**Symptom:**
```
Failed to pull image: rpc error: code = Unknown desc = Error reading manifest
```

**Causes:**
- Image doesn't exist
- Registry requires authentication
- Network policy blocks registry access

**Fix:**
```bash
# Create image pull secret
oc create secret docker-registry my-registry-secret \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password>

# Link to service account
oc secrets link default my-registry-secret --for=pull
```

---

## Quick Reference: Secure Pod Template

Use this as a starting point for all deployments:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  serviceAccountName: my-app-sa
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

---

## Additional Resources

- [OpenShift Pod Security Standards](https://docs.openshift.com/container-platform/latest/authentication/understanding-and-managing-pod-security-admission.html)
- [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [RHACS Admission Control](https://docs.openshift.com/acs/operating/manage-admission-control.html)
