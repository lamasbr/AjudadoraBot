variable "enable_cost_alerts" {
  type = bool
}

variable "alert_email" {
  type = string
}

variable "app_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "webapp_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_storage_account" {
  type = bool
}

variable "storage_account_id" {
  type    = string
  default = null
}

locals {
  create_action = var.enable_cost_alerts && var.alert_email != ""
}

resource "azurerm_monitor_action_group" "this" {
  count               = local.create_action ? 1 : 0
  name                = "${var.app_name}-${var.environment}-cost-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "CostAlert"

  email_receiver {
    name          = "Admin"
    email_address = var.alert_email
  }

  tags = var.tags
}

locals {
  action_group_id = local.create_action ? azurerm_monitor_action_group.this[0].id : null
}

resource "azurerm_monitor_metric_alert" "cpu_usage" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-cpu-usage"
  resource_group_name = var.resource_group_name
  scopes              = [var.webapp_id]
  description         = "High CPU"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 70
  }

  dynamic "action" {
    for_each = local.create_action ? [1] : []
    content {
      action_group_id = local.action_group_id
    }
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "memory_usage" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-memory-usage"
  resource_group_name = var.resource_group_name
  scopes              = [var.webapp_id]
  description         = "High Memory"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "MemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  dynamic "action" {
    for_each = local.create_action ? [1] : []
    content {
      action_group_id = local.action_group_id
    }
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "response_time" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-response-time"
  resource_group_name = var.resource_group_name
  scopes              = [var.webapp_id]
  description         = "High Response Time"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HttpResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5
  }

  dynamic "action" {
    for_each = local.create_action ? [1] : []
    content {
      action_group_id = local.action_group_id
    }
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "http_5xx_errors" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-http-5xx-errors"
  resource_group_name = var.resource_group_name
  scopes              = [var.webapp_id]
  description         = "HTTP 5xx Errors"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  dynamic "action" {
    for_each = local.create_action ? [1] : []
    content {
      action_group_id = local.action_group_id
    }
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "data_out" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.app_name}-${var.environment}-data-out"
  resource_group_name = var.resource_group_name
  scopes              = [var.webapp_id]
  description         = "High Data Out"
  severity            = 2
  frequency           = "PT15M"
  window_size         = "PT1H"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "BytesSent"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 100000000
  }

  dynamic "action" {
    for_each = local.create_action ? [1] : []
    content {
      action_group_id = local.action_group_id
    }
  }

  tags = var.tags
}
