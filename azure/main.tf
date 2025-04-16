terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.70.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# resource "azurerm_resource_group" "rg" {
#   name     = var.resource_group_name
#   location = var.location
# }

# resource "azurerm_public_ip" "public_ip" {
#   name                         = var.public_ip_name
#   resource_group_name          = azurerm_resource_group.rg.name
#   location                     = azurerm_resource_group.rg.location
#   allocation_method = "Static"
#   idle_timeout_in_minutes      = 4
#   sku                          = "Basic"

#   tags = {
#     Name = "lab_public_ip"
#   }
# }

# resource "tls_private_key" "key" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# resource "null_resource" "ssh_key" {
#   provisioner "local-exec" {
#     command = <<-EOT
#       rm -f ./'${var.ssh_key_name}'.pem 2> /dev/null
#       echo '${tls_private_key.key.private_key_pem}' > ./'${var.ssh_key_name}'.pem
#       chmod 400 ./'${var.ssh_key_name}'.pem
#     EOT
#   }
# }

# resource "azurerm_network_interface" "nic" {
#   name                     = var.nic_name
#   location                 = azurerm_resource_group.rg.location
#   resource_group_name      = azurerm_resource_group.rg.name

#   tags = {
#     Name = "lab_nic"
#   }

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.subnet.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.public_ip.id
#   }
# }

# resource "azurerm_linux_virtual_machine" "topic-2-lab" {
#   name                = var.vm_name
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   size                = var.vm_size
#   network_interface_ids = [
#     azurerm_network_interface.nic.id
#   ]
#   admin_username = var.vm_admin_username
  
#   admin_ssh_key {
#     username   = var.vm_admin_username
#     public_key = tls_private_key.key.public_key_openssh
#   }

#   user_data = base64encode(templatefile("cloud_init.yml.tftpl", {
#     wg_port                      = var.wg_port,
#     public_iface                 = var.public_iface,
#     vpn_network_address          = var.vpn_network_address,
#     docker_compose_b64_encoded   = filebase64("${path.root}/uploads/docker-compose.yml"),
#     nginx_conf_b64_encoded       = filebase64("${path.root}/uploads/nginx.conf"),
#     setup_nginx_conf_b64_encoded = filebase64("${path.root}/uploads/setup_nginx.conf"),
#     init_script_b64_encoded      = filebase64("${path.root}/uploads/init_script.sh"),
#     setting_up_page_b64_encoded  = filebase64("${path.root}/uploads/index.html"),
#     subscription_id              = var.subscription_id, 
#     aws_account_id               = var.aws_account_id,
#     region                       = var.region
#   }))
  
#   computer_name = substr(var.vm_name, 0, 15)

#   os_disk {
#     name              = "${var.vm_name}_os_disk"
#     caching           = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#     disk_size_gb      = 30
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }

#   identity {
#     type = "SystemAssigned"
#   }

#   tags = {
#     Name = "lab_vm"
#   }

#   depends_on = [
#     azurerm_network_security_group.nsg
#   ]
# }

# resource "azurerm_container_registry" "acr" {
#   name                = var.acr_name
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   sku                 = "Basic"
#   admin_enabled       = true
# }

# 创建资源组
resource "azurerm_resource_group" "nyc_taxi" {
  name     = "rg-nyc-taxi"
  location = "westus"
}

# 创建 Storage Account (ADLS Gen2)
resource "azurerm_storage_account" "nyc_taxi_storage" {
  name                     = "nyctaxistorage25"  # 需全局唯一，请修改
  resource_group_name      = azurerm_resource_group.nyc_taxi.name
  location                 = azurerm_resource_group.nyc_taxi.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true  # 启用分层命名空间
}

# 创建 Blob Container
resource "azurerm_storage_container" "nyc_taxi_raw" {
  name                  = "nyc-taxi-raw"
  storage_account_name  = azurerm_storage_account.nyc_taxi_storage.name
  container_access_type = "private"
}

# 创建 Data Factory
resource "azurerm_data_factory" "nyc_taxi_adf" {
  name                = "adf-nyc-taxi-25"
  location            = azurerm_resource_group.nyc_taxi.location
  resource_group_name = azurerm_resource_group.nyc_taxi.name
}

# 创建 Databricks 工作区
resource "azurerm_databricks_workspace" "nyc_taxi_databricks" {
  name                = "dbw-nyctaxi"
  resource_group_name = azurerm_resource_group.nyc_taxi.name
  location            = azurerm_resource_group.nyc_taxi.location
  sku                 = "premium"
}

# 创建 Azure SQL Server
resource "azurerm_mssql_server" "nyc_taxi_sql" {
  name                         = "nycsql25"
  resource_group_name          = azurerm_resource_group.nyc_taxi.name
  location                     = azurerm_resource_group.nyc_taxi.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd!2023"  # 请修改为强密码

  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = var.azuread_administrator_object_id
  }

  tags = {
    environment = "production"
  }
}

# 配置 SQL 防火墙规则（允许 Azure 服务访问）
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.nyc_taxi_sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# 创建 SQL 数据库
resource "azurerm_mssql_database" "nyc_taxi_db" {
  name           = "db-nyc-taxi"
  server_id      = azurerm_mssql_server.nyc_taxi_sql.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "Basic"
  max_size_gb    = 2
  read_scale     = false
  zone_redundant = false
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# 创建 Synapse Workspace
resource "azurerm_storage_account" "synapse_storage" {
  name                     = "nyctaxi${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.nyc_taxi.name
  location                 = azurerm_resource_group.nyc_taxi.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
}

resource "azurerm_synapse_workspace" "nyc_taxi_synapse" {
  name                                 = "synapse-nyc-taxi"
  resource_group_name                  = azurerm_resource_group.nyc_taxi.name
  location                             = azurerm_resource_group.nyc_taxi.location
  storage_data_lake_gen2_filesystem_id = "https://${azurerm_storage_account.nyc_taxi_storage.name}.dfs.core.windows.net/${azurerm_storage_container.nyc_taxi_raw.name}"
  
  sql_administrator_login          = "sqladminuser"
  sql_administrator_login_password = "P@ssw0rd!2025"

  managed_virtual_network_enabled = false
 
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }

  depends_on = [
    azurerm_storage_account.synapse_storage
  ]
}

# 创建专用 SQL 池
resource "azurerm_synapse_sql_pool" "nyc_taxi_pool" {
  name                 = "nyctaxipool"
  synapse_workspace_id = azurerm_synapse_workspace.nyc_taxi_synapse.id
  sku_name             = "DW100c"
  create_mode          = "Default"
  storage_account_type  = "GRS"
  
  data_encrypted        = true
}

# 配置防火墙规则允许 Azure 服务访问
resource "azurerm_synapse_firewall_rule" "allow_azure" {
  name                 = "AllowAllWindowsAzureIps"
  synapse_workspace_id = azurerm_synapse_workspace.nyc_taxi_synapse.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"
}

# 授予 Synapse 访问存储账户的权限
resource "azurerm_role_assignment" "synapse_storage_access" {
  scope                = azurerm_storage_account.nyc_taxi_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.nyc_taxi_synapse.identity[0].principal_id
}

# 在 outputs.tf 中添加
output "synapse_workspace_name" {
  value = azurerm_synapse_workspace.nyc_taxi_synapse.name
}

output "synapse_sql_endpoint" {
  value = azurerm_synapse_workspace.nyc_taxi_synapse.connectivity_endpoints.sql
}

output "storage_account_name" {
  value = azurerm_storage_account.nyc_taxi_storage.name
}

output "storage_account_key" {
  value = azurerm_storage_account.nyc_taxi_storage.primary_access_key
  sensitive = true
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.nyc_taxi_sql.fully_qualified_domain_name
}

output "databricks_workspace_url" {
  value = "https://${azurerm_databricks_workspace.nyc_taxi_databricks.workspace_url}"
}
