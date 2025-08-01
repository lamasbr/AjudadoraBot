# Azure Container Monitoring Script for AjudadoraBot
# PowerShell script for monitoring containerized applications in Azure App Service

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('staging', 'production', 'both')]
    [string]$Environment = 'both',
    
    [Parameter(Mandatory=$false)]
    [int]$DurationMinutes = 30,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory=$false)]
    [switch]$Continuous,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\monitoring-reports"
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Environment configurations
$environments = @{}
if ($Environment -eq 'staging' -or $Environment -eq 'both') {
    $environments['staging'] = @{
        ResourceGroup = 'ajudadorabot-staging-rg'
        AppServiceName = 'ajudadorabot-staging-api'
        AcrName = 'ajudadorabotregistrystaging'
        ApplicationInsights = 'ajudadorabot-staging-insights'
    }
}
if ($Environment -eq 'production' -or $Environment -eq 'both') {
    $environments['production'] = @{
        ResourceGroup = 'ajudadorabot-production-rg'
        AppServiceName = 'ajudadorabot-production-api'
        AcrName = 'ajudadorabotregistryproduction'
        ApplicationInsights = 'ajudadorabot-production-insights'
    }
}

Write-Host "🔍 Starting Azure Container Monitoring" -ForegroundColor Green
Write-Host "Environment(s): $Environment" -ForegroundColor Yellow
Write-Host "Duration: $DurationMinutes minutes" -ForegroundColor Yellow

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

# Function to get container health status
function Get-ContainerHealth {
    param([string]$AppServiceName, [string]$ResourceGroup)
    
    try {
        $appDetails = az webapp show --name $AppServiceName --resource-group $ResourceGroup --output json | ConvertFrom-Json
        
        $health = @{
            State = $appDetails.state
            UsageState = $appDetails.usageState
            HostNames = $appDetails.defaultHostName
            Kind = $appDetails.kind
            LastModifiedTimeUtc = $appDetails.lastModifiedTimeUtc
        }
        
        # Test health endpoint
        try {
            $healthUrl = "https://$($appDetails.defaultHostName)/health"
            $response = Invoke-WebRequest -Uri $healthUrl -Method GET -TimeoutSec 10 -UseBasicParsing
            $health.HealthEndpoint = @{
                StatusCode = $response.StatusCode
                Status = "Healthy"
                ResponseTime = $response.Headers.'X-Response-Time'
            }
        }
        catch {
            $health.HealthEndpoint = @{
                Status = "Unhealthy"
                Error = $_.Exception.Message
            }
        }
        
        return $health
    }
    catch {
        Write-Log "Error getting container health for $AppServiceName`: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Function to get container metrics
function Get-ContainerMetrics {
    param([string]$AppServiceName, [string]$ResourceGroup, [datetime]$StartTime, [datetime]$EndTime)
    
    try {
        $metrics = @{}
        
        # CPU usage
        $cpuMetrics = az monitor metrics list `
            --resource "/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$AppServiceName" `
            --metric "CpuPercentage" `
            --start-time $StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $EndTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --aggregation Average Maximum `
            --output json | ConvertFrom-Json
        
        if ($cpuMetrics.value -and $cpuMetrics.value[0].timeseries) {
            $cpuData = $cpuMetrics.value[0].timeseries[0].data
            $metrics.CPU = @{
                Average = ($cpuData | Where-Object { $_.average } | Measure-Object -Property average -Average).Average
                Maximum = ($cpuData | Where-Object { $_.maximum } | Measure-Object -Property maximum -Maximum).Maximum
                DataPoints = $cpuData.Count
            }
        }
        
        # Memory usage
        $memoryMetrics = az monitor metrics list `
            --resource "/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$AppServiceName" `
            --metric "MemoryPercentage" `
            --start-time $StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $EndTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --aggregation Average Maximum `
            --output json | ConvertFrom-Json
        
        if ($memoryMetrics.value -and $memoryMetrics.value[0].timeseries) {
            $memoryData = $memoryMetrics.value[0].timeseries[0].data
            $metrics.Memory = @{
                Average = ($memoryData | Where-Object { $_.average } | Measure-Object -Property average -Average).Average
                Maximum = ($memoryData | Where-Object { $_.maximum } | Measure-Object -Property maximum -Maximum).Maximum
                DataPoints = $memoryData.Count
            }
        }
        
        # HTTP requests
        $httpMetrics = az monitor metrics list `
            --resource "/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$AppServiceName" `
            --metric "Requests" `
            --start-time $StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $EndTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --aggregation Total `
            --output json | ConvertFrom-Json
        
        if ($httpMetrics.value -and $httpMetrics.value[0].timeseries) {
            $httpData = $httpMetrics.value[0].timeseries[0].data
            $metrics.HTTP = @{
                TotalRequests = ($httpData | Where-Object { $_.total } | Measure-Object -Property total -Sum).Sum
                DataPoints = $httpData.Count
            }
        }
        
        return $metrics
    }
    catch {
        Write-Log "Error getting container metrics for $AppServiceName`: $($_.Exception.Message)" "ERROR"
        return @{}
    }
}

# Function to get Application Insights data
function Get-ApplicationInsightsData {
    param([string]$AppInsightsName, [string]$ResourceGroup, [datetime]$StartTime, [datetime]$EndTime)
    
    try {
        # Get Application Insights App ID
        $appInsights = az monitor app-insights component show --app $AppInsightsName --resource-group $ResourceGroup --output json | ConvertFrom-Json
        $appId = $appInsights.appId
        
        # Query for exceptions
        $exceptionsQuery = @"
exceptions
| where timestamp between (datetime('$($StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ"))') .. datetime('$($EndTime.ToString("yyyy-MM-ddTHH:mm:ssZ"))'))
| summarize count() by bin(timestamp, 5m), type
| order by timestamp desc
"@
        
        $exceptionsData = az monitor app-insights query --app $appId --analytics-query $exceptionsQuery --output json | ConvertFrom-Json
        
        # Query for performance data
        $performanceQuery = @"
requests
| where timestamp between (datetime('$($StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ"))') .. datetime('$($EndTime.ToString("yyyy-MM-ddTHH:mm:ssZ"))'))
| summarize 
    avg(duration),
    percentile(duration, 95),
    count()
by bin(timestamp, 5m)
| order by timestamp desc
"@
        
        $performanceData = az monitor app-insights query --app $appId --analytics-query $performanceQuery --output json | ConvertFrom-Json
        
        return @{
            Exceptions = $exceptionsData.tables[0].rows
            Performance = $performanceData.tables[0].rows
        }
    }
    catch {
        Write-Log "Error getting Application Insights data for $AppInsightsName`: $($_.Exception.Message)" "ERROR"
        return @{}
    }
}

# Function to check container logs for errors
function Get-ContainerErrors {
    param([string]$AppServiceName, [string]$ResourceGroup)
    
    try {
        Write-Log "Checking container logs for errors..." "INFO"
        $logOutput = az webapp log tail --name $AppServiceName --resource-group $ResourceGroup --timeout 30 2>&1
        
        $errors = @()
        $warnings = @()
        
        foreach ($line in $logOutput) {
            if ($line -match "ERROR|Exception|Failed") {
                $errors += $line
            }
            elseif ($line -match "WARN|WARNING") {
                $warnings += $line
            }
        }
        
        return @{
            Errors = $errors
            Warnings = $warnings
            TotalLines = $logOutput.Count
        }
    }
    catch {
        Write-Log "Error getting container logs for $AppServiceName`: $($_.Exception.Message)" "ERROR"
        return @{
            Errors = @("Failed to retrieve logs: $($_.Exception.Message)")
            Warnings = @()
            TotalLines = 0
        }
    }
}

# Function to generate monitoring report
function Generate-MonitoringReport {
    param([hashtable]$MonitoringData, [string]$Environment, [datetime]$StartTime, [datetime]$EndTime)
    
    $reportPath = Join-Path $OutputPath "container-monitoring-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AjudadoraBot Container Monitoring Report - $Environment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .healthy { color: green; font-weight: bold; }
        .unhealthy { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        .metric { margin: 10px 0; }
        .error-log { background-color: #ffe6e6; padding: 10px; margin: 5px 0; border-left: 4px solid red; }
        .warning-log { background-color: #fff3cd; padding: 10px; margin: 5px 0; border-left: 4px solid orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>AjudadoraBot Container Monitoring Report</h1>
        <p><strong>Environment:</strong> $Environment</p>
        <p><strong>Period:</strong> $($StartTime.ToString("yyyy-MM-dd HH:mm:ss")) - $($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))</p>
        <p><strong>Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    </div>
"@
    
    # Add health status
    $healthStatus = if ($MonitoringData.Health.HealthEndpoint.Status -eq "Healthy") { "healthy" } else { "unhealthy" }
    $html += @"
    <div class="section">
        <h2>Container Health Status</h2>
        <p><strong>Overall Status:</strong> <span class="$healthStatus">$($MonitoringData.Health.HealthEndpoint.Status)</span></p>
        <p><strong>App State:</strong> $($MonitoringData.Health.State)</p>
        <p><strong>Usage State:</strong> $($MonitoringData.Health.UsageState)</p>
        <p><strong>Host Name:</strong> $($MonitoringData.Health.HostNames)</p>
    </div>
"@
    
    # Add metrics
    if ($MonitoringData.Metrics.CPU) {
        $html += @"
    <div class="section">
        <h2>Performance Metrics</h2>
        <div class="metric">
            <h3>CPU Usage</h3>
            <p>Average: $([math]::Round($MonitoringData.Metrics.CPU.Average, 2))%</p>
            <p>Maximum: $([math]::Round($MonitoringData.Metrics.CPU.Maximum, 2))%</p>
        </div>
"@
    }
    
    if ($MonitoringData.Metrics.Memory) {
        $html += @"
        <div class="metric">
            <h3>Memory Usage</h3>
            <p>Average: $([math]::Round($MonitoringData.Metrics.Memory.Average, 2))%</p>
            <p>Maximum: $([math]::Round($MonitoringData.Metrics.Memory.Maximum, 2))%</p>
        </div>
"@
    }
    
    if ($MonitoringData.Metrics.HTTP) {
        $html += @"
        <div class="metric">
            <h3>HTTP Requests</h3>
            <p>Total Requests: $($MonitoringData.Metrics.HTTP.TotalRequests)</p>
        </div>
    </div>
"@
    }
    
    # Add errors and warnings
    if ($MonitoringData.Logs.Errors.Count -gt 0 -or $MonitoringData.Logs.Warnings.Count -gt 0) {
        $html += @"
    <div class="section">
        <h2>Log Analysis</h2>
"@
        
        if ($MonitoringData.Logs.Errors.Count -gt 0) {
            $html += "<h3>Errors ($($MonitoringData.Logs.Errors.Count))</h3>"
            foreach ($error in $MonitoringData.Logs.Errors | Select-Object -First 10) {
                $html += "<div class='error-log'>$error</div>"
            }
        }
        
        if ($MonitoringData.Logs.Warnings.Count -gt 0) {
            $html += "<h3>Warnings ($($MonitoringData.Logs.Warnings.Count))</h3>"
            foreach ($warning in $MonitoringData.Logs.Warnings | Select-Object -First 10) {
                $html += "<div class='warning-log'>$warning</div>"
            }
        }
        
        $html += "</div>"
    }
    
    $html += @"
</body>
</html>
"@
    
    $html | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Log "Monitoring report generated: $reportPath" "SUCCESS"
    return $reportPath
}

# Main monitoring function
function Start-ContainerMonitoring {
    $startTime = (Get-Date).AddMinutes(-$DurationMinutes)
    $endTime = Get-Date
    $reports = @()
    
    foreach ($env in $environments.Keys) {
        Write-Log "Monitoring $env environment..." "INFO"
        $config = $environments[$env]
        
        $monitoringData = @{}
        
        # Get container health
        Write-Log "Checking container health..." "INFO"
        $monitoringData.Health = Get-ContainerHealth -AppServiceName $config.AppServiceName -ResourceGroup $config.ResourceGroup
        
        if ($monitoringData.Health) {
            $healthStatus = $monitoringData.Health.HealthEndpoint.Status
            Write-Log "Container health: $healthStatus" $(if ($healthStatus -eq "Healthy") { "SUCCESS" } else { "ERROR" })
        }
        
        # Get metrics
        Write-Log "Collecting performance metrics..." "INFO"
        $monitoringData.Metrics = Get-ContainerMetrics -AppServiceName $config.AppServiceName -ResourceGroup $config.ResourceGroup -StartTime $startTime -EndTime $endTime
        
        if ($monitoringData.Metrics.CPU) {
            Write-Log "CPU - Avg: $([math]::Round($monitoringData.Metrics.CPU.Average, 2))%, Max: $([math]::Round($monitoringData.Metrics.CPU.Maximum, 2))%" "INFO"
        }
        if ($monitoringData.Metrics.Memory) {
            Write-Log "Memory - Avg: $([math]::Round($monitoringData.Metrics.Memory.Average, 2))%, Max: $([math]::Round($monitoringData.Metrics.Memory.Maximum, 2))%" "INFO"
        }
        
        # Get Application Insights data
        Write-Log "Collecting Application Insights data..." "INFO"
        $monitoringData.AppInsights = Get-ApplicationInsightsData -AppInsightsName $config.ApplicationInsights -ResourceGroup $config.ResourceGroup -StartTime $startTime -EndTime $endTime
        
        # Check container logs
        Write-Log "Analyzing container logs..." "INFO"
        $monitoringData.Logs = Get-ContainerErrors -AppServiceName $config.AppServiceName -ResourceGroup $config.ResourceGroup
        
        if ($monitoringData.Logs.Errors.Count -gt 0) {
            Write-Log "Found $($monitoringData.Logs.Errors.Count) errors in logs" "WARN"
        }
        if ($monitoringData.Logs.Warnings.Count -gt 0) {
            Write-Log "Found $($monitoringData.Logs.Warnings.Count) warnings in logs" "WARN"
        }
        
        # Generate report if requested
        if ($GenerateReport) {
            $reportPath = Generate-MonitoringReport -MonitoringData $monitoringData -Environment $env -StartTime $startTime -EndTime $endTime
            $reports += $reportPath
        }
        
        Write-Log "Completed monitoring for $env environment" "SUCCESS"
    }
    
    return $reports
}

# Execute monitoring
do {
    $reports = Start-ContainerMonitoring
    
    if ($reports.Count -gt 0) {
        Write-Log "Generated $($reports.Count) monitoring report(s):" "INFO"
        foreach ($report in $reports) {
            Write-Log "  - $report" "INFO"
        }
    }
    
    if ($Continuous) {
        Write-Log "Waiting 5 minutes before next monitoring cycle..." "INFO"
        Start-Sleep -Seconds 300
    }
} while ($Continuous)

Write-Log "🎉 Container monitoring completed!" "SUCCESS"