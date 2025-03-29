output "mongodb_connection_string" {
  # Change this to use the mongodb_password variable instead of key vault secret
  value       = "mongodb://admin:${var.mongodb_password}@${azurerm_linux_virtual_machine.mongodb.private_ip_address}:27017/admin"
  description = "MongoDB connection string"
  sensitive   = true
  
  # Remove the invalid depends_on - this resource doesn't exist
  # depends_on = [azurerm_key_vault_access_policy.pipeline_sp]
  
  # Instead, depend on the role assignments if needed
  depends_on = [
    azurerm_role_assignment.terraform_keyvault_secrets_user,
    azurerm_role_assignment.pipeline_keyvault_secrets_user
  ]
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