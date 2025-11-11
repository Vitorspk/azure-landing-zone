# Data source for current Azure AD client
data "azuread_client_config" "current" {}

# Data source for current Azure RM client
data "azurerm_client_config" "current" {}

# Data source for subscription
data "azurerm_subscription" "current" {}

# Resource Group for IAM resources
resource "azurerm_resource_group" "iam" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ==========================================
# Service Principal for Terraform (Optional)
# ==========================================

# Azure AD Application for Terraform
resource "azuread_application" "terraform" {
  count        = var.create_service_principal ? 1 : 0
  display_name = "sp-terraform-${var.environment}"

  owners = [data.azuread_client_config.current.object_id]
}

# Service Principal for the Application
resource "azuread_service_principal" "terraform" {
  count                        = var.create_service_principal ? 1 : 0
  client_id                    = azuread_application.terraform[0].client_id
  app_role_assignment_required = false

  owners = [data.azuread_client_config.current.object_id]
}

# Service Principal Password/Secret
resource "azuread_service_principal_password" "terraform" {
  count                = var.create_service_principal ? 1 : 0
  service_principal_id = azuread_service_principal.terraform[0].id
  end_date             = timeadd(timestamp(), "8760h") # 1 year
}

# Role Assignment: Network Contributor on Resource Group
resource "azurerm_role_assignment" "terraform_network_contributor" {
  count                = var.create_service_principal ? 1 : 0
  scope                = azurerm_resource_group.iam.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_service_principal.terraform[0].object_id
}

# Role Assignment: Contributor on Subscription (if needed)
resource "azurerm_role_assignment" "terraform_contributor" {
  count                = var.create_service_principal ? 1 : 0
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.terraform[0].object_id
}

# ==========================================
# User-Assigned Managed Identity for AKS
# ==========================================

resource "azurerm_user_assigned_identity" "aks" {
  count               = var.create_aks_identity ? 1 : 0
  name                = "mi-aks-cluster-${var.environment}"
  resource_group_name = azurerm_resource_group.iam.name
  location            = azurerm_resource_group.iam.location
  tags                = var.tags
}

# Role Assignment: Network Contributor for AKS Identity
resource "azurerm_role_assignment" "aks_network_contributor" {
  count                = var.create_aks_identity ? 1 : 0
  scope                = azurerm_resource_group.iam.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks[0].principal_id
}

# Role Assignment: Storage Blob Data Contributor for AKS Identity
resource "azurerm_role_assignment" "aks_storage_contributor" {
  count                = var.create_aks_identity ? 1 : 0
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.aks[0].principal_id
}

# ==========================================
# Additional Managed Identities for Environments
# ==========================================

locals {
  environments = ["dev", "stg", "prd", "sdx"]
}

resource "azurerm_user_assigned_identity" "aks_env" {
  for_each            = var.create_aks_identity ? toset(local.environments) : toset([])
  name                = "mi-aks-${each.key}"
  resource_group_name = azurerm_resource_group.iam.name
  location            = azurerm_resource_group.iam.location

  tags = merge(var.tags, {
    Environment = each.key
  })
}

resource "azurerm_role_assignment" "aks_env_network_contributor" {
  for_each             = var.create_aks_identity ? toset(local.environments) : toset([])
  scope                = azurerm_resource_group.iam.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_env[each.key].principal_id
}

resource "azurerm_role_assignment" "aks_env_contributor" {
  for_each             = var.create_aks_identity ? toset(local.environments) : toset([])
  scope                = azurerm_resource_group.iam.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_env[each.key].principal_id
}
