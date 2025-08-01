# Terraform variables for AjudadoraBot deployment
# Based on provided Azure credentials

# Application Configuration
app_name    = "ajudadorabot"
environment = "production"
location    = "East US"
app_version = "1.0.0"

# GitHub Container Registry (Free) - placeholder values
container_registry = "ghcr.io"
ghcr_username     = "testuser"
ghcr_token        = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Telegram Bot Configuration - placeholder (proper format)
telegram_bot_token = "1234567890:AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTTUUVVWWXXYYZZaabbccddee"

# JWT Configuration (will be auto-generated)
jwt_secret = ""

# Datadog Configuration - placeholder (proper format)
datadog_api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
datadog_site    = "datadoghq.com"

# CORS Configuration for Telegram Mini App
allowed_origins = [
  "https://web.telegram.org",
  "https://k.web.telegram.org", 
  "https://z.web.telegram.org",
  "https://a.web.telegram.org"
]

# Cost Optimization Settings
create_storage_account = false

# Monitoring and Alerting
enable_cost_alerts = true
alert_email       = "admin@example.com"

# Additional App Settings
additional_app_settings = {}

# Additional Tags
additional_tags = {
  "Project"     = "AjudadoraBot"
  "Owner"       = "DevOps"
  "Environment" = "Production"
}