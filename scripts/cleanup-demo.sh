#!/bin/bash
set -e

echo "Cleaning up OpenShift ACM Security Demo..."

# Delete sample application
echo "Deleting sample application..."
oc delete -f applications/sample-app/ --ignore-not-found=true

# Delete ACM Policies
if oc get crd policies.policy.open-cluster-management.io &> /dev/null; then
    echo "Deleting ACM policies..."
    oc delete -f policies/security/ --ignore-not-found=true
    oc delete -f policies/compliance/ --ignore-not-found=true
fi

# Delete Network Policies
echo "Deleting Network Policies..."
oc delete -f manifests/network-policies/ --ignore-not-found=true

# Delete RBAC configurations
echo "Deleting RBAC configurations..."
oc delete -f manifests/rbac/ --ignore-not-found=true

# Delete SCC (requires cluster-admin)
echo "Deleting Security Context Constraints..."
oc delete -f manifests/scc/ --ignore-not-found=true

# Delete namespace
echo "Deleting demo namespace..."
oc delete -f manifests/namespaces/ --ignore-not-found=true

echo "Demo cleanup complete!"
