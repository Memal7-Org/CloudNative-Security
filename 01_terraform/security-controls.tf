# Setup Microsoft Defender for Cloud (preventative control)
resource "azurerm_security_center_subscription_pricing" "defender_for_containers" {
  tier          = "Standard"
  resource_type = "ContainerRegistry"
}

resource "azurerm_security_center_subscription_pricing" "defender_for_aks" {
  tier          = "Standard"
  resource_type = "KubernetesService"
}

resource "azurerm_security_center_subscription_pricing" "defender_for_servers" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

# Enable Azure Security Center alerts (detective control)
resource "azurerm_security_center_contact" "security_alerts" {
  name              = "security-contact"
  email             = "security@example.com"
  phone             = "+1-555-123-4567"
  
  alert_notifications = true
  alerts_to_admins    = true
}

# Enable diagnostic settings for AKS (control plane audit logging)
resource "azurerm_monitor_diagnostic_setting" "aks_diagnostics" {
  name                       = "${azurerm_kubernetes_cluster.aks.name}-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_logs.id
  
  enabled_log {
    category = "kube-audit"
    
    retention_policy {
      enabled = true
      days    = 30
    }
  }
  
  enabled_log {
    category = "kube-audit-admin"
    
    retention_policy {
      enabled = true
      days    = 30
    }
  }
  
  enabled_log {
    category_group = "allLogs"
    retention_policy {
      enabled = true
      days    = 30
    }
  }
  
  metric {
    category = "AllMetrics"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = 30
    }
  }
}

# Create Log Analytics workspace for audit logs
resource "azurerm_log_analytics_workspace" "aks_logs" {
  name                = "law-${var.environment}-${random_pet.suffix.id}"
  resource_group_name = data.azurerm_resource_group.rg-existing.name
  location            = data.azurerm_resource_group.rg-existing.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = local.common_tags
}