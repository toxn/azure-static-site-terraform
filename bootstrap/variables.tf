variable "project" {
  description = "Short lowercase slug used in resource names (e.g. \"demo\")."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.project))
    error_message = "project must be 2-8 characters, lowercase letters and digits only."
  }
}

variable "location" {
  description = "Azure region for the state storage account and the app resource group."
  type        = string
  default     = "eastus2"
}

variable "github_owner" {
  description = "GitHub user or organisation that owns the repository."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.github_owner))
    error_message = "github_owner must be a GitHub username or organisation (no slashes)."
  }
}

variable "github_repo" {
  description = "GitHub repository name (without the owner)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be the bare repository name (no owner/slash)."
  }
}

variable "github_environment" {
  description = "GitHub Actions environment used by the apply job. Its OIDC subject must match."
  type        = string
  default     = "production"
}

variable "create_pull_request_credential" {
  description = "Also allow the pull_request event to authenticate (needed for plan-on-PR)."
  type        = bool
  default     = true
}

variable "app_resource_group_name" {
  description = "Resource group that will hold the app. Defaults to rg-<project>."
  type        = string
  default     = null
}

variable "state_resource_group_name" {
  description = "Resource group for the Terraform state account. Defaults to rg-<project>-tfstate."
  type        = string
  default     = null
}

variable "state_storage_account_name" {
  description = "Globally unique state account name (3-24 lowercase alphanumerics). Defaults to a generated name."
  type        = string
  default     = null

  validation {
    condition     = var.state_storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.state_storage_account_name))
    error_message = "state_storage_account_name must be 3-24 lowercase letters and digits."
  }
}
