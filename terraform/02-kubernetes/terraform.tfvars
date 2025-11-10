# Note: subscription_id is now read from ARM_SUBSCRIPTION_ID environment variable

resource_group_name = "rg-network"
vnet_name           = "vnet-shared-network"

aks_clusters = {
  dev = {
    cluster_name       = "aks-dev"
    subnet_name        = "dev-subnet"
    kubernetes_version = "1.31"

    default_node_pool = {
      name                = "system"
      node_count          = 1
      vm_size             = "Standard_D2s_v3"
      os_disk_size_gb     = 50
      os_disk_type        = "Ephemeral"
      max_pods            = 110
      enable_auto_scaling = true
      min_count           = 1
      max_count           = 3
      zones               = ["1"]
    }

    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = "192.168.100.10"
    service_cidr   = "192.168.100.0/24"

    private_cluster_enabled         = false
    api_server_authorized_ip_ranges = ["0.0.0.0/0"]

    enable_azure_policy = false
    enable_oms_agent    = false
  }

  stg = {
    cluster_name       = "aks-stg"
    subnet_name        = "stg-subnet"
    kubernetes_version = "1.31"

    default_node_pool = {
      name                = "system"
      node_count          = 1
      vm_size             = "Standard_D2s_v3"
      os_disk_size_gb     = 50
      os_disk_type        = "Ephemeral"
      max_pods            = 110
      enable_auto_scaling = true
      min_count           = 1
      max_count           = 3
      zones               = ["1"]
    }

    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = "192.168.101.10"
    service_cidr   = "192.168.101.0/24"

    private_cluster_enabled         = false
    api_server_authorized_ip_ranges = ["0.0.0.0/0"]

    enable_azure_policy = false
    enable_oms_agent    = false
  }

  prd = {
    cluster_name       = "aks-prd"
    subnet_name        = "prd-subnet"
    kubernetes_version = "1.31"

    default_node_pool = {
      name                = "system"
      node_count          = 2
      vm_size             = "Standard_D4s_v3"
      os_disk_size_gb     = 100
      os_disk_type        = "Managed"
      max_pods            = 110
      enable_auto_scaling = true
      min_count           = 2
      max_count           = 5
      zones               = ["1", "2"]
    }

    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = "192.168.102.10"
    service_cidr   = "192.168.102.0/24"

    private_cluster_enabled         = true
    api_server_authorized_ip_ranges = []

    enable_azure_policy = true
    enable_oms_agent    = false
  }

  sdx = {
    cluster_name       = "aks-sdx"
    subnet_name        = "sdx-subnet"
    kubernetes_version = "1.31"

    default_node_pool = {
      name                = "system"
      node_count          = 1
      vm_size             = "Standard_D2s_v3"
      os_disk_size_gb     = 50
      os_disk_type        = "Ephemeral"
      max_pods            = 110
      enable_auto_scaling = true
      min_count           = 1
      max_count           = 2
      zones               = ["1"]
    }

    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = "192.168.103.10"
    service_cidr   = "192.168.103.0/24"

    private_cluster_enabled         = false
    api_server_authorized_ip_ranges = ["0.0.0.0/0"]

    enable_azure_policy = false
    enable_oms_agent    = false
  }
}

tags = {
  Project    = "azure-landing-zone"
  ManagedBy  = "terraform"
  CostCenter = "infrastructure"
}
