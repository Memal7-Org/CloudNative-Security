output "mongodb_connection_string" {
  description = "MongoDB connection string"
  value       = "mongodb://admin:${data.azurerm_key_vault_secret.mongodb_password.value}@${azurerm_linux_virtual_machine.mongodb.private_ip_address}:27017/admin"
  sensitive   = true
}

output "acr_name" {
  description = "The name of the Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "The login server URL for the Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = data.azurerm_resource_group.rg-existing.name
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.backup.name
}

output "acr_admin_username" {
  description = "The admin username for the Azure Container Registry"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "The admin password for the Azure Container Registry"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}