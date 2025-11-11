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

# Configuration
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="vschiavotfstate"
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
    echo -e "${YELLOW}⚠️  Resource group already exists${NC}"
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
    echo -e "${YELLOW}⚠️  Storage account already exists${NC}"
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

# Enable versioning
echo -e "${BLUE}Step 3: Enabling Blob Versioning${NC}"
az storage account blob-service-properties update \
    --account-name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --enable-versioning true \
    --enable-change-feed true

echo -e "${GREEN}✓ Blob versioning enabled${NC}"
echo ""

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query '[0].value' -o tsv)

# Create container
echo -e "${BLUE}Step 4: Creating Blob Container${NC}"
if az storage container show \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$ACCOUNT_KEY" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Container already exists${NC}"
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
echo -e "${BLUE}Step 5: Verifying Setup${NC}"
echo ""
az group show --name "$RESOURCE_GROUP" --query "{Name:name, Location:location}" -o table
echo ""
az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "{Name:name, Sku:sku.name}" -o table

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ Azure Storage Backend Created!${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════════
# NEXT STEPS
# ═══════════════════════════════════════════════════════════════

echo -e "${BOLD}NEXT STEPS - Choose Migration Strategy:${NC}"
echo ""

echo -e "${BOLD}Option A: Start Fresh${NC} ${GREEN}(Recommended - Simplest)${NC}"
echo "──────────────────────────────────────────────────────────────"
echo "Best if: No critical resources or willing to redeploy"
echo ""
echo "1. Clean existing Azure resources:"
echo -e "   ${GREEN}./scripts/cleanup-complete.sh${NC}"
echo ""
echo "2. Initialize modules with empty backend:"
echo -e "   ${GREEN}cd terraform/00-iam && terraform init${NC}"
echo -e "   ${GREEN}cd ../01-networking && terraform init${NC}"
echo -e "   ${GREEN}cd ../02-kubernetes && terraform init${NC}"
echo ""
echo "3. Deploy via GitHub Actions (state will be saved remotely)"
echo ""

echo -e "${BOLD}Option B: Migrate Existing State${NC} ${YELLOW}(If you have resources)${NC}"
echo "──────────────────────────────────────────────────────────────"
echo "Best if: Have resources in Azure that must be preserved"
echo ""
echo "1. BACKUP current state files:"
echo -e "   ${YELLOW}mkdir -p state-backup-\$(date +%Y%m%d)${NC}"
echo -e "   ${YELLOW}cp terraform/*/terraform.tfstate* state-backup-\$(date +%Y%m%d)/${NC}"
echo ""
echo "2. Migrate each module:"
echo -e "   ${GREEN}cd terraform/00-iam${NC}"
echo -e "   ${GREEN}terraform init -migrate-state${NC}"
echo -e "   ${YELLOW}   → Type 'yes' when prompted${NC}"
echo ""
echo -e "   ${GREEN}cd ../01-networking${NC}"
echo -e "   ${GREEN}terraform init -migrate-state${NC}"
echo -e "   ${YELLOW}   → Type 'yes' when prompted${NC}"
echo ""
echo -e "   ${GREEN}cd ../02-kubernetes${NC}"
echo -e "   ${GREEN}terraform init -migrate-state${NC}"
echo -e "   ${YELLOW}   → Type 'yes' when prompted${NC}"
echo ""
echo "3. Verify migration:"
echo -e "   ${GREEN}terraform state list${NC} (in each module)"
echo ""
echo "4. Test plan to ensure state is correct:"
echo -e "   ${GREEN}terraform plan${NC} (should show no changes)"
echo ""
echo "5. Delete local state files after verification:"
echo -e "   ${GREEN}rm terraform/*/terraform.tfstate*${NC}"
echo ""

echo -e "${BOLD}Option C: Rollback${NC} ${RED}(If migration fails)${NC}"
echo "──────────────────────────────────────────────────────────────"
echo "1. Restore from backup:"
echo -e "   ${GREEN}cp state-backup-*/terraform.tfstate terraform/00-iam/${NC}"
echo ""
echo "2. Remove backend config temporarily:"
echo -e "   ${GREEN}mv terraform/00-iam/backend.tf terraform/00-iam/backend.tf.disabled${NC}"
echo ""
echo "3. Re-initialize with local backend:"
echo -e "   ${GREEN}cd terraform/00-iam && terraform init${NC}"
echo ""
echo "4. Retry migration after fixing issues"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo -e "${BLUE}Storage Details:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Container: $CONTAINER_NAME"
echo ""
echo -e "${RED}⚠️  NEVER delete rg-terraform-state - it contains all state!${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
