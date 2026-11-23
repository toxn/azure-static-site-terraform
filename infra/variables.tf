variable "project" {
  description = "Short lowercase slug used in resource names."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.project))
    error_message = "project must be 2-8 characters, lowercase letters and digits only."
  }
}

variable "environment" {
  description = "Deployment environment (prod, staging, dev...). Also used in the state key if you add more stacks."
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-z]{2,10}$", var.environment))
    error_message = "environment must be 2-10 lowercase letters."
  }
}

variable "location" {
  description = "Region for the Static Web App. Supported: eastus2, centralus, westus2, westeurope, eastasia."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Resource group created by bootstrap/. Defaults to rg-<project>."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Static Web App plan. Free is $0/month and includes SSL + a global CDN."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be either Free or Standard."
  }
}

variable "custom_domain" {
  description = "Optional custom domain, e.g. \"www.example.com\". Requires DNS access to validate."
  type        = string
  default     = null
}

variable "custom_domain_validation_type" {
  description = "dns-txt-token for apex domains, cname-delegation for subdomains."
  type        = string
  default     = "dns-txt-token"

  validation {
    condition     = contains(["dns-txt-token", "cname-delegation"], var.custom_domain_validation_type)
    error_message = "custom_domain_validation_type must be dns-txt-token or cname-delegation."
  }
}

variable "tags" {
  description = "Extra tags merged into the default tag set."
  type        = map(string)
  default     = {}
}
