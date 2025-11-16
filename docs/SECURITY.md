# Security Best Practices - Azure Landing Zone

This document outlines security best practices for deploying and managing the Azure Landing Zone infrastructure.

## 🔐 Credential Management

### Never Commit Sensitive Data

**NEVER commit these files to version control:**

- `*.tfvars` - Terraform variable files with real values
- `*.tfstate` - Terraform state files (CRITICAL!)
- `*.tfstate.backup` - State backup files
- `.terraform/` - Terraform working directory
- `.env` - Environment variable files
- `.azure/` - Azure CLI configuration
- `azure_credentials.json` - Service Principal credentials
- `*.pem` - SSH private keys
- `*.key` - Private keys

### Use Azure Environment Variables

For authentication, always use environment variables:

```bash
# For local development
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
export ARM_CLIENT_ID="your-client-id"  # If using Service Principal
export ARM_CLIENT_SECRET="your-client-secret"  # If using Service Principal

# For GitHub Actions (use GitHub Secrets)
# AZURE_SUBSCRIPTION_ID
# AZURE_TENANT_ID
# AZURE_CLIENT_ID
# AZURE_CLIENT_SECRET
```

### Use GitHub Secrets

For CI/CD pipelines, always use GitHub Secrets:

1. **Required Secrets:**
   - `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
   - `AZURE_TENANT_ID` - Azure AD tenant ID
   - `AZURE_CLIENT_ID` - Service Principal application ID
   - `AZURE_CLIENT_SECRET` - Service Principal password

2. **How to add secrets:**
   ```
   Repository → Settings → Secrets and variables → Actions → New repository secret
   ```

3. **Reference secrets in workflows:**
   ```yaml
   - name: Azure Login
     uses: azure/login@v1
     with:
       creds: |
         {
           "clientId": "${{ secrets.AZURE_CLIENT_ID }}",
           "clientSecret": "${{ secrets.AZURE_CLIENT_SECRET }}",
           "subscriptionId": "${{ secrets.AZURE_SUBSCRIPTION_ID }}",
           "tenantId": "${{ secrets.AZURE_TENANT_ID }}"
         }
   ```

### Service Principal Security

**Recommended Service Principal Setup:**

1. **Create a Service Principal:**
   ```bash
   az ad sp create-for-rbac \
     --name "terraform-deployer" \
     --role "Owner" \
     --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID"
   ```

2. **Save the output securely** (you'll only see the password once!)

3. **Store in GitHub Secrets** (never commit to repo!)

4. **Rotate secrets regularly** (every 90 days recommended)

5. **Use Managed Identities when possible** instead of Service Principals

## 🛡️ Terraform Security

### Remote State Storage

**ALWAYS use remote state storage:**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate"
    container_name       = "tfstate"
    key                  = "iam.tfstate"
  }
}
```

**Critical Benefits:**
- State is NOT in version control (prevents data leaks)
- Encrypted at rest in Azure Storage
- Supports state locking
- Team collaboration
- Versioning enabled for rollback

### .gitignore Configuration

**CRITICAL: Your .gitignore MUST include:**

```gitignore
# Terraform state (NEVER commit!)
*.tfstate
*.tfstate.*
*.tfstate.backup
.terraform/
.terraform.lock.hcl

# Variable files (NEVER commit!)
*.tfvars
!*.tfvars.example

# Azure credentials
.azure/
azure_credentials.json
```

**NEVER use patterns like:**
```gitignore
!terraform.tfvars  # ❌ DANGEROUS! This ALLOWS commits!
```

### Variable Files

**Use terraform.tfvars.example as template:**

1. Copy example file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit with your values:
   ```hcl
   resource_group_name = "rg-network"
   location            = "brazilsouth"
   ```

3. **NEVER commit terraform.tfvars!**

### Sensitive Variables

For sensitive values, use Terraform's `sensitive` attribute:

```hcl
variable "admin_password" {
  type      = string
  sensitive = true
}
```

## 🔍 Pre-Deployment Checklist

Before running `terraform apply`, verify:

- [ ] `.gitignore` properly configured (no `!terraform.tfvars`)
- [ ] No `.tfstate` files in repository
- [ ] No `.terraform/` directories in repository
- [ ] Azure credentials in environment variables or GitHub Secrets
- [ ] Remote backend configured for state storage
- [ ] Service Principal has Owner role for IAM operations
- [ ] All sensitive variables marked as `sensitive = true`
- [ ] `terraform.tfvars` not committed to Git

## 🚨 Incident Response

### If Credentials Are Accidentally Committed:

1. **Immediately rotate the compromised credentials:**
   ```bash
   # Reset Service Principal password
   az ad sp credential reset \
     --id YOUR_APP_ID
   ```

2. **Remove from Git history:**
   ```bash
   # Use git-filter-repo (recommended)
   pip install git-filter-repo
   git filter-repo --path path/to/secret/file --invert-paths
   
   # Or use BFG Repo-Cleaner
   bfg --delete-files terraform.tfstate
   ```

3. **Update GitHub Secrets** with new credentials

4. **Review Activity Logs:**
   ```bash
   az monitor activity-log list \
     --caller YOUR_SERVICE_PRINCIPAL_NAME \
     --max-events 50
   ```

### If .tfstate Files Were Committed:

**CRITICAL:** `.tfstate` files can contain sensitive data!

1. **Immediately remove from Git:**
   ```bash
   ./scripts/cleanup-sensitive-files.sh
   ```

2. **Clean Git history:**
   ```bash
   git filter-repo --path '*.tfstate' --invert-paths
   git filter-repo --path '.terraform/' --invert-paths
   ```

3. **Force push** (warning: rewrites history):
   ```bash
   git push origin --force --all
   ```

4. **Audit what was exposed:**
   - Review state file contents
   - Check for secrets, IPs, resource IDs
   - Rotate any exposed credentials

## 🔒 Network Security

### Private AKS Clusters

For production, use private clusters:

```hcl
private_cluster_enabled = true
api_server_authorized_ip_ranges = []
```

### Network Security Groups

Review NSG rules before deployment:

```bash
# List NSGs
az network nsg list \
  --resource-group rg-network \
  --output table

# Show NSG rules
az network nsg rule list \
  --resource-group rg-network \
  --nsg-name nsg-dev-subnet \
  --output table
```

### Network Policies

Enable Azure Network Policy on AKS:

```hcl
network_policy = "azure"
```

## 📋 Compliance

### Azure Policy

Enable Azure Policy for governance:

```hcl
enable_azure_policy = true
```

### Activity Logs

Monitor resource changes:

```bash
az monitor activity-log list \
  --resource-group rg-network \
  --max-events 50
```

### Cost Management

Enable cost alerts:

```bash
az consumption budget create \
  --budget-name monthly-budget \
  --amount 500 \
  --time-grain Monthly
```

### Regular Security Reviews

Perform security reviews:

1. **Monthly:** Review IAM assignments and Service Principal permissions
2. **Quarterly:** Rotate Service Principal secrets
3. **Annually:** Full security audit and compliance review

## 🔗 Additional Resources

- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
- [Terraform Security Guidelines](https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables)
- [Azure Landing Zone documentation](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [AKS Security Best Practices](https://docs.microsoft.com/en-us/azure/aks/security-best-practices)

## 📞 Reporting Security Issues

If you discover a security vulnerability, please:

1. **DO NOT** open a public issue
2. Email the maintainer directly
3. Provide detailed information about the vulnerability
4. Allow time for the issue to be fixed before public disclosure

---

## ⚠️ CRITICAL SECURITY NOTES FOR THIS REPOSITORY

### History Contains Sensitive Files!

**This repository previously had these files committed:**
- ✅ `.tfstate` files (removed but in history)
- ✅ `.terraform/` directories (removed but in history)
- ✅ `.tfvars` files (removed but in history)

### Recommended Actions:

**Option 1: Clean Git History (Recommended)**
```bash
# Install git-filter-repo
pip install git-filter-repo

# Remove sensitive files from history
git filter-repo --path '*.tfvars' --invert-paths
git filter-repo --path '*.tfstate' --invert-paths
git filter-repo --path '*.tfstate.backup' --invert-paths
git filter-repo --path '.terraform/' --invert-paths

# Force push (rewrites history)
git push origin --force --all
```

**Option 2: Create New Repository (Most Secure)**
1. Create new GitHub repository
2. Copy only clean code (no .git/)
3. Initialize fresh Git history
4. Push to new repository
5. Archive old repository (don't delete to preserve history)

---

**Remember:** Security is everyone's responsibility. When in doubt, ask before committing!
