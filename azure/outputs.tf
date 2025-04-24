output "repo_url" {
  description = "Azure DevOps Git Repository URL"
  value       = azuredevops_git_repository.nyc_taxi.remote_url
}

output "storage_account_name" {
  value = azurerm_storage_account.nyc_taxi_storage.name
}

output "databricks_workspace_url" {
  value = "https://${azurerm_databricks_workspace.nyc_taxi_databricks.workspace_url}"
}

output "agent_vm_public_ip" {
  value = azurerm_public_ip.agent_pip.ip_address
}

output "ssh_command" {
  value = "ssh -i ./azure_vm_key.pem azureuser@${azurerm_public_ip.agent_pip.ip_address}"
}