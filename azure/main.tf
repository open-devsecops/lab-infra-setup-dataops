terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.70.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.35.0"  
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 1.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "nyc_taxi" {
  name     = "rg-nyc-taxi"
  location = "eastus"
}

resource "azurerm_storage_account" "nyc_taxi_storage" {
  name                     = "nyctaxistorage${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.nyc_taxi.name
  location                 = azurerm_resource_group.nyc_taxi.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "nyc_taxi_raw" {
  name                  = "nyc-taxi-raw"
  storage_account_name  = azurerm_storage_account.nyc_taxi_storage.name
  container_access_type = "private"
}

resource "azurerm_data_factory" "nyc_taxi_adf" {
  name                = "adf-nyc-taxi-25"
  location            = azurerm_resource_group.nyc_taxi.location
  resource_group_name = azurerm_resource_group.nyc_taxi.name
}

resource "azurerm_data_factory_linked_service_web" "http_nyc_taxi" {
  name                = "auto creation(please ignore)" //HttpNycTaxi
  data_factory_id     = azurerm_data_factory.nyc_taxi_adf.id
  url                 = "https://d37ci6vzurychx.cloudfront.net/trip-data/"
  authentication_type = "Anonymous"
  additional_properties = {
    "typeProperties.enableServerCertificateValidation" = "true"
  }
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "blob_nyc_taxi" {
  name                = "BlobNycTaxi"
  data_factory_id     = azurerm_data_factory.nyc_taxi_adf.id
  connection_string   = azurerm_storage_account.nyc_taxi_storage.primary_connection_string
}

resource "azurerm_data_factory_dataset_http" "http_dataset" {
  name                = "HttpNycTaxiDataset"
  data_factory_id     = azurerm_data_factory.nyc_taxi_adf.id
  linked_service_name = azurerm_data_factory_linked_service_web.http_nyc_taxi.name
  relative_url   = "yellow_tripdata_2025-01.parquet"
  request_method = "GET"
}

resource "azurerm_data_factory_dataset_azure_blob" "blob_dataset" {
  name                = "BlobNycTaxiDataset"

  data_factory_id     = azurerm_data_factory.nyc_taxi_adf.id
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.blob_nyc_taxi.name

  path     = "nyc-taxi-raw/yellow/2025/01"
  filename = "yellow_tripdata_2025-01.parquet"

  dynamic "schema_column" {
    for_each = range(20) # Adjust based on actual schema
    content {
      name = "column${schema_column.key}"
      type = "String"
    }
  }
}

# ADF Pipeline
resource "azurerm_data_factory_pipeline" "nyc_taxi_ingestion" {
  name                = "CopyNYCTaxiData"
  data_factory_id     = azurerm_data_factory.nyc_taxi_adf.id

  activities_json = jsonencode([
    {
      name = "CopyFromHTTPToBlob"
      type = "Copy"
      inputs = [
        {
          referenceName = azurerm_data_factory_dataset_http.http_dataset.name
          type          = "DatasetReference"
        }
      ]
      outputs = [
        {
          referenceName = azurerm_data_factory_dataset_azure_blob.blob_dataset.name
          type          = "DatasetReference"
        }
      ]
      typeProperties = {
        source = {
          type = "BinarySource"
        }
        sink = {
          type = "BlobSink"
        }
      }
    }
  ])
}

# 创建 Databricks 工作区
resource "azurerm_databricks_workspace" "nyc_taxi_databricks" {
  name                = "wksp-nyc-taxi"
  resource_group_name = azurerm_resource_group.nyc_taxi.name
  location            = azurerm_resource_group.nyc_taxi.location
  sku                 = "standard"
}

# Automate Databricks Cluster Creation
provider "databricks" {
  alias = "workspace"
  host  = azurerm_databricks_workspace.nyc_taxi_databricks.workspace_url
  azure_workspace_resource_id = azurerm_databricks_workspace.nyc_taxi_databricks.id
}

resource "databricks_cluster" "nyc_taxi" {
  provider = databricks.workspace

  cluster_name            = "nyc-taxi-cluster-2"
  spark_version           = "15.4.x-scala2.12"
  node_type_id            = "Standard_DS3_v2"
  autotermination_minutes = 120

  spark_conf = {
    "spark.databricks.cluster.profile" : "singleNode"
    "spark.master" : "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
  }

  num_workers = 0
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

output "storage_account_name" {
  value = azurerm_storage_account.nyc_taxi_storage.name
}

output "storage_account_key" {
  value = azurerm_storage_account.nyc_taxi_storage.primary_access_key
  sensitive = true
}

output "databricks_workspace_url" {
  value = "https://${azurerm_databricks_workspace.nyc_taxi_databricks.workspace_url}"
}

# Azure DevOps Provider
provider "azuredevops" {
  org_service_url       = "https://dev.azure.com/${var.azuredevops_org}"
  personal_access_token = var.azuredevops_pat
}

resource "azuredevops_project" "nyc_taxi" {
  name               = "nyc-taxi-pipeline"
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Basic"
}

# Create Service Connection to Azure
resource "azuredevops_serviceendpoint_azurerm" "azure_connection" {
  project_id            = azuredevops_project.nyc_taxi.id
  service_endpoint_name = "AzureServiceConnection"
  credentials {
    serviceprincipalid  = var.azure_client_id
    serviceprincipalkey = var.azure_client_secret
  }
  azurerm_spn_tenantid      = var.azure_tenant_id
  azurerm_subscription_id   = var.subscription_id
  azurerm_subscription_name = "Your Azure Subscription"
}

# Create Variable Group
resource "azuredevops_variable_group" "db_secrets" {
  project_id   = azuredevops_project.nyc_taxi.id
  name         = "databricks-secrets"
  description  = "Secrets for Databricks integration"
  allow_access = true

  variable {
    name  = "dbToken"
    secret_value = var.databricks_pat
    is_secret = true
  }

  variable {
    name  = "clusterId"
    value = databricks_cluster.nyc_taxi.id
  }
}

# Create Pipeline Definition
resource "azuredevops_build_definition" "main_pipeline" {
  project_id = azuredevops_project.nyc_taxi.id
  name       = "NYC Taxi Pipeline"

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.nyc_taxi.id
    yml_path    = "azure-pipelines.yml"
  }

  variable_groups = [azuredevops_variable_group.db_secrets.id]

  ci_trigger {
    use_yaml = true
  }
}

# Create Git Repository
resource "azuredevops_git_repository" "nyc_taxi" {
  project_id = azuredevops_project.nyc_taxi.id
  name       = "nyc-taxi-repo"
  initialization {
    init_type = "Clean"
  }
}

# Create Synapse Workspace
resource "azurerm_synapse_workspace" "nyctaxi" {
  name                = "synapse-nyctaxi-test"
  resource_group_name = "rg-nyc-taxi"
  location            = "eastus"
  storage_data_lake_gen2_filesystem_id = "${azurerm_storage_account.nyc_taxi_storage.primary_dfs_endpoint}${azurerm_storage_container.synapse_temp.name}"

  sql_administrator_login          = var.sql_admin_user
  sql_administrator_login_password = var.sql_admin_password

  identity {
    type = "SystemAssigned"
  }
}

# Create firewall rule to allow all IPs
resource "azurerm_synapse_firewall_rule" "allow_all" {
  name                 = "AllowAllIPs"
  synapse_workspace_id = azurerm_synapse_workspace.nyctaxi.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "255.255.255.255"
}

# Create Synapse SQL Pool
resource "azurerm_synapse_sql_pool" "nyctaxipool" {
  name                 = "nyctaxipool"
  synapse_workspace_id = azurerm_synapse_workspace.nyctaxi.id
  sku_name             = "DW100c"
  create_mode          = "Default"
  storage_account_type  = "GRS"
}

# Create storage container
resource "azurerm_storage_container" "synapse_temp" {
  name                  = "synapse-temp"
  storage_account_name  = azurerm_storage_account.nyc_taxi_storage.name
}

# Variables for sensitive values
variable "sql_admin_user" {
  description = "SQL administrator username"
  type        = string
  default     = "sqladminuser"
}

variable "sql_admin_password" {
  description = "SQL administrator password"
  type        = string
  sensitive   = true
  default     = "wxy12345!"
}