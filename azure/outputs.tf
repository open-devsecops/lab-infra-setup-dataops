output "please_note" {
  value = [
    "Tool installation could take several minutes to complete.",
    "Verify completion by entering the following command on the server:",
    "grep 'Lab Infrastructure Provisioning Complete' /var/log/cloud-init-output.log"
  ]
}

output "repo_url" {
  description = "Azure DevOps Git Repository URL"
  value       = azuredevops_git_repository.nyc_taxi.remote_url
}