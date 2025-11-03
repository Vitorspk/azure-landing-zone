# Azure Landing Zone

Production-ready Infrastructure as Code (IaC) for Azure using Terraform, implementing best practices for security, governance, and multi-environment deployments.

## Overview

This landing zone provides a complete foundation for running containerized workloads on Azure Kubernetes Service (AKS) with proper network isolation, identity management, and security controls. The infrastructure is organized into modular layers that can be deployed independently or as a complete stack.

## Architecture Highlights

- **Multi-environment support**: DEV, STG, PRD, and SDX environments with isolated subnets
- **Network security**: NSGs, NAT Gateway for egress traffic, and private cluster support for production
- **Identity management**: Managed identities for AKS workloads with proper RBAC assignments
- **Kubernetes-ready**: 4 AKS clusters (v1.30) with Azure CNI, network policies, and auto-scaling
- **GitOps-ready**: GitHub Actions workflows for automated validation and deployment
- **Cost-optimized**: Estimated $350-650/month with configurable VM sizes per environment

## Project Structure

```
azure-landing-zone/
├── .github/
│   └── workflows/           # CI/CD pipelines
│       ├── terraform-validate.yml
│       └── deploy-infrastructure.yml
│
├── terraform/
│   ├── 00-iam/             # Identity & Access Management
│   │   ├── main.tf         # Provider configuration
│   │   ├── variables.tf    # Input variables
│   │   ├── service-principals.tf  # Managed identities
│   │   └── outputs.tf      # Exported values
│   │
│   ├── 01-networking/      # Network Infrastructure
│   │   ├── main.tf         # VNet, subnets, NSG, NAT Gateway
│   │   ├── variables.tf    # Network configuration
│   │   └── outputs.tf      # Network IDs and references
│   │
│   └── 02-kubernetes/      # AKS Clusters
│       ├── main.tf         # Cluster definitions
│       ├── variables.tf    # Cluster configuration
│       ├── outputs.tf      # Kubeconfig and endpoints
│       └── modules/
│           └── aks-cluster/  # Reusable AKS module
│
├── manifests/              # Kubernetes manifests
│   ├── ingress-nginx-external.yaml
│   └── ingress-nginx-internal.yaml
│
├── scripts/                # Helper scripts
│   ├── format-terraform.sh
│   ├── pre-deployment-check.sh
│   └── get-kubeconfig.sh
│
├── docs/                   # Comprehensive documentation
│   ├── ARCHITECTURE.md     # Detailed architecture diagrams
│   ├── DEPLOYMENT.md       # Step-by-step deployment guide
│   ├── GITHUB_SECRETS.md   # CI/CD configuration
│   └── PROJECT_SUMMARY.md  # Quick reference
│
├── Makefile               # Automation commands
├── QUICKSTART.md          # Fast deployment guide
└── STRUCTURE.md           # Detailed structure reference
```

## Quick Start

### Prerequisites

- Terraform >= 1.5.0
- Azure CLI >= 2.50.0
- An active Azure subscription
- Appropriate permissions to create resources

### 1. Authenticate with Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 2. Get Required Azure IDs

```bash
# Get your subscription ID
az account show --query id -o tsv

# Get your tenant ID
az account show --query tenantId -o tsv
```

### 3. Configure Variables

For each module, copy the example variables file and customize:

```bash
# IAM module
cd terraform/00-iam
cp terraform.tfvars.example terraform.tfvars
# Edit with your subscription_id and tenant_id

# Networking module
cd ../01-networking
cp terraform.tfvars.example terraform.tfvars
# Edit with your subscription_id

# Kubernetes module
cd ../02-kubernetes
cp terraform.tfvars.example terraform.tfvars
# Edit with your subscription_id
```

### 4. Deploy Infrastructure

From the project root:

```bash
# Deploy all modules in order
make deploy-all

# Or deploy individually
make iam-apply      # Identity and access management
make network-apply  # VNet, subnets, NSG, NAT Gateway
make k8s-apply      # AKS clusters
```

### 5. Access Your Clusters

```bash
# Get kubeconfig for all clusters
./scripts/get-kubeconfig.sh

# Or manually for each cluster
az aks get-credentials --resource-group rg-network --name aks-dev
az aks get-credentials --resource-group rg-network --name aks-stg
az aks get-credentials --resource-group rg-network --name aks-prd
az aks get-credentials --resource-group rg-network --name aks-sdx

# Verify connectivity
kubectl get nodes
```

## Infrastructure Components

### Identity & Access Management (00-iam)

- **Resource Group**: `rg-network` - Central resource group for all networking and compute resources
- **Managed Identities**: User-assigned identities for each environment (dev, stg, prd, sdx)
- **RBAC Assignments**: Network Contributor and Contributor roles for AKS workloads

### Networking (01-networking)

- **Virtual Network**: `vnet-shared-network` (172.31.0.0/16)
- **Subnets**:
  - DEV: 172.31.0.0/20 (~4,094 IPs)
  - STG: 172.31.16.0/20 (~4,094 IPs)
  - PRD: 172.31.32.0/20 (~4,094 IPs)
  - SDX: 172.31.48.0/20 (~4,094 IPs)
- **Network Security Groups**: Basic rules for SSH, HTTP, HTTPS
- **NAT Gateway**: Zone-redundant gateway for outbound internet connectivity
- **Region**: Brazil South (brazilsouth)

### Kubernetes (02-kubernetes)

Four AKS clusters with environment-specific configurations:

| Cluster   | Version | VM Size         | Node Range | Private | Purpose                 |
|-----------|---------|-----------------|------------|---------|-------------------------|
| aks-dev   | 1.30    | Standard_D2s_v3 | 1-3        | No      | Development & testing   |
| aks-stg   | 1.30    | Standard_D2s_v3 | 1-3        | No      | Staging & pre-prod      |
| aks-prd   | 1.30    | Standard_D4s_v3 | 2-5        | Yes     | Production workloads    |
| aks-sdx   | 1.30    | Standard_D2s_v3 | 1-2        | No      | Sandbox & experiments   |

**Features**:
- Azure CNI networking for native VNet integration
- Azure Network Policy for pod-to-pod security
- Auto-scaling enabled on all node pools
- Managed identity authentication
- Private cluster for production environment

## Cost Estimation

| Component        | Monthly Cost  | Notes                                      |
|------------------|---------------|--------------------------------------------|
| NAT Gateway      | ~$45          | Zone-redundant with static public IP       |
| AKS Clusters     | ~$300-600     | Varies with node count and VM sizes        |
| **Total**        | **~$350-650** | Excludes storage, egress, and add-ons      |

Cost optimization tips:
- Scale down or stop dev/staging clusters outside business hours
- Use spot instances for non-production workloads
- Enable cluster autoscaler to match actual demand

## Available Commands

The `Makefile` provides convenient shortcuts:

```bash
make help          # Show all available commands
make deploy-all    # Deploy all infrastructure modules
make destroy-all   # Destroy all infrastructure (reverse order)
make iam-apply     # Deploy IAM module
make network-apply # Deploy networking module
make k8s-apply     # Deploy Kubernetes clusters
```

## CI/CD Integration

GitHub Actions workflows are included for automated testing and deployment:

- **terraform-validate.yml**: Validates Terraform code on pull requests
- **deploy-infrastructure.yml**: Automated deployment pipeline

See [docs/GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) for required secrets configuration.

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)**: Detailed architecture diagrams and design decisions
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)**: Step-by-step deployment and troubleshooting guide
- **[GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md)**: CI/CD secrets configuration
- **[PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md)**: Quick reference and overview

Additional guides:
- **[QUICKSTART.md](QUICKSTART.md)**: Fast-track deployment guide
- **[STRUCTURE.md](STRUCTURE.md)**: Detailed project structure reference

## Security Best Practices

This landing zone implements several security controls:

- User-assigned managed identities (no service principal secrets)
- Network security groups on all subnets
- Private cluster for production environment
- Network policies enabled for pod security
- NAT Gateway for controlled egress traffic
- No public IPs assigned to cluster nodes
- RBAC-based access control

## Deployment Order

The infrastructure must be deployed in the following order due to dependencies:

1. **IAM** (00-iam): Creates resource group and managed identities
2. **Networking** (01-networking): Creates VNet, subnets, and network security
3. **Kubernetes** (02-kubernetes): Creates AKS clusters using the network resources

For destruction, reverse the order to avoid dependency conflicts.

## Remote State Backend

For production use, enable remote state backend. Uncomment the backend configuration in each module's `main.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "sttfstate"
  container_name       = "tfstate"
  key                  = "iam.tfstate"  # Change per module
}
```

Create the state storage before deployment:

```bash
# Create resource group for state
az group create --name rg-terraform-state --location brazilsouth

# Create storage account
az storage account create \
  --name sttfstate \
  --resource-group rg-terraform-state \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name tfstate \
  --account-name sttfstate
```

## Validation and Testing

Pre-deployment checks:

```bash
# Run pre-deployment validation
./scripts/pre-deployment-check.sh

# Format Terraform code
./scripts/format-terraform.sh

# Validate each module
cd terraform/00-iam && terraform validate
cd ../01-networking && terraform validate
cd ../02-kubernetes && terraform validate
```

Post-deployment verification:

```bash
# Verify resource group
az group show --name rg-network

# List virtual networks
az network vnet list --resource-group rg-network --output table

# List AKS clusters
az aks list --resource-group rg-network --output table

# Check cluster health
kubectl get nodes --all-namespaces
kubectl get pods --all-namespaces
```

## Troubleshooting

### Unable to access AKS cluster

For non-private clusters, you may need to authorize your IP:

```bash
az aks update \
  --resource-group rg-network \
  --name aks-dev \
  --api-server-authorized-ip-ranges $(curl -s https://ifconfig.me)/32
```

### NAT Gateway not working

Verify NAT Gateway configuration:

```bash
az network nat gateway show \
  --resource-group rg-network \
  --name nat-gateway-shared
```

### Terraform state lock issues

If using remote backend and encountering lock issues:

```bash
terraform force-unlock <lock-id>
```

## Cleanup

To destroy all infrastructure:

```bash
# Destroy all resources (in reverse order)
make destroy-all

# Or destroy individually
cd terraform/02-kubernetes && terraform destroy
cd ../01-networking && terraform destroy
cd ../00-iam && terraform destroy
```

## Contributing

When contributing to this project:

1. Format code using `./scripts/format-terraform.sh`
2. Validate changes with `terraform validate`
3. Test in development environment first
4. Update documentation as needed

## License

This project is provided as-is for educational and production use.

## Support

For issues or questions:
- Review the documentation in `docs/`
- Check existing GitHub issues
- Create a new issue with detailed information

## Additional Resources

- [Azure Landing Zone documentation](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Azure Kubernetes Service best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [Terraform Azure Provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
