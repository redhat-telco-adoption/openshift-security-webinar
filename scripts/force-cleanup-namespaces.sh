#!/bin/bash
# Force cleanup script for namespaces stuck in Terminating status
# This removes finalizers to allow namespace deletion to complete
#
# SAFETY: This script ONLY targets namespaces created by this demo project
# to prevent accidentally breaking the OpenShift cluster.

set -e

echo "=== Force Namespace Cleanup Script ==="
echo "This script will remove finalizers from stuck namespaces"
echo ""
echo "⚠️  SAFETY: Only cleaning up demo project namespaces"
echo "    This script will NOT touch cluster infrastructure namespaces"
echo ""

# List of namespaces created by this demo project
# IMPORTANT: Only add namespaces that are explicitly created by this demo
NAMESPACES=(
  "security-demo"
  "test-namespace"
)

echo "Checking for stuck namespaces..."
echo ""

# Additional safety check: prevent deletion of critical cluster namespaces
PROTECTED_NAMESPACES=(
  "default"
  "kube-system"
  "kube-public"
  "kube-node-lease"
  "openshift"
  "openshift-.*"
  "open-cluster-management"
  "open-cluster-management-.*"
  "multicluster-engine"
  "cert-manager"
  "rhacs-operator"
  "stackrox"
  "hive"
  "hypershift"
)

# Validate that we're not targeting protected namespaces
for ns in "${NAMESPACES[@]}"; do
  for protected in "${PROTECTED_NAMESPACES[@]}"; do
    if [[ "$ns" =~ ^$protected$ ]]; then
      echo "❌ ERROR: Cannot target protected namespace: $ns"
      echo "   This namespace is critical cluster infrastructure"
      exit 1
    fi
  done
done

# Confirmation prompt
echo "About to force-cleanup the following namespaces if stuck:"
for ns in "${NAMESPACES[@]}"; do
  echo "  - $ns"
done
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted by user"
  exit 0
fi

echo ""
echo "Proceeding with cleanup..."
echo ""

for ns in "${NAMESPACES[@]}"; do
  # Check if namespace exists and is terminating
  STATUS=$(oc get namespace "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

  if [ "$STATUS" == "Terminating" ]; then
    echo "Found stuck namespace: $ns"
    echo "  Current status: Terminating"

    # Get current finalizers
    FINALIZERS=$(oc get namespace "$ns" -o jsonpath='{.spec.finalizers[*]}' 2>/dev/null || echo "")
    echo "  Current finalizers: ${FINALIZERS:-none}"

    # Remove all finalizers using JSON patch to force update
    echo "  Removing finalizers..."
    oc get namespace "$ns" -o json | \
      jq '.spec.finalizers = []' | \
      oc replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || {
        echo "  Failed with finalize API, trying patch..."
        oc patch namespace "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge || \
        echo "  Failed to remove finalizers for $ns"
      }

    # Verify removal
    sleep 2
    NEW_STATUS=$(oc get namespace "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Deleted")
    if [ "$NEW_STATUS" == "Deleted" ] || [ "$NEW_STATUS" == "" ]; then
      echo "  ✓ Namespace $ns successfully deleted"
    else
      echo "  ⚠ Namespace $ns still exists with status: $NEW_STATUS"
    fi
    echo ""
  elif [ "$STATUS" == "NotFound" ]; then
    echo "Namespace $ns: Already deleted ✓"
  else
    echo "Namespace $ns: Status is $STATUS (not stuck)"
  fi
done

echo ""
echo "=== Cleanup Complete ==="
echo "Checking for any remaining Terminating namespaces..."
oc get namespaces | grep Terminating || echo "No namespaces stuck in Terminating status ✓"
