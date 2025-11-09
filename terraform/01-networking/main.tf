terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Uncomment for remote state
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate"
  #   container_name       = "tfstate"
  #   key                  = "networking.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Data source for IAM resource group
data "azurerm_resource_group" "network" {
  name = var.resource_group_name
}

# ==========================================
# Virtual Network
# ==========================================

resource "azurerm_virtual_network" "shared" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = data.azurerm_resource_group.network.location
  resource_group_name = data.azurerm_resource_group.network.name
  tags                = var.tags
}

# ==========================================
# Subnets
# ==========================================

resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_configs

  name                 = each.value.name
  resource_group_name  = data.azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [each.value.address_prefix]
  service_endpoints    = each.value.service_endpoints

  # Disable private endpoint network policies
  private_endpoint_network_policies = "Disabled"
}

# ==========================================
# Network Security Groups
# ==========================================

resource "azurerm_network_security_group" "allow_ssh" {
  name                = var.nsg_name
  location            = data.azurerm_resource_group.network.location
  resource_group_name = data.azurerm_resource_group.network.name
  tags                = var.tags

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with Subnets
resource "azurerm_subnet_network_security_group_association" "subnets" {
  for_each = var.subnet_configs

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.allow_ssh.id
}

# ==========================================
# Public IP for NAT Gateway
# ==========================================

resource "azurerm_public_ip" "nat_gateway" {
  name                = var.nat_gateway_pip_name
  location            = data.azurerm_resource_group.network.location
  resource_group_name = data.azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# ==========================================
# NAT Gateway
# ==========================================

resource "azurerm_nat_gateway" "shared" {
  name                    = var.nat_gateway_name
  location                = data.azurerm_resource_group.network.location
  resource_group_name     = data.azurerm_resource_group.network.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
  # NAT Gateway doesn't support multiple zones - it's automatically zone-redundant when zones is not specified
  tags = var.tags
}

# Associate Public IP with NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "nat_gateway" {
  nat_gateway_id       = azurerm_nat_gateway.shared.id
  public_ip_address_id = azurerm_public_ip.nat_gateway.id
}

# Associate NAT Gateway with Subnets
resource "azurerm_subnet_nat_gateway_association" "subnets" {
  for_each = var.subnet_configs

  subnet_id      = azurerm_subnet.subnets[each.key].id
  nat_gateway_id = azurerm_nat_gateway.shared.id
}
