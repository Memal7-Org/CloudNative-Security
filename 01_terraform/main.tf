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
  
  # ...rest of the configuration...
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = data.azurerm_resource_group.rg-existing.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_config.subnet_prefix]
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
    name            = "default"
    node_count      = var.aks_config.node_count
    vm_size         = var.aks_config.vm_size       
    vnet_subnet_id  = azurerm_subnet.aks_subnet.id
    os_disk_size_gb = var.aks_config.os_disk_size_gb 
  }

  identity {
    type = "SystemAssigned"
  }

  # Add this network_profile block to specify a non-overlapping service CIDR
  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = "172.16.0.10"
    service_cidr       = "172.16.0.0/16"  # Non-overlapping with your VNet CIDR
  }

  tags = local.common_tags
}

# Add node pools defined in the aks_node_pools variable
resource "azurerm_kubernetes_cluster_node_pool" "additional_pools" {
  for_each = var.aks_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = each.value.vm_size
  node_count            = each.value.min_count
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  max_pods              = each.value.max_pods
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_type               = each.value.os_type
  os_disk_type          = each.value.os_disk_type
  zones                 = each.value.zones
  node_labels           = each.value.node_labels
  node_taints           = each.value.node_taints
  orchestrator_version  = each.value.orchestrator_version  
  upgrade_settings {
    max_surge = each.value.max_surge
  }
}

# Azure Container Registry for storing container images
resource "azurerm_container_registry" "acr" {
  name                     = lower("acr${var.environment}${random_pet.suffix.id}")
  resource_group_name      = data.azurerm_resource_group.rg-existing.name
  location                 = data.azurerm_resource_group.rg-existing.location
  sku                      = "Standard"
  admin_enabled            = true # Enable admin user for testing purposes!

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
  admin_password                  = var.mongodb_password
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

  # Inject the MongoDB installation script from an external file
  custom_data = base64encode(templatefile("scripts/install_mongodb.sh", {
    mongodb_password = var.mongodb_password
  }))

  tags = local.common_tags
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

/*
resource "azurerm_role_assignment" "terraform_keyvault_secrets_user" {
  scope                = data.azurerm_key_vault.existing.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "pipeline_keyvault_secrets_user" {
  scope                = data.azurerm_key_vault.existing.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_client_config.current.object_id
}
*/

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

resource "azurerm_storage_container" "backup_container" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.backup.id
}
