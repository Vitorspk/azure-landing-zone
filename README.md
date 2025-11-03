# Azure Landing Zone

Infraestrutura como Código (IaC) para Azure usando Terraform.

## ��️ Estrutura
```
azure-landing-zone/
├── terraform/
│   ├── 00-iam/           # Identidades e permissões
│   ├── 01-networking/    # VNet, Subnets, NSG, NAT Gateway
│   └── 02-kubernetes/    # Clusters AKS
├── docs/                 # Documentação
├── manifests/            # Manifestos Kubernetes
└── scripts/              # Scripts auxiliares
```

## 🚀 Quick Start
```bash
# 1. Configurar variáveis
cd terraform/00-iam
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com seus valores

# 2. Autenticar no Azure
az login
az account set --subscription "<subscription-id>"

# 3. Deploy
make deploy-all
```


Ver pasta `docs/` para documentação completa.
