#!/bin/bash
set -e

echo "Setting up OpenShift ACM Security Demo..."

# Check if logged in to OpenShift
if ! oc whoami &> /dev/null; then
    echo "Error: Not logged in to OpenShift. Please run 'oc login' first."
    exit 1
fi

# Create namespace
echo "Creating demo namespace..."
oc apply -f manifests/namespaces/

# Apply RBAC configurations
echo "Applying RBAC configurations..."
oc apply -f manifests/rbac/

# Apply Network Policies
echo "Applying Network Policies..."
oc apply -f manifests/network-policies/

# Apply Security Context Constraints (requires cluster-admin)
echo "Applying Security Context Constraints..."
oc apply -f manifests/scc/

# Deploy sample application
echo "Deploying sample application..."
oc apply -f applications/sample-app/

# Apply ACM Policies (if ACM is available)
if oc get crd policies.policy.open-cluster-management.io &> /dev/null; then
    echo "Applying ACM policies..."
    oc apply -f policies/security/
    oc apply -f policies/compliance/
else
    echo "Warning: ACM not detected. Skipping policy deployment."
fi

echo "Demo setup complete!"
echo "Run 'oc get all -n security-demo' to verify deployment."
