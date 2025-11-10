#!/bin/bash
# ==============================================================================
# IMPORT EXISTING AZURE RESOURCES INTO TERRAFORM STATE
# ==============================================================================
# This script imports existing Azure resources into Terraform state to avoid
# "already exists" errors when running terraform apply on existing infrastructure.
#
# Usage: ./scripts/import-existing-resources.sh <module> <subscription_id>
# Example: ./scripts/import-existing-resources.sh 00-iam 35a5288e-6993-4afa-97a9-2862baaf944e

set -e

MODULE=${1:-"00-iam"}
SUBSCRIPTION_ID=${2:-$ARM_SUBSCRIPTION_ID}
RESOURCE_GROUP="rg-network"

if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "❌ Error: SUBSCRIPTION_ID not provided"
  echo "Usage: $0 <module> <subscription_id>"
  echo "   or: export ARM_SUBSCRIPTION_ID=<subscription_id>"
  exit 1
fi

echo "=================================================="
echo "🔄 Importing Existing Resources"
echo "=================================================="
echo "Module: $MODULE"
echo "Subscription: $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

cd terraform/$MODULE

# ==============================================================================
# MODULE 00-iam
# ==============================================================================

if [ "$MODULE" == "00-iam" ]; then
  echo "📦 Importing IAM resources..."
  
  # 1. Resource Group
  if az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "  → Resource Group: $RESOURCE_GROUP"
    terraform import azurerm_resource_group.iam /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP 2>/dev/null || echo "    Already in state"
  fi
  
  # 2. Managed Identity: Shared (se create_aks_identity=true no tfvars)
  if az identity show --name mi-aks-cluster-shared --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "  → Managed Identity: mi-aks-cluster-shared"
    terraform import 'azurerm_user_assigned_identity.aks[0]' /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-aks-cluster-shared 2>/dev/null || echo "    Already in state"
  fi
  
  # 3. Managed Identities: Per Environment
  for env in dev stg prd sdx; do
    if az identity show --name mi-aks-$env --resource-group $RESOURCE_GROUP &>/dev/null; then
      echo "  → Managed Identity: mi-aks-$env"
      terraform import "azurerm_user_assigned_identity.aks_env[\"$env\"]" /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-aks-$env 2>/dev/null || echo "    Already in state"
    fi
  done
  
  echo "✅ IAM resources import completed"
fi

# ==============================================================================
# MODULE 01-networking
# ==============================================================================

if [ "$MODULE" == "01-networking" ]; then
  echo "🌐 Importing Networking resources..."
  
  # 1. Virtual Network
  if az network vnet show --name vnet-shared-network --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "  → Virtual Network: vnet-shared-network"
    terraform import azurerm_virtual_network.shared /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/vnet-shared-network 2>/dev/null || echo "    Already in state"
  fi
  
  # 2. Subnets
  for subnet in dev-subnet stg-subnet prd-subnet sdx-subnet; do
    env=$(echo $subnet | cut -d'-' -f1)
    if az network vnet subnet show --vnet-name vnet-shared-network --name $subnet --resource-group $RESOURCE_GROUP &>/dev/null; then
      echo "  → Subnet: $subnet"
      terraform import "azurerm_subnet.subnets[\"$env\"]" /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/vnet-shared-network/subnets/$subnet 2>/dev/null || echo "    Already in state"
    fi
  done
  
  # 3. Network Security Group
  if az network nsg show --name nsg-allow-ssh --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "  → NSG: nsg-allow-ssh"
    terraform import azurerm_network_security_group.allow_ssh /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/networkSecurityGroups/nsg-allow-ssh 2>/dev/null || echo "    Already in state"
  fi
  
  # 4. Public IP for NAT Gateway
  if az network public-ip show --name pip-nat-gateway-shared --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "  → Public IP: pip-nat-gateway-shared"
    terraform import azurerm_public_ip.nat_gateway /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/publicIPAddresses/pip-nat-gateway-shared 2>/dev/null || echo "    Already in state"
  fi
  
  # 5. NAT Gateway
  if az network nat gateway show --name nat-gateway-shared --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "  → NAT Gateway: nat-gateway-shared"
    terraform import azurerm_nat_gateway.shared /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/natGateways/nat-gateway-shared 2>/dev/null || echo "    Already in state"
  fi
  
  echo "✅ Networking resources import completed"
  echo ""
  echo "⚠️  Note: Associations (NSG, NAT) are not imported - they will be created/updated as needed"
fi

# ==============================================================================
# MODULE 02-kubernetes
# ==============================================================================

if [ "$MODULE" == "02-kubernetes" ]; then
  echo "☸️  Importing Kubernetes resources..."
  
  # AKS Clusters
  for cluster in aks-dev aks-stg aks-prd aks-sdx; do
    env=$(echo $cluster | cut -d'-' -f2)
    if az aks show --name $cluster --resource-group $RESOURCE_GROUP &>/dev/null; then
      echo "  → AKS Cluster: $cluster"
      terraform import "module.aks_clusters[\"$env\"].azurerm_kubernetes_cluster.aks" /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$cluster 2>/dev/null || echo "    Already in state"
    fi
  done
  
  echo "✅ Kubernetes resources import completed"
fi

echo ""
echo "=================================================="
echo "✅ Import process completed!"
echo "=================================================="
echo ""
echo "Next step: Run 'terraform plan' to verify state"
