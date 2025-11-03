variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "kubernetes_version" {
  description = "Version of Kubernetes"
  type        = string
}

variable "vnet_subnet_id" {
  description = "ID of the subnet for the AKS cluster"
  type        = string
}

variable "default_node_pool" {
  description = "Configuration for the default node pool"
  type = object({
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
}

variable "identity_ids" {
  description = "List of User Assigned Managed Identity IDs"
  type        = list(string)
}

variable "network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "network_policy" {
  description = "Network policy for AKS (azure or calico)"
  type        = string
  default     = "azure"
}

variable "dns_service_ip" {
  description = "IP address for DNS service"
  type        = string
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
}

variable "private_cluster_enabled" {
  description = "Enable private cluster"
  type        = bool
  default     = false
}

variable "api_server_authorized_ip_ranges" {
  description = "Authorized IP ranges for API server access"
  type        = list(string)
  default     = []
}

variable "enable_http_application_routing" {
  description = "Enable HTTP application routing add-on"
  type        = bool
  default     = false
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy add-on"
  type        = bool
  default     = false
}

variable "enable_oms_agent" {
  description = "Enable OMS agent for monitoring"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for OMS agent"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
