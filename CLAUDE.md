# CLAUDE.md — Azure Landing Zone

Instructions for AI assistants (Claude Code, @claude in PRs, etc.) working on this repository.

---

## Project overview

Terraform Infrastructure-as-Code for an Azure landing zone (Vitorspk/azure-landing-zone), deployed via GitHub Actions.

- Three ordered Terraform modules: `terraform/00-iam` (Managed Identities, RBAC) → `terraform/01-networking` (VNet, subnets, NSG, NAT Gateway) → `terraform/02-kubernetes` (4 AKS clusters: dev/stg/prd/sdx, selectable via `deploy_clusters`)
- Remote state: Azure Storage (`vschiavotfstate` / `rg-terraform-state`), one blob per module — see each module's `backend.tf`
- Ingress (NGINX) is deployed separately from Terraform, via `deploy-ingress-nginx.yml` + `kubectl` against the manifests in `manifests/`
- `terraform/02-kubernetes/modules/aks-cluster` is the only local module; everything else is root-level resources

---

## Rules

### Git workflow (mandatory)

- **Never commit directly to `master`**
- Always branch: `git checkout -b <type>/<description>` from `master` (types: `fix/`, `feat/`, `chore/`, `docs/`)
- Push branch, open PR with `gh pr create`, wait for CI green, squash-merge
- PRs run `terraform-validate.yml` (fmt/validate/tflint, blocking + checkov, report-only) plus automated Claude Code Review — fix everything the review flags before merging

### Security (non-negotiable)

- **Never commit `.tfvars` or `.tfstate` files** — this repo's history already had a real incident (see `docs/SECURITY.md`, commit `5ccfcee`). Only `terraform.tfvars.example` files are tracked.
- Azure credentials come from environment variables (`ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `AZURE_CLIENT_ID`/`AZURE_CLIENT_SECRET` as GitHub Secrets) — never hardcoded.
- Treat any diff touching `.tfvars`/`.tfstate`/`.terraform/` as a stop-and-check moment before staging.

### Terraform variables

- **Every variable must have either a `default` or a value supplied by CI** (`-var`, `-var-file`, or `TF_VAR_*`). A required variable with no value source doesn't fail fast in GitHub Actions — Terraform blocks on an interactive prompt that never resolves on a non-interactive runner, hanging for hours while holding the state lock. This exact bug (missing default on `aks_clusters`) caused a multi-hour incident on 2026-08-09; see PR #18.
- Prefer `validation` blocks on variables with a constrained value set (see `deploy_clusters`, `network_plugin`/`network_policy` for the pattern) over hoping the value is right.

### CI/workflow conventions

- Every `workflow_dispatch` operational workflow (`deploy-infrastructure.yml`, `deploy-ingress-nginx.yml`, `destroy-ingress-nginx.yml`) must have a `concurrency:` group that actually prevents two invocations from racing the same state/cluster — use a **constant** group name, not one interpolated from an input, unless every possible input value is guaranteed disjoint. An interpolated key silently fails to serialize `module=all` against `module=02-kubernetes` (or `clusters=all` against `clusters=dev`), which is the same class of bug as the incident above.
- `terraform apply`/`plan` output in a `run:` step must stream live (e.g. via `tee`), never be captured into a shell variable and echoed only at the end (`OUTPUT=$(terraform apply ...); echo "$OUTPUT"`) — buffering hides all progress until the command finishes or hangs, making a stuck run indistinguishable from a slow one.
- `#checkov:skip=<ID>:<reason>` comments only take effect as the **first line inside** the resource block (right after the opening `{`) — placed above the `resource` line, checkov silently ignores it and still reports the finding as failed.

### State lock recovery

If a `deploy-infrastructure` run is cancelled or killed mid-apply, the Azure Storage blob lease is **not** released (it's an infinite-duration lease, only freed by graceful completion). The next run will fail fast with `Error acquiring the state lock: state blob is already locked`. Fix:
```bash
az storage blob lease break --account-name vschiavotfstate --container-name tfstate --blob-name "azure-landing-zone/<module>/terraform.tfstate" --auth-mode key
```
Do this before retrying — waiting does not help (the lease doesn't expire on its own).

---

## Recommended models (Claude Code)

Model selection is **manual** — pick it when launching (`claude --model <alias>`) or switch mid-session with `/model <alias>`. Claude Code does not auto-switch per task; this table is the project convention:

| Task | Model | Command |
|------|-------|---------|
| Day-to-day work (reviewing plans, small fixes, deploys) | Sonnet | `claude --model sonnet` — **project default** |
| Local iteration / fast feedback | Haiku | `claude --model haiku` |
| Incident diagnosis, security-sensitive changes (NSG/IAM/policy), complex debugging | Opus | `claude --model opus` |
| Architecture design (plan + execute) | opusplan | `claude --model opusplan` — Opus in plan mode, Sonnet on execution |

Three tiers: **local iteration (Haiku)** → **day-to-day (Sonnet)** → **critical decisions (Opus)**.

The day-to-day default (Sonnet) is pinned in `.claude/settings.json` (`"model": "sonnet"`), so it applies automatically when opening Claude Code in this repo. Note: `.claude/` is git-ignored, so this default is local to each contributor's machine.

This tiering is for the **main conversation model** only. When orchestrating subagents (`superpowers:subagent-driven-development`, the `Workflow` tool, or ad-hoc background agents), assign models per task explicitly regardless of the session default — e.g. cheap/mechanical Terraform edits on Haiku, judgment-heavy task review on Sonnet, and the final whole-branch review on Opus. That routing already works today with no extra setup; it was used for the full 2026-08-09 hardening pass (PRs #22-#26).

---

## Local validation

```bash
make fmt        # terraform fmt -recursive across all modules
make lint       # tflint on all 4 modules (00-iam, 01-networking, 02-kubernetes, aks-cluster submodule)
make validate   # terraform validate on all 4 modules
```

Matches the `terraform-validate.yml` CI gate (fmt + validate + tflint, blocking) minus the `checkov` job (report-only, CI-only).

---

## CI workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `terraform-validate.yml` | push/PR touching `terraform/**` | Blocking: `terraform fmt -check`, `terraform validate`, `tflint` per module. Separate job, report-only: `checkov` security scan. |
| `deploy-infrastructure.yml` | `workflow_dispatch` | `plan`/`apply`/`destroy` per module (`00-iam`/`01-networking`/`02-kubernetes`/`all`), selectable clusters. `destroy` requires typing `DESTROY`. Concurrency-protected (constant group). |
| `deploy-ingress-nginx.yml` / `destroy-ingress-nginx.yml` | `workflow_dispatch` | `kubectl`-based ingress-nginx install/removal against selected clusters, external/internal/both. Concurrency-protected (constant `ingress` group, shared between both workflows so a deploy and a destroy queue behind each other). |
| `claude-code-review.yml` | PR | AI code review, posts feedback as PR comment |
| `claude.yml` | `@claude` mention | On-demand Claude Code in issues/PRs |

---

## What to avoid

- Do not add Log Analytics Workspace / diagnostic settings or real `azurerm_policy_*` resources without discussing cost first — both were explicitly deferred in the 2026-08-09 hardening pass to avoid new recurring Azure spend.
- Do not restructure a root module's `backend.tf` into a separate `versions.tf` — stylistic churn with no functional benefit; the child module `modules/aks-cluster` is the one exception (it had zero version constraints and needed a `versions.tf` added).
- Do not add a required Terraform variable without a `default` unless the CI workflow that calls that module is also updated to supply it via `-var`/`-var-file`/`TF_VAR_*` — see "Terraform variables" above.
- Do not assume the design/planning docs under `docs/superpowers/specs/` are current — they're point-in-time; verify against actual code before relying on a claim from one of them (one was found to have a factual error about `docs/INGRESS-NGINX-DEPLOYMENT.md` during the 2026-08-09 hardening pass).
