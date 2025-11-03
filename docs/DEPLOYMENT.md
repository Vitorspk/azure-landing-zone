# Guia de Deployment

## Pré-requisitos

- Terraform >= 1.5.0
- Azure CLI >= 2.50.0
- kubectl (opcional)

## Autenticação

```bash
az login
az account set --subscription "<subscription-id>"
```

## Deploy Completo

### 1. Configurar Variáveis

```bash
# Para cada módulo
cd terraform/00-iam
cp terraform.tfvars.example terraform.tfvars
# Editar com seus valores

cd ../01-networking
cp terraform.tfvars.example terraform.tfvars
# Editar com seus valores

cd ../02-kubernetes
cp terraform.tfvars.example terraform.tfvars
# Editar com seus valores
```

### 2. Deploy em Ordem

```bash
# IAM
cd terraform/00-iam
terraform init
terraform plan
terraform apply

# Networking
cd ../01-networking
terraform init
terraform plan
terraform apply

# Kubernetes
cd ../02-kubernetes
terraform init
terraform plan
terraform apply
```

### 3. Obter Kubeconfigs

```bash
az aks get-credentials --resource-group rg-network --name aks-dev
az aks get-credentials --resource-group rg-network --name aks-stg
az aks get-credentials --resource-group rg-network --name aks-prd
az aks get-credentials --resource-group rg-network --name aks-sdx
```

## Validações

```bash
# Verificar clusters
az aks list --resource-group rg-network --output table

# Verificar nodes
kubectl get nodes

# Verificar conectividade
kubectl run test --image=nginx --rm -it -- curl https://ifconfig.me
```

## Rollback

```bash
# Ordem reversa
cd terraform/02-kubernetes && terraform destroy
cd ../01-networking && terraform destroy
cd ../00-iam && terraform destroy
```

## Troubleshooting

### Cluster não acessível
```bash
az aks update \
  --resource-group rg-network \
  --name aks-dev \
  --api-server-authorized-ip-ranges $(curl -s https://ifconfig.me)/32
```

### Verificar NAT Gateway
```bash
az network nat gateway show \
  --resource-group rg-network \
  --name nat-gateway-shared
```
