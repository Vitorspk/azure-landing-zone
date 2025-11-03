# Azure Landing Zone - Sumário do Projeto

## Visão Geral

Infraestrutura completa na Azure usando Terraform.

## Estrutura

```
azure-landing-zone/
├── terraform/
│   ├── 00-iam/          # Identidades
│   ├── 01-networking/    # Rede
│   └── 02-kubernetes/    # AKS
├── docs/                 # Documentação
├── manifests/            # Kubernetes manifests
└── scripts/              # Scripts auxiliares
```

## Componentes

### IAM (00-iam)
- Resource Group: rg-network
- Managed Identities para AKS (dev, stg, prd, sdx)
- RBAC configurado

### Networking (01-networking)
- VNet: vnet-shared-network (172.31.0.0/16)
- 4 Subnets isoladas
- NSG com regras básicas
- NAT Gateway para saída

### Kubernetes (02-kubernetes)
- 4 Clusters AKS
- Kubernetes 1.30
- Azure CNI + Network Policy
- Auto-scaling habilitado

## Deploy

```bash
make deploy-all
```

## Custos

~$350-650/mês (estimado)

## Documentação

Ver pasta `docs/` para mais detalhes.
