#!/usr/bin/env bash
#
# One-time bootstrap helper.
#
# Creates the Terraform state account and the keyless GitHub Actions identity,
# then prints the `gh variable set` commands you need to run.
#
# Usage:
#   az login
#   ./scripts/bootstrap.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v terraform >/dev/null || die "terraform is not installed (https://developer.hashicorp.com/terraform/install)"
command -v az        >/dev/null || die "the Azure CLI is not installed (https://learn.microsoft.com/cli/azure/install-azure-cli)"

info "Checking Azure CLI session"
az account show --only-show-errors >/dev/null 2>&1 || die "not signed in - run 'az login' first"
echo "    subscription: $(az account show --query name -o tsv)"
echo "    tenant:       $(az account show --query tenantId -o tsv)"

if [[ ! -f bootstrap/terraform.tfvars ]]; then
  info "Creating bootstrap/terraform.tfvars from the example"
  cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
  die "edit bootstrap/terraform.tfvars (github_owner, github_repo), then re-run this script"
fi

info "Initialising bootstrap stack"
terraform -chdir=bootstrap init -input=false

info "Applying bootstrap stack (remote state + OIDC identity + RBAC)"
terraform -chdir=bootstrap apply -input=false

echo
info "Done. Configure the repository with:"
echo
terraform -chdir=bootstrap output -raw github_variable_commands
echo
if command -v gh >/dev/null 2>&1; then
  echo "Tip: pipe the block above into bash, or set the variables by hand in"
  echo "     Settings -> Secrets and variables -> Actions -> Variables."
else
  echo "Install the GitHub CLI (gh) to set these from the terminal."
fi
