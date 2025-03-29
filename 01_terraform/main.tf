terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Create a random identifier for unique resource names
resource "random_pet" "suffix" {
  length    = 1
  separator = ""
}

# Virtual Network and Subnets
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.environment}"
  location            = data.azurerm_resource_group.rg-existing.location
  resource_group_name = data.azurerm_resource_group.rg-existing.name
  address_space       = var.vnet_address_space

  tags = local.common_tags
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = data.azurerm_resource_group.rg-existing.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_prefix]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = data.azurerm_resource_group.rg-existing.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.db_subnet_prefix]
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.environment}"
  location            = data.azurerm_resource_group.rg-existing.location
  resource_group_name = data.azurerm_resource_group.rg-existing.name
  dns_prefix          = "aks-${var.environment}"

  default_node_pool {
    name           = "default"
    node_count     = var.aks_node_count
    vm_size        = var.aks_vm_size
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    service_cidr      = "10.2.0.0/16"  // Non-overlapping CIDR
    dns_service_ip    = "10.2.0.10"    // Within the service CIDR
  }

  tags = local.common_tags
}

# Azure Container Registry for storing container images
resource "azurerm_container_registry" "acr" {
  name                     = lower("acr${var.environment}${random_pet.suffix.id}")
  resource_group_name      = data.azurerm_resource_group.rg-existing.name
  location                 = data.azurerm_resource_group.rg-existing.location
  sku                      = "Standard"
  admin_enabled            = true # Enable admin user for testing purposes

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Grant AKS access to ACR
resource "azurerm_role_assignment" "aks_to_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# MongoDB VM (Database Tier)
resource "azurerm_linux_virtual_machine" "mongodb" {
  name                            = "vm-mongodb-${var.environment}"
  resource_group_name             = data.azurerm_resource_group.rg-existing.name
  location                        = data.azurerm_resource_group.rg-existing.location
  size                            = var.db_vm_size
  admin_username                  = var.db_admin_username
  admin_password                  = data.azurerm_key_vault_secret.db_password.value
  disable_password_authentication = false

  network_interface_ids           = [
    azurerm_network_interface.mongodb_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.db_os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y gnupg
    wget -qO - https://www.mongodb.org/static/pgp/server-4.0.asc | apt-key add -
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list
    apt-get update
    apt-get install -y mongodb-org
    
    # Configure MongoDB to listen on all interfaces
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    
    # Create admin user for authentication
    cat > /tmp/init-mongo.js << 'INITJS'
    db = db.getSiblingDB('admin');
    db.createUser({
      user: "${var.db_admin_username}",
      pwd: "${data.azurerm_key_vault_secret.db_password.value}",
      roles: [ { role: "root", db: "admin" } ]
    });
    INITJS
    
    # Enable MongoDB authentication
    sed -i 's/#security:/security:\n  authorization: enabled/' /etc/mongod.conf
    
    # Start MongoDB
    systemctl start mongod
    systemctl enable mongod
    
    # Initialize MongoDB with admin user
    sleep 10
    mongo admin /tmp/init-mongo.js
    rm /tmp/init-mongo.js
    
    # Create backup directory
    mkdir -p /var/backups/mongodb
    
    # Setup backup cron job
    echo "0 0 * * * mongodump --out /var/backups/mongodb/\$(date +\%Y-\%m-\%d) && tar -czf /var/backups/mongodb/mongodb-backup-\$(date +\%Y-\%m-\%d).tar.gz /var/backups/mongodb/\$(date +\%Y-\%m-\%d) && az storage blob upload --account-name stgbackup${random_pet.suffix.id} --container-name ${var.storage_container_name} --name mongodb-backup-\$(date +\%Y-\%m-\%d).tar.gz --file /var/backups/mongodb/mongodb-backup-\$(date +\%Y-\%m-\%d).tar.gz --auth-mode login" > /var/spool/cron/crontabs/root
  EOF
  )

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

// Add after MongoDB VM resource

resource "azurerm_role_assignment" "mongodb_vm_contributor" {
  scope                = data.azurerm_resource_group.rg-existing.id
  role_definition_name = "Contributor"  // Highly privileged role
  principal_id         = azurerm_linux_virtual_machine.mongodb.identity[0].principal_id
}

// Allow SSH from anywhere (security weakness as required)
resource "azurerm_network_security_group" "mongodb_nsg" {
  name                = "nsg-mongodb-${var.environment}"
  location            = data.azurerm_resource_group.rg-existing.location
  resource_group_name = data.azurerm_resource_group.rg-existing.name

  security_rule {
    name                       = "allow_ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_mongodb_from_aks"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = var.aks_subnet_prefix
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_interface_security_group_association" "mongodb_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.mongodb_nic.id
  network_security_group_id = azurerm_network_security_group.mongodb_nsg.id
}

resource "azurerm_network_interface" "mongodb_nic" {
  name                = "nic-mongodb-${var.environment}"
  location            = data.azurerm_resource_group.rg-existing.location
  resource_group_name = data.azurerm_resource_group.rg-existing.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mongodb.id # For security demo purposes only!
  }

  tags = local.common_tags
}

resource "azurerm_public_ip" "mongodb" {
  name                = "public-ip-mongodb-${var.environment}"
  location            = data.azurerm_resource_group.rg-existing.location
  resource_group_name = data.azurerm_resource_group.rg-existing.name
  allocation_method   = "Static"
}

# Grant Terraform service principal access to Key Vault secrets
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = data.azurerm_key_vault.existing.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List"
  ]
}

# Storage Account for Backups (Storage Tier)
resource "azurerm_storage_account" "backup" {
  name                     = lower("stgbackup${random_pet.suffix.id}")
  resource_group_name      = data.azurerm_resource_group.rg-existing.name
  location                 = data.azurerm_resource_group.rg-existing.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type

  allow_nested_items_to_be_public   = true # Intentional misconfiguration for security demo.
  
  tags = local.common_tags
}

// Update storage container for public access

resource "azurerm_storage_container" "backup_container" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.backup.id
  container_access_type = "blob"  // Allows public read access
}
