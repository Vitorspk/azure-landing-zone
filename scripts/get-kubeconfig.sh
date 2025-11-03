#!/bin/bash
set -e

RESOURCE_GROUP="${1:-rg-network}"
CLUSTERS=("aks-dev" "aks-stg" "aks-prd" "aks-sdx")

echo "Fetching kubeconfig for AKS clusters..."

for cluster in "${CLUSTERS[@]}"; do
    echo "Getting credentials for $cluster..."
    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$cluster" \
        --overwrite-existing
done

echo ""
echo "✓ Kubeconfig updated successfully!"
echo ""
echo "Available contexts:"
kubectl config get-contexts
