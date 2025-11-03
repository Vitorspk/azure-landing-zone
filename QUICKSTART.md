# 🚀 Quick Start Guide

## Pré-requisitos

```bash
# Verificar instalações
terraform version  # >= 1.5.0
az version        # >= 2.50.0
```

## Deploy Rápido

```bash
# 1. Autenticar
az login
az account set --subscription "<subscription-id>"

# 2. Configurar variáveis (para cada módulo)
cd terraform/00-iam
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com subscription_id e tenant_id

# 3. Deploy tudo
cd ../..
make deploy-all

# 4. Obter kubeconfigs
./scripts/get-kubeconfig.sh

# 5. Verificar
kubectl get nodes
```

## Configuração Mínima

Edite `terraform/00-iam/terraform.tfvars`:
```hcl
subscription_id = "sua-subscription-id-aqui"
tenant_id       = "seu-tenant-id-aqui"
```

Edite `terraform/01-networking/terraform.tfvars`:
```hcl
subscription_id = "sua-subscription-id-aqui"
```

Edite `terraform/02-kubernetes/terraform.tfvars`:
```hcl
subscription_id = "sua-subscription-id-aqui"
```

## Obter IDs necessários

```bash
# Subscription ID
az account show --query id -o tsv

# Tenant ID
az account show --query tenantId -o tsv
```

## Deploy por Módulo

```bash
# IAM
make iam-apply

# Networking
make network-apply

# Kubernetes
make k8s-apply
```

## Verificar Deploy

```bash
# Resource Group
az group show --name rg-network

# VNet
az network vnet list --resource-group rg-network --output table

# Clusters
az aks list --resource-group rg-network --output table
```

## Custos

~$350-650/mês (estimado)

## Documentação Completa

Ver `docs/DEPLOYMENT.md` para guia detalhado.
