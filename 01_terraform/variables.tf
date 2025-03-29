variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "environment" {
  description     = "Environment tag (e.g., dev, stage, prod)."
}

variable "vnet_address_space" {
  description     = "Address space for the Virtual Network."
}

variable "aks_subnet_prefix" {
  description     = "Address prefix for the AKS subnet."
  default     = "10.1.2.0/24" 

}

variable "db_subnet_prefix" {
  description     = "Address prefix for the database subnet."
  default         = "10.1.3.0/24"
}

variable "aks_node_count" {
  description     = "Number of nodes in the AKS cluster."
  default         = 3
}

variable "aks_vm_size" {
  description     = "VM size for AKS nodes."
  default         = "Standard_DS2_v2"
}

variable "aks_admin_group_id" {
  description = "The Object ID of the Azure AD group that will be granted the Admin role on the AKS cluster"
  type        = string
  default     = "admin-group-id"
}

variable "db_vm_size" {
  description = "VM size for MongoDB server"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "db_admin_username" {
  description = "Admin username for the MongoDB VM"
  type        = string
  default     = "admin-group-id"
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

variable "db_os_disk_size_gb" {
  description = "OS disk size for MongoDB VM in GB"
  type        = number
  default     = 30
}

variable "storage_account_tier" {
  description = "Tier for storage account"
  type        = string
  default     = "Standard"
}