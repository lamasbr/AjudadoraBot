variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "plan_id" {
  type = string
}

variable "container_registry" {
  type = string
}

variable "app_name" {
  type = string
}

variable "app_version" {
  type = string
}

variable "ghcr_username" {
  type = string
}

variable "ghcr_token" {
  type = string
}

variable "allowed_origins" {
  type = list(string)
}

variable "additional_app_settings" {
  type    = map(string)
  default = {}
}

variable "key_vault_uri" {
  type = string
}

variable "key_vault_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_detailed_errors" {
  type    = bool
  default = true
}

resource "azurerm_linux_web_app" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = var.plan_id
  https_only          = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      docker_image_name   = "${var.container_registry}/${var.app_name}:${var.app_version}"
      docker_registry_url = "https://${var.container_registry}"
    }
    always_on               = false
    health_check_path       = "/health"
    ftps_state              = "Disabled"
    http2_enabled           = true
    minimum_tls_version     = "1.2"
    scm_minimum_tls_version = "1.2"
    use_32_bit_worker       = true
    websockets_enabled      = false

    cors {
      allowed_origins     = var.allowed_origins
      support_credentials = true
    }
  }

  app_settings = merge({
    "ASPNETCORE_ENVIRONMENT"               = var.environment == "production" ? "Production" : "Staging"
    "ASPNETCORE_URLS"                      = "http://+:8080"
    "ASPNETCORE_FORWARDEDHEADERS_ENABLED"  = "true"
    "DOCKER_REGISTRY_SERVER_URL"           = "https://${var.container_registry}"
    "DOCKER_REGISTRY_SERVER_USERNAME"      = var.ghcr_username
    "DOCKER_REGISTRY_SERVER_PASSWORD"      = var.ghcr_token
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"  = "true"
    "WEBSITES_CONTAINER_START_TIME_LIMIT"  = "230"
    "WEBSITE_TIME_ZONE"                    = "UTC"
    "WEBSITE_RUN_FROM_PACKAGE"             = "0"
    "ConnectionStrings__DefaultConnection" = "Data Source=/home/data/ajudadorabot.db"
    "KeyVault__VaultUrl"                   = var.key_vault_uri
  }, var.additional_app_settings)

  connection_string {
    name  = "DefaultConnection"
    type  = "Custom"
    value = "Data Source=/home/data/ajudadorabot.db"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }

    http_logs {
      file_system {
        retention_in_days = 3
        retention_in_mb   = 35
      }
    }

    detailed_error_messages = var.enable_detailed_errors
    failed_request_tracing  = var.enable_detailed_errors
  }

  tags = var.tags
}

output "name" {
  value = azurerm_linux_web_app.this.name
}

output "default_hostname" {
  value = azurerm_linux_web_app.this.default_hostname
}

output "principal_id" {
  value = azurerm_linux_web_app.this.identity[0].principal_id
}

output "id" {
  value = azurerm_linux_web_app.this.id
}
