# Data sources
data "azurerm_resource_group" "network" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "shared" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "environments" {
  for_each = local.filtered_aks_clusters

  name                 = each.value.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

data "azurerm_user_assigned_identity" "aks_env" {
  for_each = local.filtered_aks_clusters

  name                = "mi-aks-${each.key}"
  resource_group_name = var.resource_group_name
}

# ==============================================================================
# AKS CLUSTERS (Selective Deployment)
# ==============================================================================
# Only clusters specified in deploy_clusters variable will be deployed.
# Use deploy_clusters="all" to deploy all clusters (default).
# Use deploy_clusters="dev" to deploy only DEV cluster.
# Use deploy_clusters="dev,stg" to deploy DEV and STG clusters.
# ==============================================================================

module "aks_clusters" {
  source = "./modules/aks-cluster"

  for_each = local.filtered_aks_clusters

  cluster_name        = each.value.cluster_name
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.network.location

  kubernetes_version = each.value.kubernetes_version

  # Network configuration
  vnet_subnet_id = data.azurerm_subnet.environments[each.key].id

  # Node pool configuration
  default_node_pool = each.value.default_node_pool

  # Identity
  identity_ids = [data.azurerm_user_assigned_identity.aks_env[each.key].id]

  # Network
  network_plugin = each.value.network_plugin
  network_policy = each.value.network_policy
  dns_service_ip = each.value.dns_service_ip
  service_cidr   = each.value.service_cidr

  # Security
  private_cluster_enabled         = each.value.private_cluster_enabled
  api_server_authorized_ip_ranges = each.value.api_server_authorized_ip_ranges

  # Add-ons
  enable_azure_policy = each.value.enable_azure_policy
  enable_oms_agent    = each.value.enable_oms_agent

  tags = merge(var.tags, {
    Environment = each.key
    Cluster     = each.value.cluster_name
  })
}
