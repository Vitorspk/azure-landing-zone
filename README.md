# Azure Landing Zone

Production-ready Infrastructure as Code (IaC) for Azure using Terraform, implementing best practices for security, governance, and multi-environment deployments.

## Overview

This landing zone provides a complete foundation for running containerized workloads on Azure Kubernetes Service (AKS) with proper network isolation, identity management, and security controls. The infrastructure is organized into modular layers that can be deployed independently or as a complete stack.

## Architecture Highlights

- **Multi-environment support**: DEV, STG, PRD, and SDX environments with isolated subnets
- **Selective cluster deployment**: Deploy only the clusters you need (dev, stg, prd, sdx, or any combination)
- **Network security**: NSGs, NAT Gateway for egress traffic, and private cluster support for production
- **Identity management**: Managed identities for AKS workloads with proper RBAC assignments
- **Kubernetes-ready**: 4 AKS clusters (v1.30) with Azure CNI, network policies, and auto-scaling
- **GitOps-ready**: GitHub Actions workflows for automated validation and deployment with cluster selection
- **Cost-optimized**: Estimated $90-650/month depending on which clusters you deploy

## Project Structure

```
azure-landing-zone/
├── .github/
│   └── workflows/           # CI/CD pipelines
│       ├── terraform-validate.yml        # Terraform validation
│       ├── deploy-infrastructure.yml     # Core infrastructure
│       ├── deploy-ingress-nginx.yml      # Ingress deployment
│       └── destroy-ingress-nginx.yml     # Ingress cleanup
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
│   ├── aks-ingress-nginx-1.13.3-external.yaml
│   ├── aks-ingress-nginx-1.13.3-internal.yaml
│   └── README.md
│
├── scripts/                # Helper scripts
│   ├── deploy-ingress-controllers.sh
│   ├── format-terraform.sh
│   ├── pre-deployment-check.sh
│   └── get-kubeconfig.sh
│
├── docs/                   # Comprehensive documentation
│   ├── ARCHITECTURE.md     # Detailed architecture diagrams
│   ├── DEPLOYMENT.md       # Step-by-step deployment guide
│   ├── GITHUB_SECRETS.md   # CI/CD configuration
│   ├── NETWORK-RANGE-FIX.md  # Network CIDR fix documentation
│   ├── SELECTIVE-DEPLOYMENT.md  # Selective cluster deployment guide
│   └── PROJECT_SUMMARY.md  # Quick reference
│
├── Makefile               # Automation commands
├── QUICKSTART.md          # Fast deployment guide
└── STRUCTURE.md           # Detailed structure reference
```

## Quick Start

### 1. Deploy Core Infrastructure
```
GitHub Actions → deploy-infrastructure
  module: all
  action: apply
  clusters: all
⏱️ ~60-70 minutes
```

### 2. Deploy Ingress NGINX (Separate Workflow)
```
GitHub Actions → deploy-ingress-nginx
  clusters: all
  ingress_type: both
  action: apply
  validate: true
⏱️ ~5 minutes per cluster
```

### 3. Access Your Clusters
```bash
az aks get-credentials --resource-group rg-network --name aks-<ENV>
kubectl get nodes
```

### 4. Verify Ingress
```
GitHub Actions → deploy-ingress-nginx
  action: status
```

---

### Prerequisites

- Terraform >= 1.5.0
- Azure CLI >= 2.50.0
- An active Azure subscription
- **Service Principal with Owner role** (for GitHub Actions) or Owner permissions on your Azure account
- Appropriate permissions to create resources and role assignments

### 🔑 Authentication Setup

This project uses Azure environment variables for authentication. You no longer need to manually configure `subscription_id` in `.tfvars` files.

**For GitHub Actions (CI/CD):**
Configure these repository secrets (see [GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md)):
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_TENANT_ID`

⚠️ **Important**: The Service Principal must have **Owner** role to create IAM role assignments.

**For Local Development:**
```bash
# Option 1: Use Azure CLI (recommended)
az login
az account set --subscription "<your-subscription-id>"

# Option 2: Set environment variables
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="your-tenant-id"
```

See [docs/AZURE_CREDENTIALS_MIGRATION.md](docs/AZURE_CREDENTIALS_MIGRATION.md) for detailed setup instructions.

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
# Deploy all modules in order (all clusters)
make deploy-all

# Or deploy individually
make iam-apply      # Identity and access management
make network-apply  # VNet, subnets, NSG, NAT Gateway
make k8s-apply      # AKS clusters (all environments)
```

#### Selective Cluster Deployment

You can choose which clusters to deploy to save time and costs:

```bash
# Deploy only DEV cluster (~15-20 min, ~$90/month)
cd terraform/02-kubernetes
terraform apply -var="deploy_clusters=dev"

# Deploy DEV + STG (~25-30 min, ~$180/month)
terraform apply -var="deploy_clusters=dev,stg"

# Deploy DEV + STG + PRD (~40-50 min, ~$350/month)
terraform apply -var="deploy_clusters=dev,stg,prd"

# Deploy all clusters (~60-70 min, ~$450-650/month)
terraform apply -var="deploy_clusters=all"
# Or simply (all is the default):
terraform apply

# Deploy only production
terraform apply -var="deploy_clusters=prd"

# Deploy only sandbox for testing
terraform apply -var="deploy_clusters=sdx"
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

- **Virtual Network**: `vnet-shared-network` (192.168.0.0/16)
- **Subnets**:
  - DEV: 192.168.0.0/20 (~4,094 IPs)
  - STG: 192.168.16.0/20 (~4,094 IPs)
  - PRD: 192.168.32.0/20 (~4,094 IPs)
  - SDX: 192.168.48.0/20 (~4,094 IPs)
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

### Infrastructure Workflows

1. **deploy-infrastructure.yml** - Deploy core infrastructure
   - IAM (Module 00)
   - Networking (Module 01)
   - Kubernetes/AKS (Module 02)
   - Does NOT deploy Ingress NGINX

2. **terraform-validate.yml** - Terraform validation and security scanning
   - Runs on pull requests
   - Validates syntax and formatting

### Ingress NGINX Workflows

3. **deploy-ingress-nginx.yml** - Deploy/manage Ingress NGINX
   - Deploy External and/or Internal Ingress
   - Multi-cluster support
   - Automatic validation
   - Actions: apply, delete, status

4. **destroy-ingress-nginx.yml** - Cleanup Ingress NGINX
   - Remove Ingress from specific clusters
   - Requires explicit confirmation
   - Complete cleanup including stuck resources

### Why Separate Ingress Workflow?

Ingress NGINX is deployed via a **dedicated workflow** (not part of infrastructure deployment):

**Benefits:**
- ✅ **Independent updates**: Update Ingress without touching infrastructure (~5 min vs ~60 min)
- ✅ **Selective deployment**: Choose specific clusters and ingress types
- ✅ **Quick rollback**: Easy to rollback or update Ingress versions
- ✅ **Isolated testing**: Test Ingress changes without risking infra
- ✅ **Cost efficiency**: Deploy Ingress only when needed

### Automated Deployment via GitHub Actions

Trigger the `deploy-infrastructure` workflow with:

#### Parameters:
- **module**: `all`, `00-iam`, `01-networking`, or `02-kubernetes`
- **action**: `plan` or `apply`
- **clusters**: `all`, `dev`, `stg`, `prd`, `sdx`, or combinations like `dev,stg` (for kubernetes module only)

#### Examples:

**Deploy all infrastructure with all clusters:**
```
Workflow: deploy-infrastructure
Inputs:
  - module: all
  - action: apply
  - clusters: all
```

**Deploy only Kubernetes module with specific clusters:**
```
Workflow: deploy-infrastructure
Inputs:
  - module: 02-kubernetes
  - action: apply
  - clusters: dev,stg
```

**Plan changes for production cluster only:**
```
Workflow: deploy-infrastructure
Inputs:
  - module: 02-kubernetes
  - action: plan
  - clusters: prd
```

### Ingress NGINX Deployment Examples

**Deploy Ingress to all clusters:**
```
Workflow: deploy-ingress-nginx
Inputs:
  - clusters: all
  - ingress_type: both
  - action: apply
  - validate: true
```

**Deploy only External Ingress to DEV:**
```
Workflow: deploy-ingress-nginx
Inputs:
  - clusters: dev
  - ingress_type: external
  - action: apply
  - validate: true
```

**Check Ingress status:**
```
Workflow: deploy-ingress-nginx
Inputs:
  - clusters: all
  - ingress_type: both
  - action: status
  - validate: false
```

**Remove Ingress from staging:**
```
Workflow: destroy-ingress-nginx
Inputs:
  - clusters: stg
  - ingress_type: both
  - confirm: yes
```

See [docs/GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) for required secrets configuration.

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)**: Detailed architecture diagrams and design decisions
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)**: Step-by-step deployment and troubleshooting guide
- **[GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md)**: CI/CD secrets configuration
- **[AZURE_CREDENTIALS_MIGRATION.md](docs/AZURE_CREDENTIALS_MIGRATION.md)**: 🆕 Authentication setup guide
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

### AuthorizationFailed: Cannot create role assignments

**Error**: `The client does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'`

**Cause**: Service Principal lacks Owner or User Access Administrator role.

**Solution**:
```bash
# Find your Service Principal
az ad sp list --show-mine --query "[].{Name:displayName, AppId:appId}" -o table

# Add Owner role
az role assignment create \
  --assignee "<APP_ID>" \
  --role "Owner" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"

# Verify
az role assignment list --assignee "<APP_ID>" --output table
```

See [GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) for complete setup instructions.

### Resource Already Exists Error

**Error**: `a resource with the ID "/subscriptions/.../resourceGroups/rg-network" already exists`

**Cause**: Resource was created outside Terraform or state file is missing.

**Solution**: The workflow now **automatically imports** existing resource groups. However, if import fails:

**Quick Fix (Recommended for initial setup):**
```bash
# Delete the resource group and all its contents
az group delete --name rg-network --yes --no-wait

# Wait 2-3 minutes for Azure to complete deletion
# Verify it's gone:
az group show --name rg-network
# Should return: (ResourceGroupNotFound)

# Then re-run the workflow
```

**Alternative Solutions:**

1. **For local development:**
   ```bash
   cd terraform/00-iam
   
   # Import resource group
   terraform import azurerm_resource_group.iam /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-network
   
   # Import managed identities (if they exist)
   terraform import 'azurerm_user_assigned_identity.aks_env["dev"]' /subscriptions/<SUB_ID>/resourceGroups/rg-network/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-aks-dev
   # Repeat for stg, prd, sdx
   
   terraform apply
   ```

2. **For production (recommended):** Use remote state backend - see "Remote State Backend" section below.

3. **Check what exists in Azure:**
   ```bash
   # List all resources in the resource group
   az resource list --resource-group rg-network --output table
   
   # If empty or only has managed identities from previous runs:
   az group delete --name rg-network --yes
   ```

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
