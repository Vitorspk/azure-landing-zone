# Terraform Best-Practices Hardening — Design

**Date:** 2026-08-09
**Status:** Approved, ready for implementation planning

## Context

Earlier the same day, a stuck `deploy-infrastructure` CI run was root-caused (missing default for `aks_clusters`, an orphaned Terraform state lock, and a stale `kubernetes_version`) and fixed via three merged PRs (#17, #18, #19). That work brought the `02-kubernetes` module to a working state and created a real `aks-dev` cluster + ingress-nginx in the `brazilsouth` subscription.

A full repository survey (Explore agent) then covered every Terraform module, the CI workflows, docs, Makefile, and scripts. This spec captures the follow-up hardening pass requested by the user: "atualize todo o projeto e deixe ele muito melhor do que está hoje até em código terraform usando as melhores práticas."

## Goals

Bring the repo's Terraform code, CI, and docs in line with common Terraform/Azure best practices, fixing concretely identified issues from the survey — without expanding scope into new infrastructure capabilities.

## Non-goals (explicitly deferred, by user decision)

- **Log Analytics Workspace / diagnostic settings** — would make `enable_oms_agent` actually do something, but adds real recurring Azure cost. Deferred.
- **Real `azurerm_policy_definition`/`azurerm_policy_assignment` resources** — would make `enable_azure_policy` do more than toggle the empty AKS add-on. Deferred.
- **Bigger architectural rework** — e.g. switching cross-module coupling from data-source lookups to `terraform_remote_state`/output passing, splitting `backend.tf` into a dedicated `versions.tf`, or moving to a Terraform Registry module structure. These are taste/architecture decisions, not correctness fixes; out of scope for this pass.
- **`api_server_authorized_ip_ranges = ["0.0.0.0/0"]` on dev/stg/sdx** — already reviewed and consciously kept as-is earlier today (mirrors the public `terraform.tfvars.example`, non-prod only).

## Risk tolerance (confirmed with user)

- Changes may run a real `terraform apply` against the live `rg-network` / `aks-dev` in the `brazilsouth` subscription. Verification isn't limited to `terraform plan`.
- Neither the ingress-nginx layer nor any in-cluster workload needs to be running for this work — PRs 1–2 only need the `aks-dev` cluster resource itself to exist (for apply verification); PRs 3–4 don't touch cloud state at all.

## Scope: four themed PRs, in order

Ordered to minimize risk: code correctness (no functional infra change beyond one tag) → network security (real but low-risk infra change) → CI (no infra) → docs (describes the end state, so it must come last).

Each PR follows the same flow already used today: feature branch → commit → push → PR → CI green → squash-merge → delete branch.

### PR 1 — Terraform correctness & consistency

| Change | File(s) | Notes |
|---|---|---|
| Add `validation` block to `deploy_clusters` | `terraform/02-kubernetes/variables.tf` | Must be `"all"` or a comma-separated subset of `dev,stg,prd,sdx`. Today a typo silently deploys nothing via the `contains()` filter, with no error. |
| Add `validation` block to `vnet_address_space` | `terraform/01-networking/variables.tf` | Must be a valid CIDR (`can(cidrhost(var.vnet_address_space, 0))`). |
| Add `validation` blocks to `network_plugin`/`network_policy` | `terraform/02-kubernetes/modules/aks-cluster/variables.tf` | Constrain to Azure's actual accepted values (`azure`/`kubenet` for plugin; `azure`/`calico`/`""` for policy). |
| Remove unused `project_name` variable | `terraform/00-iam/variables.tf` | Declared, never referenced anywhere in the module. |
| Fix `terraform.tfvars.example` CIDR drift | `terraform/01-networking/terraform.tfvars.example` | Currently `172.31.0.0/16`, diverges from the `variables.tf` default, `ARCHITECTURE.md`, and the CIDRs actually in use (`192.168.0.0/16`). Align to `192.168.0.0/16`. |
| Add `Environment` to `tags` default | `terraform/02-kubernetes/variables.tf` | `00-iam`/`01-networking` tag defaults already include `Environment = "shared"`; `02-kubernetes` omits it. Bring it in line. **This is the one real infra touch in this PR** — next `apply` adds a tag to existing resources. |
| Fix SP secret plan-diff bug | `terraform/00-iam/service-principals.tf` | `end_date = timeadd(timestamp(), "8760h")` recomputes every plan, causing permanent drift. Add `lifecycle { ignore_changes = [end_date] }` on `azuread_service_principal_password.terraform`. Low priority in practice — this resource only exists when `create_service_principal = true`, which defaults to `false` and isn't exercised by the current deployment (managed identities are used instead), but it's a real bug worth a one-line fix. |

**Verification:** `terraform fmt -check`, `terraform validate` for all three modules; `terraform plan` for `00-iam`/`01-networking`/`02-kubernetes` against the real backend; `terraform apply` for the tag change against `rg-network`/`aks-dev`, then confirm via `az resource show`/`az aks show` that the tag landed and nothing else diffed unexpectedly.

### PR 2 — Network security

| Change | File(s) | Notes |
|---|---|---|
| Remove the `AllowSSH` security rule (port 22, `0.0.0.0/0`) | `terraform/01-networking/main.tf` (`azurerm_network_security_group.allow_ssh`) | No legitimate use case identified in this AKS-based architecture (node access should go through `az aks command invoke` / `kubectl debug`, not direct SSH). `AllowHTTP`/`AllowHTTPS` (80/443, also `0.0.0.0/0`) are untouched — that's the intended public-ingress path. |

**Verification:** `terraform plan`/`apply` against `01-networking`'s real state; confirm via `az network nsg rule list` that only the HTTP/HTTPS rules remain; confirm the `aks-dev` ingress (external LoadBalancer on 80/443) is still reachable/unaffected (the NSG change only removes port 22, not 80/443).

### PR 3 — CI/CD hardening

| Change | File(s) | Notes |
|---|---|---|
| Add `tflint` step (blocking) | `.github/workflows/terraform-validate.yml`, new `.tflint.hcl` | Azure ruleset plugin; catches naming/unused-declaration/structural issues. |
| Add `checkov` step (report-only, `continue-on-error: true`) | `.github/workflows/terraform-validate.yml` | Surfaces security-posture findings as CI annotations without blocking merges. Add inline `#checkov:skip=<ID>:<reason>` comments for the specific risks already knowingly accepted (open `api_server_authorized_ip_ranges` on dev/stg/sdx), so the suppression is visible and justified in the code itself, not silent. |
| Add `concurrency:` groups | `deploy-infrastructure.yml`, `deploy-ingress-nginx.yml`, `destroy-ingress-nginx.yml` | Nothing today stops two simultaneous runs (or a deploy racing a destroy) from colliding against the same cluster/state. Group key scoped per-workflow (e.g. by module+cluster inputs) so unrelated deploys aren't serialized unnecessarily. |
| Pin `kubectl` version | `deploy-ingress-nginx.yml`, `destroy-ingress-nginx.yml` (if it also sets up kubectl) | Currently `azure/setup-kubectl@v4` with `version: 'latest'` — non-deterministic across runs. |
| Constrain `destroy-ingress-nginx.yml`'s `confirm` input | `destroy-ingress-nginx.yml` | Currently a free-form `type: string` interpolated via `${{ }}` directly into a `run:` shell block — the canonical GH Actions script-injection shape. Change to a fixed `type: choice` (e.g. `yes`/`no`), matching how every other input in both ingress workflows is already handled. |
| Fix `Makefile` | `Makefile` | `.PHONY` is missing `iam-apply`/`network-apply`/`k8s-apply`. Add `fmt`, `lint` (wraps `tflint`), and `validate` targets (today `terraform fmt` only exists as a separate, Makefile-independent script). |

**Verification:** open a PR touching a `terraform/**` file to confirm `tflint`/`checkov` actually run and report; confirm existing `terraform-validate.yml` matrix still passes; no live infra involved.

### PR 4 — Documentation freshness

| Change | File(s) | Notes |
|---|---|---|
| Fix stale Kubernetes version references (1.31/1.30 → 1.36) | `docs/ARCHITECTURE.md`, `docs/INGRESS-NGINX-DEPLOYMENT.md`, `manifests/README.md` | These still describe the pre-incident version; code has been at 1.36 since PR #19. |
| Fix backend state-key example | `docs/DEPLOYMENT.md` | Documents `iam.tfstate`/`networking.tfstate`/`kubernetes.tfstate`; actual `backend.tf` keys are `azure-landing-zone/iam/terraform.tfstate` etc. |
| Correct CI description | `docs/ARCHITECTURE.md` | Currently claims `terraform-validate.yml` "performs security scanning" — only becomes true once PR 3 lands, so this PR must merge after PR 3. |

**Verification:** no infra; just accuracy — diff each claim against the actual current file it describes.

## Ordering dependency

PR 4 depends on PR 3 having merged first (the CI-description fix references what PR 3 adds). PRs 1–3 are independent of each other and could technically merge in any order, but the stated order (correctness → security → CI → docs) keeps each PR's blast radius increasing only when necessary and keeps docs accurate at every intermediate step except the CI claim, which is called out.

## Rollback

Each PR is a small, independently revertible `git revert` if something regresses. PR 1 and PR 2's infra-touching applies are both easily reversible in Terraform (re-adding a removed NSG rule or tag is a one-line change and another apply).
