variable "name" {
  description = "Globally unique Static Web App name."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku_tier" {
  description = "Free or Standard."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be either Free or Standard."
  }
}

variable "custom_domain" {
  description = "Optional custom domain to attach."
  type        = string
  default     = null
}

variable "custom_domain_validation_type" {
  description = "How DNS ownership is proven. dns-txt-token for apex, cname-delegation for subdomains."
  type        = string
  default     = "dns-txt-token"

  validation {
    condition     = contains(["dns-txt-token", "cname-delegation"], var.custom_domain_validation_type)
    error_message = "custom_domain_validation_type must be dns-txt-token or cname-delegation."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
