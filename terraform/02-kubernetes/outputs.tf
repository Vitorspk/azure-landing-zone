output "aks_cluster_ids" {
  description = "Map of AKS cluster IDs"
  value = {
    for env, cluster in module.aks_clusters : env => cluster.cluster_id
  }
}

output "aks_cluster_names" {
  description = "Map of AKS cluster names"
  value = {
    for env, cluster in module.aks_clusters : env => cluster.cluster_name
  }
}

output "aks_cluster_endpoints" {
  description = "Map of AKS cluster API endpoints"
  value = {
    for env, cluster in module.aks_clusters : env => cluster.cluster_endpoint
  }
}

output "aks_kube_configs" {
  description = "Map of AKS kubeconfig files"
  value = {
    for env, cluster in module.aks_clusters : env => cluster.kube_config
  }
  sensitive = true
}

output "aks_node_resource_groups" {
  description = "Map of AKS node resource groups"
  value = {
    for env, cluster in module.aks_clusters : env => cluster.node_resource_group
  }
}
