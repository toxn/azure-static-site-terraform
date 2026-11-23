# Azure Static Site · Terraform + GitHub Actions (keyless)

A static site on **Azure Static Web Apps**, provisioned with **Terraform** and shipped by a
**GitHub Actions** pipeline that authenticates with **OIDC** — no client secrets, no stored
keys, no long-lived credentials anywhere.

The whole thing runs on the Azure **Free** tier: **$0/month**.

```
push ──► validate ──► plan ──► apply (saved plan) ──► deploy site ──► https://<app>.azurestaticapps.net
```

---

## What this demonstrates

- **Infrastructure as Code** with a reusable module, variables, validation rules and outputs.
- **Remote state** in Azure Storage with native blob-lease locking and versioning.
- **Keyless CI/CD** using GitHub OIDC → Microsoft Entra ID federated credentials.
- **Least-privilege RBAC**: `Contributor` on one resource group, `Storage Account Contributor` on one storage account.
- **Plan review on pull requests**, applied exactly as reviewed (`plan -out` → `apply tfplan`).
- **Pipeline hygiene**: concurrency groups, protected `production` environment, pinned provider lock file, Dependabot.

---

## Cost

| Resource                              | Tier                  | Monthly cost |
| ------------------------------------- | --------------------- | ------------ |
| Azure Static Web Apps                 | Free                  | **$0**       |
| Storage account (Terraform state)     | Standard LRS, a few KB| ~$0.00       |
| Egress / bandwidth (100 GB included)  | Free                  | **$0**       |
| Entra ID app registration + OIDC      | Free                  | **$0**       |

No App Service plan, no CDN profile, no Front Door. If you have an Azure subscription you
already have everything you need.

> Static Web Apps Free includes SSL, a global CDN, custom domains and per-PR preview
> environments. The `Standard` tier only matters for an SLA, private endpoints and built-in auth.

---

## Repository layout

```
.
├── bootstrap/                 # run once: state account, Entra app, federated creds, RBAC
│   ├── main.tf
│   ├── outputs.tf             # prints the `gh variable set` commands for you
│   ├── variables.tf
│   └── terraform.tfvars.example
├── infra/                     # the deployable stack (remote state)
│   ├── main.tf
│   ├── providers.tf           # backend "azurerm" {} configured at runtime
│   ├── variables.tf
│   ├── outputs.tf
│   ├── tests/infra.tftest.hcl # offline tests with mocked providers
│   └── modules/static_web_app/
├── site/                      # the actual website
│   ├── index.html
│   ├── styles.css
│   ├── app.js
│   └── staticwebapp.config.json   # security headers, routing fallback
├── .github/workflows/pipeline.yml # validate → plan → apply → deploy
├── docs/architecture.md       # diagram + design decisions
├── scripts/bootstrap.sh       # friendly wrapper around bootstrap/
└── Makefile                   # local DX: make plan, make site-url, ...
```

---

## Quickstart

### 0. Prerequisites

- An Azure subscription (the free one is fine)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.9 and the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [GitHub CLI](https://cli.github.com/) (`gh auth login`)
- Permission to create resource groups and app registrations in your tenant

> No Terraform locally? Run the bootstrap step in **Azure Cloud Shell** — it ships with
> both `terraform` and `az`.

### 1. Create an empty GitHub repository

Create `azure-static-site-terraform` on GitHub with **no** README or license, then:

```bash
git init -b main
git add -A
git commit -m "feat: terraform + github actions pipeline for azure static web apps"
git remote add origin git@github.com:<you>/azure-static-site-terraform.git
```

Don't push yet — the pipeline needs its variables first, and a failed first run looks bad
on a fresh repo.

### 2. Bootstrap the backend and the OIDC identity

```bash
az login
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
$EDITOR bootstrap/terraform.tfvars     # set github_owner and github_repo
./scripts/bootstrap.sh
```

This creates:

- `rg-<project>-tfstate` + a versioned storage account + the `tfstate` container
- `rg-<project>` — the resource group the app lives in
- an Entra ID app registration + service principal, with **three** federated credentials:
  `refs/heads/main`, `pull_request`, and `environment:production`
- two scoped role assignments (no secrets, no certificates)

### 3. Wire the repository variables

The bootstrap prints ready-made commands. Run them:

```bash
terraform -chdir=bootstrap output -raw github_variable_commands | bash
```

They set six **repository variables** (identifiers, not credentials):

| Variable                   | Example                    |
| -------------------------- | -------------------------- |
| `AZURE_CLIENT_ID`          | app registration client ID |
| `AZURE_TENANT_ID`          | Entra tenant ID            |
| `AZURE_SUBSCRIPTION_ID`    | subscription ID            |
| `TF_STATE_RESOURCE_GROUP`  | `rg-demo-tfstate`          |
| `TF_STATE_STORAGE_ACCOUNT` | `stdemostatea1b2c3`        |
| `TF_STATE_CONTAINER`       | `tfstate`                  |

### 4. Optional: protect the environment

Settings → **Environments** → `production` → add yourself as a **required reviewer**.
The apply job will then wait for approval; deploys still run automatically afterwards.

### 5. Ship it

```bash
git push -u origin main
```

Watch the **pipeline** workflow: `validate → plan → apply → deploy`. When it finishes, the
job summary links to your live site.

```bash
curl -s https://<your-app>.azurestaticapps.net/healthz   # -> ok
```

---

## How the pipeline works

| Job        | Trigger          | What it does                                                                    |
| ---------- | ---------------- | ------------------------------------------------------------------------------- |
| `validate` | every push / PR  | `terraform fmt -check -recursive`, `validate` on both stacks. No cloud access.   |
| `plan`     | every push / PR  | OIDC login, `plan -out=tfplan`, uploads the artifact, comments the diff on PRs.  |
| `apply`    | push to `main`   | OIDC login, downloads **that** plan, `apply tfplan` behind `production`.          |
| `deploy`   | push to `main`   | Fetches the deployment token with `az staticwebapp secrets list`, uploads `site/`.|

A pull request gets a sticky comment with the full plan, updated on every push.
Fork PRs are deliberately skipped, because a `pull_request` OIDC subject cannot
distinguish a fork from a trusted branch.

---

## Security notes

- **No secrets in GitHub.** Only non-sensitive identifiers are stored, as repository *variables*.
- **OIDC subject matching** is the trust boundary: `repo:<owner>/<repo>:ref:refs/heads/main`,
  `…:pull_request`, `…:environment:production`. Anything else is rejected by Entra.
- **Scoped RBAC.** The identity cannot touch other resource groups or storage accounts.
- **Deployment token is fetched at runtime** and masked in logs, rather than pasted into a secret
  that nobody rotates.
- **State is encrypted at rest**, versioned, with 7-day soft delete on blobs and containers.

---

## Run it without Azure

You do not need a subscription to exercise most of this repository.

| Command       | What it proves                                                    | Azure needed? |
| ------------- | ----------------------------------------------------------------- | ------------- |
| `make check`  | formatting, provider schema, variable validation, offline tests     | no            |
| `make test`   | the whole graph plans, and naming/outputs/validation are correct   | no            |
| `make serve`  | the site renders at <http://localhost:8080>                        | no            |
| `make init`   | the backend exists and state locking works                         | yes           |
| `make plan`   | what would change in your subscription                             | yes           |
| `make apply`  | the change actually happens                                        | yes           |

`infra/tests/infra.tftest.hcl` uses Terraform's `mock_provider`, so the Azure
provider is replaced with one that returns generated values. The entire module
graph is planned in about a second, and assertions check the naming scheme, the
outputs and the input validation — no credentials, no network calls to Azure.
CI runs the same file on every push.

---

## Local development

```bash
make help          # list targets
make check         # fmt + validate + offline tests (no Azure)
make serve         # preview the site at http://localhost:8080
make bootstrap     # one-time setup (same as scripts/bootstrap.sh)
make init          # init against the remote backend (reads bootstrap outputs)
make plan          # plan
make apply         # apply the saved plan
make site-url      # print the live URL
make destroy       # destroy the app stack (state + bootstrap resources survive)
```

`make serve` is just `python3 -m http.server --directory site 8080` — the site is
plain HTML/CSS/JS with no build step, so what you see locally is what deploys.

---

## Custom domain

```hcl
# infra/terraform.tfvars
custom_domain                = "www.example.com"
custom_domain_validation_type = "cname-delegation"   # subdomain
# custom_domain_validation_type = "dns-txt-token"    # apex, e.g. example.com
```

Apply, then create the DNS records Terraform/Azure ask for (a `CNAME` to
`<app>.azurestaticapps.net`, plus the validation `TXT`/`CNAME`). Azure issues the
certificate automatically — still $0 on the Free tier.

---

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `AADSTS70021: No matching federated identity record found` | Subject mismatch. Check the repo **owner/name**, the branch (`main`), and whether the job uses `environment: production`. |
| `AuthorizationFailed` on the storage account during `init` | Role assignment is still propagating — wait ~5 minutes and re-run. |
| `Error building account: could not acquire access token` | `ARM_USE_OIDC=true` or `id-token: write` is missing. |
| `Backend initialization required` locally | Run `make init` (the backend is intentionally unconfigured in code). |
| `Resource group 'rg-…' was not found` | Run `./scripts/bootstrap.sh` first. |
| Deploy fails fetching the token | The `staticwebapp` az extension was not installed — the workflow installs it, check that step's logs. |
| `terraform fmt` fails in CI | Run `make fmt` and commit. |

---

## Interview talking points

- **Why OIDC instead of a service principal secret?** Nothing to leak or rotate; tokens live
  for minutes and are bound to a repository, branch and environment.
- **Why apply a saved plan?** The reviewed diff is the applied diff — it closes the gap
  between "what the PR showed" and "what ran".
- **Why is the backend block empty?** Configuration is injected per environment, so the same
  module serves staging and prod with no code changes and no committed account names.
- **How is blast radius limited?** Two narrow role assignments instead of subscription
  `Contributor`, and a resource group the pipeline cannot delete.
- **What breaks first at scale?** State contention — solved here by native blob leasing and a
  `concurrency` group that never cancels a running apply.
- **What would you add?** `tflint` + `trivy` as required checks, a staging stack from a
  `develop` branch, Static Web Apps preview environments per PR, and `terraform test`.

More detail in [`docs/architecture.md`](docs/architecture.md).

---

## Before you publish

- [ ] Add a screenshot of a green pipeline run to `docs/` and embed it at the top of this README.
- [ ] Put the live URL in the repository description (and on your résumé).
- [ ] Keep Dependabot PRs merged so the pinned provider stays current.
