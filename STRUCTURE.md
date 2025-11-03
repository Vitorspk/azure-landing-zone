# Estrutura do Projeto Azure Landing Zone

## Árvore de Diretórios

```
azure-landing-zone/
├── .github/
│   └── workflows/
│       ├── terraform-validate.yml
│       └── deploy-infrastructure.yml
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   ├── GITHUB_SECRETS.md
│   └── PROJECT_SUMMARY.md
│
├── manifests/
│   ├── README.md
│   ├── ingress-nginx-external.yaml
│   └── ingress-nginx-internal.yaml
│
├── scripts/
│   ├── format-terraform.sh
│   ├── pre-deployment-check.sh
│   └── get-kubeconfig.sh
│
├── terraform/
│   ├── 00-iam/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── service-principals.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── 01-networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   └── 02-kubernetes/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars.example
│       └── modules/
│           └── aks-cluster/
│               ├── main.tf
│               ├── variables.tf
│               └── outputs.tf
│
├── .gitignore
├── Makefile
├── README.md
└── PROJECT_STATUS.md
```

## Recursos que serão criados

### 00-iam
- Resource Group: rg-network
- Managed Identities: mi-aks-dev, mi-aks-stg, mi-aks-prd, mi-aks-sdx

### 01-networking
- VNet: vnet-shared-network (172.31.0.0/16)
- Subnets: dev, stg, prd, sdx
- NSG: nsg-allow-ssh
- NAT Gateway: nat-gateway-shared

### 02-kubernetes
- Clusters: aks-dev, aks-stg, aks-prd, aks-sdx
- Kubernetes version: 1.30
- Auto-scaling habilitado
