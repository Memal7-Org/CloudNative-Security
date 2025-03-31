# Get current client config for access policy
data "azurerm_client_config" "current" {}

# Reference existing resource group
data "azurerm_resource_group" "rg-existing" {
  name = "ODL-candidate-sandbox-02-1652694"
}