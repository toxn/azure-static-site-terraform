output "client_id" {
  description = "Application (client) ID used by the workflow. Not a secret."
  value       = azuread_application.ci.client_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

output "app_resource_group_name" {
  value = azurerm_resource_group.app.name
}

output "state_resource_group_name" {
  value = azurerm_resource_group.state.name
}

output "state_storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "state_container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "github_variable_commands" {
  description = "Copy/paste these into a terminal to configure the repository."
  value       = <<-EOT
    # Repository variables (identifiers, not credentials - safe to store as vars)
    gh variable set AZURE_CLIENT_ID          --repo ${local.github_repository} --body "${azuread_application.ci.client_id}"
    gh variable set AZURE_TENANT_ID          --repo ${local.github_repository} --body "${data.azurerm_client_config.current.tenant_id}"
    gh variable set AZURE_SUBSCRIPTION_ID    --repo ${local.github_repository} --body "${data.azurerm_client_config.current.subscription_id}"
    gh variable set TF_STATE_RESOURCE_GROUP  --repo ${local.github_repository} --body "${azurerm_resource_group.state.name}"
    gh variable set TF_STATE_STORAGE_ACCOUNT --repo ${local.github_repository} --body "${azurerm_storage_account.tfstate.name}"
    gh variable set TF_STATE_CONTAINER       --repo ${local.github_repository} --body "${azurerm_storage_container.tfstate.name}"
  EOT
}

output "next_steps" {
  value = <<-EOT
    1. Run the gh commands from `terraform output github_variable_commands`.
    2. Push this repository to GitHub (branch: main).
    3. Watch the "pipeline" workflow: validate -> plan -> apply -> deploy.
  EOT
}
