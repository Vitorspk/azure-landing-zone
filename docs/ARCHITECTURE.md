# Arquitetura Azure Landing Zone

## Visão Geral

Esta arquitetura implementa uma landing zone completa na Azure seguindo as melhores práticas de segurança e governança.

## Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Subscription                       │
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │         Identidades (00-iam)                       │     │
│  │                                                    │     │
│  │  • Service Principal (sp-terraform) - Opcional     │     │
│  │  • Managed Identities (mi-aks-*)                   │     │
│  │    - mi-aks-dev                                    │     │
│  │    - mi-aks-stg                                    │     │
│  │    - mi-aks-prd                                    │     │
│  │    - mi-aks-sdx                                    │     │
│  └────────────────────────────────────────────────────┘     │
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │          Resource Group: rg-network                │     │
│  │                                                    │     │
│  │  ┌─────────────────────────────────────────────┐   │     │
│  │  │  Virtual Network: vnet-shared-network       │   │     │
│  │  │  172.31.0.0/16                              │   │     │
│  │  │                                             │   │     │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │   │     │
│  │  │  │dev-subnet│  │stg-subnet│  │prd-subnet│   │   │     │
│  │  │  │.0.0/20   │  │.16.0/20  │  │.32.0/20  │   │   │     │
│  │  │  └─────┬────┘  └─────┬────┘  └─────┬────┘   │   │     │
│  │  │        │             │             │        │   │     │
│  │  │  ┌─────┴─────────────┴─────────────┴────┐   │   │     │
│  │  │  │         NAT Gateway                   │   │   │     │
│  │  │  │    (pip-nat-gateway-shared)           │   │   │     │
│  │  │  └───────────────┬───────────────────────┘   │   │     │
│  │  │                  │                           │   │     │
│  │  │                  ▼ Internet                  │   │     │
│  │  └─────────────────────────────────────────────┘   │     │
│  └────────────────────────────────────────────────────┘     │
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │     Kubernetes Clusters (02-kubernetes)            │     │
│  │                                                    │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐         │     │
│  │  │ aks-dev  │  │ aks-stg  │  │ aks-prd  │         │     │
│  │  │ (v1.30)  │  │ (v1.30)  │  │ (v1.30)  │         │     │
│  │  └──────────┘  └──────────┘  └──────────┘         │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Componentes

### 1. Identidades e Acesso (00-iam)

#### Managed Identities
- **User-Assigned**: Uma identidade por ambiente AKS
- **Permissões**: Network Contributor, Contributor
- **Uso**: Autenticação de workloads no AKS

### 2. Networking (01-networking)

#### Virtual Network
- **Nome**: vnet-shared-network
- **CIDR**: 172.31.0.0/16
- **Região**: Brazil South

#### Subnets

| Ambiente | Nome        | CIDR           | IPs Disponíveis |
|----------|-------------|----------------|-----------------|
| DEV      | dev-subnet  | 172.31.0.0/20  | ~4,094          |
| STG      | stg-subnet  | 172.31.16.0/20 | ~4,094          |
| PRD      | prd-subnet  | 172.31.32.0/20 | ~4,094          |
| SDX      | sdx-subnet  | 172.31.48.0/20 | ~4,094          |

#### Segurança
- **NSG**: nsg-allow-ssh (Portas 22, 443, 80)

#### Conectividade
- **NAT Gateway**: nat-gateway-shared (Zone-redundant)

### 3. Kubernetes (02-kubernetes)

#### Clusters AKS

| Cluster   | Versão | VM Size         | Nodes   | Private |
|-----------|--------|-----------------|---------|---------|
| aks-dev   | 1.30   | Standard_D2s_v3 | 1-3     | Não     |
| aks-stg   | 1.30   | Standard_D2s_v3 | 1-3     | Não     |
| aks-prd   | 1.30   | Standard_D4s_v3 | 2-5     | Sim     |
| aks-sdx   | 1.30   | Standard_D2s_v3 | 1-2     | Não     |

## Fluxo de Provisionamento

1. **IAM**: Resource Group, Managed Identities, RBAC
2. **Networking**: VNet, Subnets, NSG, NAT Gateway
3. **Kubernetes**: Clusters AKS com integração de rede

## Segurança

- Managed Identities para workloads
- NSGs aplicados a todas as subnets
- Network policies habilitadas
- Private cluster em produção

## Custos Estimados

| Componente     | Custo Mensal |
|----------------|--------------|
| NAT Gateway    | ~$45/mês     |
| AKS (4 clusters) | ~$300-600/mês |
| **Total**      | **~$350-650/mês** |
