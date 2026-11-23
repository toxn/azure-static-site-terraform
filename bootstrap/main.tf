# ---------------------------------------------------------------------------
# One-time bootstrap: remote state + keyless (OIDC) identity for GitHub Actions
#
# This root module is intentionally kept OUT of the main pipeline and uses
# local state, because it creates the very backend the main pipeline uses.
# Run it once from an account that can create resource groups and app
# registrations (Owner / User Access Administrator + Application Developer).
# ---------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  app_resource_group_name    = coalesce(var.app_resource_group_name, "rg-${var.project}")
  state_resource_group_name  = coalesce(var.state_resource_group_name, "rg-${var.project}-tfstate")
  state_storage_account_name = coalesce(var.state_storage_account_name, "st${var.project}state${random_string.suffix.result}")
  state_container_name       = "tfstate"
  github_repository          = "${var.github_owner}/${var.github_repo}"

  tags = {
    project    = var.project
    managed_by = "terraform-bootstrap"
  }
}

# ---------------------------------------------------------------------------
# Remote state
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "state" {
  name     = local.state_resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                            = local.state_storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  blob_properties {
    versioning_enabled = true

    # Cheap insurance: state files are the one thing you cannot rebuild.
    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = local.state_container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Application resource group (owned by bootstrap so RBAC can be scoped to it)
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "app" {
  name     = local.app_resource_group_name
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# GitHub Actions identity: Entra app registration + federated credentials
#
# No client secret is ever created. GitHub mints a short-lived OIDC token,
# Entra validates the issuer/subject pair below and exchanges it for an
# access token. That is the whole point of this project.
# ---------------------------------------------------------------------------

resource "azuread_application" "ci" {
  display_name = "gh-${var.project}-terraform"
  owners       = [data.azurerm_client_config.current.object_id]
  tags         = ["terraform", "github-actions", "oidc"]
}

resource "azuread_service_principal" "ci" {
  client_id = azuread_application.ci.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

locals {
  # Each subject maps to a different way the workflow can be triggered.
  federated_credentials = merge(
    {
      branch-main = "repo:${local.github_repository}:ref:refs/heads/main"
    },
    var.create_pull_request_credential ? {
      pull-request = "repo:${local.github_repository}:pull_request"
    } : {},
    {
      "environment-${var.github_environment}" = "repo:${local.github_repository}:environment:${var.github_environment}"
    },
  )
}

resource "azuread_application_federated_identity_credential" "github" {
  for_each = local.federated_credentials

  application_id = azuread_application.ci.id
  display_name   = "github-${each.key}"
  description    = "GitHub Actions OIDC subject ${each.value}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value
}

# ---------------------------------------------------------------------------
# Least-privilege RBAC
#
# - Contributor on the app resource group: enough to create/update/destroy
#   the Static Web App, but nothing else in the subscription.
# - Storage Account Contributor on the state account: enough to read and
#   write the state blob (it can list keys), but not to touch other accounts.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "app" {
  scope                = azurerm_resource_group.app.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.ci.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "state" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azuread_service_principal.ci.object_id
  principal_type       = "ServicePrincipal"
}
