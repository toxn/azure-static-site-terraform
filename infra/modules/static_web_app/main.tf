resource "azurerm_static_web_app" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  # The Free tier is a real product, not a trial: free SSL, global CDN and
  # 100 GB/month of bandwidth at $0.
  sku_tier = var.sku_tier
  sku_size = var.sku_tier

  tags = var.tags
}

# Optional custom domain.
# - dns-txt-token:    apex domains, prove ownership with a TXT record
# - cname-delegation: subdomains, prove ownership with a CNAME record
resource "azurerm_static_web_app_custom_domain" "this" {
  count = var.custom_domain == null ? 0 : 1

  static_web_app_id = azurerm_static_web_app.this.id
  domain_name       = var.custom_domain
  validation_type   = var.custom_domain_validation_type
}
