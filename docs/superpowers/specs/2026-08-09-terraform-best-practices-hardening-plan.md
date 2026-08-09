# Terraform Best-Practices Hardening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `azure-landing-zone`'s Terraform code, CI, and docs in line with common best practices, fixing the concrete issues identified in the 2026-08-09 repository survey and design spec, without adding new infrastructure capability.

**Architecture:** Four independently-mergeable PRs, in order: (1) Terraform correctness/consistency, (2) network security, (3) CI/CD hardening, (4) docs freshness. Each PR is its own branch → commits per task → `gh pr create` → CI green → squash-merge, matching the flow already used earlier today for PRs #17–#20.

**Tech Stack:** Terraform >= 1.5.0, `hashicorp/azurerm ~> 4.0`, `hashicorp/azuread ~> 3.0`, GitHub Actions, `tflint` 0.64.0 (+ `tflint-ruleset-azurerm` 0.28.0), `checkov` 3.3.0.

## Global Constraints

- Every module keeps its existing `terraform { required_version = ">= 1.5.0" }` / `azurerm ~> 4.0` constraint style — do not consolidate `backend.tf` into a separate `versions.tf` for the three root modules (explicitly out of scope per the design spec). The one exception is `modules/aks-cluster`, a child module that currently has **no** version constraints at all — that gets a new `versions.tf` (adding missing content, not restructuring existing content).
- Every new/changed variable keeps a `description`.
- No new Azure resources that add recurring cost (no Log Analytics Workspace, no Azure Policy definitions — deferred per spec).
- Follow the existing local git workflow: feature branch off `master`, commit per task, push, `gh pr create`, wait for checks, `gh pr merge --squash --delete-branch`.
- As of this plan's authoring, all live infra (`aks-dev`, networking, IAM) is being destroyed by user request — PR 1 and PR 2's infra-touching steps verify via `terraform plan` (and `apply` once anything exists again), not against a specific pre-existing resource.

---

## PR 1 — Terraform correctness & consistency

**Branch:** `fix/terraform-correctness`

### Task 1.1: Add `validation` to `deploy_clusters`

**Files:**
- Modify: `terraform/02-kubernetes/variables.tf:21-25`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new — same variable, same type, same default; adds a `validation` block only.

- [ ] **Step 1: Add the validation block**

Replace:
```hcl
variable "deploy_clusters" {
  description = "Comma-separated list of clusters to deploy (dev,stg,prd,sdx) or 'all' for all clusters"
  type        = string
  default     = "all"
}
```
with:
```hcl
variable "deploy_clusters" {
  description = "Comma-separated list of clusters to deploy (dev,stg,prd,sdx) or 'all' for all clusters"
  type        = string
  default     = "all"

  validation {
    condition = var.deploy_clusters == "all" || alltrue([
      for c in split(",", var.deploy_clusters) : contains(["dev", "stg", "prd", "sdx"], c)
    ])
    error_message = "deploy_clusters must be \"all\" or a comma-separated list containing only: dev, stg, prd, sdx."
  }
}
```

- [ ] **Step 2: Verify it rejects a bad value**

Run: `cd terraform/02-kubernetes && terraform init -backend=false && terraform plan -var="deploy_clusters=dev,stx" -out=/dev/null`
Expected: fails during variable validation with `deploy_clusters must be "all" or a comma-separated list containing only: dev, stg, prd, sdx.` (typo `stx` triggers it) — not a Terraform crash, and not silent success.

- [ ] **Step 3: Verify the real default still works**

Run: `terraform plan -var="deploy_clusters=all"` (still `-backend=false` from the same directory)
Expected: passes validation (plan may still fail later on missing backend/credentials in a `-backend=false` context — that's fine, the point is it gets *past* the variable-validation stage without the error from Step 2).

- [ ] **Step 4: Commit**

```bash
git add terraform/02-kubernetes/variables.tf
git commit -m "fix: validate deploy_clusters against known environments"
```

### Task 1.2: Add `validation` to `vnet_address_space`

**Files:**
- Modify: `terraform/01-networking/variables.tf:13-17`

- [ ] **Step 1: Add the validation block**

Replace:
```hcl
variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = string
  default     = "192.168.0.0/16"
}
```
with:
```hcl
variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = string
  default     = "192.168.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "vnet_address_space must be a valid CIDR block (e.g. \"192.168.0.0/16\")."
  }
}
```

- [ ] **Step 2: Verify it rejects a bad value**

Run: `cd terraform/01-networking && terraform init -backend=false && terraform plan -var="vnet_address_space=not-a-cidr" -out=/dev/null`
Expected: fails with `vnet_address_space must be a valid CIDR block (e.g. "192.168.0.0/16").`

- [ ] **Step 3: Verify the real default still works**

Run: `terraform plan` (no override — uses the default)
Expected: passes CIDR validation.

- [ ] **Step 4: Commit**

```bash
git add terraform/01-networking/variables.tf
git commit -m "fix: validate vnet_address_space is a real CIDR block"
```

### Task 1.3: Add `validation` to `network_plugin`/`network_policy`

**Files:**
- Modify: `terraform/02-kubernetes/modules/aks-cluster/variables.tf:47-57`

- [ ] **Step 1: Add both validation blocks**

Replace:
```hcl
variable "network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "network_policy" {
  description = "Network policy for AKS (azure or calico)"
  type        = string
  default     = "azure"
}
```
with:
```hcl
variable "network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "network_plugin must be either \"azure\" or \"kubenet\"."
  }
}

variable "network_policy" {
  description = "Network policy for AKS (azure, calico, or cilium)"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "calico", "cilium"], var.network_policy)
    error_message = "network_policy must be \"azure\", \"calico\", or \"cilium\"."
  }
}
```

- [ ] **Step 2: Verify rejection**

This module has no `default` for `cluster_name`, `resource_group_name`, `location`, `kubernetes_version`, `vnet_subnet_id`, `default_node_pool`, `identity_ids`, `dns_service_ip`, and `service_cidr` — every one of them must be supplied or Terraform will block waiting for interactive input that never arrives (exactly the class of bug fixed earlier today). Create a throwaway test tfvars file rather than fighting a giant one-line `-var` list:

```bash
cd terraform/02-kubernetes/modules/aks-cluster
terraform init -backend=false
cat > /tmp/test.tfvars <<'EOF'
cluster_name        = "x"
resource_group_name = "x"
location            = "x"
kubernetes_version  = "1.36"
vnet_subnet_id      = "x"
identity_ids        = []
dns_service_ip      = "1.1.1.1"
service_cidr        = "1.1.1.0/24"
network_plugin      = "flannel"
default_node_pool = {
  name                = "system"
  node_count          = 1
  vm_size             = "Standard_D2s_v3"
  os_disk_size_gb     = 50
  os_disk_type        = "Ephemeral"
  max_pods            = 110
  enable_auto_scaling = true
  min_count           = 1
  max_count           = 3
  zones               = ["1"]
}
EOF
terraform plan -var-file=/tmp/test.tfvars -out=/dev/null
```
Expected: fails with `network_plugin must be either "azure" or "kubenet".`

- [ ] **Step 3: Verify the real value still passes**

Edit `/tmp/test.tfvars`, change `network_plugin = "flannel"` to `network_plugin = "azure"`, then re-run the same `terraform plan -var-file=/tmp/test.tfvars -out=/dev/null` command.
Expected: passes the plugin/policy validation (may still error later on provider auth in a `-backend=false`, no-credentials context — irrelevant here). Clean up with `rm /tmp/test.tfvars` when done.

- [ ] **Step 4: Commit**

```bash
git add terraform/02-kubernetes/modules/aks-cluster/variables.tf
git commit -m "fix: validate AKS network_plugin and network_policy values"
```

### Task 1.4: Remove unused `project_name` variable

**Files:**
- Modify: `terraform/00-iam/variables.tf:13-17`
- Modify: `terraform/00-iam/terraform.tfvars.example:12`

**Interfaces:** none — pure removal of dead code. Confirmed via `grep -rn "project_name" terraform/ docs/` that it's referenced nowhere outside its own declaration and the example tfvars file.

- [ ] **Step 1: Remove the variable block**

Delete from `terraform/00-iam/variables.tf`:
```hcl
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "azure-landing-zone"
}

```
(including the blank line after it, so `location` and `environment` blocks remain separated by exactly one blank line as before).

- [ ] **Step 2: Remove it from the example tfvars**

In `terraform/00-iam/terraform.tfvars.example`, delete the two lines:
```
# Project Configuration
project_name = "azure-landing-zone"
```

- [ ] **Step 3: Verify**

Run: `cd terraform/00-iam && terraform init -backend=false && terraform validate`
Expected: `Success! The configuration is valid.` (no "undeclared variable" or leftover reference errors).

Run: `tflint` (from the same directory; assumes `tflint --init` has been run once already in this repo checkout)
Expected: no more `variable "project_name" is declared but not used` warning.

- [ ] **Step 4: Commit**

```bash
git add terraform/00-iam/variables.tf terraform/00-iam/terraform.tfvars.example
git commit -m "fix: remove unused project_name variable from 00-iam"
```

### Task 1.5: Remove unused `azurerm_virtual_network` data source

**Files:**
- Modify: `terraform/02-kubernetes/main.tf:6-9`

**Interfaces:** none — confirmed via `grep -n "data.azurerm_virtual_network" terraform/02-kubernetes/*.tf` that `data.azurerm_virtual_network.shared` is declared but never referenced anywhere in this module (subnets and identities are looked up directly by name via `var.vnet_name`/`var.resource_group_name`, not through this data source).

- [ ] **Step 1: Delete the unused block**

Delete from `terraform/02-kubernetes/main.tf`:
```hcl
data "azurerm_virtual_network" "shared" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

```

- [ ] **Step 2: Verify**

Run: `cd terraform/02-kubernetes && terraform init -backend=false && terraform validate`
Expected: `Success! The configuration is valid.`

Run: `tflint`
Expected: no more `data "azurerm_virtual_network" "shared" is declared but not used` warning.

- [ ] **Step 3: Commit**

```bash
git add terraform/02-kubernetes/main.tf
git commit -m "fix: remove unused azurerm_virtual_network data source"
```

### Task 1.6: Add missing version constraints to the `aks-cluster` child module

**Files:**
- Create: `terraform/02-kubernetes/modules/aks-cluster/versions.tf`

**Interfaces:** none — this is a constraints-only file, no resources/variables/outputs.

- [ ] **Step 1: Create the file**

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

- [ ] **Step 2: Verify**

Run: `cd terraform/02-kubernetes/modules/aks-cluster && terraform init -backend=false && terraform validate`
Expected: `Success! The configuration is valid.`

Run: `tflint`
Expected: the two previously-seen warnings (`Missing version constraint for provider "azurerm"`, `terraform "required_version" attribute is required`) are gone.

- [ ] **Step 3: Commit**

```bash
git add terraform/02-kubernetes/modules/aks-cluster/versions.tf
git commit -m "fix: add required_version/required_providers to aks-cluster module"
```

### Task 1.7: Fix `terraform.tfvars.example` CIDR drift in `01-networking`

**Files:**
- Modify: `terraform/01-networking/terraform.tfvars.example:9-33`

- [ ] **Step 1: Align the example to the real deployed CIDRs**

Replace lines 9-33 (the `vnet_address_space` line through the end of the `subnet_configs` block) so every `172.31.x.x` becomes `192.168.x.x`, matching `variables.tf`'s defaults and `docs/ARCHITECTURE.md`:

```hcl
vnet_name          = "vnet-shared-network"
vnet_address_space = "192.168.0.0/16"

# Subnet Configuration
subnet_configs = {
  dev = {
    name              = "dev-subnet"
    address_prefix    = "192.168.0.0/20"
    service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault"]
  }
  stg = {
    name              = "stg-subnet"
    address_prefix    = "192.168.16.0/20"
    service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault"]
  }
  prd = {
    name              = "prd-subnet"
    address_prefix    = "192.168.32.0/20"
    service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault", "Microsoft.AzureCosmosDB"]
  }
  sdx = {
    name              = "sdx-subnet"
    address_prefix    = "192.168.48.0/20"
    service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault", "Microsoft.EventHub"]
  }
}
```

- [ ] **Step 2: Verify**

Run: `diff <(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' terraform/01-networking/terraform.tfvars.example) <(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' terraform/01-networking/variables.tf)`
Expected: no output (both files now list the exact same five CIDRs in the same order: the `/16` vnet space, then `dev`/`stg`/`prd`/`sdx` in that order).

- [ ] **Step 3: Commit**

```bash
git add terraform/01-networking/terraform.tfvars.example
git commit -m "fix: align terraform.tfvars.example CIDRs with actual deployed range"
```

### Task 1.8: Add `Environment` to the `02-kubernetes` `tags` default

**Files:**
- Modify: `terraform/02-kubernetes/variables.tf` (the `tags` variable, near the end of the file)

**Note:** `terraform/02-kubernetes/main.tf:69-72` already does `tags = merge(var.tags, { Environment = each.key, Cluster = each.value.cluster_name })` for every real AKS cluster resource — the second map's `Environment` always wins in a `merge()`, so this change is a **variable-default consistency fix only** (matching the shape of `00-iam`'s and `01-networking`'s `tags` defaults, which both include `Environment = "shared"`); it does **not** change any tag actually applied to a real cluster, since that's always overridden per-cluster already. Do not describe this as an infra-affecting change when opening the PR.

- [ ] **Step 1: Update the default**

Replace:
```hcl
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project   = "azure-landing-zone"
    ManagedBy = "terraform"
  }
}
```
with:
```hcl
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "azure-landing-zone"
    ManagedBy   = "terraform"
    Environment = "shared"
  }
}
```

- [ ] **Step 2: Verify**

Run: `cd terraform/02-kubernetes && terraform init -backend=false && terraform validate`
Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add terraform/02-kubernetes/variables.tf
git commit -m "fix: align 02-kubernetes tags default with other modules"
```

### Task 1.9: Fix Service Principal secret plan-diff bug

**Files:**
- Modify: `terraform/00-iam/service-principals.tf:39-43`

- [ ] **Step 1: Add the lifecycle block**

Replace:
```hcl
# Service Principal Password/Secret
resource "azuread_service_principal_password" "terraform" {
  count                = var.create_service_principal ? 1 : 0
  service_principal_id = azuread_service_principal.terraform[0].id
  end_date             = timeadd(timestamp(), "8760h") # 1 year
}
```
with:
```hcl
# Service Principal Password/Secret
resource "azuread_service_principal_password" "terraform" {
  count                = var.create_service_principal ? 1 : 0
  service_principal_id = azuread_service_principal.terraform[0].id
  end_date             = timeadd(timestamp(), "8760h") # 1 year

  lifecycle {
    ignore_changes = [end_date]
  }
}
```

- [ ] **Step 2: Verify**

Run: `cd terraform/00-iam && terraform init -backend=false && terraform validate`
Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add terraform/00-iam/service-principals.tf
git commit -m "fix: stop azuread_service_principal_password from diffing every plan"
```

### Task 1.10: Full-module validation sweep, open PR, merge

- [ ] **Step 1: Format and validate every module**

Run from repo root:
```bash
terraform fmt -check -recursive terraform/
for m in 00-iam 01-networking 02-kubernetes 02-kubernetes/modules/aks-cluster; do
  (cd "terraform/$m" && terraform init -backend=false -upgrade=false >/dev/null && terraform validate) || echo "FAILED: $m"
done
```
Expected: `fmt -check` prints nothing (already formatted); all four `terraform validate` calls print `Success! The configuration is valid.`; no `FAILED:` lines.

- [ ] **Step 2: Real plan against the live backend (if infra exists) or a from-scratch plan (if it was destroyed)**

Run for each of `00-iam`, `01-networking`, `02-kubernetes` (in that order, real init this time — no `-backend=false`):
```bash
cd terraform/<module> && terraform init && terraform plan
```
Expected: no unexpected diffs beyond what each task above already described (e.g. `02-kubernetes`'s plan may show zero changes for the `Environment` tag per Task 1.8's note; if all infra was destroyed, expect a full create plan reflecting a clean, from-scratch deployment with everything from Tasks 1.1–1.9 already baked in).

- [ ] **Step 3: Push, open PR, wait for checks, merge**

```bash
git push -u origin fix/terraform-correctness
gh pr create --repo Vitorspk/azure-landing-zone \
  --title "fix: Terraform correctness and consistency pass" \
  --body "Adds validation blocks (deploy_clusters, vnet_address_space, network_plugin/network_policy), removes dead code (project_name variable, unused azurerm_virtual_network data source), adds missing version constraints to the aks-cluster module, fixes CIDR drift in 01-networking's example tfvars, aligns the 02-kubernetes tags default, and fixes a plan-diff bug in the (disabled-by-default) service principal secret. Part of the post-incident hardening pass — see docs/superpowers/specs/2026-08-09-terraform-best-practices-hardening-design.md."
```
Wait for `GitGuardian Security Checks` and `claude-review` (and `Terraform Validate` matrix, since this PR touches `terraform/**`) to pass, then:
```bash
gh pr merge --repo Vitorspk/azure-landing-zone --squash --delete-branch <PR-number>
```

---

## PR 2 — Network security

**Branch:** `fix/remove-open-ssh-rule`

### Task 2.1: Remove the `AllowSSH` NSG rule

**Files:**
- Modify: `terraform/01-networking/main.tf:39-80` (the `azurerm_network_security_group.allow_ssh` resource)

**Interfaces:** none — the resource's Terraform address (`azurerm_network_security_group.allow_ssh`) and its association resource are unchanged; only one `security_rule` block inside it is removed. `AllowHTTP`/`AllowHTTPS` are untouched.

- [ ] **Step 1: Remove the SSH rule block**

Delete this block from inside `resource "azurerm_network_security_group" "allow_ssh"`:
```hcl
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

```
Leave `AllowHTTPS` (priority 110) and `AllowHTTP` (priority 120) exactly as they are.

- [ ] **Step 2: Verify**

Run: `cd terraform/01-networking && terraform init -backend=false && terraform validate && terraform fmt -check`
Expected: `Success! The configuration is valid.`, no fmt diff.

Run: `checkov -d . --compact --quiet --check CKV_AZURE_10` (from `terraform/01-networking`)
Expected: `Passed checks: 1, Failed checks: 0` (previously failed on `azurerm_network_security_group.allow_ssh`; now passes since the SSH rule is gone).

- [ ] **Step 3: Plan/apply against real state and confirm on Azure**

```bash
terraform init && terraform plan
```
Expected: plan shows exactly one change — the `AllowSSH` rule removed from `azurerm_network_security_group.allow_ssh` (no other resource affected). If the user has approved applying: `terraform apply` (or via the `deploy-infrastructure` GitHub Actions workflow, `module=01-networking`, `action=apply`), then:
```bash
az network nsg rule list --resource-group rg-network --nsg-name nsg-allow-ssh -o table
```
Expected: only `AllowHTTP` and `AllowHTTPS` remain (no `AllowSSH` row).

- [ ] **Step 4: Commit**

```bash
git add terraform/01-networking/main.tf
git commit -m "fix: remove unrestricted SSH ingress rule (no legitimate use case in this AKS architecture)"
```

### Task 2.2: Open PR, wait for checks, merge

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin fix/remove-open-ssh-rule
gh pr create --repo Vitorspk/azure-landing-zone \
  --title "fix: remove unrestricted SSH ingress rule from shared NSG" \
  --body "Removes the AllowSSH rule (port 22, source 0.0.0.0/0) from the shared NSG applied to every environment's subnet. No legitimate use case in this AKS-based architecture — node access should go through az aks command invoke / kubectl debug, not direct SSH. HTTP/HTTPS rules (needed for public ingress) are untouched. Confirmed via checkov (CKV_AZURE_10 now passes). Part of the post-incident hardening pass."
```

- [ ] **Step 2: Wait for checks, then squash-merge**

```bash
gh pr merge --repo Vitorspk/azure-landing-zone --squash --delete-branch <PR-number>
```

---

## PR 3 — CI/CD hardening

**Branch:** `chore/ci-hardening`

### Task 3.1: Add `.tflint.hcl` and wire `tflint` into `terraform-validate.yml`

**Files:**
- Create: `.tflint.hcl` (repo root)
- Modify: `.github/workflows/terraform-validate.yml`

- [ ] **Step 1: Create the config**

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.28.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
```

- [ ] **Step 2: Add the CI step**

In `.github/workflows/terraform-validate.yml`, insert a new step between `Terraform Init` and `Terraform Validate`:
```yaml
      - name: TFLint
        working-directory: terraform/${{ matrix.module }}
        run: |
          tflint --init --config="${{ github.workspace }}/.tflint.hcl"
          tflint --config="${{ github.workspace }}/.tflint.hcl"
```
And add a setup step before it (right after `Setup Terraform`):
```yaml
      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.64.0
```

- [ ] **Step 3: Verify locally before pushing**

Run for every module:
```bash
for m in 00-iam 01-networking 02-kubernetes 02-kubernetes/modules/aks-cluster; do
  echo "=== $m ==="
  (cd "terraform/$m" && tflint --init --config="$(git rev-parse --show-toplevel)/.tflint.hcl" 2>/dev/null; tflint --config="$(git rev-parse --show-toplevel)/.tflint.hcl")
done
```
Expected: zero issues in all four (assuming PR 1 already merged — Tasks 1.4/1.5/1.6 fixed the only three real findings tflint had surfaced).

- [ ] **Step 4: Commit**

```bash
git add .tflint.hcl .github/workflows/terraform-validate.yml
git commit -m "ci: add tflint (blocking) to terraform-validate workflow"
```

### Task 3.2: Add `checkov` (report-only) to `terraform-validate.yml`

**Files:**
- Modify: `.github/workflows/terraform-validate.yml`
- Modify: `terraform/01-networking/main.tf` (one inline skip comment)

- [ ] **Step 1: Add the documented skip for the one deliberately-accepted finding**

Checkov only honors a skip comment as the **first line inside** the resource block, immediately after the opening `{` — a comment placed above the `resource` line has no effect (verified locally: it still reports FAILED, not SKIPPED). In `terraform/01-networking/main.tf`, change:
```hcl
resource "azurerm_network_security_group" "allow_ssh" {
  name                = var.nsg_name
```
to:
```hcl
resource "azurerm_network_security_group" "allow_ssh" {
  #checkov:skip=CKV_AZURE_160:HTTP (80) is intentionally open - this NSG fronts a public ingress controller that must accept plain-HTTP traffic, redirected to HTTPS at the ingress layer rather than blocked at the network layer. See docs/superpowers/specs/2026-08-09-terraform-best-practices-hardening-design.md.
  name                = var.nsg_name
```
(No space after `#`, and the whole annotation must be a single line — verified locally with `checkov -d terraform/01-networking --compact --quiet --check CKV_AZURE_160`, which flips from `Failed checks: 1` to `Skipped checks: 1` once the comment is in this exact position.)

- [ ] **Step 2: Add the checkov step**

This step runs once for the whole `terraform/` tree (not per-matrix-module, since checkov resolves cross-module references best from the root) — add it as a **separate job** in the same workflow file, after the existing `validate` job:
```yaml
  security-scan:
    name: Checkov Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Checkov
        uses: bridgecrewio/checkov-action@v12
        continue-on-error: true
        with:
          directory: terraform/
          compact: true
          quiet: true
```

- [ ] **Step 3: Verify locally**

Run: `checkov -d terraform/ --compact --quiet`
Expected: `CKV_AZURE_10` (SSH) and `CKV_AZURE_160` (HTTP) no longer appear in the failed list (SSH removed by PR 2, HTTP explicitly skipped). The remaining ~10 findings (paid SKU, CSI driver auto-rotation, local admin account, private cluster for non-prod, disk encryption set, system-node taint isolation, ephemeral OS disk on prd, upgrade channel, min-50-pods, temp-disk encryption) are expected and intentionally left as non-blocking CI visibility — none are fixed in this plan (deferred per the design spec's non-goals).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/terraform-validate.yml terraform/01-networking/main.tf
git commit -m "ci: add checkov security scan (report-only) to terraform-validate workflow"
```

### Task 3.3: Add `concurrency` groups to the three operational workflows

**Files:**
- Modify: `.github/workflows/deploy-infrastructure.yml`
- Modify: `.github/workflows/deploy-ingress-nginx.yml`
- Modify: `.github/workflows/destroy-ingress-nginx.yml`

- [ ] **Step 1: Add a concurrency group to each workflow**

In `deploy-infrastructure.yml`, right after the `on:` block (before `jobs:`), add:
```yaml
concurrency:
  group: deploy-infrastructure-${{ github.event.inputs.module }}
  cancel-in-progress: false
```

In `deploy-ingress-nginx.yml`, right after the `env:` block, add:
```yaml
concurrency:
  group: ingress-${{ github.event.inputs.clusters }}
  cancel-in-progress: false
```

In `destroy-ingress-nginx.yml`, right after the `env:` block, add:
```yaml
concurrency:
  group: ingress-${{ github.event.inputs.clusters }}
  cancel-in-progress: false
```

(Same group prefix `ingress-` on both ingress workflows so a deploy and a destroy targeting the same cluster set queue behind each other instead of racing. `cancel-in-progress: false` because these mutate real cloud/cluster state — a queued run should wait its turn, never get silently cancelled mid-apply.)

- [ ] **Step 2: Verify YAML validity**

Run: `actionlint .github/workflows/deploy-infrastructure.yml .github/workflows/deploy-ingress-nginx.yml .github/workflows/destroy-ingress-nginx.yml`
Expected: no new findings beyond the pre-existing shellcheck style nits already present before this change (compare against `git stash`'d output the same way verified earlier today for PR #17).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/deploy-infrastructure.yml .github/workflows/deploy-ingress-nginx.yml .github/workflows/destroy-ingress-nginx.yml
git commit -m "ci: add concurrency groups so deploys/destroys can't race the same cluster"
```

### Task 3.4: Pin `kubectl` version and constrain the `confirm` input

**Files:**
- Modify: `.github/workflows/deploy-ingress-nginx.yml:61-63` (or wherever `azure/setup-kubectl@v4` appears)
- Modify: `.github/workflows/destroy-ingress-nginx.yml:58-60` and the `confirm` input block (lines 26-29)

- [ ] **Step 1: Pin kubectl in both workflows**

In both `deploy-ingress-nginx.yml` and `destroy-ingress-nginx.yml`, change:
```yaml
        uses: azure/setup-kubectl@v4
        with:
          version: 'latest'
```
to:
```yaml
        uses: azure/setup-kubectl@v4
        with:
          version: 'v1.36.3'
```
(`v1.36.3` is the current upstream stable release and matches the AKS server minor version now in use — confirmed via `curl -s https://dl.k8s.io/release/stable.txt`.)

- [ ] **Step 2: Constrain the `confirm` input in `destroy-ingress-nginx.yml`**

Change:
```yaml
      confirm:
        description: 'Type "yes" to confirm destruction'
        required: true
        type: string
```
to:
```yaml
      confirm:
        description: 'Confirm destruction'
        required: true
        type: choice
        options:
          - 'no'
          - 'yes'
```
The consuming step already does `if [ "${{ github.event.inputs.confirm }}" != "yes" ]; then exit 1; fi` — no change needed there, since `"yes"` is still a valid option value; the fix is constraining the input to a fixed enum instead of accepting arbitrary text.

- [ ] **Step 3: Verify**

Run: `actionlint .github/workflows/deploy-ingress-nginx.yml .github/workflows/destroy-ingress-nginx.yml`
Expected: no new findings.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/deploy-ingress-nginx.yml .github/workflows/destroy-ingress-nginx.yml
git commit -m "fix: pin kubectl version and constrain destroy confirmation to a fixed choice"
```

### Task 3.5: Fix the `Makefile`

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Fix `.PHONY` and add `fmt`/`lint`/`validate` targets**

Replace:
```makefile
.PHONY: help deploy-all destroy-all
```
with:
```makefile
.PHONY: help deploy-all destroy-all iam-apply network-apply k8s-apply fmt lint validate
```

Append at the end of the file:
```makefile

fmt:
	terraform fmt -recursive terraform/

lint:
	@for m in 00-iam 01-networking 02-kubernetes 02-kubernetes/modules/aks-cluster; do \
		echo "=== $$m ==="; \
		(cd terraform/$$m && tflint --init --config="$$(git rev-parse --show-toplevel)/.tflint.hcl" 2>/dev/null; tflint --config="$$(git rev-parse --show-toplevel)/.tflint.hcl") || exit 1; \
	done

validate:
	@for m in 00-iam 01-networking 02-kubernetes 02-kubernetes/modules/aks-cluster; do \
		echo "=== $$m ==="; \
		(cd terraform/$$m && terraform init -backend=false -input=false >/dev/null && terraform validate) || exit 1; \
	done
```
Update the `help` target's echoed usage text to mention the three new targets:
```makefile
help:
	@echo 'Usage: make [target]'
	@echo 'Targets:'
	@echo '  deploy-all    - Deploy all modules'
	@echo '  destroy-all   - Destroy all modules'
	@echo '  iam-apply     - Deploy IAM module'
	@echo '  network-apply - Deploy Network module'
	@echo '  k8s-apply     - Deploy Kubernetes module'
	@echo '  fmt           - Format all Terraform files'
	@echo '  lint          - Run tflint on every module'
	@echo '  validate      - Run terraform validate on every module'
```

- [ ] **Step 2: Verify**

Run: `make fmt && make lint && make validate`
Expected: all three succeed with no errors (assumes PR 1 and Task 3.1 already merged, so there's nothing left for `fmt`/`lint`/`validate` to catch).

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "fix: complete .PHONY list and add fmt/lint/validate Makefile targets"
```

### Task 3.6: Open PR, wait for checks, merge

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin chore/ci-hardening
gh pr create --repo Vitorspk/azure-landing-zone \
  --title "ci: tflint + checkov, concurrency groups, pinned kubectl, Makefile targets" \
  --body "Adds tflint (blocking) and checkov (report-only) to terraform-validate.yml; adds concurrency groups to all three operational workflows so deploys/destroys targeting the same cluster can't race; pins kubectl to v1.36.3 in both ingress workflows (was 'latest'); constrains destroy-ingress-nginx.yml's confirm input to a fixed choice instead of free text; fixes Makefile .PHONY and adds fmt/lint/validate targets. Part of the post-incident hardening pass."
```

- [ ] **Step 2: Wait for checks (including the new tflint/checkov steps actually running), then squash-merge**

```bash
gh pr merge --repo Vitorspk/azure-landing-zone --squash --delete-branch <PR-number>
```

---

## PR 4 — Documentation freshness

**Branch:** `docs/refresh-stale-references`

**Precondition:** PR 3 must already be merged (this PR's CI-description fix references what PR 3 adds).

### Task 4.1: Fix stale Kubernetes version references

**Files:**
- Modify: `docs/ARCHITECTURE.md` (every `1.30`/`1.31` cluster-version reference)
- Modify: `docs/INGRESS-NGINX-DEPLOYMENT.md` (footer: "Testado em: AKS 1.31")
- Modify: `manifests/README.md` (footer: "Testado em: AKS 1.31")

- [ ] **Step 1: Find every occurrence**

Run: `grep -rn "1\.30\|1\.31\|v1\.31" docs/ARCHITECTURE.md docs/INGRESS-NGINX-DEPLOYMENT.md manifests/README.md`

- [ ] **Step 2: Update each occurrence to 1.36**

For every line found in Step 1, replace the version reference (`1.30`, `1.31`, or `v1.31`) with `1.36` (or `v1.36`, matching the original's format), keeping surrounding text unchanged. In `docs/ARCHITECTURE.md`'s AKS cluster table specifically, update the `Kubernetes Version` column for all four clusters (dev/stg/prd/sdx) to `1.36`.

- [ ] **Step 3: Verify**

Run: `grep -rn "1\.30\|1\.31\|v1\.31" docs/ARCHITECTURE.md docs/INGRESS-NGINX-DEPLOYMENT.md manifests/README.md`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add docs/ARCHITECTURE.md docs/INGRESS-NGINX-DEPLOYMENT.md manifests/README.md
git commit -m "docs: update stale Kubernetes 1.31 references to 1.36"
```

### Task 4.2: Fix backend state-key example in `DEPLOYMENT.md`

**Files:**
- Modify: `docs/DEPLOYMENT.md` (the remote-backend example around line 757)

- [ ] **Step 1: Find the mismatched example**

Run: `grep -n "iam.tfstate\|networking.tfstate\|kubernetes.tfstate" docs/DEPLOYMENT.md`

- [ ] **Step 2: Correct it to match the real `backend.tf` keys**

Replace any `key = "iam.tfstate"` / `key = "networking.tfstate"` / `key = "kubernetes.tfstate"`-style example with the actual keys used in each module's `backend.tf`:
- `terraform/00-iam/backend.tf` → `key = "azure-landing-zone/iam/terraform.tfstate"`
- `terraform/01-networking/backend.tf` → `key = "azure-landing-zone/networking/terraform.tfstate"`
- `terraform/02-kubernetes/backend.tf` → `key = "azure-landing-zone/kubernetes/terraform.tfstate"`

- [ ] **Step 3: Verify**

Run: `grep -n "azure-landing-zone/iam/terraform.tfstate\|azure-landing-zone/networking/terraform.tfstate\|azure-landing-zone/kubernetes/terraform.tfstate" docs/DEPLOYMENT.md`
Expected: at least one match per key (confirms the fix landed), and the earlier `grep` from Step 1 (re-run) now returns nothing.

- [ ] **Step 4: Commit**

```bash
git add docs/DEPLOYMENT.md
git commit -m "docs: fix backend state-key example to match actual backend.tf values"
```

### Task 4.3: Correct the CI security-scanning claim

**Files:**
- Modify: `docs/ARCHITECTURE.md` (line ~203, the `terraform-validate.yml` description)

- [ ] **Step 1: Find the claim**

Run: `grep -n "security scanning\|Performs security" docs/ARCHITECTURE.md`

- [ ] **Step 2: Make it accurate**

Update the sentence describing `terraform-validate.yml` to reflect what it actually does after PR 3: runs `terraform fmt -check`, `terraform validate`, and `tflint` (blocking) on every push/PR touching `terraform/**`, plus a report-only `checkov` security scan in a separate job.

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: describe terraform-validate.yml's actual CI checks accurately"
```

### Task 4.4: Open PR, wait for checks, merge

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin docs/refresh-stale-references
gh pr create --repo Vitorspk/azure-landing-zone \
  --title "docs: refresh stale Kubernetes version and CI references" \
  --body "Updates AKS version references (1.31 -> 1.36) across ARCHITECTURE.md, INGRESS-NGINX-DEPLOYMENT.md, and manifests/README.md; fixes the backend state-key example in DEPLOYMENT.md to match the real backend.tf values; corrects ARCHITECTURE.md's description of what terraform-validate.yml actually checks now that PR #<PR3-number> added tflint/checkov. Final PR of the post-incident hardening pass."
```

- [ ] **Step 2: Wait for checks, then squash-merge**

```bash
gh pr merge --repo Vitorspk/azure-landing-zone --squash --delete-branch <PR-number>
```

---

## Final verification (after all four PRs merged)

- [ ] Run `make fmt && make lint && make validate` from repo root on a fresh `git pull` of `master` — all three succeed.
- [ ] Trigger `deploy-infrastructure` (`module=all`, `action=apply`) via `gh workflow run` and confirm it completes successfully end-to-end (validates PR 1's and PR 2's changes against a real, freshly-created `aks-dev`/`aks-stg`/`aks-prd`/`aks-sdx` — or whichever subset the user chooses via `clusters=`).
- [ ] Open a throwaway PR touching a `terraform/*.tf` file and confirm `TFLint` (blocking, must pass) and `Checkov Security Scan` (report-only, shows findings but doesn't block) both actually run and report in the PR checks list.
