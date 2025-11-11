terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "vschiavotfstate"
    container_name       = "tfstate"
    key                  = "azure-landing-zone/kubernetes/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  # subscription_id will be read from ARM_SUBSCRIPTION_ID environment variable
}
