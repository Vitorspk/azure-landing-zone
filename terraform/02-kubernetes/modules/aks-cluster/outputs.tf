output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kube_config" {
  description = "Kubernetes configuration"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Endpoint for the AKS cluster API server"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "cluster_identity" {
  description = "Identity of the AKS cluster"
  value = {
    type         = azurerm_kubernetes_cluster.aks.identity[0].type
    principal_id = azurerm_kubernetes_cluster.aks.identity[0].principal_id
    tenant_id    = azurerm_kubernetes_cluster.aks.identity[0].tenant_id
  }
}

output "kubelet_identity" {
  description = "Kubelet identity"
  value = {
    client_id                 = azurerm_kubernetes_cluster.aks.kubelet_identity[0].client_id
    object_id                 = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
    user_assigned_identity_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].user_assigned_identity_id
  }
}

output "node_resource_group" {
  description = "Resource group name for AKS nodes"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}
