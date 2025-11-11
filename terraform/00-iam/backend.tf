terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "vschiavotfstate"
    container_name       = "tfstate"
    key                  = "azure-landing-zone/iam/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  # subscription_id will be read from ARM_SUBSCRIPTION_ID environment variable
}

provider "azuread" {
  # tenant_id will be read from ARM_TENANT_ID environment variable
}
