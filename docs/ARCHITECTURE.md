# Azure Landing Zone Architecture

## Overview

This architecture implements a complete Azure landing zone following best practices for security, governance, and multi-environment deployments.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Subscription                       │
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │         Identity (00-iam)                          │     │
│  │                                                    │     │
│  │  • Service Principal (sp-terraform) - Optional     │     │
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
│  │  │  192.168.0.0/16                             │   │     │
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
│  │                                                    │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐         │     │
│  │  │ aks-dev  │  │ aks-stg  │  │ aks-prd  │         │     │
│  │  │ (v1.30)  │  │ (v1.30)  │  │ (v1.30)  │         │     │
│  │  │ Public   │  │ Public   │  │ Private  │         │     │
│  │  └──────────┘  └──────────┘  └──────────┘         │     │
│  │                                                    │     │
│  │  ┌──────────┐                                      │     │
│  │  │ aks-sdx  │                                      │     │
│  │  │ (v1.30)  │                                      │     │
│  │  │ Public   │                                      │     │
│  │  └──────────┘                                      │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Identity & Access Management (00-iam)

#### Managed Identities
- **User-Assigned**: One identity per AKS environment
- **Permissions**: Network Contributor, Contributor roles
- **Usage**: Authentication for AKS workloads

#### Service Principal (Optional)
- Can be created for Terraform automation
- Disabled by default in favor of managed identities

### 2. Networking (01-networking)

#### Virtual Network
- **Name**: vnet-shared-network
- **CIDR**: 192.168.0.0/16
- **Region**: Brazil South (brazilsouth)

#### Subnets

| Environment | Name        | CIDR            | Available IPs |
|-------------|-------------|-----------------|---------------|
| DEV         | dev-subnet  | 192.168.0.0/20  | ~4,094        |
| STG         | stg-subnet  | 192.168.16.0/20 | ~4,094        |
| PRD         | prd-subnet  | 192.168.32.0/20 | ~4,094        |
| SDX         | sdx-subnet  | 192.168.48.0/20 | ~4,094        |

#### Security
- **NSG**: nsg-allow-ssh (Ports 22, 80, 443)
- **Service Endpoints**: Enabled for Storage, SQL, KeyVault, CosmosDB, EventHub

#### Connectivity
- **NAT Gateway**: nat-gateway-shared (Zone-redundant)
- **Public IP**: pip-nat-gateway-shared (Static, Standard SKU)
- **Purpose**: Controlled egress traffic for all subnets

### 3. Kubernetes (02-kubernetes)

#### AKS Clusters

| Cluster   | Version | VM Size         | Nodes   | Private | Features              |
|-----------|---------|-----------------|---------|---------|----------------------|
| aks-dev   | 1.31    | Standard_D2s_v3 | 1-3     | No      | Auto-scaling, Ephemeral OS |
| aks-stg   | 1.31    | Standard_D2s_v3 | 1-3     | No      | Auto-scaling, Ephemeral OS |
| aks-prd   | 1.31    | Standard_D4s_v3 | 2-5     | Yes     | Multi-zone, Managed OS |
| aks-sdx   | 1.31    | Standard_D2s_v3 | 1-2     | No      | Auto-scaling, Ephemeral OS |

#### Cluster Features
- **Network Plugin**: Azure CNI for native VNet integration
- **Network Policy**: Azure Network Policy for pod-to-pod security
- **Service CIDR**: Separate per cluster (10.0.0.0/16, 10.1.0.0/16, etc.)
- **Auto-scaling**: Enabled on all node pools
- **Managed Identity**: User-assigned per environment

#### Selective Deployment
You can choose which clusters to deploy using the `deploy_clusters` variable:
- `all` - Deploy all 4 clusters (default)
- `dev` - Deploy only DEV cluster
- `dev,stg` - Deploy DEV and STG clusters
- `prd` - Deploy only production cluster
- Any combination of dev, stg, prd, sdx

## Provisioning Flow

The infrastructure must be deployed in order due to dependencies:

1. **IAM** (00-iam): Creates Resource Group, Managed Identities, RBAC assignments
2. **Networking** (01-networking): Creates VNet, Subnets, NSG, NAT Gateway
3. **Kubernetes** (02-kubernetes): Creates AKS clusters with network integration
4. **Ingress NGINX** (separate workflow): Deploys ingress controllers to clusters

### Deployment Order Diagram

```
┌──────────────┐
│   00-iam     │  Creates:
│              │  - Resource Group (rg-network)
│              │  - Managed Identities (mi-aks-*)
│              │  - RBAC Assignments
└──────┬───────┘
       │
       ▼
┌──────────────┐
│01-networking │  Creates:
│              │  - Virtual Network
│              │  - Subnets (4)
│              │  - NSG
│              │  - NAT Gateway
└──────┬───────┘
       │
       ▼
┌──────────────┐
│02-kubernetes │  Creates:
│              │  - AKS Clusters (selective)
│              │  - Node Pools
│              │  - Network Integration
└──────┬───────┘
       │
       ▼
┌──────────────┐
│Ingress NGINX │  Deploys:
│(separate)    │  - External Ingress
│              │  - Internal Ingress
│              │  - IngressClasses
└──────────────┘
```

## Security

### Network Security
- **NSGs**: Applied to all subnets with baseline rules
- **NAT Gateway**: Controlled egress traffic
- **Private Cluster**: Production cluster with private API endpoint
- **Network Policies**: Azure Network Policy enabled for pod-level security
- **Service Endpoints**: Secure connectivity to Azure PaaS services

### Identity Security
- **Managed Identities**: No secrets to manage or rotate
- **RBAC**: Least privilege access per environment
- **Azure AD Integration**: Available for AKS authentication

### Cluster Security
- **Private Cluster**: Production cluster API not exposed to internet
- **Authorized IP Ranges**: Configurable for non-private clusters
- **Auto-upgrade**: Disabled for controlled maintenance windows
- **Azure Policy**: Optional enforcement of organizational policies

## GitHub Actions Workflows

### Infrastructure Workflows

#### 1. deploy-infrastructure.yml
Deploys core infrastructure modules:
- **Module selection**: all, 00-iam, 01-networking, 02-kubernetes
- **Action**: plan or apply
- **Cluster selection**: For kubernetes module only
- **Secrets required**: AZURE_CREDENTIALS, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID

#### 2. terraform-validate.yml
Validates Terraform code:
- Runs on pull requests
- Validates syntax and formatting
- Performs security scanning

### Ingress NGINX Workflows

#### 3. deploy-ingress-nginx.yml
Manages Ingress NGINX deployment:
- **Clusters**: all, dev, stg, prd, sdx, or combinations
- **Ingress type**: both, external, internal
- **Actions**: apply, delete, status
- **Validation**: Optional post-deployment checks

#### 4. destroy-ingress-nginx.yml
Removes Ingress NGINX:
- Requires explicit confirmation
- Complete cleanup including stuck resources
- Selectable clusters and ingress types

## Cost Estimation

### Monthly Costs (Estimated)

| Component              | Configuration      | Monthly Cost  |
|------------------------|--------------------|---------------|
| **NAT Gateway**        | Zone-redundant     | ~$45          |
| **AKS - DEV**          | 1 node (D2s_v3)    | ~$70          |
| **AKS - STG**          | 1 node (D2s_v3)    | ~$70          |
| **AKS - PRD**          | 2 nodes (D4s_v3)   | ~$280         |
| **AKS - SDX**          | 1 node (D2s_v3)    | ~$70          |
| **Public IPs**         | NAT + LoadBalancers| ~$15          |
| **Network Egress**     | Variable           | ~$10-50       |
| **Total (all clusters)**| All 4 clusters     | **~$560-660** |
| **Total (dev only)**   | DEV cluster only   | **~$130-150** |
| **Total (dev+stg)**    | DEV + STG          | **~$200-220** |

### Cost Optimization Tips
- **Selective deployment**: Deploy only needed clusters (~$90-660/month range)
- **Auto-shutdown**: Stop dev/staging clusters outside business hours (save ~40%)
- **Spot instances**: Use for non-production workloads (save ~60-80%)
- **Ephemeral OS disks**: Reduce storage costs (already configured for dev/stg/sdx)
- **Node pool scaling**: Configure auto-scaler to match actual demand
- **Reserved instances**: Commit to 1-3 year reservations for production (save ~40%)

## High Availability

### Production Cluster (aks-prd)
- **Multi-zone**: Nodes spread across availability zones 1 and 2
- **Auto-scaling**: 2-5 nodes to handle load variations
- **Managed OS**: Production-grade OS disk
- **Private cluster**: Enhanced security with private API endpoint
- **Azure Policy**: Optional governance and compliance

### Non-Production Clusters
- **Single zone**: Cost-optimized with zone 1 only
- **Auto-scaling**: Flexible node counts (1-3 or 1-2)
- **Ephemeral OS**: Fast boot and lower costs
- **Public clusters**: Easy access for development

## Monitoring and Observability

### Available Options
- **Container Insights**: Optional (enable_oms_agent = true)
- **Azure Monitor**: Cluster and node metrics
- **Diagnostic Settings**: Can be enabled per cluster
- **Log Analytics**: Optional workspace integration

### Recommended Monitoring Setup
```hcl
enable_oms_agent = true  # For production
enable_azure_policy = true  # For compliance
```

## Disaster Recovery

### Backup Strategy
- **AKS clusters**: Stateless by design, can be recreated
- **Persistent volumes**: Use Azure Backup for AKS
- **Terraform state**: Store in remote Azure Storage with versioning
- **Manifests**: Version controlled in Git

### Recovery Time Objectives
- **Infrastructure**: ~60 minutes (full stack deployment)
- **Single cluster**: ~15-20 minutes
- **Ingress only**: ~5 minutes
- **Application**: Depends on GitOps/deployment tooling

## Compliance and Governance

### Azure Policy Support
- **Production**: Enabled by default
- **Non-production**: Disabled for flexibility
- **Custom policies**: Can be added per cluster

### Tags
All resources tagged with:
- `Project`: azure-landing-zone
- `ManagedBy`: terraform
- `Environment`: dev, stg, prd, sdx, or shared
- `CostCenter`: Optional, configure per team

## Network Address Planning

### Virtual Network: 192.168.0.0/16
- **Total IPs**: 65,536
- **Reserved per subnet**: ~4,094 usable IPs
- **Azure reserved**: First 4 IPs per subnet

### Service CIDRs (Kubernetes internal)
- **DEV**: 192.168.100.0/24 (DNS: 192.168.100.10)
- **STG**: 192.168.101.0/24 (DNS: 192.168.101.10)
- **PRD**: 192.168.102.0/24 (DNS: 192.168.102.10)
- **SDX**: 192.168.103.0/24 (DNS: 192.168.103.10)

**Note**: Service CIDRs do not overlap with VNet CIDR and are internal to each cluster.

## Future Enhancements

### Potential Additions
- **Azure Firewall**: Centralized egress filtering (alternative to NAT Gateway)
- **Application Gateway**: Layer 7 load balancing and WAF
- **Azure Key Vault**: Secrets management with CSI driver
- **Azure Container Registry**: Private container images
- **Azure Monitor Workspace**: Advanced observability
- **Service Mesh**: Istio or Linkerd for advanced traffic management

### Scalability Considerations
- Current design supports ~16,000 IPs per environment
- NAT Gateway supports 64,000 concurrent connections
- Can add additional node pools per cluster
- Can extend with additional subnets if needed
