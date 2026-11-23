terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partially configured on purpose: the state location is injected with
  # `-backend-config` (CI) or `make init` (local). Nothing environment-specific
  # is hard-coded, so the same code can be reused for a second stack.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
