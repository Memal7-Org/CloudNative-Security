variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "environment" {
  description = "Environment tag (e.g., dev, stage, prod)"
  type        = string
  default     = "wizdemo"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

# AKS cluster configuration
variable "aks_config" {
  description = "Configuration for the AKS cluster"
  type = object({
    subnet_prefix    = string
    node_count       = number
    vm_size          = string
    admin_group_id   = string
    os_disk_size_gb  = number
  })
  default = {
    subnet_prefix    = "10.1.2.0/24"
    node_count       = 2           
    vm_size          = "Standard_B2s"
    admin_group_id   = "admin-group-id"
    os_disk_size_gb  = 30
  }
}

# Node pools configuration optimized for small web app
variable "aks_node_pools" {
  description = "Node pools configuration for AKS"
  type = map(object({
    vm_size              = string
    node_count           = number
    max_pods             = number
    max_surge            = string
    os_disk_size_gb      = number
    os_disk_type         = string
    os_type              = string
    os_sku               = string
    orchestrator_version = string
    zones                = list(string)
    node_labels          = map(string)
    node_taints          = list(string)
  }))
  default = {
    webapp = {
      vm_size              = "Standard_B2s"
      node_count           = 1
      max_pods             = 30
      max_surge            = "25%"
      os_disk_size_gb      = 30
      os_disk_type         = "Managed"
      os_type              = "Linux"
      os_sku               = "Ubuntu"
      orchestrator_version = null
      zones                = ["1", "2"]
      node_labels          = { "app" = "webapp" }
      node_taints          = []
    }
  }
}

variable "db_subnet_prefix" {
  description     = "Address prefix for the database subnet."
  type        = string
  default         = "10.1.3.0/24"
}

variable "db_vm_size" {
  description = "VM size for MongoDB server"
  type        = string
  default     = "Standard_B1ms"
}

variable "db_admin_username" {
  description = "Admin username for the MongoDB VM"
  type        = string
  default     = "dbadmin"
}

variable "db_os_disk_size_gb" {
  description = "OS disk size for MongoDB VM in GB"
  type        = number
  default     = 30
}

variable "storage_account_replication_type" {
  description = "Replication type for storage account"
  type        = string
  default     = "LRS"
}

variable "storage_container_name" {
  description = "Name of storage container"
  type        = string
  default     = "dbbackups"
}

variable "storage_account_tier" {
  description = "Tier for storage account"
  type        = string
  default     = "Standard"
}
variable "mongodb_password" {
  description = "Password for MongoDB admin user" # Intentionally added to the code for testing purposes!
  type        = string
  sensitive   = true
  default     = "SecurePassword123!"

}