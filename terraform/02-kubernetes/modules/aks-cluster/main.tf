resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  node_resource_group = "${var.resource_group_name}-${var.cluster_name}-nodes"

  default_node_pool {
    name            = var.default_node_pool.name
    vm_size         = var.default_node_pool.vm_size
    os_disk_size_gb = var.default_node_pool.os_disk_size_gb
    os_disk_type    = var.default_node_pool.os_disk_type
    vnet_subnet_id  = var.vnet_subnet_id
    max_pods        = var.default_node_pool.max_pods
    zones           = var.default_node_pool.zones

    # Auto-scaling configuration
    auto_scaling_enabled = var.default_node_pool.enable_auto_scaling
    node_count           = var.default_node_pool.enable_auto_scaling ? null : var.default_node_pool.node_count
    min_count            = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.min_count : null
    max_count            = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.max_count : null

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = var.identity_ids
  }

  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    dns_service_ip    = var.dns_service_ip
    service_cidr      = var.service_cidr
    load_balancer_sku = "standard"
  }

  private_cluster_enabled = var.private_cluster_enabled

  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  http_application_routing_enabled = var.enable_http_application_routing

  azure_policy_enabled = var.enable_azure_policy

  dynamic "oms_agent" {
    for_each = var.enable_oms_agent && var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  # automatic_upgrade_channel removed - defaults to no automatic upgrades when not specified

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [22, 23]
    }
  }

  tags = var.tags
}
