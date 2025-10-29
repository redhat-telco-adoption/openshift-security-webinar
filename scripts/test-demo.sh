#!/bin/bash
# Test script to verify OpenShift ACM Security Demo deployment
# This script validates all components are deployed and functioning correctly

# Don't exit on error - we want to run all tests and report at the end
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}Testing:${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((FAILED++))
}

print_warn() {
    echo -e "${YELLOW}⚠ WARN:${NC} $1"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}ℹ INFO:${NC} $1"
}

# Check if logged in to OpenShift
check_connectivity() {
    print_header "Checking Cluster Connectivity"

    print_test "OpenShift cluster access"
    if oc whoami &> /dev/null; then
        USER=$(oc whoami)
        print_pass "Connected as user: $USER"
    else
        print_fail "Not logged in to OpenShift cluster"
        echo "Run: oc login --server=<cluster-url> --token=<token>"
        exit 1
    fi

    print_test "Cluster info"
    if CLUSTER_URL=$(oc cluster-info 2>&1 | grep -m 1 "Kubernetes\|control plane" || echo "Unknown"); then
        print_pass "Cluster accessible"
    else
        print_fail "Cannot retrieve cluster info"
    fi
}

# Test namespace
check_namespace() {
    print_header "Checking Demo Namespace"

    print_test "Namespace 'security-demo' exists"
    if oc get namespace security-demo &> /dev/null; then
        print_pass "Namespace 'security-demo' found"
    else
        print_fail "Namespace 'security-demo' not found"
        echo "Run: oc apply -f manifests/namespaces/"
        return 0  # Don't stop execution, continue with other tests
    fi

    print_test "Pod Security Standards labels"
    PSS_ENFORCE=$(oc get namespace security-demo -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
    PSS_AUDIT=$(oc get namespace security-demo -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null)
    PSS_WARN=$(oc get namespace security-demo -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null)

    if [[ "$PSS_ENFORCE" == "restricted" ]] && [[ "$PSS_AUDIT" == "restricted" ]] && [[ "$PSS_WARN" == "restricted" ]]; then
        print_pass "Pod Security Standards set to 'restricted'"
    else
        print_fail "Pod Security Standards not configured correctly (enforce=$PSS_ENFORCE, audit=$PSS_AUDIT, warn=$PSS_WARN)"
    fi
}

# Test secure application
check_secure_app() {
    print_header "Checking Secure Application"

    print_test "Deployment 'secure-app' exists"
    if oc get deployment secure-app -n security-demo &> /dev/null; then
        print_pass "Deployment 'secure-app' found"
    else
        print_fail "Deployment 'secure-app' not found"
        echo "Run: oc apply -f applications/sample-app/"
        return 0  # Continue with other tests
    fi

    print_test "Pods are running"
    READY_PODS=$(oc get deployment secure-app -n security-demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    DESIRED_PODS=$(oc get deployment secure-app -n security-demo -o jsonpath='{.spec.replicas}' 2>/dev/null)

    if [[ "$READY_PODS" == "$DESIRED_PODS" ]] && [[ "$READY_PODS" -gt 0 ]]; then
        print_pass "All pods running ($READY_PODS/$DESIRED_PODS ready)"
    else
        print_fail "Pods not ready ($READY_PODS/$DESIRED_PODS ready)"
        oc get pods -n security-demo
    fi

    print_test "Service account exists"
    if oc get serviceaccount secure-app-sa -n security-demo &> /dev/null; then
        print_pass "Service account 'secure-app-sa' found"
    else
        print_fail "Service account 'secure-app-sa' not found"
    fi

    print_test "Service exists"
    if oc get service secure-app -n security-demo &> /dev/null; then
        print_pass "Service 'secure-app' found"
    else
        print_fail "Service 'secure-app' not found"
    fi

    print_test "Security context configuration"
    RUN_AS_NON_ROOT=$(oc get deployment secure-app -n security-demo -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null)
    READ_ONLY_FS=$(oc get deployment secure-app -n security-demo -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)

    if [[ "$RUN_AS_NON_ROOT" == "true" ]]; then
        print_pass "Running as non-root user"
    else
        print_fail "Not configured to run as non-root"
    fi

    if [[ "$READ_ONLY_FS" == "true" ]]; then
        print_pass "Read-only root filesystem enabled"
    else
        print_warn "Read-only root filesystem not enabled (recommended but not required)"
    fi
}

# Test network policies
check_network_policies() {
    print_header "Checking Network Policies"

    print_test "NetworkPolicy 'deny-all-ingress' exists"
    if oc get networkpolicy deny-all-ingress -n security-demo &> /dev/null; then
        print_pass "NetworkPolicy 'deny-all-ingress' found"
    else
        print_fail "NetworkPolicy 'deny-all-ingress' not found"
        echo "Run: oc apply -f manifests/network-policies/"
    fi

    print_test "NetworkPolicy 'allow-same-namespace' exists"
    if oc get networkpolicy allow-same-namespace -n security-demo &> /dev/null; then
        print_pass "NetworkPolicy 'allow-same-namespace' found"
    else
        print_fail "NetworkPolicy 'allow-same-namespace' not found"
    fi
}

# Test RBAC
check_rbac() {
    print_header "Checking RBAC Configuration"

    print_test "Role 'developer-role' exists"
    if oc get role developer-role -n security-demo &> /dev/null; then
        print_pass "Role 'developer-role' found"
    else
        print_fail "Role 'developer-role' not found"
        echo "Run: oc apply -f manifests/rbac/"
    fi

    print_test "RoleBinding 'developer-binding' exists"
    if oc get rolebinding developer-binding -n security-demo &> /dev/null; then
        print_pass "RoleBinding 'developer-binding' found"
    else
        print_fail "RoleBinding 'developer-binding' not found"
    fi
}

# Test Security Context Constraints
check_scc() {
    print_header "Checking Security Context Constraints"

    print_test "SCC 'demo-restricted-scc' exists"
    if oc get scc demo-restricted-scc &> /dev/null; then
        print_pass "SCC 'demo-restricted-scc' found"
    else
        print_fail "SCC 'demo-restricted-scc' not found"
        echo "Run: oc apply -f manifests/scc/ (requires cluster-admin)"
    fi

    print_test "Default OpenShift SCCs present"
    SCC_COUNT=$(oc get scc --no-headers 2>/dev/null | wc -l)
    if [[ "$SCC_COUNT" -gt 5 ]]; then
        print_pass "OpenShift SCCs available (count: $SCC_COUNT)"
    else
        print_warn "Unexpected SCC count: $SCC_COUNT"
    fi
}

# Test ACM policies
check_acm_policies() {
    print_header "Checking ACM Policies"

    print_test "ACM CRDs available"
    if oc get crd policies.policy.open-cluster-management.io &> /dev/null; then
        print_pass "ACM CRDs found"

        print_test "ACM policies deployed"
        POLICY_COUNT=$(oc get policies -A 2>/dev/null | grep -v NAMESPACE | wc -l)
        if [[ "$POLICY_COUNT" -gt 0 ]]; then
            print_pass "ACM policies found (count: $POLICY_COUNT)"
        else
            print_warn "No ACM policies deployed (optional for demo)"
            print_info "Run: oc apply -f policies/security/ && oc apply -f policies/compliance/"
        fi
    else
        print_warn "ACM not installed (optional for demo)"
        print_info "ACM policies section can be skipped in demo"
    fi
}

# Test that insecure deployments are blocked
# Note: Deployments may show warnings during dry-run, but the actual pods
# would be blocked when created. We test for warnings, violations, and blocks.
test_security_enforcement() {
    print_header "Testing Security Enforcement"

    print_test "Privileged container is blocked"
    OUTPUT=$(oc apply -f applications/insecure-examples/privileged-pod.yaml --dry-run=server 2>&1)
    if echo "$OUTPUT" | grep -qE "(forbidden|violates PodSecurity|Warning.*violates)"; then
        print_pass "Privileged containers are blocked"
    else
        print_fail "Privileged containers are NOT blocked - security controls may not be working"
        echo "Output: $OUTPUT"
    fi

    print_test "Root user is blocked"
    OUTPUT=$(oc apply -f applications/insecure-examples/root-user.yaml --dry-run=server 2>&1)
    if echo "$OUTPUT" | grep -qE "(forbidden|violates|would violate|runAsUser=0)"; then
        print_pass "Root user containers are blocked/warned"
    else
        print_fail "Root user containers are NOT blocked"
        echo "Output: $OUTPUT"
    fi

    print_test "Host access is blocked"
    OUTPUT=$(oc apply -f applications/insecure-examples/host-access.yaml --dry-run=server 2>&1)
    if echo "$OUTPUT" | grep -qE "(forbidden|violates|would violate|host namespaces)"; then
        print_pass "Host namespace access is blocked"
    else
        print_fail "Host namespace access is NOT blocked"
        echo "Output: $OUTPUT"
    fi

    print_test "Dangerous capabilities are blocked"
    OUTPUT=$(oc apply -f applications/insecure-examples/dangerous-capabilities.yaml --dry-run=server 2>&1)
    if echo "$OUTPUT" | grep -qE "(forbidden|violates|would violate|unrestricted capabilities)"; then
        print_pass "Dangerous capabilities are blocked/warned"
    else
        print_fail "Dangerous capabilities are NOT blocked"
        echo "Output: $OUTPUT"
    fi
}

# Test documentation files
check_documentation() {
    print_header "Checking Documentation"

    local docs=(
        "README.md"
        "CLAUDE.md"
        "docs/demo-script.md"
        "docs/security-violations-guide.md"
        "docs/presentation-script.md"
        "applications/insecure-examples/README.md"
    )

    for doc in "${docs[@]}"; do
        if [[ -f "$doc" ]]; then
            print_pass "Documentation found: $doc"
        else
            print_fail "Documentation missing: $doc"
        fi
    done
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  OpenShift ACM Security Demo - Test Suite              ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Run all checks - don't let individual failures stop the script
    check_connectivity || true
    check_namespace || true
    check_secure_app || true
    check_network_policies || true
    check_rbac || true
    check_scc || true
    check_acm_policies || true
    test_security_enforcement || true
    check_documentation || true

    # Summary
    print_header "Test Summary"
    echo ""
    echo -e "${GREEN}Passed:   $PASSED${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo -e "${RED}Failed:   $FAILED${NC}"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✓ All critical tests passed - Demo is ready!          ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Review the demo script: docs/demo-script.md"
        echo "  2. Review the presentation script: docs/presentation-script.md"
        echo "  3. Practice the failure scenarios"
        echo ""
        exit 0
    else
        echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ✗ Some tests failed - Demo needs attention             ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Fix the failures above, then run this script again."
        echo ""
        exit 1
    fi
}

# Run main function
main
