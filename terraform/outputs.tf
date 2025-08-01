# Outputs for free-tier optimized Azure deployment

# App Service Information
output "app_service_name" {
  description = "Name of the App Service"
  value       = azurerm_linux_web_app.main.name
}

output "app_service_url" {
  description = "URL of the deployed application"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "app_service_default_hostname" {
  description = "Default hostname of the App Service"
  value       = azurerm_linux_web_app.main.default_hostname
}

output "app_service_principal_id" {
  description = "Principal ID of the App Service managed identity"
  value       = azurerm_linux_web_app.main.identity[0].principal_id
}

# Resource Group Information
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# App Service Plan Information
output "service_plan_name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.main.name
}

output "service_plan_sku" {
  description = "SKU of the App Service Plan (should be F1 for free tier)"
  value       = azurerm_service_plan.main.sku_name
}

# Key Vault Information
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

# Storage Account Information (if created)
output "storage_account_name" {
  description = "Name of the storage account"
  value       = var.create_storage_account ? azurerm_storage_account.main[0].name : null
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = var.create_storage_account ? azurerm_storage_account.main[0].primary_blob_endpoint : null
}

# Deployment Configuration
output "deployment_config" {
  description = "Deployment configuration summary"
  value = {
    app_name                = var.app_name
    environment            = var.environment
    location               = var.location
    container_registry     = var.container_registry
    datadog_site          = var.datadog_site
    free_tier_constraints = var.free_tier_constraints
  }
}

# Free Tier Limits Information
output "free_tier_info" {
  description = "Free tier limits and constraints"
  value = {
    daily_compute_hours = "${var.free_tier_constraints.compute_hours_per_day} hours"
    storage_limit      = "${var.free_tier_constraints.storage_gb} GB"
    daily_bandwidth    = "${var.free_tier_constraints.bandwidth_gb} GB"
    custom_domains     = var.free_tier_constraints.custom_domains
    ssl_connections    = var.free_tier_constraints.ssl_connections
    deployment_slots   = var.free_tier_constraints.deployment_slots
    
    key_vault_operations = "${var.free_tier_constraints.key_vault_operations}/month"
    
    datadog_hosts      = var.free_tier_constraints.datadog_hosts
    datadog_retention  = "${var.free_tier_constraints.datadog_retention_days} days"
  }
}

# Webhook URLs for Telegram Bot
output "telegram_webhook_url" {
  description = "Telegram webhook URL for bot configuration"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}/webhook"
}

# Health Check URL
output "health_check_url" {
  description = "Health check endpoint URL"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}/health"
}

# API Documentation URL
output "swagger_url" {
  description = "Swagger API documentation URL (if enabled)"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}/swagger"
}

# Container Registry Information
output "container_registry_info" {
  description = "Container registry configuration"
  value = {
    registry_url = var.container_registry
    image_name   = "${var.container_registry}/${var.app_name}"
    latest_tag   = "${var.container_registry}/${var.app_name}:latest"
  }
}

# Cost Optimization Summary
output "cost_optimization_summary" {
  description = "Summary of cost optimization measures"
  value = {
    app_service_tier     = "F1 (Free)"
    always_on_disabled   = "Yes (not available in F1)"
    storage_strategy     = var.create_storage_account ? "Azure Storage (LRS, Cool)" : "App Service Local Storage"
    container_registry   = "GitHub Container Registry (Free)"
    monitoring           = "Datadog Free Tier"
    key_vault_tier      = "Standard (Free operations)"
    custom_domain       = "No (using *.azurewebsites.net)"
    ssl_certificate     = "Shared SSL (Free)"
    backup_strategy     = "Manual/Script-based (Free)"
    log_retention       = "3 days (cost optimized)"
  }
}

# Datadog Configuration
output "datadog_config" {
  description = "Datadog monitoring configuration"
  value = {
    api_key_secret = azurerm_key_vault_secret.datadog_api_key.name
    site          = var.datadog_site
    service_name  = var.app_name
    environment   = var.environment
    version       = var.app_version
    apm_enabled   = true
    logs_enabled  = true
    trace_enabled = true
  }
}

# Security Configuration
output "security_config" {
  description = "Security configuration summary"
  value = {
    https_only              = true
    min_tls_version        = "1.2"
    key_vault_integration  = true
    managed_identity       = true
    ftps_disabled         = true
    system_assigned_identity = azurerm_linux_web_app.main.identity[0].principal_id
  }
}