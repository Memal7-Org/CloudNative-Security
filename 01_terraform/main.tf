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

  # Add network_profile block to specify a non-overlapping service CIDR
  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = "172.16.0.10"
    service_cidr       = "172.16.0.0/16"  # Non-overlapping with your VNet CIDR
  }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "aks_rbac_reader" {
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azurerm_kubernetes_cluster.aks.id
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  role_definition_name = "Network Contributor"
  scope                = azurerm_subnet.aks_subnet.id
  principal_id         = data.azurerm_client_config.current.object_id
}

# Add node pools defined in the aks_node_pools variable
resource "azurerm_kubernetes_cluster_node_pool" "additional_pools" {
  for_each = var.aks_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  max_pods              = each.value.max_pods
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_disk_type          = each.value.os_disk_type
  os_type               = each.value.os_type
  zones                 = each.value.zones
  node_labels           = each.value.node_labels
  node_taints           = each.value.node_taints
  orchestrator_version  = each.value.orchestrator_version  
  upgrade_settings {
    max_surge = each.value.max_surge
  }
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                     = lower("acr${var.environment}${random_pet.suffix.id}")
  resource_group_name      = data.azurerm_resource_group.rg-existing.name
  location                 = data.azurerm_resource_group.rg-existing.location
  sku                      = "Standard"
  admin_enabled            = true

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
    sku       = "18.04-LTS" # Intentional misconfiguration for security demo!
    version   = "latest"
  }

  custom_data = base64encode(templatefile("scripts/install_mongodb.sh", {
    mongodb_password = var.mongodb_password,
    db_user_password = var.mongodb_password
  }))

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Add overly permissive role assignment to the MongoDB VM
resource "azurerm_role_assignment" "mongodb_contributor" {
  scope                = data.azurerm_resource_group.rg-existing.id
  role_definition_name = "Contributor"  # Overly permissive role
  principal_id         = azurerm_linux_virtual_machine.mongodb.identity[0].principal_id
}

resource "azurerm_network_interface" "mongodb_nic" {
  name                = "nic-mongodb-${var.environment}"
  location            = data.azurerm_resource_group.rg-existing.location
  resource_group_name = data.azurerm_resource_group.rg-existing.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mongodb.id # Intentional misconfiguration for security demo!
  }

  tags = local.common_tags
}

resource "azurerm_public_ip" "mongodb" { # Intentional misconfiguration for security demo!
  name                = "public-ip-mongodb-${var.environment}"
  location            = data.azurerm_resource_group.rg-existing.location
  resource_group_name = data.azurerm_resource_group.rg-existing.name
  allocation_method   = "Static"
}

# Storage Account for Backups (Storage Tier)
resource "azurerm_storage_account" "backup" {
  name                     = lower("stgbackup${random_pet.suffix.id}")
  resource_group_name      = data.azurerm_resource_group.rg-existing.name
  location                 = data.azurerm_resource_group.rg-existing.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type

  allow_nested_items_to_be_public   = true # Intentional misconfiguration for security demo!
  
  tags = local.common_tags
}

resource "azurerm_storage_container" "backup_container" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.backup.id
}

# Generate SAS token for storage container
data "azurerm_storage_account_sas" "backup_sas" {
  connection_string = azurerm_storage_account.backup.primary_connection_string
  
  resource_types {
    service   = false
    container = true
    object    = true
  }
  
  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }
  
  start  = "2023-01-01T00:00:00Z"
  expiry = "2030-01-01T00:00:00Z"
  
  permissions {
    read    = true
    write   = true
    delete  = false
    list    = true
    add     = true
    create  = true
    update  = true
    process = false
    tag     = false
    filter  = false
  }
}
