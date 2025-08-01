# Application Insights Setup Script for Containerized AjudadoraBot
# PowerShell script for configuring Application Insights monitoring for container deployments

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('staging', 'production')]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [switch]$SetupAlerts,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateDashboard,
    
    [Parameter(Mandatory=$false)]
    [switch]$SetupLiveMetrics,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Set environment-specific variables
if ($Environment -eq 'staging') {
    $resourceGroup = $ResourceGroupName ?? "ajudadorabot-staging-rg"
    $appServiceName = "ajudadorabot-staging-api"
    $appInsightsName = "ajudadorabot-staging-insights"
    $logAnalyticsName = "ajudadorabot-staging-logs"
    $actionGroupName = "ajudadorabot-staging-alerts"
} else {
    $resourceGroup = $ResourceGroupName ?? "ajudadorabot-production-rg"
    $appServiceName = "ajudadorabot-production-api"
    $appInsightsName = "ajudadorabot-production-insights"
    $logAnalyticsName = "ajudadorabot-production-logs"
    $actionGroupName = "ajudadorabot-production-alerts"
}

Write-Host "📊 Starting Application Insights Configuration" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "⚠️  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
}

# Function to write timestamped log
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Function to configure Application Insights for containers
function Configure-ApplicationInsights {
    try {
        Write-Log "Configuring Application Insights for containers..." "INFO"
        
        if (-not $DryRun) {
            # Get Application Insights details
            $appInsights = az monitor app-insights component show --app $appInsightsName --resource-group $resourceGroup --output json | ConvertFrom-Json
            $instrumentationKey = $appInsights.instrumentationKey
            $connectionString = $appInsights.connectionString
            
            # Configure App Service with Application Insights
            az webapp config appsettings set `
                --name $appServiceName `
                --resource-group $resourceGroup `
                --settings @(
                    "APPINSIGHTS_INSTRUMENTATIONKEY=$instrumentationKey",
                    "APPLICATIONINSIGHTS_CONNECTION_STRING=$connectionString",
                    "ApplicationInsightsAgent_EXTENSION_VERSION=~3",
                    "APPINSIGHTS_PROFILERFEATURE_VERSION=1.0.0",
                    "APPINSIGHTS_SNAPSHOTFEATURE_VERSION=1.0.0",
                    "InstrumentationEngine_EXTENSION_VERSION=~1",
                    "SnapshotDebugger_EXTENSION_VERSION=~1",
                    "XDT_MicrosoftApplicationInsights_BaseExtensions=~1",
                    "XDT_MicrosoftApplicationInsights_Mode=recommended",
                    "XDT_MicrosoftApplicationInsights_PreemptSdk=disabled"
                )
            
            # Enable container monitoring
            az webapp config set `
                --name $appServiceName `
                --resource-group $resourceGroup `
                --generic-configurations '{"APPINSIGHTS_PORTALINFO":"ASP.NETCORE","APPINSIGHTS_AUTOCOLLECTKEYVALUES":"false","APPINSIGHTS_PROFILERFEATURE_VERSION":"1.0.0"}'
            
            Write-Log "Application Insights configured for container monitoring" "SUCCESS"
        } else {
            Write-Log "DRY RUN: Would configure Application Insights for containers" "INFO"
        }
    }
    catch {
        Write-Log "Error configuring Application Insights: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup custom monitoring queries
function Setup-MonitoringQueries {
    try {
        Write-Log "Setting up custom monitoring queries..." "INFO"
        
        if (-not $DryRun) {
            # Container-specific monitoring queries
            $containerQueries = @{
                "Container Performance" = @"
let timeRange = 1h;
requests
| where timestamp > ago(timeRange)
| summarize 
    RequestCount = count(),
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95),
    SuccessRate = countif(success == true) * 100.0 / count()
by bin(timestamp, 5m)
| render timechart
"@
                
                "Container Health Checks" = @"
let timeRange = 24h;
requests
| where timestamp > ago(timeRange)
| where url contains "/health"
| summarize 
    HealthCheckCount = count(),
    SuccessfulChecks = countif(success == true),
    FailedChecks = countif(success == false)
by bin(timestamp, 1h)
| extend SuccessRate = SuccessfulChecks * 100.0 / HealthCheckCount
| render columnchart
"@
                
                "Container Error Analysis" = @"
let timeRange = 24h;
exceptions
| where timestamp > ago(timeRange)
| summarize 
    ErrorCount = count(),
    UniqueErrors = dcount(type)
by bin(timestamp, 1h), type
| order by timestamp desc, ErrorCount desc
"@
                
                "Container Resource Usage" = @"
let timeRange = 6h;
performanceCounters
| where timestamp > ago(timeRange)
| where counterName in ("% Processor Time", "Available MBytes")
| summarize avg(counterValue) by bin(timestamp, 15m), counterName
| render timechart
"@
                
                "Bot Telegram API Calls" = @"
let timeRange = 24h;
requests
| where timestamp > ago(timeRange)
| where url contains "/api/bot" or url contains "/webhook"
| summarize 
    TelegramCalls = count(),
    AvgResponseTime = avg(duration),
    ErrorRate = countif(success == false) * 100.0 / count()
by bin(timestamp, 1h)
| render timechart
"@
                
                "User Activity Analysis" = @"
let timeRange = 24h;
customEvents
| where timestamp > ago(timeRange)
| where name in ("UserInteraction", "MessageReceived", "CommandExecuted")
| summarize 
    Events = count(),
    UniqueUsers = dcount(tostring(customDimensions["UserId"]))
by bin(timestamp, 1h), name
| render columnchart
"@
            }
            
            # Save queries to files
            $queriesPath = "app-insights-queries"
            if (-not (Test-Path $queriesPath)) {
                New-Item -ItemType Directory -Path $queriesPath -Force | Out-Null
            }
            
            foreach ($queryName in $containerQueries.Keys) {
                $fileName = "$queriesPath/$($queryName -replace ' ', '-' -replace '[^a-zA-Z0-9-]', '').kql"
                $containerQueries[$queryName] | Out-File -FilePath $fileName -Encoding UTF8
                Write-Log "Query saved: $fileName" "SUCCESS"
            }
            
        } else {
            Write-Log "DRY RUN: Would setup custom monitoring queries" "INFO"
        }
    }
    catch {
        Write-Log "Error setting up monitoring queries: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup Application Insights alerts
function Setup-ApplicationInsightsAlerts {
    try {
        Write-Log "Setting up Application Insights alerts..." "INFO"
        
        if (-not $DryRun) {
            $subscriptionId = az account show --query id --output tsv
            $appInsightsResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/components/$appInsightsName"
            
            # Container-specific alerts
            $alerts = @(
                @{
                    name = "Container-High-Error-Rate"
                    description = "Alert when container error rate exceeds 5%"
                    severity = 2
                    query = @"
requests
| where timestamp > ago(5m)
| summarize 
    Total = count(),
    Errors = countif(success == false)
| extend ErrorRate = (Errors * 100.0) / Total
| where ErrorRate > 5
"@
                    threshold = 0
                },
                @{
                    name = "Container-High-Response-Time"
                    description = "Alert when average response time exceeds 5 seconds"
                    severity = 3
                    query = @"
requests
| where timestamp > ago(5m)
| summarize AvgDuration = avg(duration)
| where AvgDuration > 5000
"@
                    threshold = 0
                },
                @{
                    name = "Container-Health-Check-Failure"
                    description = "Alert when health checks are failing"
                    severity = 1
                    query = @"
requests
| where timestamp > ago(10m)
| where url contains "/health"
| summarize 
    Total = count(),
    Failed = countif(success == false)
| where Failed > 0 and Total > 0
"@
                    threshold = 0
                },
                @{
                    name = "Container-Memory-Usage-High"
                    description = "Alert when memory usage is consistently high"
                    severity = 2
                    query = @"
performanceCounters
| where timestamp > ago(15m)
| where counterName == "Available MBytes"
| summarize AvgMemory = avg(counterValue)
| where AvgMemory < 100
"@
                    threshold = 0
                },
                @{
                    name = "Bot-API-Failures"
                    description = "Alert when Telegram bot API calls are failing"
                    severity = 2
                    query = @"
requests
| where timestamp > ago(5m)
| where url contains "/api/bot" or url contains "/webhook"
| summarize 
    Total = count(),
    Failures = countif(success == false)
| extend FailureRate = (Failures * 100.0) / Total
| where FailureRate > 10
"@
                    threshold = 0
                }
            )
            
            foreach ($alert in $alerts) {
                $alertName = "$($alert.name)-$Environment"
                
                try {
                    az monitor scheduled-query create `
                        --name $alertName `
                        --resource-group $resourceGroup `
                        --scopes $appInsightsResourceId `
                        --condition "count 'Placeholder' > $($alert.threshold)" `
                        --condition-query $alert.query `
                        --description $alert.description `
                        --evaluation-frequency "PT5M" `
                        --severity $alert.severity `
                        --window-size "PT15M" `
                        --action-groups "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/actionGroups/$actionGroupName"
                    
                    Write-Log "Alert created: $alertName" "SUCCESS"
                }
                catch {
                    Write-Log "Warning: Could not create alert $alertName : $($_.Exception.Message)" "WARN"
                }
            }
            
        } else {
            Write-Log "DRY RUN: Would setup Application Insights alerts" "INFO"
        }
    }
    catch {
        Write-Log "Error setting up alerts: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to create monitoring dashboard
function Create-MonitoringDashboard {
    try {
        Write-Log "Creating monitoring dashboard..." "INFO"
        
        if (-not $DryRun) {
            $dashboardTemplate = @{
                tags = @{
                    "hidden-title" = "AjudadoraBot Container Monitoring - $Environment"
                }
                properties = @{
                    lenses = @{
                        "0" = @{
                            order = 0
                            parts = @{
                                "0" = @{
                                    position = @{ x = 0; y = 0; rowSpan = 4; colSpan = 6 }
                                    metadata = @{
                                        inputs = @(
                                            @{
                                                name = "ComponentId"
                                                value = @{
                                                    SubscriptionId = (az account show --query id --output tsv)
                                                    ResourceGroup = $resourceGroup
                                                    Name = $appInsightsName
                                                }
                                            }
                                        )
                                        type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
                                        settings = @{
                                            content = @{
                                                Query = @"
requests
| where timestamp > ago(1h)
| summarize RequestCount = count() by bin(timestamp, 5m)
| render timechart
"@
                                                ControlType = "AnalyticsGrid"
                                                SpecificChart = "Line"
                                                Dimensions = @{
                                                    xAxis = @{ name = "timestamp"; type = "datetime" }
                                                    yAxis = @( @{ name = "RequestCount"; type = "long" } )
                                                    splitBy = @()
                                                    aggregation = "Sum"
                                                }
                                            }
                                        }
                                    }
                                },
                                "1" = @{
                                    position = @{ x = 6; y = 0; rowSpan = 4; colSpan = 6 }
                                    metadata = @{
                                        inputs = @(
                                            @{
                                                name = "ComponentId"
                                                value = @{
                                                    SubscriptionId = (az account show --query id --output tsv)
                                                    ResourceGroup = $resourceGroup
                                                    Name = $appInsightsName
                                                }
                                            }
                                        )
                                        type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
                                        settings = @{
                                            content = @{
                                                Query = @"
requests
| where timestamp > ago(1h)
| summarize AvgDuration = avg(duration) by bin(timestamp, 5m)
| render timechart
"@
                                                ControlType = "AnalyticsGrid"
                                                SpecificChart = "Line"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    metadata = @{
                        model = @{
                            timeRange = @{
                                value = @{
                                    relative = @{
                                        duration = 24
                                        timeUnit = 1
                                    }
                                }
                                type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
                            }
                        }
                    }
                }
            }
            
            $dashboardJson = $dashboardTemplate | ConvertTo-Json -Depth 20
            $dashboardName = "AjudadoraBot-Container-Dashboard-$Environment"
            
            # Save dashboard template to file
            $dashboardJson | Out-File -FilePath "$dashboardName.json" -Encoding UTF8
            
            Write-Log "Dashboard template created: $dashboardName.json" "SUCCESS"
            Write-Log "Import this dashboard manually in Azure Portal" "INFO"
            
        } else {
            Write-Log "DRY RUN: Would create monitoring dashboard" "INFO"
        }
    }
    catch {
        Write-Log "Error creating dashboard: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup Live Metrics Stream
function Setup-LiveMetrics {
    try {
        Write-Log "Setting up Live Metrics Stream..." "INFO"
        
        if (-not $DryRun) {
            # Enable Live Metrics for the App Service
            az webapp config appsettings set `
                --name $appServiceName `
                --resource-group $resourceGroup `
                --settings @(
                    "APPINSIGHTS_PREVIEW_PROFILER_ENABLED=true",
                    "APPINSIGHTS_PREVIEW_SNAPSHOTS_ENABLED=true"
                )
            
            # Configure custom performance counters for containers
            $perfCounterConfig = @{
                "performanceCounters" = @(
                    @{
                        "categoryName" = "Process"
                        "counterName" = "Private Bytes"
                        "instanceName" = "_Total"
                    },
                    @{
                        "categoryName" = "Process"
                        "counterName" = "% Processor Time"
                        "instanceName" = "_Total"
                    },
                    @{
                        "categoryName" = "Memory"
                        "counterName" = "Available MBytes"
                    }
                )
            }
            
            $perfCounterConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath "live-metrics-config.json" -Encoding UTF8
            Write-Log "Live Metrics configuration saved: live-metrics-config.json" "SUCCESS"
            
        } else {
            Write-Log "DRY RUN: Would setup Live Metrics Stream" "INFO"
        }
    }
    catch {
        Write-Log "Error setting up Live Metrics: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup container-specific instrumentation
function Setup-ContainerInstrumentation {
    try {
        Write-Log "Setting up container-specific instrumentation..." "INFO"
        
        if (-not $DryRun) {
            # Create custom telemetry configuration for containers
            $telemetryConfig = @"
{
  "TelemetryModules": {
    "Add": [
      {
        "Type": "Microsoft.ApplicationInsights.DependencyCollector.DependencyTrackingTelemetryModule, Microsoft.AI.DependencyCollector"
      },
      {
        "Type": "Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCollectorModule, Microsoft.AI.PerfCounterCollector"
      },
      {
        "Type": "Microsoft.ApplicationInsights.WindowsServer.DeveloperModeWithDebuggerTelemetryModule, Microsoft.AI.WindowsServer"
      }
    ]
  },
  "TelemetryInitializers": {
    "Add": [
      {
        "Type": "Microsoft.ApplicationInsights.WindowsServer.AzureRoleEnvironmentTelemetryInitializer, Microsoft.AI.WindowsServer"
      }
    ]
  },
  "InstrumentationKey": "#{APPINSIGHTS_INSTRUMENTATIONKEY}#",
  "ApplicationInsights": {
    "LogLevel": {
      "Default": "Information"
    }
  }
}
"@
            
            $telemetryConfig | Out-File -FilePath "applicationinsights.config" -Encoding UTF8
            
            # Create container monitoring startup script
            $monitoringScript = @"
#!/bin/bash
# Container monitoring startup script

echo "Starting Application Insights monitoring for container..."

# Set up container-specific environment variables
export APPINSIGHTS_PROFILERFEATURE_VERSION=1.0.0
export APPINSIGHTS_SNAPSHOTFEATURE_VERSION=1.0.0

# Start the application with monitoring
echo "Application Insights configured for container monitoring"
"@
            
            $monitoringScript | Out-File -FilePath "container-monitoring-startup.sh" -Encoding UTF8
            
            Write-Log "Container instrumentation files created" "SUCCESS"
            
        } else {
            Write-Log "DRY RUN: Would setup container-specific instrumentation" "INFO"
        }
    }
    catch {
        Write-Log "Error setting up container instrumentation: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Main setup function
function Setup-AppInsightsMonitoring {
    try {
        Write-Log "Starting Application Insights monitoring setup..." "INFO"
        
        # Configure Application Insights for containers
        Configure-ApplicationInsights
        
        # Setup custom monitoring queries
        Setup-MonitoringQueries
        
        # Setup alerts if requested
        if ($SetupAlerts) {
            Setup-ApplicationInsightsAlerts
        }
        
        # Create dashboard if requested
        if ($CreateDashboard) {
            Create-MonitoringDashboard
        }
        
        # Setup Live Metrics if requested
        if ($SetupLiveMetrics) {
            Setup-LiveMetrics
        }
        
        # Setup container-specific instrumentation
        Setup-ContainerInstrumentation
        
        Write-Log "✅ Application Insights monitoring setup completed successfully!" "SUCCESS"
        
        # Output monitoring information
        if (-not $DryRun) {
            $appInsights = az monitor app-insights component show --app $appInsightsName --resource-group $resourceGroup --output json | ConvertFrom-Json
            
            Write-Host "`n📊 Monitoring Information:" -ForegroundColor Cyan
            Write-Host "Application Insights Name: $appInsightsName" -ForegroundColor White
            Write-Host "Instrumentation Key: $($appInsights.instrumentationKey)" -ForegroundColor White
            Write-Host "Application ID: $($appInsights.appId)" -ForegroundColor White
            Write-Host "Live Metrics URL: https://portal.azure.com/#@/resource$($appInsights.id)/live" -ForegroundColor White
            Write-Host "`n🎯 Next Steps:" -ForegroundColor Cyan
            Write-Host "1. Restart your App Service to apply monitoring settings" -ForegroundColor White
            Write-Host "2. Review custom queries in the 'app-insights-queries' folder" -ForegroundColor White
            Write-Host "3. Import the dashboard template in Azure Portal" -ForegroundColor White
            Write-Host "4. Configure alert notification channels" -ForegroundColor White
        }
        
    }
    catch {
        Write-Log "❌ Application Insights setup failed: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# Execute setup
Setup-AppInsightsMonitoring

Write-Log "🎉 Application Insights configuration completed!" "SUCCESS"