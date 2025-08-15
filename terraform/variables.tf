# Variables for free-tier optimized Azure deployment

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "ajudadorabot"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.app_name))
    error_message = "App name must be 3-24 characters long and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging"], var.environment)
    error_message = "Environment must be 'production' or 'staging'."
  }
}

variable "location" {
  description = "Azure region for resources (choose cost-effective region)"
  type        = string
  default     = "East US"

  validation {
    # Permitir lista ampliada de regiões populares de baixo custo
    condition     = can(regex("^(East US( 2)?|South Central US|West US 2|West US 3|Central US|North Central US|West Central US|Canada Central|North Europe|West Europe|UK South|Southeast Asia|East Asia|Brazil South)$", var.location))
    error_message = "Location must be a supported cost-effective Azure region."
  }
}

variable "app_version" {
  description = "Application version for tagging"
  type        = string
  default     = "1.0.0"
}

# Container Registry Configuration (GitHub Container Registry - Free)
variable "container_registry" {
  description = "Container registry URL (GitHub Container Registry is free)"
  type        = string
  default     = "ghcr.io"
}

variable "ghcr_username" {
  description = "GitHub Container Registry username"
  type        = string
}

variable "ghcr_token" {
  description = "GitHub Container Registry token (PAT with read:packages scope)"
  type        = string
}

# Telegram Bot Configuration
variable "telegram_bot_token" {
  description = "Telegram Bot API token"
  type        = string
}

# JWT Configuration
variable "jwt_secret" {
  description = "JWT signing secret (auto-generated if not provided)"
  type        = string
  default     = ""
}

# Datadog Configuration (Free tier: up to 5 hosts, 1-day retention)
variable "datadog_api_key" {
  description = "Datadog API key for monitoring"
  type        = string
}

variable "datadog_site" {
  description = "Datadog site (e.g., datadoghq.com, datadoghq.eu)"
  type        = string
  default     = "datadoghq.com"
  validation {
    condition     = contains(["datadoghq.com", "datadoghq.eu", "us3.datadoghq.com", "us5.datadoghq.com", "ap1.datadoghq.com", "ddog-gov.com"], var.datadog_site)
    error_message = "Invalid Datadog site."
  }
}

# CORS Configuration for Telegram Mini App
variable "allowed_origins" {
  description = "Allowed origins for CORS (Telegram domains)"
  type        = list(string)
  default = [
    "https://web.telegram.org",
    "https://k.web.telegram.org",
    "https://z.web.telegram.org",
    "https://a.web.telegram.org"
  ]
}

variable "additional_allowed_origins" {
  description = "Extra allowed origins for CORS"
  type        = list(string)
  default     = []
}

# Additional App Settings
variable "additional_app_settings" {
  description = "Additional application settings"
  type        = map(string)
  default     = {}
}

# Cost Optimization Settings
variable "create_storage_account" {
  description = "Create Azure Storage Account (optional)"
  type        = bool
  default     = false
}

# Free Tier Limits and Constraints
variable "free_tier_constraints" {
  description = "Free tier constraints and limits"
  type = object({
    compute_hours_per_day  = number
    storage_gb             = number
    bandwidth_gb           = number
    custom_domains         = number
    ssl_connections        = number
    deployment_slots       = number
    key_vault_operations   = number
    datadog_hosts          = number
    datadog_retention_days = number
  })
  default = {
    compute_hours_per_day  = 1
    storage_gb             = 1
    bandwidth_gb           = 0.165
    custom_domains         = 0
    ssl_connections        = 0
    deployment_slots       = 0
    key_vault_operations   = 25000
    datadog_hosts          = 5
    datadog_retention_days = 1
  }
}

# Monitoring and Alerting
variable "enable_cost_alerts" {
  description = "Enable cost / performance alerts"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for cost and monitoring alerts"
  type        = string
  default     = ""
}

# Resource Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "secret_expiration_days" {
  description = "Number of days until secret expiration (0 = no explicit expiration to ensure idempotency)"
  type        = number
  default     = 0
  validation {
    condition     = var.secret_expiration_days >= 0 && var.secret_expiration_days <= 3650
    error_message = "Secret expiration days must be between 0 and 3650."
  }
}