variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-network"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "brazilsouth"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "azure-landing-zone"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "shared"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "azure-landing-zone"
    ManagedBy   = "terraform"
    Environment = "shared"
  }
}

variable "create_service_principal" {
  description = "Create Service Principal for Terraform automation"
  type        = bool
  default     = false
}

variable "create_aks_identity" {
  description = "Create User-Assigned Managed Identity for AKS clusters"
  type        = bool
  default     = true
}
