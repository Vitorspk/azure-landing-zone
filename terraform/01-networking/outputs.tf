output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.network.name
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.shared.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.shared.name
}

output "vnet_address_space" {
  description = "Address space of the Virtual Network"
  value       = azurerm_virtual_network.shared.address_space
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value = {
    for key, subnet in azurerm_subnet.subnets : key => subnet.id
  }
}

output "subnet_names" {
  description = "Map of environment to subnet names"
  value = {
    for key, subnet in azurerm_subnet.subnets : key => subnet.name
  }
}

output "nsg_id" {
  description = "ID of the Network Security Group"
  value       = azurerm_network_security_group.allow_ssh.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = azurerm_nat_gateway.shared.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = azurerm_public_ip.nat_gateway.ip_address
}
