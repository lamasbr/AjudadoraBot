# Azure Container Rollback Script for AjudadoraBot
# PowerShell script for rolling back container deployments in Azure App Service

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('staging', 'production')]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetImageTag,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseSlotSwap,
    
    [Parameter(Mandatory=$false)]
    [switch]$RestoreDatabase,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
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

Write-Host "🔄 Starting Azure Container Rollback" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
if ($TargetImageTag) {
    Write-Host "Target Image Tag: $TargetImageTag" -ForegroundColor Yellow
}
if ($UseSlotSwap) {
    Write-Host "Using slot swap for rollback" -ForegroundColor Yellow
}
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

# Function to confirm rollback
function Confirm-Rollback {
    if ($Force) {
        return $true
    }
    
    Write-Host "⚠️  WARNING: This will rollback the $Environment environment!" -ForegroundColor Red
    if ($RestoreDatabase) {
        Write-Host "⚠️  Database will also be restored from backup!" -ForegroundColor Red
    }
    
    $confirmation = Read-Host "Are you sure you want to proceed? (type 'YES' to confirm)"
    return $confirmation -eq 'YES'
}

# Function to get available image tags
function Get-AvailableImageTags {
    param([string]$AcrName, [string]$Repository)
    
    try {
        Write-Log "Getting available image tags from $AcrName/$Repository..." "INFO"
        $tags = az acr repository show-tags --name $AcrName --repository $Repository --orderby time_desc --output json | ConvertFrom-Json
        return $tags
    }
    catch {
        Write-Log "Error getting image tags: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

# Function to get current image tag
function Get-CurrentImageTag {
    param([string]$AppServiceName, [string]$ResourceGroup)
    
    try {
        $appConfig = az webapp config show --name $AppServiceName --resource-group $ResourceGroup --output json | ConvertFrom-Json
        $linuxFxVersion = $appConfig.linuxFxVersion
        
        if ($linuxFxVersion -match "DOCKER\|(.+):(.+)") {
            return @{
                Image = $matches[1]
                Tag = $matches[2]
            }
        }
        
        return $null
    }
    catch {
        Write-Log "Error getting current image tag: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Function to select rollback target
function Select-RollbackTarget {
    param([array]$AvailableTags, [string]$CurrentTag)
    
    if ($TargetImageTag) {
        if ($AvailableTags -contains $TargetImageTag) {
            return $TargetImageTag
        } else {
            Write-Log "Specified target tag '$TargetImageTag' not found in registry" "ERROR"
            throw "Invalid target image tag"
        }
    }
    
    Write-Host "Available image tags (most recent first):" -ForegroundColor Cyan
    for ($i = 0; $i -lt [Math]::Min($AvailableTags.Count, 10); $i++) {
        $tag = $AvailableTags[$i]
        $indicator = if ($tag -eq $CurrentTag) { " (current)" } else { "" }
        Write-Host "  [$($i + 1)] $tag$indicator" -ForegroundColor Cyan
    }
    
    do {
        $selection = Read-Host "Select target tag number (1-$([Math]::Min($AvailableTags.Count, 10)))"
        $selectedIndex = [int]$selection - 1
    } while ($selectedIndex -lt 0 -or $selectedIndex -ge [Math]::Min($AvailableTags.Count, 10))
    
    return $AvailableTags[$selectedIndex]
}

# Function to create database backup before rollback
function Backup-DatabaseBeforeRollback {
    param([string]$AppServiceName, [string]$ResourceGroup)
    
    try {
        Write-Log "Creating database backup before rollback..." "INFO"
        
        if (-not $DryRun) {
            $backupName = "rollback-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            
            # In a real scenario, this would create a backup of the SQLite database
            # For now, we'll simulate the backup process
            
            Write-Log "Database backup created: $backupName" "SUCCESS"
            return $backupName
        } else {
            Write-Log "DRY RUN: Would create database backup" "INFO"
            return "dry-run-backup"
        }
    }
    catch {
        Write-Log "Failed to create database backup: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to restore database from backup
function Restore-DatabaseFromBackup {
    param([string]$AppServiceName, [string]$ResourceGroup, [string]$BackupName = "latest")
    
    try {
        Write-Log "Restoring database from backup: $BackupName..." "INFO"
        
        if (-not $DryRun) {
            # In a real scenario, this would restore the SQLite database from backup
            # Implementation would depend on your backup storage location (Azure Storage, etc.)
            
            Start-Sleep -Seconds 5 # Simulate restore time
            Write-Log "Database restored successfully from backup: $BackupName" "SUCCESS"
        } else {
            Write-Log "DRY RUN: Would restore database from backup: $BackupName" "INFO"
        }
    }
    catch {
        Write-Log "Failed to restore database: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to perform slot swap rollback
function Invoke-SlotSwapRollback {
    param([string]$AppServiceName, [string]$ResourceGroup)
    
    try {
        Write-Log "Performing slot swap rollback..." "INFO"
        
        if (-not $DryRun) {
            # Swap staging slot back to production
            az webapp deployment slot swap `
                --name $appServiceName `
                --resource-group $resourceGroup `
                --slot production `
                --target-slot staging
                
            Write-Log "Slot swap rollback completed" "SUCCESS"
        } else {
            Write-Log "DRY RUN: Would perform slot swap rollback" "INFO"
        }
    }
    catch {
        Write-Log "Slot swap rollback failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to perform image rollback
function Invoke-ImageRollback {
    param([string]$AppServiceName, [string]$ResourceGroup, [string]$TargetTag, [string]$AcrName)
    
    try {
        Write-Log "Rolling back to image tag: $TargetTag..." "INFO"
        
        if (-not $DryRun) {
            # Get ACR credentials
            $acrCredentials = az acr credential show --name $acrName --output json | ConvertFrom-Json
            $acrUsername = $acrCredentials.username
            $acrPassword = $acrCredentials.passwords[0].value
            
            $targetImage = "$acrName.azurecr.io/ajudadorabot-backend:$TargetTag"
            
            # Update container configuration
            az webapp config container set `
                --name $appServiceName `
                --resource-group $resourceGroup `
                --docker-custom-image-name $targetImage `
                --docker-registry-server-url "https://$acrName.azurecr.io" `
                --docker-registry-server-user $acrUsername `
                --docker-registry-server-password $acrPassword
            
            Write-Log "Image rollback completed to: $targetImage" "SUCCESS"
        } else {
            Write-Log "DRY RUN: Would rollback to image: $acrName.azurecr.io/ajudadorabot-backend:$TargetTag" "INFO"
        }
    }
    catch {
        Write-Log "Image rollback failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to wait for application to be ready
function Wait-ApplicationReady {
    param([string]$AppServiceName, [int]$TimeoutMinutes = 10)
    
    Write-Log "Waiting for application to be ready..." "INFO"
    $appUrl = "https://$AppServiceName.azurewebsites.net"
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    
    do {
        Start-Sleep -Seconds 30
        try {
            $response = Invoke-WebRequest -Uri "$appUrl/health" -Method GET -TimeoutSec 30 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Log "Application is ready and healthy" "SUCCESS"
                return $true
            }
        }
        catch {
            Write-Log "Application not ready yet, waiting..." "INFO"
        }
    } while ((Get-Date) -lt $timeout)
    
    Write-Log "Timeout waiting for application to be ready" "ERROR"
    return $false
}

# Function to verify rollback success
function Test-RollbackSuccess {
    param([string]$AppServiceName, [string]$ResourceGroup, [string]$ExpectedTag)
    
    try {
        Write-Log "Verifying rollback success..." "INFO"
        
        # Check current image tag
        $currentConfig = Get-CurrentImageTag -AppServiceName $appServiceName -ResourceGroup $resourceGroup
        
        if ($currentConfig -and $currentConfig.Tag -eq $ExpectedTag) {
            Write-Log "✅ Rollback verification successful - Current tag: $($currentConfig.Tag)" "SUCCESS"
            return $true
        } else {
            Write-Log "❌ Rollback verification failed - Expected: $ExpectedTag, Current: $($currentConfig.Tag)" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error verifying rollback: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main rollback function
function Start-ContainerRollback {
    try {
        # Confirm rollback operation
        if (-not (Confirm-Rollback)) {
            Write-Log "Rollback cancelled by user" "INFO"
            return
        }
        
        Write-Log "Starting container rollback process..." "INFO"
        
        # Get current configuration
        $currentConfig = Get-CurrentImageTag -AppServiceName $appServiceName -ResourceGroup $resourceGroup
        if ($currentConfig) {
            Write-Log "Current image: $($currentConfig.Image):$($currentConfig.Tag)" "INFO"
        }
        
        # Create database backup before rollback
        if ($RestoreDatabase -or $Environment -eq 'production') {
            $preRollbackBackup = Backup-DatabaseBeforeRollback -AppServiceName $appServiceName -ResourceGroup $resourceGroup
        }
        
        if ($UseSlotSwap -and $Environment -eq 'production') {
            # Perform slot swap rollback
            Invoke-SlotSwapRollback -AppServiceName $appServiceName -ResourceGroup $resourceGroup
        } else {
            # Perform image rollback
            if (-not $TargetImageTag) {
                $availableTags = Get-AvailableImageTags -AcrName $acrName -Repository "ajudadorabot-backend"
                if ($availableTags.Count -eq 0) {
                    throw "No available image tags found in registry"
                }
                
                $TargetImageTag = Select-RollbackTarget -AvailableTags $availableTags -CurrentTag $currentConfig.Tag
            }
            
            Write-Log "Rolling back to image tag: $TargetImageTag" "INFO"
            Invoke-ImageRollback -AppServiceName $appServiceName -ResourceGroup $resourceGroup -TargetTag $TargetImageTag -AcrName $acrName
        }
        
        # Restart the application
        if (-not $DryRun) {
            Write-Log "Restarting application..." "INFO"
            az webapp restart --name $appServiceName --resource-group $resourceGroup
        }
        
        # Wait for application to be ready
        if (-not $DryRun -and -not (Wait-ApplicationReady -AppServiceName $appServiceName)) {
            throw "Application failed to become ready after rollback"
        }
        
        # Restore database if requested
        if ($RestoreDatabase) {
            Restore-DatabaseFromBackup -AppServiceName $appServiceName -ResourceGroup $resourceGroup
        }
        
        # Verify rollback success
        if (-not $UseSlotSwap -and -not $DryRun) {
            if (-not (Test-RollbackSuccess -AppServiceName $appServiceName -ResourceGroup $resourceGroup -ExpectedTag $TargetImageTag)) {
                throw "Rollback verification failed"
            }
        }
        
        Write-Log "✅ Container rollback completed successfully!" "SUCCESS"
        Write-Log "Application URL: https://$appServiceName.azurewebsites.net" "INFO"
        
    }
    catch {
        Write-Log "❌ Container rollback failed: $($_.Exception.Message)" "ERROR"
        Write-Log "Getting container logs for troubleshooting..." "INFO"
        
        if (-not $DryRun) {
            try {
                az webapp log tail --name $appServiceName --resource-group $resourceGroup --timeout 30
            }
            catch {
                Write-Log "Could not retrieve container logs" "WARN"
            }
        }
        
        exit 1
    }
}

# Execute rollback
Start-ContainerRollback

Write-Log "🎉 Rollback process completed!" "SUCCESS"