variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
  default     = "ADD_YOUR_AZURE_SUBSCRIPTION_ID"
}

variable "azuredevops_pat" {
  description = "Azure DevOps Personal Access Token"
  type        = string
  sensitive   = true
  default     = "ADD_YOUR_AZURE_DEVOPS_PERSONAL_ACCESS_TOKEN"
}

variable "azure_client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
  default     = "ADD_YOUR_AZURE_CLIENT_ID"
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
  default     = "ADD_YOUR_AZURE_CLIENT_SECRET"
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  default     = "ADD_YOUR_AZURE_TENANT_ID"
}

variable "databricks_pat" {
  description = "Databricks Personal Access Token"
  type        = string
  sensitive   = true
  default     = "ADD_YOUR_DATABRICKS_PERSONAL_ACCESS_TOKEN"
}

variable "azuredevops_org" {
  description = "Azure DevOps organization name"
  type        = string
  default     = "ADD_YOUR_AZURE_DEVOPS_ORG_NAME"
}

variable "ado_org_url" {
  description = "Azure DevOps organization URL"
  type        = string
  default     = "https://dev.azure.com/<ADD_YOUR_AZURE_DEVOPS_ORG_NAME>"
}

variable "sql_admin_user" {
  description = "SQL administrator username"
  type        = string
  default     = "sqladminuser"
}

variable "sql_admin_password" {
  description = "SQL administrator password"
  type        = string
  sensitive   = true
  default     = "Sql12345!"
}