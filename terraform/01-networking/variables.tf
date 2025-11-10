variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-network"
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
  default     = "vnet-shared-network"
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = string
  default     = "192.168.0.0/16"
}

variable "subnet_configs" {
  description = "Configuration for subnets"
  type = map(object({
    name              = string
    address_prefix    = string
    service_endpoints = list(string)
  }))
  default = {
    dev = {
      name              = "dev-subnet"
      address_prefix    = "192.168.0.0/20"
      service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault"]
    }
    stg = {
      name              = "stg-subnet"
      address_prefix    = "192.168.16.0/20"
      service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault"]
    }
    prd = {
      name              = "prd-subnet"
      address_prefix    = "192.168.32.0/20"
      service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault", "Microsoft.AzureCosmosDB"]
    }
    sdx = {
      name              = "sdx-subnet"
      address_prefix    = "192.168.48.0/20"
      service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault", "Microsoft.EventHub"]
    }
  }
}

variable "nsg_name" {
  description = "Name of the Network Security Group"
  type        = string
  default     = "nsg-allow-ssh"
}

variable "nat_gateway_name" {
  description = "Name of the NAT Gateway"
  type        = string
  default     = "nat-gateway-shared"
}

variable "nat_gateway_pip_name" {
  description = "Name of the Public IP for NAT Gateway"
  type        = string
  default     = "pip-nat-gateway-shared"
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
