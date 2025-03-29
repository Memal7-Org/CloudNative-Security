# Get current client config for access policy
data "azurerm_client_config" "current" {}

# Reference existing resource group
data "azurerm_resource_group" "rg-existing" {
  name = "ODL-candidate-sandbox-02-1652694"
}

# Get the existing Key Vault
data "azurerm_key_vault" "existing" {
  name                = "kv-wiz-demo"
  resource_group_name = "ODL-candidate-sandbox-02-1652694"    
}

# Get the password secret from Key Vault
data "azurerm_key_vault_secret" "db_password" {
   name         = "mongodb-password"
   key_vault_id = data.azurerm_key_vault.existing.id
   }