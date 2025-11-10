# ==============================================================================
# PROJECT VARIABLES
# ==============================================================================

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

# ==============================================================================
# CLUSTER SELECTION
# ==============================================================================

variable "deploy_clusters" {
  description = "Comma-separated list of clusters to deploy (dev,stg,prd,sdx) or 'all' for all clusters"
  type        = string
  default     = "all"
}

locals {
  # Parse deploy_clusters string into a set
  clusters_to_deploy = var.deploy_clusters == "all" ? toset(["dev", "stg", "prd", "sdx"]) : toset(split(",", var.deploy_clusters))

  # Create boolean map for each cluster
  deploy_cluster_map = {
    dev = contains(local.clusters_to_deploy, "dev")
    stg = contains(local.clusters_to_deploy, "stg")
    prd = contains(local.clusters_to_deploy, "prd")
    sdx = contains(local.clusters_to_deploy, "sdx")
  }

  # Filter aks_clusters based on deploy_cluster_map
  filtered_aks_clusters = {
    for k, v in var.aks_clusters : k => v if local.deploy_cluster_map[k]
  }
}

# ==============================================================================
# AKS CONFIGURATION
# ==============================================================================

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
