variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

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

variable "aks_clusters" {
  description = "Configuration for AKS clusters"
  type = map(object({
    cluster_name       = string
    subnet_name        = string
    kubernetes_version = string
    
    default_node_pool = object({
      name                = string
      node_count          = number
      vm_size             = string
      os_disk_size_gb     = number
      os_disk_type        = string
      max_pods            = number
      enable_auto_scaling = bool
      min_count           = number
      max_count           = number
      zones               = list(string)
    })
    
    network_plugin = string
    network_policy = string
    dns_service_ip = string
    service_cidr   = string
    
    private_cluster_enabled         = bool
    api_server_authorized_ip_ranges = list(string)
    
    enable_azure_policy = bool
    enable_oms_agent    = bool
  }))
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project   = "azure-landing-zone"
    ManagedBy = "terraform"
  }
}
