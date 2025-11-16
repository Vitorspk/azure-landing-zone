# Azure Landing Zone

Production-ready Infrastructure as Code (IaC) for Azure using Terraform, implementing best practices for security, governance, and multi-environment deployments.

## ⚠️ Security Notice

**CRITICAL: Before deploying this infrastructure:**

1. 🔐 **Never commit `.tfvars` files with real values** - Use `terraform.tfvars.example` as a template
2. 🚨 **Never commit `.tfstate` files** - ALWAYS use remote backend (Azure Storage)
3. 🔑 **Always use environment variables for Azure credentials** - Never hardcode secrets
4. 🛡️ **Review IAM permissions before applying** - Service Principal needs Owner role
5. 📝 **Keep sensitive data out of version control** - Check `.gitignore` is properly configured

**⚠️ IMPORTANT:** This repository previously had sensitive files committed. See [SECURITY.md](docs/SECURITY.md) for cleanup instructions.

For detailed security guidelines, see [SECURITY.md](docs/SECURITY.md).

---

## Overview

This landing zone provides a complete foundation for running containerized workloads on Azure Kubernetes Service (AKS) with proper network isolation, identity management, and security controls. The infrastructure is organized into modular layers that can be deployed independently or as a complete stack.

## Architecture Highlights

- **Multi-environment support**: DEV, STG, PRD, and SDX environments with isolated subnets
- **Selective cluster deployment**: Deploy only the clusters you need (dev, stg, prd, sdx, or any combination)
- **Network security**: NSGs, NAT Gateway for egress traffic, and private cluster support for production
- **Identity management**: Managed identities for AKS workloads with proper RBAC assignments
- **Kubernetes-ready**: 4 AKS clusters (v1.31) with Azure CNI, network policies, and auto-scaling
- **GitOps-ready**: GitHub Actions workflows for automated validation and deployment with cluster selection
- **Cost-optimized**: Estimated $90-650/month depending on which clusters you deploy

## Project Structure

```
azure-landing-zone/
├── .github/workflows/           # CI/CD pipelines
├── terraform/
│   ├── 00-iam/                 # Identity & Access Management
│   ├── 01-networking/          # Network Infrastructure
│   └── 02-kubernetes/          # AKS Clusters
├── manifests/                  # Kubernetes manifests
├── scripts/                    # Helper scripts
├── docs/                       # Comprehensive documentation
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   ├── SECURITY.md             # ⭐ Security best practices
│   └── GITHUB_SECRETS.md
├── .gitignore                  # ⚠️ Properly configured
├── LICENSE                     # MIT License
├── CONTRIBUTING.md             # Contribution guidelines
└── README.md                   # This file
```

## Prerequisites

Before deploying, ensure you have:

- Terraform >= 1.5.0
- Azure CLI >= 2.50.0
- An active Azure subscription
- Service Principal with **Owner role** (for IAM operations)
- GitHub repository secrets configured (for CI/CD)

## Quick Start

### 1. Configure Environment Variables

**For local development:**
```bash
# Copy template
cp .env.example .env

# Edit .env with your Azure credentials
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Load variables
source .env
```

**For GitHub Actions:**
See [docs/GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) for setup instructions.

### 2. Deploy Core Infrastructure

**Via GitHub Actions (Recommended):**
```
Workflow: deploy-infrastructure
Inputs:
  - module: all
  - action: apply
  - clusters: all
⏱️ ~60-70 minutes
```

**Via CLI:**
```bash
# Copy configuration templates
cd terraform/00-iam
cp terraform.tfvars.example terraform.tfvars
# Edit with your values (don't commit!)

# Deploy in order
make iam-apply
make network-apply
make k8s-apply
```

### 3. Deploy Ingress NGINX (Separate Workflow)

```
GitHub Actions → deploy-ingress-nginx
Inputs:
  - clusters: all
  - ingress_type: both
  - action: apply
  - validate: true
⏱️ ~5 minutes per cluster
```

### 4. Access Your Clusters

```bash
az aks get-credentials --resource-group rg-network --name aks-dev
kubectl get nodes
```

---

## Deployment

### Configuration

**For each Terraform module:**
```bash
cd terraform/00-iam
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
# NEVER commit this file!
```

### Manual Deployment

```bash
# Phase 0: IAM
cd terraform/00-iam
terraform init
terraform plan
terraform apply

# Phase 1: Networking
cd ../01-networking
terraform init
terraform plan
terraform apply

# Phase 2: Kubernetes
cd ../02-kubernetes
terraform init
terraform plan
terraform apply
```

### Selective Cluster Deployment

Choose which clusters to deploy to save time and costs:

```bash
# Deploy only DEV cluster (~15-20 min, ~$90/month)
terraform apply -var="deploy_clusters=dev"

# Deploy DEV + STG (~25-30 min, ~$180/month)
terraform apply -var="deploy_clusters=dev,stg"

# Deploy all clusters (~60-70 min, ~$450-650/month)
terraform apply -var="deploy_clusters=all"
```

### Automated Deployment via GitHub Actions

**1. Configure GitHub Secrets:**
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`

See [docs/GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) for details.

**2. Deploy Infrastructure:**
```
Workflow: deploy-infrastructure
Inputs:
  - module: all (or 00-iam, 01-networking, 02-kubernetes)
  - action: apply
  - clusters: all (or dev, stg, prd, sdx, or combinations)
```

**3. Deploy Ingress NGINX:**
```
Workflow: deploy-ingress-nginx
Inputs:
  - clusters: all
  - ingress_type: both
  - action: apply
```

## Environments

| Environment | Cluster | Subnet CIDR | Service CIDR |
|-------------|---------|-------------|--------------|
| Development | aks-dev | 192.168.0.0/20 | 192.168.100.0/24 |
| Staging | aks-stg | 192.168.16.0/20 | 192.168.101.0/24 |
| Production | aks-prd | 192.168.32.0/20 | 192.168.102.0/24 |
| Sandbox | aks-sdx | 192.168.48.0/20 | 192.168.103.0/24 |

## Features

- ✅ Centralized Identity management with Managed Identities
- ✅ Isolated VNet subnets per environment
- ✅ Private AKS cluster for production
- ✅ NGINX Ingress Controllers (external + internal)
- ✅ Selective cluster deployment
- ✅ Automated validation and security scanning
- ✅ Multi-AZ deployment for high availability
- ✅ Azure CNI networking

## Infrastructure Components

### Identity & Access Management (00-iam)
- Resource Group: `rg-network`
- Managed Identities for each environment
- RBAC assignments for AKS workloads

### Networking (01-networking)
- Virtual Network: `vnet-shared-network` (192.168.0.0/16)
- 4 subnets (DEV, STG, PRD, SDX)
- Network Security Groups
- NAT Gateway for outbound connectivity

### Kubernetes (02-kubernetes)
- 4 AKS clusters with environment-specific configurations
- Azure CNI networking
- Azure Network Policy
- Auto-scaling enabled
- Managed identity authentication

## Security

- Private cluster for production environment
- Managed identities (no Service Principal secrets)
- Network security groups on all subnets
- Network policies enabled for pod security
- NAT Gateway for controlled egress traffic
- No public IPs on cluster nodes
- RBAC-based access control

## Cost Estimation

| Component | Monthly Cost | Notes |
|-----------|-------------|-------|
| NAT Gateway | ~$45 | Zone-redundant with static IP |
| AKS Clusters | ~$300-600 | Varies with node count and VM sizes |
| **Total** | **~$350-650** | Excludes storage and egress |

## Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Architecture overview
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deployment guide
- [SECURITY.md](docs/SECURITY.md) - **⭐ Security best practices**
- [GITHUB_SECRETS.md](docs/GITHUB_SECRETS.md) - CI/CD configuration
- [INGRESS-NGINX-DEPLOYMENT.md](docs/INGRESS-NGINX-DEPLOYMENT.md) - Ingress guide

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Cleanup

To destroy all infrastructure:

```bash
make destroy-all
```

Or manually in reverse order:
```bash
cd terraform/02-kubernetes && terraform destroy
cd ../01-networking && terraform destroy
cd ../00-iam && terraform destroy
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues or questions:
- Review the documentation in `docs/`
- Check existing GitHub issues
- Create a new issue with detailed information

## Additional Resources

- [Azure Landing Zone documentation](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Azure Kubernetes Service best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [Terraform Azure Provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
