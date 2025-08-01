# Free-tier optimized Azure Infrastructure for AjudadoraBot
# Terraform configuration for cost-optimized deployment with Datadog monitoring

# Terraform and provider configurations are defined in providers.tf

# Current client configuration for tenant ID
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.app_name}-${var.environment}-rg"
  location = var.location

  tags = local.common_tags
}

# Free Tier App Service Plan (F1)
resource "azurerm_service_plan" "main" {
  name                = "${var.app_name}-${var.environment}-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "F1" # Free tier: shared infrastructure, 1GB storage, 60 minutes/day compute

  tags = local.common_tags
}

# App Service for hosting both backend API and frontend
resource "azurerm_linux_web_app" "main" {
  name                = "${var.app_name}-${var.environment}-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    # Container configuration for GitHub Container Registry
    application_stack {
      docker_image_name   = "${var.container_registry}/${var.app_name}:latest"
      docker_registry_url = "https://${var.container_registry}"
    }

    # Free tier limitations - AlwaysOn not available
    always_on                         = false
    container_registry_use_managed_identity = false
    
    # Performance optimizations within free tier limits
    app_command_line                  = ""
    health_check_path                 = "/health"
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version          = "1.2"
    use_32_bit_worker                 = true # F1 plan only supports 32-bit workers
    websockets_enabled                = false
    
    # CORS configuration for Telegram Mini App
    cors {
      allowed_origins = var.allowed_origins
      support_credentials = true
    }
  }

  # Application settings optimized for free tier and Datadog
  app_settings = merge({
    # Core application settings
    "ASPNETCORE_ENVIRONMENT"     = var.environment == "production" ? "Production" : "Staging"
    "ASPNETCORE_URLS"            = "http://+:8080"
    "ASPNETCORE_FORWARDEDHEADERS_ENABLED" = "true"
    
    # Container registry settings for GitHub Container Registry
    "DOCKER_REGISTRY_SERVER_URL"      = "https://${var.container_registry}"
    "DOCKER_REGISTRY_SERVER_USERNAME" = var.ghcr_username
    "DOCKER_REGISTRY_SERVER_PASSWORD" = var.ghcr_token
    
    # Azure App Service specific settings for free tier
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
    "WEBSITES_CONTAINER_START_TIME_LIMIT" = "230"
    "WEBSITE_TIME_ZONE"                   = "UTC"
    "WEBSITE_RUN_FROM_PACKAGE"            = "0"
    
    # Database configuration - SQLite with local storage
    "ConnectionStrings__DefaultConnection" = "Data Source=/home/data/ajudadorabot.db"
    
    # Key Vault reference (free tier)
    "KeyVault__VaultUrl" = azurerm_key_vault.main.vault_uri
    
    # Datadog configuration (replace Application Insights)
    "DD_API_KEY"     = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=datadog-api-key)"
    "DD_SITE"        = var.datadog_site
    "DD_SERVICE"     = var.app_name
    "DD_ENV"         = var.environment
    "DD_VERSION"     = var.app_version
    "DD_LOGS_ENABLED" = "true"
    "DD_APM_ENABLED"  = "true"
    "DD_TRACE_ENABLED" = "true"
    "DD_PROFILING_ENABLED" = "true"
    "DD_APM_NON_LOCAL_TRAFFIC" = "true"
    
    # Telegram Bot configuration
    "TelegramBot__Token" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=telegram-bot-token)"
    "TelegramBot__WebhookUrl" = "https://${var.app_name}-${var.environment}-app.azurewebsites.net/webhook"
    
    # JWT configuration for Mini App
    "MiniApp__JwtSecret" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=jwt-secret)"
    "MiniApp__JwtIssuer" = "${var.app_name}-${var.environment}"
    "MiniApp__JwtAudience" = "${var.app_name}-users"
    
    # Rate limiting (reduced for free tier)
    "RateLimiting__PermitLimit" = "50"
    "RateLimiting__WindowMinutes" = "1"
    "RateLimiting__QueueLimit" = "5"
    
  }, var.additional_app_settings)

  # Connection strings
  connection_string {
    name  = "DefaultConnection"
    type  = "Custom"
    value = "Data Source=/home/data/ajudadorabot.db"
  }

  logs {
    # Minimal logging to stay within free tier limits
    application_logs {
      file_system_level = "Information"
    }
    
    http_logs {
      file_system {
        retention_in_days = 3
        retention_in_mb   = 35 # Free tier storage limit consideration
      }
    }
    
    detailed_error_messages = var.environment != "production"
    failed_request_tracing  = var.environment != "production"
  }

  tags = local.common_tags
}

# Key Vault (Free tier - 25,000 operations/month)
resource "azurerm_key_vault" "main" {
  name                          = "${var.app_name}-prod-kv"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  enabled_for_disk_encryption   = false # Not needed for free tier
  enabled_for_deployment        = true
  enabled_for_template_deployment = true
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = 7 # Minimum for cost optimization
  purge_protection_enabled      = false # Disabled for free tier flexibility
  
  sku_name = "standard" # Free tier available operations

  # Network ACLs - Allow access from Azure services (free tier friendly)
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = local.common_tags
}

# Key Vault Access Policy for App Service
resource "azurerm_key_vault_access_policy" "app_service" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  depends_on = [azurerm_linux_web_app.main]
}

# Key Vault Access Policy for Terraform Service Principal
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set"
  ]
}

# Key Vault Secrets (to be populated via CI/CD or manually)
resource "azurerm_key_vault_secret" "telegram_bot_token" {
  name            = "telegram-bot-token"
  value           = var.telegram_bot_token
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "Telegram Bot API Token"
  expiration_date = timeadd(timestamp(), "8760h") # 1 year expiration

  depends_on = [azurerm_key_vault_access_policy.terraform]

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = var.jwt_secret != "" ? var.jwt_secret : random_password.jwt_secret.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "JWT Signing Secret"
  expiration_date = timeadd(timestamp(), "8760h") # 1 year expiration

  depends_on = [azurerm_key_vault_access_policy.terraform]

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "datadog_api_key" {
  name         = "datadog-api-key"
  value        = var.datadog_api_key
  key_vault_id = azurerm_key_vault.main.id
  content_type = "Datadog API Key"
  expiration_date = timeadd(timestamp(), "8760h") # 1 year expiration

  depends_on = [azurerm_key_vault_access_policy.terraform]

  tags = local.common_tags
}

# Generate JWT secret if not provided
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Storage Account for SQLite database persistence (cheapest tier)
# Note: Using App Service local storage for SQLite in free tier
# This is a backup option if needed for file shares
resource "azurerm_storage_account" "main" {
  count                    = var.create_storage_account ? 1 : 0
  name                     = replace("${var.app_name}${var.environment}stor", "-", "")
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Cheapest option
  
  # Cost optimization settings
  access_tier                     = "Cool" # Cheaper access tier
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  
  # Disable expensive features for cost optimization
  shared_access_key_enabled       = true
  public_network_access_enabled   = true
  
  blob_properties {
    delete_retention_policy {
      days = 7 # Minimum retention for cost savings
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}

# Local variables
locals {
  common_tags = {
    Environment     = var.environment
    Application     = var.app_name
    ManagedBy      = "Terraform"
    CostCenter     = "Free-Tier"
    DeploymentType = "Cost-Optimized"
    DatadogMonitored = "true"
  }
}