#!/bin/bash
#
# ACM Policy Testing Script
# Tests all ACM policies and verifies their compliance status
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ACM Policy Testing Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print test results
print_result() {
    local test_name=$1
    local status=$2
    local message=$3

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ "$status" == "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    elif [ "$status" == "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        [ -n "$message" ] && echo -e "  ${RED}→${NC} $message"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    elif [ "$status" == "SKIP" ]; then
        echo -e "${YELLOW}⊘ SKIP${NC}: $test_name - $message"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    fi
}

# Function to check if ACM is available
check_acm_available() {
    if ! oc get crd policies.policy.open-cluster-management.io &>/dev/null; then
        echo -e "${YELLOW}ACM CRDs not found - ACM tests will be skipped${NC}"
        return 1
    fi
    return 0
}

# Check ACM availability
if ! check_acm_available; then
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}ACM not available - exiting${NC}"
    echo -e "${YELLOW}========================================${NC}"
    exit 0
fi

echo -e "${GREEN}ACM is available - proceeding with tests${NC}"
echo ""

# Test 1: Check if all policies exist
echo -e "${BLUE}Test Group: Policy Existence${NC}"
echo ""

EXPECTED_POLICIES=(
    "policy-pod-security-standards"
    "policy-image-security"
    "policy-certificate-management"
    "policy-etcd-encryption"
    "policy-rbac-governance"
    "policy-resource-quotas"
    "policy-namespace-security"
    "policy-network-security"
    "policy-container-security-operator"
)

for policy in "${EXPECTED_POLICIES[@]}"; do
    if oc get policy "$policy" -n default &>/dev/null; then
        print_result "Policy exists: $policy" "PASS"
    else
        print_result "Policy exists: $policy" "FAIL" "Policy not found"
    fi
done

echo ""

# Test 2: Check PlacementBindings
echo -e "${BLUE}Test Group: PlacementBindings${NC}"
echo ""

EXPECTED_BINDINGS=(
    "binding-pod-security-standards"
    "binding-image-security"
    "binding-certificate-management"
    "binding-etcd-encryption"
    "binding-rbac-governance"
    "binding-resource-quotas"
    "binding-namespace-security"
    "binding-network-security"
)

for binding in "${EXPECTED_BINDINGS[@]}"; do
    if oc get placementbinding "$binding" -n default &>/dev/null; then
        print_result "PlacementBinding exists: $binding" "PASS"
    else
        print_result "PlacementBinding exists: $binding" "FAIL" "Binding not found"
    fi
done

echo ""

# Test 3: Check PlacementRules
echo -e "${BLUE}Test Group: PlacementRules${NC}"
echo ""

EXPECTED_PLACEMENTS=(
    "placement-all-clusters"
    "placement-production-clusters"
)

for placement in "${EXPECTED_PLACEMENTS[@]}"; do
    if oc get placementrule "$placement" -n default &>/dev/null; then
        print_result "PlacementRule exists: $placement" "PASS"
    else
        print_result "PlacementRule exists: $placement" "FAIL" "PlacementRule not found"
    fi
done

echo ""

# Test 4: Check policy compliance status
echo -e "${BLUE}Test Group: Policy Compliance${NC}"
echo ""

for policy in "${EXPECTED_POLICIES[@]}"; do
    if oc get policy "$policy" -n default &>/dev/null; then
        compliance=$(oc get policy "$policy" -n default -o jsonpath='{.status.compliant}' 2>/dev/null || echo "")

        if [ -z "$compliance" ]; then
            print_result "Policy compliance: $policy" "SKIP" "No compliance status available (policy may not be evaluated yet)"
        elif [ "$compliance" == "Compliant" ]; then
            print_result "Policy compliance: $policy" "PASS"
        elif [ "$compliance" == "NonCompliant" ]; then
            # Get violation details
            violations=$(oc get policy "$policy" -n default -o jsonpath='{.status.status[*].compliant}' 2>/dev/null || echo "")
            print_result "Policy compliance: $policy" "FAIL" "Status: NonCompliant - Check policy details for violations"
        else
            print_result "Policy compliance: $policy" "SKIP" "Status: $compliance (may be processing)"
        fi
    fi
done

echo ""

# Test 5: Check policy annotations
echo -e "${BLUE}Test Group: Policy Annotations${NC}"
echo ""

for policy in "${EXPECTED_POLICIES[@]}"; do
    if oc get policy "$policy" -n default &>/dev/null; then
        standards=$(oc get policy "$policy" -n default -o jsonpath='{.metadata.annotations.policy\.open-cluster-management\.io/standards}' 2>/dev/null || echo "")
        categories=$(oc get policy "$policy" -n default -o jsonpath='{.metadata.annotations.policy\.open-cluster-management\.io/categories}' 2>/dev/null || echo "")
        controls=$(oc get policy "$policy" -n default -o jsonpath='{.metadata.annotations.policy\.open-cluster-management\.io/controls}' 2>/dev/null || echo "")

        if [ -n "$standards" ] && [ -n "$categories" ] && [ -n "$controls" ]; then
            print_result "Policy annotations: $policy" "PASS"
        else
            print_result "Policy annotations: $policy" "FAIL" "Missing required annotations (standards, categories, or controls)"
        fi
    fi
done

echo ""

# Test 6: Check remediation actions
echo -e "${BLUE}Test Group: Remediation Actions${NC}"
echo ""

for policy in "${EXPECTED_POLICIES[@]}"; do
    if oc get policy "$policy" -n default &>/dev/null; then
        remediation=$(oc get policy "$policy" -n default -o jsonpath='{.spec.remediationAction}' 2>/dev/null || echo "")

        if [ "$remediation" == "inform" ] || [ "$remediation" == "enforce" ]; then
            print_result "Remediation action: $policy" "PASS" "Action: $remediation"
        else
            print_result "Remediation action: $policy" "FAIL" "Invalid or missing remediation action: $remediation"
        fi
    fi
done

echo ""

# Test 7: Verify policy templates
echo -e "${BLUE}Test Group: Policy Templates${NC}"
echo ""

for policy in "${EXPECTED_POLICIES[@]}"; do
    if oc get policy "$policy" -n default &>/dev/null; then
        template_count=$(oc get policy "$policy" -n default -o jsonpath='{.spec.policy-templates}' 2>/dev/null | grep -o 'objectDefinition' | wc -l || echo "0")

        if [ "$template_count" -gt 0 ]; then
            print_result "Policy templates: $policy" "PASS" "Templates: $template_count"
        else
            print_result "Policy templates: $policy" "FAIL" "No policy templates found"
        fi
    fi
done

echo ""

# Test 8: Check managed cluster availability
echo -e "${BLUE}Test Group: Managed Clusters${NC}"
echo ""

cluster_count=$(oc get managedclusters 2>/dev/null | grep -v NAME | wc -l || echo "0")
if [ "$cluster_count" -gt 0 ]; then
    print_result "Managed clusters available" "PASS" "Clusters: $cluster_count"

    # Check cluster availability
    available_clusters=$(oc get managedclusters -o json 2>/dev/null | jq -r '.items[] | select(.status.conditions[] | select(.type=="ManagedClusterConditionAvailable" and .status=="True")) | .metadata.name' | wc -l || echo "0")
    if [ "$available_clusters" -eq "$cluster_count" ]; then
        print_result "All managed clusters available" "PASS"
    else
        print_result "All managed clusters available" "FAIL" "Only $available_clusters of $cluster_count clusters are available"
    fi
else
    print_result "Managed clusters available" "SKIP" "No managed clusters found (single cluster setup)"
fi

echo ""

# Test 9: Check policy distribution
echo -e "${BLUE}Test Group: Policy Distribution${NC}"
echo ""

if [ "$cluster_count" -gt 0 ]; then
    for policy in "${EXPECTED_POLICIES[@]}"; do
        if oc get policy "$policy" -n default &>/dev/null; then
            distributed_count=$(oc get policy "$policy" -n default -o jsonpath='{.status.status}' 2>/dev/null | grep -o 'clustername' | wc -l || echo "0")

            if [ "$distributed_count" -gt 0 ]; then
                print_result "Policy distributed: $policy" "PASS" "Distributed to $distributed_count cluster(s)"
            else
                print_result "Policy distributed: $policy" "FAIL" "Policy not distributed to any clusters"
            fi
        fi
    done
else
    print_result "Policy distribution" "SKIP" "No managed clusters to distribute to"
fi

echo ""

# Test 10: Validate policy syntax (dry-run)
echo -e "${BLUE}Test Group: Policy YAML Validation${NC}"
echo ""

POLICY_FILES=(
    "policies/security/pod-security-policy.yaml"
    "policies/security/image-security-policy.yaml"
    "policies/security/certificate-policy.yaml"
    "policies/security/etcd-encryption-policy.yaml"
    "policies/security/namespace-security-policy.yaml"
    "policies/security/network-policy-governance.yaml"
    "policies/governance/rbac-governance-policy.yaml"
    "policies/governance/resource-quota-policy.yaml"
    "policies/compliance/container-security-operator.yaml"
)

for policy_file in "${POLICY_FILES[@]}"; do
    if [ -f "$policy_file" ]; then
        if oc apply -f "$policy_file" --dry-run=client &>/dev/null; then
            print_result "YAML validation: $(basename $policy_file)" "PASS"
        else
            print_result "YAML validation: $(basename $policy_file)" "FAIL" "Invalid YAML syntax"
        fi
    else
        print_result "YAML validation: $(basename $policy_file)" "FAIL" "File not found"
    fi
done

echo ""

# Print summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total Tests:  ${TOTAL_TESTS}"
echo -e "${GREEN}Passed:       ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed:       ${FAILED_TESTS}${NC}"
echo -e "${YELLOW}Skipped:      ${SKIPPED_TESTS}${NC}"
echo ""

# Calculate pass rate
if [ "$TOTAL_TESTS" -gt 0 ]; then
    PASS_RATE=$(echo "scale=2; ($PASSED_TESTS / ($TOTAL_TESTS - $SKIPPED_TESTS)) * 100" | bc)
    echo -e "Pass Rate:    ${PASS_RATE}%"
fi

echo -e "${BLUE}========================================${NC}"
echo ""

# Exit with error if any tests failed
if [ "$FAILED_TESTS" -gt 0 ]; then
    echo -e "${RED}Some tests failed. Please review the failures above.${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed successfully!${NC}"
    exit 0
fi
