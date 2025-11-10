# GitHub Secrets Configuration

Complete guide for configuring GitHub secrets required for CI/CD workflows.

---

## 📝 Quick Checklist

Before running GitHub Actions workflows, ensure:

- [ ] Service Principal created with **Owner** role (not Contributor)
- [ ] All 5 secrets configured in GitHub repository
- [ ] Service Principal has both Contributor AND Owner roles visible in `az role assignment list`
- [ ] Wait 1-2 minutes after creating/updating permissions before running workflows

⚠️ **Common Issue**: Creating Service Principal with "Contributor" role will cause `AuthorizationFailed` errors when Terraform tries to create role assignments. Always use **"Owner"** role.

---

## Overview

This project uses GitHub Actions for automated infrastructure deployment and management. The workflows require several Azure credentials configured as GitHub secrets to authenticate and deploy resources.

---

## Required Secrets

Configure the following secrets in your GitHub repository for the workflows to function properly:

### 1. AZURE_CREDENTIALS

JSON-formatted credentials for Azure Service Principal authentication in GitHub Actions.

**Format:**
```json
{
  "clientId": "<AZURE_CLIENT_ID>",
  "clientSecret": "<AZURE_CLIENT_SECRET>",
  "subscriptionId": "<AZURE_SUBSCRIPTION_ID>",
  "tenantId": "<AZURE_TENANT_ID>"
}
```

**Usage**: Used by `azure/login@v2` action for authentication

---

### 2. AZURE_CLIENT_ID

The Application (client) ID of your Azure Service Principal.

**Example**: `12345678-1234-1234-1234-123456789abc`

**Usage**: Used as environment variable `ARM_CLIENT_ID` for Terraform

---

### 3. AZURE_CLIENT_SECRET

The client secret (password) of your Azure Service Principal.

**Example**: `abcdefghijklmnopqrstuvwxyz123456789`

**Usage**: Used as environment variable `ARM_CLIENT_SECRET` for Terraform

**Security**: This is a sensitive value. Never commit it to code.

---

### 4. AZURE_SUBSCRIPTION_ID

Your Azure subscription ID where resources will be deployed.

**Usage**: Used as environment variable `ARM_SUBSCRIPTION_ID` for Terraform

---

### 5. AZURE_TENANT_ID

Your Azure Active Directory (Entra ID) tenant ID.

**Usage**: Used as environment variable `ARM_TENANT_ID` for Terraform

---

## How to Get Azure Credentials

### Step 1: Get Subscription and Tenant IDs

These values are easy to retrieve from Azure CLI:

```bash
# Get your subscription ID
az account show --query id -o tsv

# Get your tenant ID
az account show --query tenantId -o tsv
```

### Step 2: Create Service Principal

Create a Service Principal with **Owner** role for GitHub Actions. This is required because Terraform needs to create role assignments:

```bash
# Create Service Principal with Owner role
az ad sp create-for-rbac \
  --name "sp-github-actions-landing-zone" \
  --role "Owner" \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> \
  --sdk-auth
```

**⚠️ Important**: Use **"Owner"** role (not "contributor") because:
- Terraform needs to create IAM role assignments
- The `00-iam` module assigns roles to managed identities
- Without Owner, you'll get "AuthorizationFailed" errors

**Output** (save this JSON):
```json
{
  "clientId": "12345678-1234-1234-1234-123456789abc",
  "clientSecret": "your-client-secret-here",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

**Important**:
- Save the entire JSON output for `AZURE_CREDENTIALS` secret
- Save the `clientId` value for `AZURE_CLIENT_ID` secret
- Save the `clientSecret` value for `AZURE_CLIENT_SECRET` secret
- The `clientSecret` is only shown once - save it immediately

### Step 3: Extract Individual Values

From the JSON output above:

```bash
# AZURE_CLIENT_ID
echo "12345678-1234-1234-1234-123456789abc"

# AZURE_CLIENT_SECRET
echo "your-client-secret-here"

# AZURE_SUBSCRIPTION_ID
echo "your-subscription-id"

# AZURE_TENANT_ID
echo "your-tenant-id"
```

---

## Adding Secrets to GitHub

### Method 1: GitHub Web UI

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:

| Name | Value |
|------|-------|
| `AZURE_CREDENTIALS` | Entire JSON from `az ad sp create-for-rbac --sdk-auth` |
| `AZURE_CLIENT_ID` | `clientId` from JSON |
| `AZURE_CLIENT_SECRET` | `clientSecret` from JSON |
| `AZURE_SUBSCRIPTION_ID` | `subscriptionId` from JSON |
| `AZURE_TENANT_ID` | `tenantId` from JSON |

### Method 2: GitHub CLI

If you have GitHub CLI installed:

```bash
# Set AZURE_CREDENTIALS (entire JSON)
gh secret set AZURE_CREDENTIALS --body '{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}'

# Set individual secrets
gh secret set AZURE_CLIENT_ID --body "<client-id>"
gh secret set AZURE_CLIENT_SECRET --body "<client-secret>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"
gh secret set AZURE_TENANT_ID --body "<tenant-id>"
```

### Method 3: GitHub CLI from File

```bash
# Save Service Principal output to file
az ad sp create-for-rbac \
  --name "sp-github-actions-landing-zone" \
  --role "Owner" \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> \
  --sdk-auth > azure-credentials.json

# Set secret from file
gh secret set AZURE_CREDENTIALS < azure-credentials.json

# Extract and set individual values
export CLIENT_ID=$(cat azure-credentials.json | jq -r '.clientId')
export CLIENT_SECRET=$(cat azure-credentials.json | jq -r '.clientSecret')
export SUBSCRIPTION_ID=$(cat azure-credentials.json | jq -r '.subscriptionId')
export TENANT_ID=$(cat azure-credentials.json | jq -r '.tenantId')

gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID"
gh secret set AZURE_CLIENT_SECRET --body "$CLIENT_SECRET"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID"

# Clean up
rm azure-credentials.json
```

---

## Verify Secrets

### Check Secrets are Set

In GitHub UI:
- Go to **Settings** → **Secrets and variables** → **Actions**
- You should see all 5 secrets listed (values are hidden)

Via GitHub CLI:
```bash
gh secret list
```

### Test with Workflow

Run the `deploy-infrastructure` workflow with `action: plan` to test authentication without making changes:

```
Workflow: deploy-infrastructure
Inputs:
  module: 00-iam
  action: plan
  clusters: all
```

If authentication is successful, the workflow will show a Terraform plan.

---

## Security Best Practices

### 1. Never Commit Secrets to Code

Ensure secrets are never committed:

```bash
# Add to .gitignore
echo "*.tfvars" >> .gitignore
echo "azure-credentials.json" >> .gitignore
echo ".env" >> .gitignore
```

### 2. Rotate Secrets Regularly

Rotate Service Principal secrets periodically:

```bash
# Reset Service Principal credentials
az ad sp credential reset \
  --id <CLIENT_ID> \
  --append

# Update GitHub secrets with new values
```

### 3. Use Least Privilege

The Service Principal needs **Owner** role for this project because:
- Terraform creates IAM role assignments in the `00-iam` module
- Managed identities need roles assigned to them

If you want tighter security:
- Use **"User Access Administrator"** + **"Contributor"** instead of Owner
- Or scope Owner role only to specific resource groups after initial setup

### 4. Use Environment Secrets (Optional)

For production, consider using GitHub Environment secrets:

1. Create environments: `dev`, `stg`, `prd`
2. Add secrets per environment
3. Require approvals for production deployments

### 5. Enable Secret Scanning

Enable GitHub's secret scanning:
- Go to **Settings** → **Security** → **Code security and analysis**
- Enable **Secret scanning**

---

## Workflows Using These Secrets

### 1. deploy-infrastructure.yml

**Purpose**: Deploy core infrastructure (IAM, Networking, Kubernetes)

**Secrets used**:
- `AZURE_CREDENTIALS` - For Azure login
- `AZURE_CLIENT_ID` - Terraform ARM_CLIENT_ID
- `AZURE_CLIENT_SECRET` - Terraform ARM_CLIENT_SECRET
- `AZURE_SUBSCRIPTION_ID` - Terraform ARM_SUBSCRIPTION_ID
- `AZURE_TENANT_ID` - Terraform ARM_TENANT_ID

**Trigger**: Manual workflow dispatch

---

### 2. deploy-ingress-nginx.yml

**Purpose**: Deploy/manage Ingress NGINX controllers

**Secrets used**:
- `AZURE_CREDENTIALS` - For Azure login and kubectl access

**Trigger**: Manual workflow dispatch

---

### 3. destroy-ingress-nginx.yml

**Purpose**: Remove Ingress NGINX controllers

**Secrets used**:
- `AZURE_CREDENTIALS` - For Azure login and kubectl access

**Trigger**: Manual workflow dispatch

---

### 4. terraform-validate.yml

**Purpose**: Validate Terraform code on pull requests

**Secrets used**: None (runs validation only, no deployment)

**Trigger**: Automatic on pull requests

---

## Troubleshooting

### Error: "No subscription found"

**Cause**: `AZURE_CREDENTIALS` JSON is malformed or credentials are invalid

**Solution**:
1. Verify JSON format (use [jsonlint.com](https://jsonlint.com))
2. Recreate Service Principal:
```bash
az ad sp create-for-rbac --name "sp-github-new" --role contributor --scopes /subscriptions/<SUB_ID> --sdk-auth
```
3. Update GitHub secret with new JSON

---

### Error: "Insufficient privileges"

**Cause**: Service Principal lacks required permissions

**Solution**: Grant Owner role (required for role assignments):
```bash
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "Owner" \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

---

### Error: "Client secret has expired"

**Cause**: Service Principal credentials expired (default: 1 year)

**Solution**: Reset credentials:
```bash
az ad sp credential reset --id <CLIENT_ID>
```

Update `AZURE_CLIENT_SECRET` and `AZURE_CREDENTIALS` secrets with new values.

---

### Error: "The subscription is disabled"

**Cause**: Azure subscription is not active

**Solution**:
1. Check subscription status in Azure Portal
2. Verify correct subscription ID:
```bash
az account list --output table
```

---

## Service Principal Management

### List Service Principals

```bash
# List all Service Principals
az ad sp list --display-name "sp-github-actions" --output table
```

### Get Service Principal Details

```bash
# Get details
az ad sp show --id <CLIENT_ID>
```

### Reset Service Principal Password

```bash
# Reset password (generates new client secret)
az ad sp credential reset --id <CLIENT_ID>
```

**Important**: Update GitHub secrets after resetting password.

### Delete Service Principal

```bash
# Delete when no longer needed
az ad sp delete --id <CLIENT_ID>
```

---

## Alternative: Using Federated Identity (OpenID Connect)

For enhanced security, you can use GitHub's OIDC provider instead of client secrets.

### Benefits of OIDC
- No long-lived secrets
- Automatic credential rotation
- Better security posture

### Setup OIDC

```bash
# Create Service Principal with Owner role
SP_ID=$(az ad sp create-for-rbac \
  --name "sp-github-oidc" \
  --role "Owner" \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --query appId -o tsv)

# Add federated credential
az ad app federated-credential create \
  --id $SP_ID \
  --parameters '{
    "name": "github-actions",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<ORG>/<REPO>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### Update Workflow for OIDC

Modify `.github/workflows/deploy-infrastructure.yml`:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - name: Azure Login via OIDC
    uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

**Note**: `AZURE_CLIENT_SECRET` and `AZURE_CREDENTIALS` are not needed with OIDC.

---

## Quick Reference

### Required Secrets Summary

| Secret Name | Type | Used By | Example Value |
|-------------|------|---------|---------------|
| `AZURE_CREDENTIALS` | JSON | `azure/login@v2` | `{"clientId":"...","clientSecret":"..."}` |
| `AZURE_CLIENT_ID` | String | Terraform | `12345678-1234-...` |
| `AZURE_CLIENT_SECRET` | String | Terraform | `abcdef123456...` |
| `AZURE_SUBSCRIPTION_ID` | String | Terraform | `87654321-4321-...` |
| `AZURE_TENANT_ID` | String | Terraform | `11111111-2222-...` |

### Commands Cheat Sheet

```bash
# Get IDs
az account show --query id -o tsv          # Subscription ID
az account show --query tenantId -o tsv    # Tenant ID

# Create Service Principal with Owner role
az ad sp create-for-rbac --name "sp-name" --role "Owner" --scopes /subscriptions/<SUB_ID> --sdk-auth

# Reset credentials
az ad sp credential reset --id <CLIENT_ID>

# Set GitHub secrets
gh secret set AZURE_CREDENTIALS < credentials.json
gh secret set AZURE_CLIENT_ID --body "<value>"
gh secret set AZURE_CLIENT_SECRET --body "<value>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<value>"
gh secret set AZURE_TENANT_ID --body "<value>"

# List secrets
gh secret list
```

---

## Next Steps

After configuring secrets:

1. ✅ Test authentication by running `deploy-infrastructure` workflow with `action: plan`
2. ✅ Deploy infrastructure: [DEPLOYMENT.md](DEPLOYMENT.md)
3. ✅ Monitor workflow runs in **Actions** tab
4. ✅ Review deployment logs for any issues

---

## Additional Resources

- [GitHub Actions Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Azure Service Principals Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [GitHub OIDC with Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
