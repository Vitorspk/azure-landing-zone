# Note: Azure credentials are now read from environment variables:
#   - ARM_SUBSCRIPTION_ID (subscription_id)
#   - ARM_TENANT_ID (tenant_id)
#   Set them via: export ARM_SUBSCRIPTION_ID="..." ARM_TENANT_ID="..."
#   Or in GitHub Actions secrets as: AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID

# Resource Group Configuration
resource_group_name = "rg-network"
location            = "brazilsouth" # or "eastus"

# Project Configuration
project_name = "azure-landing-zone"
environment  = "shared"

# Identity Configuration
create_service_principal = false # Set to true if you need a Service Principal for automation
create_aks_identity      = true  # Create Managed Identities for AKS clusters

# Tags
tags = {
  Project     = "azure-landing-zone"
  ManagedBy   = "terraform"
  Environment = "shared"
  CostCenter  = "infrastructure"
}
