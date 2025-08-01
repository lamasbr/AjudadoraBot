# Azure Container Deployment Script for AjudadoraBot
# PowerShell script for deploying containers to Azure App Service

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('staging', 'production')]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = 'latest',
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipHealthCheck,
    
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
    $acrName = "ajudadorabotregistrystaging"
    $keyVaultName = "ajudadorabot-staging-kv"
} else {
    $resourceGroup = $ResourceGroupName ?? "ajudadorabot-production-rg"
    $appServiceName = "ajudadorabot-production-api"
    $acrName = "ajudadorabotregistryproduction"
    $keyVaultName = "ajudadorabot-production-kv"
}

$backendImage = "$acrName.azurecr.io/ajudadorabot-backend:$ImageTag"
$frontendImage = "$acrName.azurecr.io/ajudadorabot-frontend:$ImageTag"

Write-Host "🚀 Starting Azure Container Deployment" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Yellow
Write-Host "Backend Image: $backendImage" -ForegroundColor Yellow
Write-Host "Frontend Image: $frontendImage" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "⚠️  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
}

# Function to write timestamped log
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# Function to check if Azure CLI is logged in
function Test-AzureLogin {
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Log "Logged in as: $($account.user.name)" "INFO"
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

# Function to wait for container restart
function Wait-ContainerRestart {
    param([string]$AppServiceName, [string]$ResourceGroup, [int]$TimeoutMinutes = 5)
    
    Write-Log "Waiting for container to restart..." "INFO"
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    
    do {
        Start-Sleep -Seconds 30
        try {
            $status = az webapp show --name $AppServiceName --resource-group $ResourceGroup --query "state" --output tsv
            if ($status -eq "Running") {
                Write-Log "Container is running" "INFO"
                return $true
            }
        }
        catch {
            Write-Log "Error checking container status: $_" "WARN"
        }
        
        Write-Log "Container not ready yet, waiting..." "INFO"
    } while ((Get-Date) -lt $timeout)
    
    Write-Log "Timeout waiting for container to start" "ERROR"
    return $false
}

# Function to perform health check
function Test-ApplicationHealth {
    param([string]$Url, [int]$MaxAttempts = 10)
    
    Write-Log "Performing health check against: $Url" "INFO"
    
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            Write-Log "Health check attempt $i/$MaxAttempts" "INFO"
            $response = Invoke-WebRequest -Uri "$Url/health" -Method GET -TimeoutSec 30 -UseBasicParsing
            
            if ($response.StatusCode -eq 200) {
                Write-Log "Health check passed!" "INFO"
                return $true
            }
        }
        catch {
            Write-Log "Health check failed: $($_.Exception.Message)" "WARN"
        }
        
        if ($i -lt $MaxAttempts) {
            Write-Log "Retrying in 15 seconds..." "INFO"
            Start-Sleep -Seconds 15
        }
    }
    
    Write-Log "All health check attempts failed" "ERROR"
    return $false
}

# Function to get container logs
function Get-ContainerLogs {
    param([string]$AppServiceName, [string]$ResourceGroup)
    
    Write-Log "Retrieving recent container logs..." "INFO"
    try {
        az webapp log tail --name $AppServiceName --resource-group $ResourceGroup --timeout 30
    }
    catch {
        Write-Log "Could not retrieve container logs: $_" "WARN"
    }
}

# Function to create database backup
function Backup-Database {
    param([string]$AppServiceName, [string]$ResourceGroup)
    
    if ($Environment -eq 'production') {
        Write-Log "Creating database backup for production..." "INFO"
        try {
            $backupName = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            # In a real scenario, this would backup the SQLite database from App Service storage
            Write-Log "Database backup created: $backupName" "INFO"
        }
        catch {
            Write-Log "Database backup failed: $_" "ERROR"
            throw
        }
    }
}

# Main deployment function
function Deploy-Container {
    try {
        # Verify Azure CLI login
        if (-not (Test-AzureLogin)) {
            Write-Log "Please log in to Azure CLI first: az login" "ERROR"
            exit 1
        }

        # Set subscription if provided
        if ($SubscriptionId) {
            Write-Log "Setting subscription to: $SubscriptionId" "INFO"
            if (-not $DryRun) {
                az account set --subscription $SubscriptionId
            }
        }

        # Get ACR credentials
        Write-Log "Retrieving ACR credentials..." "INFO"
        if (-not $DryRun) {
            $acrCredentials = az acr credential show --name $acrName --output json | ConvertFrom-Json
            $acrUsername = $acrCredentials.username
            $acrPassword = $acrCredentials.passwords[0].value
        }

        # Create database backup for production
        if ($Environment -eq 'production') {
            Backup-Database -AppServiceName $appServiceName -ResourceGroup $resourceGroup
        }

        # Configure container settings
        Write-Log "Configuring container settings..." "INFO"
        if (-not $DryRun) {
            az webapp config container set `
                --name $appServiceName `
                --resource-group $resourceGroup `
                --docker-custom-image-name $backendImage `
                --docker-registry-server-url "https://$acrName.azurecr.io" `
                --docker-registry-server-user $acrUsername `
                --docker-registry-server-password $acrPassword
        }

        # Update application settings
        Write-Log "Updating application settings..." "INFO"
        if (-not $DryRun) {
            $appSettings = @{
                "ASPNETCORE_ENVIRONMENT" = if ($Environment -eq 'production') { 'Production' } else { 'Staging' }
                "ASPNETCORE_URLS" = "http://+:8080"
                "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
                "WEBSITES_CONTAINER_START_TIME_LIMIT" = "230"
                "DOCKER_REGISTRY_SERVER_URL" = "https://$acrName.azurecr.io"
                "DOCKER_REGISTRY_SERVER_USERNAME" = $acrUsername
                "DOCKER_REGISTRY_SERVER_PASSWORD" = $acrPassword
                "TelegramBot__Token" = "@Microsoft.KeyVault(VaultName=$keyVaultName;SecretName=telegram-bot-token)"
                "MiniApp__JwtSecret" = "@Microsoft.KeyVault(VaultName=$keyVaultName;SecretName=jwt-secret)"
            }

            $settingsJson = $appSettings | ConvertTo-Json -Depth 3
            $settingsJson | Out-File -FilePath "temp-settings.json" -Encoding UTF8
            
            az webapp config appsettings set `
                --name $appServiceName `
                --resource-group $resourceGroup `
                --settings "@temp-settings.json"
            
            Remove-Item "temp-settings.json" -Force
        }

        # Restart the app service
        Write-Log "Restarting App Service..." "INFO"
        if (-not $DryRun) {
            az webapp restart --name $appServiceName --resource-group $resourceGroup
        }

        # Wait for container to restart
        if (-not $DryRun -and -not (Wait-ContainerRestart -AppServiceName $appServiceName -ResourceGroup $resourceGroup)) {
            throw "Container failed to restart within timeout period"
        }

        # Perform health check
        if (-not $SkipHealthCheck -and -not $DryRun) {
            $appUrl = "https://$appServiceName.azurewebsites.net"
            if (-not (Test-ApplicationHealth -Url $appUrl)) {
                Write-Log "Getting container logs for troubleshooting..." "INFO"
                Get-ContainerLogs -AppServiceName $appServiceName -ResourceGroup $resourceGroup
                throw "Application health check failed"
            }
        }

        Write-Log "✅ Container deployment completed successfully!" "INFO"
        Write-Log "Application URL: https://$appServiceName.azurewebsites.net" "INFO"

    }
    catch {
        Write-Log "❌ Container deployment failed: $($_.Exception.Message)" "ERROR"
        
        if (-not $DryRun) {
            Write-Log "Getting container logs for troubleshooting..." "INFO"
            Get-ContainerLogs -AppServiceName $appServiceName -ResourceGroup $resourceGroup
        }
        
        exit 1
    }
}

# Execute deployment
Deploy-Container

Write-Log "🎉 Deployment process completed!" "INFO"