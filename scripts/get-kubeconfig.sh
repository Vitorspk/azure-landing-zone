#!/bin/bash
set -e

RESOURCE_GROUP="${1:-rg-network}"

echo "Fetching kubeconfig for AKS clusters..."
echo ""

# Get list of existing clusters
EXISTING_CLUSTERS=$(az aks list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null)

if [ -z "$EXISTING_CLUSTERS" ]; then
    echo "❌ No AKS clusters found in resource group: $RESOURCE_GROUP"
    exit 1
fi

echo "Found clusters:"
echo "$EXISTING_CLUSTERS"
echo ""

# Get credentials for each existing cluster
for cluster in $EXISTING_CLUSTERS; do
    echo "Getting credentials for $cluster..."
    if az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$cluster" \
        --overwrite-existing 2>/dev/null; then
        echo "✓ $cluster credentials retrieved"
    else
        echo "⚠️  Failed to get credentials for $cluster"
    fi
done

echo ""
echo "✓ Kubeconfig updated successfully!"
echo ""
echo "Available contexts:"
kubectl config get-contexts

echo ""
echo "To switch context:"
echo "  kubectl config use-context <cluster-name>"
