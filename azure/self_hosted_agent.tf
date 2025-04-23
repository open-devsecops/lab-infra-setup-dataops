# Create resource group for agent
resource "azurerm_resource_group" "agent_rg" {
  name     = "ado-agents-rg"
  location = "East US"
}

# Network Security Group for Agent
resource "azurerm_network_security_group" "agent_nsg" {
  name                = "ado-agent-nsg"
  location            = azurerm_resource_group.agent_rg.location
  resource_group_name = azurerm_resource_group.agent_rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureDevOpsOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureDevOps"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "agent_vnet" {
  name                = "ado-agent-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.agent_rg.location
  resource_group_name = azurerm_resource_group.agent_rg.name
}

# Subnet
resource "azurerm_subnet" "agent_subnet" {
  name                 = "agents-subnet"
  resource_group_name  = azurerm_resource_group.agent_rg.name
  virtual_network_name = azurerm_virtual_network.agent_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  
  //network_security_group_id = azurerm_network_security_group.agent_nsg.id
}

# Public IP
resource "azurerm_public_ip" "agent_pip" {
  name                = "ado-agent-pip-${random_string.suffix.result}"
  location            = azurerm_resource_group.agent_rg.location
  resource_group_name = azurerm_resource_group.agent_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "ado-agent-${random_string.suffix.result}" 
}

# Network Interface
resource "azurerm_network_interface" "agent_nic" {
  name                = "ado-agent-nic-${random_string.suffix.result}"
  location            = azurerm_resource_group.agent_rg.location
  resource_group_name = azurerm_resource_group.agent_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.agent_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.agent_pip.id
  }
}

# SSH Key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "agent_vm" {
  name                = "ado-agent-vm-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.agent_rg.name
  location            = azurerm_resource_group.agent_rg.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.agent_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azuredevops_agent_pool" "self_hosted" {
  name           = "self-hosted-agent"
  auto_provision = false
  pool_type      = "automation"
}

resource "azurerm_virtual_machine_extension" "agent_setup" {
  name                 = "install-ado-agent"
  virtual_machine_id   = azurerm_linux_virtual_machine.agent_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    "commandToExecute" = <<-EOF
      #!/bin/bash

      set -e

      # Remove existing agent configuration if it exists
      if [ -d "/opt/ado-agent" ]; then
        cd /opt/ado-agent
        sudo ./config.sh remove --unattended --auth PAT --token ${var.azuredevops_pat}
      fi

      # Configure environment for non-interactive installation
      export DEBIAN_FRONTEND=noninteractive

      # Install dependencies
      apt-get update -qq
      apt-get install -y -qq curl git jq docker.io

      # Install Azure CLI
      curl -sL https://aka.ms/InstallAzureCLIDeb | bash

      # Configure Docker permissions
      usermod -aG docker azureuser

      # Create agent directory
      mkdir -p /opt/ado-agent
      cd /opt/ado-agent
      
      # Download agent
      AGENT_VERSION=3.236.1
      curl -sLO https://vstsagentpackage.azureedge.net/agent/$AGENT_VERSION/vsts-agent-linux-x64-$AGENT_VERSION.tar.gz
      tar -xzf vsts-agent-linux-x64-$AGENT_VERSION.tar.gz

      # Configure agent as regular user
      runuser -u azureuser -- ./config.sh --unattended \
        --url "${var.ado_org_url}" \
        --auth pat \
        --token "${var.azuredevops_pat}" \
        --pool "${azuredevops_agent_pool.self_hosted.name}" \
        --agent "${azurerm_linux_virtual_machine.agent_vm.name}" \
        --replace \
        --acceptTeeEula \
        --runAsService

      # Install and start service
      ./svc.sh install
      ./svc.sh start
    EOF
  })
}

# Outputs
output "agent_vm_public_ip" {
  value = azurerm_public_ip.agent_pip.ip_address
}

output "ssh_command" {
  value = "ssh -i ./azure_vm_key.pem azureuser@${azurerm_public_ip.agent_pip.ip_address}"
}

output "ssh_private_key" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}