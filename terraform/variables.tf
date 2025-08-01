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
  description = "Environment name (production only for cost optimization)"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["production"], var.environment)
    error_message = "Environment must be 'production' for cost-optimized deployment."
  }
}

variable "location" {
  description = "Azure region for resources (choose cheapest available)"
  type        = string
  default     = "East US"
  
  validation {
    condition = contains([
      "East US", "East US 2", "South Central US", "West US 2", "West US 3",
      "Central US", "North Central US", "West Central US", "Canada Central",
      "North Europe", "West Europe", "UK South", "Southeast Asia", "East Asia"
    ], var.location)
    error_message = "Location must be a cost-effective Azure region."
  }
}

variable "app_version" {
  description = "Application version for Datadog tagging"
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
  sensitive   = true
}

variable "ghcr_token" {
  description = "GitHub Container Registry token (PAT with read:packages scope)"
  type        = string
  sensitive   = true
}

# Telegram Bot Configuration
variable "telegram_bot_token" {
  description = "Telegram Bot API token"
  type        = string
  sensitive   = true
}

# JWT Configuration
variable "jwt_secret" {
  description = "JWT signing secret (auto-generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

# Datadog Configuration (Free tier: up to 5 hosts, 1-day retention)
variable "datadog_api_key" {
  description = "Datadog API key for monitoring"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (e.g., datadoghq.com, datadoghq.eu)"
  type        = string
  default     = "datadoghq.com"
  
  validation {
    condition = contains([
      "datadoghq.com", "datadoghq.eu", "us3.datadoghq.com", 
      "us5.datadoghq.com", "ap1.datadoghq.com", "ddog-gov.com"
    ], var.datadog_site)
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

# Additional App Settings
variable "additional_app_settings" {
  description = "Additional application settings"
  type        = map(string)
  default     = {}
}

# Cost Optimization Settings
variable "create_storage_account" {
  description = "Create Azure Storage Account (use local App Service storage for SQLite to save costs)"
  type        = bool
  default     = false
}

# Free Tier Limits and Constraints
variable "free_tier_constraints" {
  description = "Free tier constraints and limits"
  type = object({
    # F1 App Service Plan limits
    compute_hours_per_day = number  # 60 minutes per day
    storage_gb           = number   # 1 GB
    bandwidth_gb         = number   # 165 MB/day outbound data
    custom_domains       = number   # 0 (use *.azurewebsites.net)
    ssl_connections      = number   # 0 (use shared SSL)
    deployment_slots     = number   # 0 (no staging slots)
    
    # Key Vault free tier limits
    key_vault_operations = number   # 25,000 per month
    
    # Datadog free tier limits
    datadog_hosts        = number   # 5 hosts max
    datadog_retention_days = number # 1 day retention
  })
  
  default = {
    compute_hours_per_day    = 1      # 60 minutes/day
    storage_gb              = 1       # 1 GB storage
    bandwidth_gb            = 0.165   # 165 MB/day
    custom_domains          = 0       # No custom domains
    ssl_connections         = 0       # No custom SSL
    deployment_slots        = 0       # No staging slots
    key_vault_operations    = 25000   # 25K operations/month
    datadog_hosts          = 5        # 5 hosts max
    datadog_retention_days = 1        # 1 day retention
  }
}

# Monitoring and Alerting
variable "enable_cost_alerts" {
  description = "Enable cost monitoring alerts for free tier limits"
  type        = bool
  default     = true
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