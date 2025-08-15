# Free-tier optimized Azure Infrastructure for A# Key Vault direto (sem módulo para evitar dependências circulares)
resource "azurerm_key_vault" "main" {
  name                            = substr("${substr(var.app_name, 0, 10)}-${substr(var.environment, 0, 4)}-kv-v2", 0, 24)
  location                        = module.rg.location
  resource_group_name             = module.rg.name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  enabled_for_disk_encryption     = false
  soft_delete_retention_days      = 7
  purge_protection_enabled        = false
  sku_name                        = "standard"
  public_network_access_enabled   = true

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = local.effective_tags
}

# Access policy para Terraform principal
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"]
}

# Secrets do Key Vault
resource "azurerm_key_vault_secret" "telegram_bot_token" {
  name         = "telegram-bot-token"
  value        = var.telegram_bot_token
  key_vault_id = azurerm_key_vault.main.id
  content_type = "Managed by Terraform"
  tags         = local.effective_tags

  lifecycle {
    # Evita sobrescrever o valor do segredo existente quando já houver um no Key Vault
    ignore_changes = [value]
  }

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = local.effective_jwt_secret
  key_vault_id = azurerm_key_vault.main.id
  content_type = "Managed by Terraform"
  tags         = local.effective_tags

  lifecycle {
    # Evita sobrescrever o valor do segredo existente quando já houver um no Key Vault
    ignore_changes = [value]
  }

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "datadog_api_key" {
  name         = "datadog-api-key"
  value        = var.datadog_api_key
  key_vault_id = azurerm_key_vault.main.id
  content_type = "Managed by Terraform"
  tags         = local.effective_tags

  lifecycle {
    # Evita sobrescrever o valor do segredo existente quando já houver um no Key Vault
    ignore_changes = [value]
  }

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

# Current client configuration for tenant ID
data "azurerm_client_config" "current" {}

# Tags efetivas
locals {
  common_tags = {
    Environment      = var.environment
    Application      = var.app_name
    ManagedBy        = "Terraform"
    CostCenter       = "Free-Tier"
    DeploymentType   = "Cost-Optimized"
    DatadogMonitored = "true"
  }
  effective_tags = merge(local.common_tags, var.additional_tags)
}

# Resource Group via módulo
module "rg" {
  source   = "./modules/resource_group"
  name     = "${var.app_name}-${var.environment}-rg"
  location = var.location
  tags     = local.effective_tags
}

# App Service Plan permanece direto (simples)
resource "azurerm_service_plan" "main" {
  name                = "${var.app_name}-${var.environment}-plan"
  location            = module.rg.location
  resource_group_name = module.rg.name
  os_type             = "Linux"
  sku_name            = "F1"
  tags                = local.effective_tags
}

# JWT secret random condicional
resource "random_password" "jwt_secret" {
  count   = var.jwt_secret == "" ? 1 : 0
  length  = 64
  special = true
  upper   = true
  lower   = true
  numeric = true
}
locals { effective_jwt_secret = var.jwt_secret != "" ? var.jwt_secret : random_password.jwt_secret[0].result }

# App Service module
module "app" {
  source              = "./modules/app_service"
  name                = "${var.app_name}-${var.environment}-app"
  location            = module.rg.location
  resource_group_name = module.rg.name
  plan_id             = azurerm_service_plan.main.id
  container_registry  = var.container_registry
  app_name            = var.app_name
  app_version         = var.app_version
  ghcr_username       = var.ghcr_username
  ghcr_token          = var.ghcr_token
  allowed_origins     = distinct(concat(var.allowed_origins, var.additional_allowed_origins))
  additional_app_settings = {
    "DD_API_KEY"                  = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=datadog-api-key)"
    "DD_SITE"                     = var.datadog_site
    "DD_SERVICE"                  = var.app_name
    "DD_ENV"                      = var.environment
    "DD_VERSION"                  = var.app_version
    "DD_LOGS_ENABLED"             = "true"
    "DD_APM_ENABLED"              = "true"
    "DD_TRACE_ENABLED"            = "true"
    "DD_PROFILING_ENABLED"        = "true"
    "DD_APM_NON_LOCAL_TRAFFIC"    = "true"
    "TelegramBot__Token"          = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=telegram-bot-token)"
    "TelegramBot__WebhookUrl"     = "https://${var.app_name}-${var.environment}-app.azurewebsites.net/webhook"
    "MiniApp__JwtSecret"          = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=jwt-secret)"
    "MiniApp__JwtIssuer"          = "${var.app_name}-${var.environment}"
    "MiniApp__JwtAudience"        = "${var.app_name}-users"
    "RateLimiting__PermitLimit"   = "50"
    "RateLimiting__WindowMinutes" = "1"
    "RateLimiting__QueueLimit"    = "5"
  }
  key_vault_uri          = azurerm_key_vault.main.vault_uri
  key_vault_name         = azurerm_key_vault.main.name
  environment            = var.environment
  enable_detailed_errors = var.environment != "production"
  tags                   = local.effective_tags
}

# Access policy para App Service (criada após o app service existir)
resource "azurerm_key_vault_access_policy" "app_service" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = module.app.principal_id
  secret_permissions = ["Get", "List"]
}

# Storage Account opcional
resource "azurerm_storage_account" "main" {
  count                           = var.create_storage_account ? 1 : 0
  name                            = substr(replace("${var.app_name}${var.environment}stor", "-", ""), 0, 24)
  resource_group_name             = module.rg.name
  location                        = module.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  access_tier                     = "Cool"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  public_network_access_enabled   = true
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }
  tags = local.effective_tags
}

# Monitoring via módulo
module "monitoring" {
  count                  = var.enable_cost_alerts ? 1 : 0
  source                 = "./modules/monitoring"
  enable_cost_alerts     = var.enable_cost_alerts
  alert_email            = var.alert_email
  app_name               = var.app_name
  environment            = var.environment
  resource_group_name    = module.rg.name
  webapp_id              = module.app.id
  tags                   = local.effective_tags
  create_storage_account = var.create_storage_account
  storage_account_id     = var.create_storage_account ? azurerm_storage_account.main[0].id : null
}