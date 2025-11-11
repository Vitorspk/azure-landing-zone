# Deployment Guide

Complete guide for deploying the Azure Landing Zone infrastructure.

---

## Prerequisites

Before starting the deployment, ensure you have:

### Required Tools
- **Terraform** >= 1.5.0
- **Azure CLI** >= 2.50.0
- **kubectl** (optional, for cluster access)
- **make** (optional, for using Makefile commands)

### Azure Requirements
- Active Azure subscription
- Appropriate permissions to create resources:
  - Resource Groups
  - Virtual Networks
  - Managed Identities
  - AKS Clusters
  - NAT Gateway
  - **Role Assignments** (requires Owner or User Access Administrator role)
- Service Principal with **Owner** role for GitHub Actions (if using CI/CD)

---

## Deployment Methods

You can deploy the infrastructure using three methods:

1. **GitHub Actions** (Recommended for production)
2. **Makefile** (Quick local deployment)
3. **Manual Terraform** (Full control)

---

## Method 1: GitHub Actions (Recommended)

Best for production environments with team collaboration and auditability.

### Step 1: Configure GitHub Secrets

See [GITHUB_SECRETS.md](GITHUB_SECRETS.md) for detailed instructions on setting up:
- `AZURE_CREDENTIALS`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

### Step 2: Deploy Infrastructure

Navigate to **Actions** → **Deploy Infrastructure** workflow.

#### Deploy All Infrastructure with All Clusters

```
Workflow: deploy-infrastructure
Inputs:
  module: all
  action: apply
  clusters: all
```

**Time**: ~60-70 minutes
**Resources**: All 4 AKS clusters (dev, stg, prd, sdx)

#### Deploy Specific Clusters

```
Workflow: deploy-infrastructure
Inputs:
  module: all
  action: apply
  clusters: dev,stg
```

**Time**: ~25-30 minutes
**Resources**: Only DEV and STG clusters

#### Plan Before Apply (Recommended)

Always run `plan` first to preview changes:

```
Workflow: deploy-infrastructure
Inputs:
  module: all
  action: plan
  clusters: all
```

Review the output, then run again with `action: apply`.

### Step 3: Deploy Ingress NGINX (Separate Workflow)

After infrastructure is deployed, deploy Ingress controllers:

```
Workflow: deploy-ingress-nginx
Inputs:
  clusters: all
  ingress_type: both
  action: apply
  validate: true
```

**Time**: ~5 minutes per cluster
See [INGRESS-NGINX-DEPLOYMENT.md](INGRESS-NGINX-DEPLOYMENT.md) for detailed guide.

---

## Method 2: Makefile (Quick Deployment)

Best for local development and testing.

### Prerequisites

1. Authenticate with Azure:
```bash
az login
az account set --subscription "<your-subscription-id>"
```

2. Configure variables (see Step 1 of Method 3 below)

### Deploy All Infrastructure

```bash
# Deploy all modules in order (all clusters)
make deploy-all
```

This will:
1. Deploy IAM module (00-iam)
2. Deploy Networking module (01-networking)
3. Deploy Kubernetes module (02-kubernetes) with all clusters

**Time**: ~60-70 minutes

### Deploy Individual Modules

```bash
# Deploy only IAM
make iam-apply

# Deploy only Networking
make network-apply

# Deploy only Kubernetes
make k8s-apply
```

### Selective Cluster Deployment

For selective cluster deployment with Makefile:

```bash
cd terraform/02-kubernetes
terraform init
terraform apply -var="deploy_clusters=dev,stg"
```

### Destroy All Infrastructure

```bash
# Destroy all resources (in reverse order)
make destroy-all
```

---

## Method 3: Manual Terraform (Full Control)

Best for understanding the deployment process and customizing configurations.

### Step 1: Authenticate with Azure

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "<your-subscription-id>"

# Get required IDs
az account show --query id -o tsv          # Subscription ID
az account show --query tenantId -o tsv    # Tenant ID
```

### Step 2: Configure Variables

Configure variables for each module:

#### IAM Module (00-iam)

```bash
cd terraform/00-iam
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
subscription_id = "your-subscription-id"
tenant_id       = "your-tenant-id"

resource_group_name = "rg-network"
location            = "brazilsouth"

# Optional: Create Service Principal
create_service_principal = false

# Create Managed Identities for AKS
create_aks_identity = true
```

#### Networking Module (01-networking)

```bash
cd ../01-networking
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
subscription_id = "your-subscription-id"

resource_group_name = "rg-network"
vnet_name           = "vnet-shared-network"
vnet_address_space  = "192.168.0.0/16"

# Subnets are pre-configured, no changes needed
```

#### Kubernetes Module (02-kubernetes)

```bash
cd ../02-kubernetes
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
subscription_id = "your-subscription-id"

resource_group_name = "rg-network"
vnet_name           = "vnet-shared-network"

# Clusters are pre-configured
# To deploy specific clusters, add:
# deploy_clusters = "dev,stg"  # or "all"
```

### Step 3: Deploy IAM Module

```bash
cd terraform/00-iam

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

**Resources Created**:
- Resource Group: `rg-network`
- Managed Identities: `mi-aks-dev`, `mi-aks-stg`, `mi-aks-prd`, `mi-aks-sdx`
- RBAC Assignments: Network Contributor, Contributor

**Time**: ~2-3 minutes

### Step 4: Deploy Networking Module

```bash
cd ../01-networking

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

**Resources Created**:
- Virtual Network: `vnet-shared-network` (192.168.0.0/16)
- Subnets: dev, stg, prd, sdx (4x /20 subnets)
- NSG: `nsg-allow-ssh`
- NAT Gateway: `nat-gateway-shared`
- Public IP: `pip-nat-gateway-shared`

**Time**: ~5-10 minutes

### Step 5: Deploy Kubernetes Module

#### Option A: Deploy All Clusters (Default)

```bash
cd ../02-kubernetes

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes (all clusters)
terraform apply
```

**Time**: ~60-70 minutes
**Cost**: ~$560-660/month

#### Option B: Deploy Specific Clusters

```bash
cd ../02-kubernetes
terraform init

# Deploy only DEV cluster
terraform apply -var="deploy_clusters=dev"
# Time: ~15-20 minutes, Cost: ~$130-150/month

# Deploy DEV + STG
terraform apply -var="deploy_clusters=dev,stg"
# Time: ~25-30 minutes, Cost: ~$200-220/month

# Deploy DEV + STG + PRD
terraform apply -var="deploy_clusters=dev,stg,prd"
# Time: ~40-50 minutes, Cost: ~$400-500/month

# Deploy only production
terraform apply -var="deploy_clusters=prd"
# Time: ~20-25 minutes

# Deploy only sandbox
terraform apply -var="deploy_clusters=sdx"
# Time: ~15-20 minutes
```

**Resources Created per Cluster**:
- AKS Cluster with managed identity
- Node pool with auto-scaling
- Network integration
- RBAC bindings

### Step 6: Deploy Ingress NGINX (Separate)

See [INGRESS-NGINX-DEPLOYMENT.md](INGRESS-NGINX-DEPLOYMENT.md) for detailed instructions.

Quick option:
```bash
# Deploy to specific cluster
./scripts/deploy-ingress-controllers.sh aks-dev rg-network

# Or use kubectl
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-external.yaml
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-internal.yaml
```

**Time**: ~5 minutes per cluster

---

## Post-Deployment Steps

### 1. Access Your Clusters

Get kubeconfig for all deployed clusters:

```bash
# Using helper script
./scripts/get-kubeconfig.sh

# Or manually for each cluster
az aks get-credentials --resource-group rg-network --name aks-dev --overwrite-existing
az aks get-credentials --resource-group rg-network --name aks-stg --overwrite-existing
az aks get-credentials --resource-group rg-network --name aks-prd --overwrite-existing
az aks get-credentials --resource-group rg-network --name aks-sdx --overwrite-existing
```

### 2. Verify Cluster Access

```bash
# List contexts
kubectl config get-contexts

# Switch to specific cluster
kubectl config use-context aks-dev

# Verify nodes
kubectl get nodes

# Check system pods
kubectl get pods -A
```

### 3. Verify Network Connectivity

```bash
# Test egress through NAT Gateway
kubectl run test-pod --image=alpine --rm -it -- sh
# Inside pod:
apk add curl
curl https://ifconfig.me
# Should show NAT Gateway public IP
```

### 4. Deploy Test Application

```bash
# Deploy nginx example
kubectl apply -f manifests/nginx-example.yaml

# Check ingress
kubectl get ingress -A

# Get external IP
kubectl get svc -n ingress-nginx-external ingress-nginx-controller
```

---

## Validation and Testing

### Pre-Deployment Validation

Run before deploying:

```bash
# Run pre-deployment checks
./scripts/pre-deployment-check.sh

# Validate Terraform syntax
terraform fmt -check -recursive
terraform validate
```

### Post-Deployment Validation

#### Verify Resource Group

```bash
az group show --name rg-network --output table
```

#### List Virtual Networks

```bash
az network vnet list --resource-group rg-network --output table
```

#### List Subnets

```bash
az network vnet subnet list \
  --resource-group rg-network \
  --vnet-name vnet-shared-network \
  --output table
```

#### List AKS Clusters

```bash
az aks list --resource-group rg-network --output table
```

#### Check Cluster Health

```bash
# For each cluster
kubectl get nodes
kubectl get pods -A
kubectl top nodes  # Requires metrics-server
```

#### Verify NAT Gateway

```bash
az network nat gateway show \
  --resource-group rg-network \
  --name nat-gateway-shared \
  --output table
```

#### Verify Managed Identities

```bash
az identity list --resource-group rg-network --output table
```

---

## Troubleshooting

### Issue: Unable to Access AKS Cluster

**Symptom**: `kubectl` commands fail with connection timeout

**Solution**: For non-private clusters, authorize your IP:

```bash
# Get your public IP
MY_IP=$(curl -s https://ifconfig.me)

# Authorize IP
az aks update \
  --resource-group rg-network \
  --name aks-dev \
  --api-server-authorized-ip-ranges "${MY_IP}/32"
```

For private clusters (aks-prd), you must access from within the VNet or via VPN/ExpressRoute.

### Issue: NAT Gateway Not Working

**Symptom**: Pods cannot reach internet

**Solution**: Verify NAT Gateway configuration:

```bash
# Check NAT Gateway
az network nat gateway show \
  --resource-group rg-network \
  --name nat-gateway-shared

# Check subnet association
az network vnet subnet show \
  --resource-group rg-network \
  --vnet-name vnet-shared-network \
  --name dev-subnet \
  --query natGateway
```

### Issue: Terraform State Lock

**Symptom**: `Error acquiring the state lock`

**Solution**: If using remote backend and encountering lock issues:

```bash
# Force unlock (use carefully)
terraform force-unlock <lock-id>
```

### Issue: Cluster Takes Too Long to Deploy

**Symptom**: Terraform times out waiting for cluster

**Solution**:
1. Check Azure service health
2. Verify quota limits:
```bash
az vm list-usage --location brazilsouth --output table
```
3. Consider deploying fewer clusters initially

### Issue: Insufficient Permissions

**Symptom**: `AuthorizationFailed` errors when creating role assignments

**Solution**: Verify your account or Service Principal has required roles:
- **Owner** role (preferred) - Can create resources AND role assignments
- Or **Contributor** + **User Access Administrator** roles

For Service Principal used in GitHub Actions:
```bash
# Check current permissions
az role assignment list --assignee <CLIENT_ID> --output table

# Add Owner role if missing
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "Owner" \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

**Why Owner is needed**: The IAM module (`00-iam`) creates role assignments for managed identities, which requires elevated permissions beyond Contributor.

### Issue: Ingress LoadBalancer Stuck in Pending

**Symptom**: LoadBalancer service never gets external IP

**Solution**: See [INGRESS-NGINX-DEPLOYMENT.md](INGRESS-NGINX-DEPLOYMENT.md) troubleshooting section.

Quick checks:
```bash
# Check service annotations
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -o yaml

# Check events
kubectl get events -n ingress-nginx-external --sort-by='.lastTimestamp'

# Check Azure Load Balancer
az network lb list \
  --resource-group MC_rg-network_aks-dev_brazilsouth \
  --output table
```

---

## Updating Infrastructure

### Update Single Module

```bash
cd terraform/01-networking

# Make changes to .tf files

# Plan changes
terraform plan

# Apply updates
terraform apply
```

### Update Cluster Count

To add or remove clusters:

```bash
cd terraform/02-kubernetes

# Deploy additional cluster
terraform apply -var="deploy_clusters=dev,stg,prd"

# Remove clusters (scales down)
terraform apply -var="deploy_clusters=dev"
```

**Note**: Removing a cluster from `deploy_clusters` will destroy that cluster.

### Update Kubernetes Version

Edit `terraform.tfvars` in `02-kubernetes`:

```hcl
aks_clusters = {
  dev = {
    # ... other config
    kubernetes_version = "1.31"  # Update to the desired version
  }
}
```

Then apply:
```bash
terraform apply
```

---

## Cleanup and Destruction

### Destroy All Infrastructure

**Warning**: This will delete all resources. Ensure you have backups of any data.

#### Using Makefile

```bash
make destroy-all
```

#### Using Terraform

Must destroy in reverse order:

```bash
# 1. Destroy Kubernetes clusters
cd terraform/02-kubernetes
terraform destroy

# 2. Destroy Networking
cd ../01-networking
terraform destroy

# 3. Destroy IAM
cd ../00-iam
terraform destroy
```

### Destroy Specific Clusters

```bash
cd terraform/02-kubernetes

# Destroy specific clusters by updating variable
terraform apply -var="deploy_clusters=dev"
# This keeps dev, removes others

# Or completely remove Kubernetes module
terraform destroy
```

### Destroy Only Ingress NGINX

```bash
# Via GitHub Actions
Workflow: destroy-ingress-nginx
Inputs:
  clusters: all
  ingress_type: both
  confirm: yes

# Or via kubectl
kubectl delete -f manifests/aks-ingress-nginx-1.13.3-external.yaml
kubectl delete -f manifests/aks-ingress-nginx-1.13.3-internal.yaml
```

---

## Remote State Backend

For production use, enable remote state backend to store Terraform state in Azure Storage.

### Create State Storage

```bash
# Create resource group
az group create \
  --name rg-terraform-state \
  --location brazilsouth

# Create storage account (must be globally unique)
az storage account create \
  --name sttfstate$(date +%s) \
  --resource-group rg-terraform-state \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name tfstate \
  --account-name <storage-account-name>
```

### Enable Backend in Terraform

Uncomment the backend configuration in each module's `main.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "<your-storage-account-name>"
    container_name       = "tfstate"
    key                  = "iam.tfstate"  # Change per module: iam, networking, kubernetes
  }
}
```

### Re-initialize with Backend

```bash
cd terraform/00-iam
terraform init -reconfigure
```

---

## Best Practices

### 1. Always Plan First

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### 2. Use Version Control

Commit changes to Git before applying:
```bash
git add .
git commit -m "Update cluster configuration"
git push
```

### 3. Tag Resources

Customize tags in `terraform.tfvars`:
```hcl
tags = {
  Project     = "azure-landing-zone"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
  Environment = "production"
  Owner       = "platform-team"
}
```

### 4. Test in DEV First

Always test changes in DEV before applying to production:
```bash
# Deploy to dev first
terraform apply -var="deploy_clusters=dev"

# Verify
kubectl get nodes

# Then deploy to other environments
terraform apply -var="deploy_clusters=dev,stg,prd"
```

### 5. Use Workspaces (Optional)

For managing multiple environments:
```bash
terraform workspace new dev
terraform workspace new prd
terraform workspace select dev
terraform apply
```

### 6. Regular State Backups

If using local state, backup regularly:
```bash
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d)
```

### 7. Monitor Costs

Use Azure Cost Management:
```bash
# View costs by resource group
az consumption usage list \
  --start-date 2025-01-01 \
  --end-date 2025-01-31 \
  --query "[?contains(instanceName, 'rg-network')]"
```

---

## Next Steps

After successful deployment:

1. **Configure DNS**: Point your domains to Ingress LoadBalancer IPs
2. **Setup TLS**: Deploy cert-manager for automatic certificate management
3. **Deploy Applications**: Use kubectl or Helm to deploy your workloads
4. **Setup Monitoring**: Enable Container Insights and Azure Monitor
5. **Configure Backups**: Setup Azure Backup for AKS persistent volumes
6. **Implement GitOps**: Setup ArgoCD or Flux for declarative deployments
7. **Security Hardening**: Enable Azure Policy, Pod Security Standards

---

## Additional Resources

- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Landing Zone Best Practices](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [INGRESS-NGINX-DEPLOYMENT.md](INGRESS-NGINX-DEPLOYMENT.md) - Ingress deployment guide
- [GITHUB_SECRETS.md](GITHUB_SECRETS.md) - CI/CD secrets configuration
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture details
