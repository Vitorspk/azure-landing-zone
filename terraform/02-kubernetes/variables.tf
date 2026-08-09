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

  # Values mirror terraform.tfvars.example (no secrets here — cluster
  # topology, not credentials). Without a default, this required variable
  # has no value in CI, which makes Terraform block on an interactive
  # prompt that never resolves on a non-interactive GitHub Actions runner.
  default = {
    dev = {
      cluster_name       = "aks-dev"
      subnet_name        = "dev-subnet"
      kubernetes_version = "1.36"

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
      kubernetes_version = "1.36"

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
      kubernetes_version = "1.36"

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
      kubernetes_version = "1.36"

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
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project   = "azure-landing-zone"
    ManagedBy = "terraform"
  }
}
