# Pipeline Error Fix - Resource Import

## Problem Summary

The GitHub Actions pipeline was failing with an "already exists" error even after running `terraform destroy` followed by `terraform apply`. The root cause was a **bug in the automatic resource import logic**.

## The Bug

The error occurred in the workflow's regex pattern that extracts the Terraform resource address from error messages:

```bash
# ❌ INCORRECT - Was capturing wrong text
RESOURCE_TYPE=$(echo "$APPLY_OUTPUT" | grep -oP 'with \K[^,]+' | head -1 | tr -d ' ')
```

**What it was extracting:**
```
thefollowingsymbols:
```

**What it should extract:**
```
azurerm_resource_group.iam
```

## Error Message Example

```
Error: a resource with the ID "/subscriptions/***/resourceGroups/rg-network" already exists
│   with azurerm_resource_group.iam,
│   on service-principals.tf line 11, in resource "azurerm_resource_group" "iam":
```

The old regex was matching everything up to the comma, including newlines and unwanted text.

## The Fix

Updated the regex to specifically match Terraform resource addresses (format: `resource_type.resource_name`):

```bash
# ✅ CORRECT - Extracts proper resource address
RESOURCE_ADDRESS=$(echo "$APPLY_OUTPUT" | grep -oP 'with \K[a-z_]+\.[a-z_]+' | head -1)
```

**Pattern breakdown:**
- `with \K` - Match "with " but don't include it in result
- `[a-z_]+` - Resource type (e.g., `azurerm_resource_group`)
- `\.` - Literal dot separator
- `[a-z_]+` - Resource name (e.g., `iam`)
- `| head -1` - Take only first match

## Changes Made

**File:** `.github/workflows/deploy-infrastructure.yml`

**Updated lines:**
- Line ~104 (all modules path)
- Line ~203 (single module path)

Changed from:
```yaml
RESOURCE_TYPE=$(echo "$APPLY_OUTPUT" | grep -oP 'with \K[^,]+' | head -1 | tr -d ' ')
RESOURCE_ID=$(echo "$APPLY_OUTPUT" | grep -oP 'ID "\K[^"]+' | head -1)

if [ -n "$RESOURCE_TYPE" ] && [ -n "$RESOURCE_ID" ]; then
  terraform import "$RESOURCE_TYPE" "$RESOURCE_ID"
```

To:
```yaml
RESOURCE_ADDRESS=$(echo "$APPLY_OUTPUT" | grep -oP 'with \K[a-z_]+\.[a-z_]+' | head -1)
RESOURCE_ID=$(echo "$APPLY_OUTPUT" | grep -oP 'ID "\K[^"]+' | head -1)

if [ -n "$RESOURCE_ADDRESS" ] && [ -n "$RESOURCE_ID" ]; then
  terraform import "$RESOURCE_ADDRESS" "$RESOURCE_ID"
```

## Why This Happened

The resource group `rg-network` existed in Azure even after `terraform destroy` because:

1. **No remote state backend** - The local state file may not have been pushed to GitHub
2. **State drift** - The GitHub Actions runner doesn't have access to local state files
3. **Orphaned resources** - Manual creation or previous failed runs

## Testing the Fix

### Expected Behavior Now

When you run the pipeline and encounter an "already exists" error:

```
⚠️  'Already Exists' error detected!
📋 Extracting resource information from error...
  Resource: azurerm_resource_group.iam
  ID: /subscriptions/***/resourceGroups/rg-network
🔄 Attempting to import...
✅ Import successful! Retrying apply...
✅ Apply successful after import!
```

### How to Test

1. **Ensure resources are clean:**
   ```bash
   az group delete --name rg-network --yes --no-wait
   az group delete --name rg-compute --yes --no-wait
   ```

2. **Wait 3-5 minutes** for Azure to complete deletion

3. **Run the workflow:**
   - Module: `all`
   - Action: `apply`
   - Clusters: `all`

4. **Monitor the logs** for successful import if needed

## Long-term Solution

To prevent this issue permanently, configure a **remote state backend**:

### Option 1: Azure Storage Backend (Recommended)

```hcl
# terraform/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatexxxxxxxxx"
    container_name       = "tfstate"
    key                  = "azure-landing-zone.tfstate"
  }
}
```

### Option 2: Terraform Cloud

```hcl
# terraform/backend.tf
terraform {
  cloud {
    organization = "your-org"
    workspaces {
      name = "azure-landing-zone"
    }
  }
}
```

## Manual Cleanup (If Needed)

If the auto-import still fails, manually clean up:

```bash
# Delete all resource groups
az group delete --name rg-network --yes --no-wait
az group delete --name rg-compute --yes --no-wait

# Verify deletion (should return "false")
az group exists --name rg-network
az group exists --name rg-compute

# Delete Service Principals (optional - for complete cleanup)
for env in dev stg prd sdx; do
  SP_ID=$(az ad sp list --display-name "sp-aks-$env" --query '[0].appId' -o tsv)
  if [ -n "$SP_ID" ]; then
    az ad sp delete --id "$SP_ID"
  fi
done
```

## Commit Message

```
fix: correct resource address extraction in auto-import workflow

The workflow was incorrectly extracting Terraform resource addresses from
error messages, causing the automatic import feature to fail. Updated the
regex pattern to properly match the resource_type.resource_name format.

Changes:
- Updated RESOURCE_TYPE to RESOURCE_ADDRESS for clarity
- Fixed grep pattern to: 'with \K[a-z_]+\.[a-z_]+'
- Applied fix to both module deployment paths

This resolves the issue where pipelines would fail even after terraform
destroy + apply cycles.
```

## Related Files

- `.github/workflows/deploy-infrastructure.yml` - Main fix location
- `docs/DEPLOYMENT.md` - Remote state backend instructions
- `terraform/00-iam/service-principals.tf` - Where rg-network is defined

## Prevention Checklist

✅ Always use remote state backend in production  
✅ Test pipeline changes with dry-run first  
✅ Verify regex patterns with sample error messages  
✅ Use specific regex patterns instead of greedy matches  
✅ Monitor GitHub Actions logs for extraction issues  

## References

- [Terraform Import Documentation](https://developer.hashicorp.com/terraform/cli/import)
- [Azure Resource Manager Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
