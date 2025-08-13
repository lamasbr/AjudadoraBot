# Cost monitoring and alerting moved to modules/monitoring
# This file is now managed via the monitoring module in main.tf

# All monitoring resources have been moved to:
# - modules/monitoring/main.tf
# - Called from main.tf as: module "monitoring"

# The monitoring module handles:
# - Action Groups for alerts
# - CPU usage alerts  
# - Memory usage alerts
# - Response time alerts
# - HTTP 5xx error alerts
# - Data out alerts

# Configuration is passed via module variables from main.tf

# Previous resources that were moved to the module:
# - azurerm_monitor_action_group.cost_alerts
# - azurerm_monitor_metric_alert.cpu_usage
# - azurerm_monitor_metric_alert.memory_usage  
# - azurerm_monitor_metric_alert.response_time
# - azurerm_monitor_metric_alert.http_5xx_errors
# - azurerm_monitor_metric_alert.data_out
# - azurerm_log_analytics_workspace.main
# - azurerm_log_analytics_data_export_rule.main
