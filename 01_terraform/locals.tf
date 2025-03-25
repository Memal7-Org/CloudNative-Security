locals {
  # Define local values to use throughout the configuration

  # Merge existing resource group tags with additional tags
  common_tags = merge(
    data.azurerm_resource_group.rg-existing.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Suffix      = random_pet.suffix.id
    }
  )
}