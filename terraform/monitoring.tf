# Cost monitoring and alerting for free tier optimization
# DISABLED: Monitoring components commented out to reduce complexity and costs
# To re-enable monitoring, uncomment the resources below and set enable_cost_alerts = true

/*
# Action Group for cost alerts
resource "azurerm_monitor_action_group" "cost_alerts" {
  count               = var.enable_cost_alerts && var.alert_email != "" ? 1 : 0
  name                = "${var.app_name}-${var.environment}-cost-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "CostAlert"

  email_receiver {
    name          = "Admin"
    email_address = var.alert_email
  }

  # Webhook receiver for Datadog integration (optional)
  webhook_receiver {
    name        = "DatadogWebhook"
    service_uri = "https://webhook-intake.${var.datadog_site}/api/v1/integration/webhooks/${azurerm_key_vault_secret.datadog_api_key.name}"
  }

  tags = local.common_tags
}
*/

# CPU Usage Alert (important for F1 plan with 60 min/day limit)
resource "azurerm_monitor_metric_alert" "cpu_usage" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-cpu-usage"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "Alert when CPU usage is high (F1 plan has daily compute limits)"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 70 # Lower threshold for free tier monitoring
  }

  dynamic "action" {
    for_each = var.enable_cost_alerts && var.alert_email != "" ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.cost_alerts[0].id
    }
  }

  tags = local.common_tags
}

# Memory Usage Alert (important for 1GB limit on F1 plan)
resource "azurerm_monitor_metric_alert" "memory_usage" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-memory-usage"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "Alert when memory usage is high (F1 plan has 1GB limit)"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "MemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80 # Monitor memory usage closely on free tier
  }

  dynamic "action" {
    for_each = var.enable_cost_alerts && var.alert_email != "" ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.cost_alerts[0].id
    }
  }

  tags = local.common_tags
}

# HTTP Response Time Alert
resource "azurerm_monitor_metric_alert" "response_time" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-response-time"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "Alert when response time is too high (may indicate resource constraints)"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HttpResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5 # 5 seconds threshold
  }

  dynamic "action" {
    for_each = var.enable_cost_alerts && var.alert_email != "" ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.cost_alerts[0].id
    }
  }

  tags = local.common_tags
}

# HTTP 5xx Errors Alert
resource "azurerm_monitor_metric_alert" "http_5xx_errors" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-http-5xx-errors"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "Alert when there are HTTP 5xx errors"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5 # More than 5 errors in 5 minutes
  }

  dynamic "action" {
    for_each = var.enable_cost_alerts && var.alert_email != "" ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.cost_alerts[0].id
    }
  }

  tags = local.common_tags
}

# Data Out Alert (monitor 165MB/day limit on F1 plan)
resource "azurerm_monitor_metric_alert" "data_out" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-data-out"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "Alert when data out approaches daily limit (165MB/day on F1 plan)"
  severity            = 2
  frequency           = "PT15M"
  window_size         = "PT1H"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "BytesSent"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 100000000 # 100MB in bytes (alert before hitting 165MB limit)
  }

  dynamic "action" {
    for_each = var.enable_cost_alerts && var.alert_email != "" ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.cost_alerts[0].id
    }
  }

  tags = local.common_tags
}

# Application Insights Alternative: Log Analytics Workspace (minimal configuration)
# This provides basic monitoring capabilities for free
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018" # Pay-per-GB pricing (minimal cost for small usage)
  retention_in_days   = 30

  tags = local.common_tags
}

# Log Analytics Data Export to reduce costs (export to storage)
resource "azurerm_log_analytics_data_export_rule" "main" {
  count                   = var.enable_cost_alerts && var.create_storage_account ? 1 : 0
  name                    = "${var.app_name}-${var.environment}-log-export"
  resource_group_name     = azurerm_resource_group.main.name
  workspace_resource_id   = azurerm_log_analytics_workspace.main[0].id
  destination_resource_id = azurerm_storage_account.main[0].id
  table_names            = ["AppServiceHTTPLogs", "AppServiceConsoleLogs"]
  enabled                = true
}