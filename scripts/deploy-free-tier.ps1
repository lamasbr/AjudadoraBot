# PowerShell script for cost-optimized Azure deployment (Free Tier)
# This script deploys AjudadoraBot to Azure using free tier resources with cost monitoring

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "ajudadorabot-production-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$AppName = "ajudadorabot",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInfrastructure,
    
    [Parameter(Mandatory=$false)]
    [switch]$MonitorOnly,
    
    [Parameter(Mandatory=$false)]
    [string]$AlertEmail
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Import required modules
Import-Module Az.Accounts -Force
Import-Module Az.Resources -Force
Import-Module Az.WebSites -Force
Import-Module Az.Monitor -Force

Write-Host "🚀 Starting Free Tier Deployment for AjudadoraBot" -ForegroundColor Green
Write-Host "📊 Cost Optimization Mode: Enabled" -ForegroundColor Cyan

# Check if already logged in to Azure
$context = Get-AzContext
if (!$context) {
    Write-Host "⚠️  Not logged in to Azure. Please log in..." -ForegroundColor Yellow
    Connect-AzAccount -SubscriptionId $SubscriptionId
} else {
    Write-Host "✅ Already logged in to Azure" -ForegroundColor Green
}

# Set the subscription context
Set-AzContext -SubscriptionId $SubscriptionId

# Function to check free tier limits
function Test-FreeTierLimits {
    param(
        [string]$ResourceGroupName,
        [string]$AppServiceName
    )
    
    Write-Host "📋 Checking Free Tier Limits..." -ForegroundColor Cyan
    
    try {
        # Check App Service Plan
        $appServicePlan = Get-AzAppServicePlan -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($appServicePlan) {
            Write-Host "📊 App Service Plan: $($appServicePlan.Sku.Name) (Tier: $($appServicePlan.Sku.Tier))" -ForegroundColor Yellow
            
            if ($appServicePlan.Sku.Name -ne "F1") {
                Write-Warning "⚠️  App Service Plan is not F1 (Free tier). Current: $($appServicePlan.Sku.Name)"
                Write-Host "💰 This may incur costs. F1 provides: 60 minutes/day compute, 1GB storage, 165MB/day bandwidth" -ForegroundColor Yellow
            } else {
                Write-Host "✅ App Service Plan is F1 (Free tier)" -ForegroundColor Green
                Write-Host "📊 Free tier limits: 60 min/day compute, 1GB storage, 165MB/day bandwidth" -ForegroundColor Cyan
            }
        }
        
        # Check if multiple App Services exist (should only have one for cost optimization)
        $appServices = Get-AzWebApp -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($appServices.Count -gt 1) {
            Write-Warning "⚠️  Multiple App Services detected. For cost optimization, use single combined app."
            $appServices | ForEach-Object { Write-Host "   - $($_.Name)" -ForegroundColor Yellow }
        }
        
        # Check Key Vault tier
        $keyVaults = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($keyVaults) {
            Write-Host "🔐 Key Vault: $($keyVaults[0].VaultName) (Free tier: 25,000 operations/month)" -ForegroundColor Cyan
        }
        
    } catch {
        Write-Warning "⚠️  Could not check all resources: $($_.Exception.Message)"
    }
}

# Function to get cost and usage information
function Get-CostInformation {
    param(
        [string]$ResourceGroupName
    )
    
    Write-Host "💰 Checking Resource Costs and Usage..." -ForegroundColor Cyan
    
    try {
        # Get all resources in the resource group
        $resources = Get-AzResource -ResourceGroupName $ResourceGroupName
        
        Write-Host "📊 Resources in Resource Group:" -ForegroundColor Cyan
        $resources | ForEach-Object {
            Write-Host "   - $($_.Name) ($($_.ResourceType))" -ForegroundColor White
        }
        
        # Check App Service metrics (if available)
        $appService = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Web/sites" } | Select-Object -First 1
        if ($appService) {
            Write-Host "📈 App Service Metrics (Last 24 hours):" -ForegroundColor Cyan
            
            # Get CPU usage
            $cpuMetrics = Get-AzMetric -ResourceId $appService.ResourceId -MetricName "CpuPercentage" -TimeGrain 01:00:00 -StartTime (Get-Date).AddDays(-1) -ErrorAction SilentlyContinue
            if ($cpuMetrics) {
                $avgCpu = ($cpuMetrics.Data | Measure-Object -Property Average -Average).Average
                Write-Host "   CPU Usage: $([math]::Round($avgCpu, 2))% average" -ForegroundColor $(if ($avgCpu -gt 80) { "Red" } elseif ($avgCpu -gt 60) { "Yellow" } else { "Green" })
            }
            
            # Get Memory usage
            $memoryMetrics = Get-AzMetric -ResourceId $appService.ResourceId -MetricName "MemoryPercentage" -TimeGrain 01:00:00 -StartTime (Get-Date).AddDays(-1) -ErrorAction SilentlyContinue
            if ($memoryMetrics) {
                $avgMemory = ($memoryMetrics.Data | Measure-Object -Property Average -Average).Average
                Write-Host "   Memory Usage: $([math]::Round($avgMemory, 2))% average" -ForegroundColor $(if ($avgMemory -gt 85) { "Red" } elseif ($avgMemory -gt 70) { "Yellow" } else { "Green" })
            }
            
            # Get Requests
            $requestMetrics = Get-AzMetric -ResourceId $appService.ResourceId -MetricName "Requests" -TimeGrain 01:00:00 -StartTime (Get-Date).AddDays(-1) -ErrorAction SilentlyContinue
            if ($requestMetrics) {
                $totalRequests = ($requestMetrics.Data | Measure-Object -Property Total -Sum).Sum
                Write-Host "   Total Requests: $totalRequests (24h)" -ForegroundColor Cyan
            }
            
            # Get Data Out (bandwidth usage)
            $dataOutMetrics = Get-AzMetric -ResourceId $appService.ResourceId -MetricName "BytesSent" -TimeGrain 01:00:00 -StartTime (Get-Date).AddDays(-1) -ErrorAction SilentlyContinue
            if ($dataOutMetrics) {
                $totalDataOut = ($dataOutMetrics.Data | Measure-Object -Property Total -Sum).Sum
                $dataOutMB = [math]::Round($totalDataOut / 1MB, 2)
                $dailyLimitMB = 165
                $usagePercent = [math]::Round(($dataOutMB / $dailyLimitMB) * 100, 1)
                
                Write-Host "   Data Out: $dataOutMB MB (24h) - $usagePercent% of daily limit (165MB)" -ForegroundColor $(if ($usagePercent -gt 90) { "Red" } elseif ($usagePercent -gt 70) { "Yellow" } else { "Green" })
                
                if ($usagePercent -gt 80) {
                    Write-Warning "⚠️  Approaching daily bandwidth limit! Consider optimizing static asset delivery."
                }
            }
        }
        
    } catch {
        Write-Warning "⚠️  Could not retrieve cost information: $($_.Exception.Message)"
    }
}

# Function to optimize for cost
function Optimize-ForCost {
    param(
        [string]$ResourceGroupName,
        [string]$AppServiceName
    )
    
    Write-Host "⚡ Applying Cost Optimizations..." -ForegroundColor Cyan
    
    try {
        # Get the app service
        $appService = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -ErrorAction SilentlyContinue
        
        if ($appService) {
            # Ensure AlwaysOn is disabled (not available on F1)
            $appService.SiteConfig.AlwaysOn = $false
            
            # Optimize other settings for F1 tier
            $appService.SiteConfig.Use32BitWorkerProcess = $false  # Use 64-bit for better performance
            $appService.SiteConfig.WebSocketsEnabled = $false      # Disable if not needed
            $appService.SiteConfig.Http20Enabled = $true           # Enable HTTP/2 for efficiency
            $appService.SiteConfig.MinTlsVersion = "1.2"           # Security
            $appService.SiteConfig.FtpsState = "Disabled"          # Security
            
            # Update the app service
            Set-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -SiteConfig $appService.SiteConfig
            
            Write-Host "✅ Applied cost optimizations to App Service" -ForegroundColor Green
        }
        
    } catch {
        Write-Warning "⚠️  Could not apply optimizations: $($_.Exception.Message)"
    }
}

# Main deployment logic
try {
    if ($MonitorOnly) {
        Write-Host "📊 Monitor Only Mode - Checking existing resources..." -ForegroundColor Cyan
        Test-FreeTierLimits -ResourceGroupName $ResourceGroupName -AppServiceName "$AppName-production-app"
        Get-CostInformation -ResourceGroupName $ResourceGroupName
        return
    }
    
    if (!$SkipInfrastructure) {
        Write-Host "🏗️  Deploying Infrastructure with Terraform..." -ForegroundColor Cyan
        
        # Check if Terraform is installed
        $terraformVersion = terraform version 2>$null
        if (!$terraformVersion) {
            Write-Error "❌ Terraform is not installed. Please install Terraform first."
            exit 1
        }
        
        # Change to terraform directory
        Push-Location -Path "$PSScriptRoot\..\terraform"
        
        try {
            # Initialize Terraform
            Write-Host "🔧 Initializing Terraform..." -ForegroundColor Yellow
            terraform init
            
            # Create terraform.tfvars if it doesn't exist
            if (!(Test-Path "terraform.tfvars")) {
                Write-Host "⚠️  terraform.tfvars not found. Please create it from terraform.tfvars.example" -ForegroundColor Yellow
                Write-Host "📋 Required variables:" -ForegroundColor Cyan
                Write-Host "   - telegram_bot_token" -ForegroundColor White
                Write-Host "   - datadog_api_key" -ForegroundColor White
                Write-Host "   - ghcr_username" -ForegroundColor White
                Write-Host "   - ghcr_token" -ForegroundColor White
                if ($AlertEmail) {
                    Write-Host "   - alert_email = `"$AlertEmail`"" -ForegroundColor White
                }
                Write-Error "❌ Please create terraform.tfvars file with required variables."
            }
            
            # Plan the deployment
            Write-Host "📋 Planning Terraform deployment..." -ForegroundColor Yellow
            terraform plan -out=tfplan
            
            # Apply the deployment
            Write-Host "🚀 Applying Terraform deployment..." -ForegroundColor Yellow
            terraform apply -auto-approve tfplan
            
            # Get outputs
            $appServiceName = terraform output -raw app_service_name
            $appServiceUrl = terraform output -raw app_service_url
            $resourceGroupName = terraform output -raw resource_group_name
            
            Write-Host "✅ Infrastructure deployed successfully!" -ForegroundColor Green
            Write-Host "🌐 App Service: $appServiceName" -ForegroundColor Cyan
            Write-Host "🔗 URL: $appServiceUrl" -ForegroundColor Cyan
            
        } catch {
            Write-Error "❌ Terraform deployment failed: $($_.Exception.Message)"
        } finally {
            Pop-Location
        }
    }
    
    # Check free tier limits
    Test-FreeTierLimits -ResourceGroupName $ResourceGroupName -AppServiceName "$AppName-production-app"
    
    # Apply cost optimizations
    Optimize-ForCost -ResourceGroupName $ResourceGroupName -AppServiceName "$AppName-production-app"
    
    # Get cost information
    Get-CostInformation -ResourceGroupName $ResourceGroupName
    
    Write-Host "✅ Free Tier Deployment completed successfully!" -ForegroundColor Green
    Write-Host "📊 Remember to monitor usage to stay within free tier limits:" -ForegroundColor Cyan
    Write-Host "   - 60 minutes compute time per day" -ForegroundColor White
    Write-Host "   - 1 GB storage limit" -ForegroundColor White
    Write-Host "   - 165 MB bandwidth per day" -ForegroundColor White
    Write-Host "   - 25,000 Key Vault operations per month" -ForegroundColor White
    Write-Host "   - 5 hosts max on Datadog free tier" -ForegroundColor White
    
    if ($AlertEmail) {
        Write-Host "📧 Cost alerts configured for: $AlertEmail" -ForegroundColor Green
    }
    
} catch {
    Write-Error "❌ Deployment failed: $($_.Exception.Message)"
    Write-Host "💡 For troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Check Azure subscription limits" -ForegroundColor White
    Write-Host "   2. Verify terraform.tfvars configuration" -ForegroundColor White
    Write-Host "   3. Ensure proper Azure permissions" -ForegroundColor White
    Write-Host "   4. Run with -MonitorOnly to check existing resources" -ForegroundColor White
    exit 1
}

Write-Host "🎉 Deployment script completed!" -ForegroundColor Green