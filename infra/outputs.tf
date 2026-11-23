output "site_url" {
  description = "Public HTTPS URL of the deployed site."
  value       = "https://${module.static_web_app.default_host_name}"
}

output "static_web_app_name" {
  description = "Name of the Static Web App (used by the deploy job)."
  value       = module.static_web_app.name
}

output "resource_group_name" {
  value = local.resource_group_name
}

output "custom_domain_url" {
  description = "Custom domain URL once DNS validation has completed."
  value       = var.custom_domain == null ? null : "https://${var.custom_domain}"
}
