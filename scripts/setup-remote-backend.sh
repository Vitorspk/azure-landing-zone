#!/bin/bash

# Setup Azure Storage Backend for Terraform State
# This script creates the infrastructure needed for remote state management

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}"
echo "═══════════════════════════════════════════════════════════"
echo "  Azure Storage Backend Setup for Terraform State"
echo "═══════════════════════════════════════════════════════════"
echo -e "${NC}"
echo ""

# Configuration (matching AWS/GCP pattern: vschiavo-home-terraform-state)
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="vschiavotfstate"  # Must be globally unique, 3-24 chars, lowercase + numbers only
CONTAINER_NAME="tfstate"
LOCATION="brazilsouth"

echo -e "${BLUE}Configuration:${NC}"
echo "  Resource Group:    $RESOURCE_GROUP"
echo "  Storage Account:   $STORAGE_ACCOUNT"
echo "  Container:         $CONTAINER_NAME"
echo "  Location:          $LOCATION"
echo ""

# Check if logged in
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged in to Azure${NC}"
    echo "Run: az login"
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo -e "${GREEN}✓ Logged in to Azure${NC}"
echo "  Subscription: $SUBSCRIPTION"
echo "  ID: $SUBSCRIPTION_ID"
echo ""

# Check if resource group exists
echo -e "${BLUE}Step 1: Creating Resource Group${NC}"
if az group exists --name "$RESOURCE_GROUP" 2>/dev/null | grep -q "true"; then
    echo -e "${YELLOW}⚠️  Resource group '$RESOURCE_GROUP' already exists${NC}"
else
    echo "Creating resource group..."
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "Purpose=TerraformState" "ManagedBy=Manual" "Project=azure-landing-zone"
    
    echo -e "${GREEN}✓ Resource group created${NC}"
fi
echo ""

# Check if storage account exists
echo -e "${BLUE}Step 2: Creating Storage Account${NC}"
if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Storage account '$STORAGE_ACCOUNT' already exists${NC}"
else
    echo "Creating storage account..."
    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --encryption-services blob \
        --https-only true \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --tags "Purpose=TerraformState" "ManagedBy=Manual"
    
    echo -e "${GREEN}✓ Storage account created${NC}"
fi
echo ""

# Enable versioning for state file protection
echo -e "${BLUE}Step 3: Enabling Blob Versioning${NC}"
az storage account blob-service-properties update \
    --account-name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --enable-versioning true \
    --enable-change-feed true

echo -e "${GREEN}✓ Blob versioning enabled${NC}"
echo ""

# Get storage account key
echo -e "${BLUE}Step 4: Getting Storage Account Key${NC}"
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query '[0].value' -o tsv)

echo -e "${GREEN}✓ Storage key retrieved${NC}"
echo ""

# Create container
echo -e "${BLUE}Step 5: Creating Blob Container${NC}"
if az storage container show \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$ACCOUNT_KEY" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Container '$CONTAINER_NAME' already exists${NC}"
else
    az storage container create \
        --name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$ACCOUNT_KEY" \
        --public-access off
    
    echo -e "${GREEN}✓ Container created${NC}"
fi
echo ""

# Verify setup
echo -e "${BLUE}Step 6: Verifying Setup${NC}"
echo ""
echo "Resource Group:"
az group show --name "$RESOURCE_GROUP" --query "{Name:name, Location:location, State:properties.provisioningState}" -o table

echo ""
echo "Storage Account:"
az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{Name:name, Location:location, Sku:sku.name, Https:enableHttpsTrafficOnly, Versioning:'Enabled'}" -o table

echo ""
echo "Container:"
az storage container show \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$ACCOUNT_KEY" \
    --query "{Name:name, PublicAccess:properties.publicAccess}" -o table

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ Azure Storage Backend Setup Complete!${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo -e "${BOLD}Backend Configuration:${NC}"
echo ""
echo "terraform {"
echo "  backend \"azurerm\" {"
echo "    resource_group_name  = \"$RESOURCE_GROUP\""
echo "    storage_account_name = \"$STORAGE_ACCOUNT\""
echo "    container_name       = \"$CONTAINER_NAME\""
echo "    key                  = \"azure-landing-zone/MODULE/terraform.tfstate\""
echo "  }"
echo "}"
echo ""

echo -e "${YELLOW}This configuration is already in your backend.tf files!${NC}"
echo ""

echo -e "${BOLD}Next Steps:${NC}"
echo ""
echo "1. The backend.tf files have been created in each module"
echo "2. You need to migrate existing state to remote backend:"
echo ""
echo -e "${GREEN}cd terraform/00-iam${NC}"
echo -e "${GREEN}terraform init -migrate-state${NC}"
echo ""
echo -e "${GREEN}cd ../01-networking${NC}"
echo -e "${GREEN}terraform init -migrate-state${NC}"
echo ""
echo -e "${GREEN}cd ../02-kubernetes${NC}"
echo -e "${GREEN}terraform init -migrate-state${NC}"
echo ""
echo "4. After migration, you can safely delete local .tfstate files"
echo ""

echo -e "${BLUE}Storage Account Details:${NC}"
echo "  Name: $STORAGE_ACCOUNT"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Container: $CONTAINER_NAME"
echo ""
echo -e "${YELLOW}⚠️  Keep this storage account! It's critical for state management.${NC}"
echo -e "${YELLOW}    Never delete rg-terraform-state resource group.${NC}"
echo ""
