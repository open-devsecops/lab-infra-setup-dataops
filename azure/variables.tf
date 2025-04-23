# Added manually
variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
  default     = "e2270428-9eaa-4af7-b909-d190829450ae"
}

# variable "synapse_sql_admin_password" {
#   description = "Password for Synapse SQL administrator"
#   type        = string
#   sensitive   = true
#   default = "P@ssw0rd!2025"
# }

# variable "azuread_administrator_object_id" {
#   description = "azuread_administrator_object_id"
#   default = "2f8d6ddd-e0cc-4936-8dd2-9dedcd805303" # 替换为你的 Azure AD 对象 ID
# }

variable "azuredevops_pat" {
  description = "Azure DevOps Personal Access Token"
  type        = string
  sensitive   = true
  default     = "E3ZhWpuKIBzfzHlNHI16UekDnNW5jY5UdoB7XKm3FKeKJGQAoS4eJQQJ99BDACAAAAABRVnhAAASAZDO1Yrh"
}

variable "azure_client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
  default     = "8c1c956d-edbc-479d-8caf-a24c3c460517"
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
  default     = "sYe8Q~RoflprpSRFaZKrrnx5fP5et_xZKSeOkarj"
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  default     = "f6b6dd5b-f02f-441a-99a0-162ac5060bd2"
}

variable "databricks_pat" {
  description = "Databricks Personal Access Token"
  type        = string
  sensitive   = true
  default     = "dapi8c83bada47ca4c2547aaa3ec2d61ff6e-3"
}

variable "azuredevops_org" {
  description = "Azure DevOps organization name"
  type        = string
  default     = "xinyiw12"
}

variable "ado_org_url" {
  description = "Azure DevOps organization URL"
  type        = string
  default     = "https://dev.azure.com/xinyiw12"
}

variable "admin_ip" {
  description = "Administrator IP address for SSH access"
  default     = "172.190.187.195/32"
}

