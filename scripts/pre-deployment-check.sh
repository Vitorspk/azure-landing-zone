#!/bin/bash
set -e

echo "Running pre-deployment checks..."

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "✗ Terraform not installed"
    exit 1
fi
echo "✓ Terraform installed: $(terraform version | head -n1)"

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo "✗ Azure CLI not installed"
    exit 1
fi
echo "✓ Azure CLI installed: $(az version --query '\"azure-cli\"' -o tsv)"

# Check Azure login
if ! az account show &> /dev/null; then
    echo "✗ Not logged in to Azure. Run: az login"
    exit 1
fi
echo "✓ Logged in to Azure"

# Check subscription
SUBSCRIPTION=$(az account show --query id -o tsv)
echo "✓ Current subscription: $SUBSCRIPTION"

echo ""
echo "✓ All pre-deployment checks passed!"
