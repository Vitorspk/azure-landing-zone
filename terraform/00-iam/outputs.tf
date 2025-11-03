# Resource Group Outputs
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.iam.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.iam.id
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.iam.location
}

# Service Principal Outputs
output "terraform_service_principal_client_id" {
  description = "Client ID of the Terraform Service Principal"
  value       = var.create_service_principal ? azuread_application.terraform[0].client_id : null
  sensitive   = true
}

output "terraform_service_principal_object_id" {
  description = "Object ID of the Terraform Service Principal"
  value       = var.create_service_principal ? azuread_service_principal.terraform[0].object_id : null
}

output "terraform_service_principal_client_secret" {
  description = "Client Secret of the Terraform Service Principal"
  value       = var.create_service_principal ? azuread_service_principal_password.terraform[0].value : null
  sensitive   = true
}

# AKS Managed Identity Outputs
output "aks_identity_id" {
  description = "ID of the AKS User-Assigned Managed Identity"
  value       = var.create_aks_identity ? azurerm_user_assigned_identity.aks[0].id : null
}

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS User-Assigned Managed Identity"
  value       = var.create_aks_identity ? azurerm_user_assigned_identity.aks[0].principal_id : null
}

output "aks_identity_client_id" {
  description = "Client ID of the AKS User-Assigned Managed Identity"
  value       = var.create_aks_identity ? azurerm_user_assigned_identity.aks[0].client_id : null
}

# Environment Managed Identities
output "aks_env_identities" {
  description = "Map of environment AKS Managed Identities"
  value = var.create_aks_identity ? {
    for env, identity in azurerm_user_assigned_identity.aks_env : env => {
      id           = identity.id
      principal_id = identity.principal_id
      client_id    = identity.client_id
      name         = identity.name
    }
  } : {}
}

# Subscription Information
output "subscription_id" {
  description = "Current Azure Subscription ID"
  value       = data.azurerm_subscription.current.subscription_id
}

output "tenant_id" {
  description = "Current Azure Tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}
