locals {
  resource_group_name = coalesce(var.resource_group_name, "rg-${var.project}")
  name_prefix         = "${var.project}-${var.environment}"

  tags = merge(
    {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags,
  )
}

# Static Web App names are globally unique, so a short random suffix keeps
# `terraform apply` from failing with a name collision.
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

module "static_web_app" {
  source = "./modules/static_web_app"

  name                = "swa-${local.name_prefix}-${random_string.suffix.result}"
  resource_group_name = local.resource_group_name
  location            = var.location
  sku_tier            = var.sku_tier
  custom_domain       = var.custom_domain
  tags                = local.tags

  custom_domain_validation_type = var.custom_domain_validation_type
}
