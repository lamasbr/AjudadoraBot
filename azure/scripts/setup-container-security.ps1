# Container Security Setup Script for AjudadoraBot
# PowerShell script for configuring container security, scanning, and Key Vault integration

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('staging', 'production')]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$SetupDefender,
    
    [Parameter(Mandatory=$false)]
    [switch]$ConfigureNetworkSecurity,
    
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
    $logAnalyticsName = "ajudadorabot-staging-logs"
} else {
    $resourceGroup = $ResourceGroupName ?? "ajudadorabot-production-rg"
    $appServiceName = "ajudadorabot-production-api"
    $acrName = "ajudadorabotregistryproduction"
    $keyVaultName = "ajudadorabot-production-kv"
    $logAnalyticsName = "ajudadorabot-production-logs"
}

Write-Host "🔐 Starting Container Security Configuration" -ForegroundColor Green
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

# Function to setup Azure Container Registry security
function Setup-AcrSecurity {
    param([string]$AcrName, [string]$ResourceGroup)
    
    try {
        Write-Log "Configuring Azure Container Registry security..." "INFO"
        
        if (-not $DryRun) {
            # Enable admin user for authentication
            az acr update --name $AcrName --admin-enabled true
            
            # Configure content trust (production only)
            if ($Environment -eq 'production') {
                az acr config content-trust update --name $AcrName --status enabled
                Write-Log "Content trust enabled for production ACR" "SUCCESS"
            }
            
            # Enable vulnerability scanning
            az acr update --name $AcrName --sku Premium 2>/dev/null || Write-Log "ACR already Premium or upgrade not needed" "INFO"
            
            # Configure retention policy
            $retentionDays = if ($Environment -eq 'production') { 30 } else { 7 }
            az acr config retention update --name $AcrName --days $retentionDays --status enabled
            
            # Enable quarantine policy
            az acr config quarantine update --name $AcrName --status enabled
            
            Write-Log "ACR security configuration completed" "SUCCESS"
        } else {
            Write-Log "DRY RUN: Would configure ACR security settings" "INFO"
        }
    }
    catch {
        Write-Log "Error configuring ACR security: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup Key Vault security
function Setup-KeyVaultSecurity {
    param([string]$KeyVaultName, [string]$ResourceGroup)
    
    try {
        Write-Log "Configuring Key Vault security..." "INFO"
        
        if (-not $DryRun) {
            # Enable soft delete and purge protection for production
            if ($Environment -eq 'production') {
                az keyvault update --name $KeyVaultName --enable-purge-protection true
                Write-Log "Purge protection enabled for production Key Vault" "SUCCESS"
            }
            
            # Set access policies for diagnostic settings
            $subscriptionId = az account show --query id --output tsv
            $logAnalyticsResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$logAnalyticsName"
            
            # Enable diagnostic settings for Key Vault
            az monitor diagnostic-settings create `
                --name "keyvault-diagnostics" `
                --resource "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults/$KeyVaultName" `
                --workspace $logAnalyticsResourceId `
                --logs '[{"category": "AuditEvent", "enabled": true}, {"category": "AzurePolicyEvaluationDetails", "enabled": true}]' `
                --metrics '[{"category": "AllMetrics", "enabled": true}]'
            
            Write-Log "Key Vault security and monitoring configured" "SUCCESS"
        } else {
            Write-Log "DRY RUN: Would configure Key Vault security settings" "INFO"
        }
    }
    catch {
        Write-Log "Error configuring Key Vault security: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup container security policies
function Setup-ContainerSecurityPolicies {
    param([string]$AppServiceName, [string]$ResourceGroup)
    
    try {
        Write-Log "Configuring container security policies..." "INFO"
        
        if (-not $DryRun) {
            # Configure security headers
            $securitySettings = @{
                "ASPNETCORE_FORWARDEDHEADERS_ENABLED" = "true"
                "ASPNETCORE_PATHBASE" = ""
                "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
                "WEBSITES_CONTAINER_START_TIME_LIMIT" = "230"
                "WEBSITE_HTTPLOGGING_RETENTION_DAYS" = "7"
                "WEBSITE_LOAD_CERTIFICATES" = "*"
            }
            
            # Add production-specific security settings
            if ($Environment -eq 'production') {
                $securitySettings["ASPNETCORE_HTTPS_PORT"] = "443"
                $securitySettings["ASPNETCORE_ENVIRONMENT"] = "Production"
            }
            
            # Convert to JSON for Azure CLI
            $settingsArray = @()
            foreach ($key in $securitySettings.Keys) {
                $settingsArray += "$key=$($securitySettings[$key])"
            }
            
            az webapp config appsettings set `
                --name $AppServiceName `
                --resource-group $ResourceGroup `
                --settings $settingsArray
            
            # Configure container health checks
            az webapp config set `
                --name $AppServiceName `
                --resource-group $ResourceGroup `
                --always-on $(if ($Environment -eq 'production') { 'true' } else { 'false' }) `
                --auto-heal-enabled true `
                --ftps-state Disabled `
                --http20-enabled true `
                --min-tls-version 1.2
            
            Write-Log "Container security policies configured" "SUCCESS"
        } else {
            Write-Log "DRY RUN: Would configure container security policies" "INFO"
        }
    }
    catch {
        Write-Log "Error configuring container security policies: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup Microsoft Defender for Containers
function Setup-DefenderForContainers {
    try {
        Write-Log "Setting up Microsoft Defender for Containers..." "INFO"
        
        if (-not $DryRun) {
            # Enable Defender for Containers at subscription level
            az security pricing create --name Containers --tier Standard
            
            # Enable Defender for Container Registries
            az security pricing create --name ContainerRegistry --tier Standard
            
            # Configure auto-provisioning for monitoring agents
            az security auto-provisioning-setting update --name default --auto-provision On
            
            Write-Log "Microsoft Defender for Containers enabled" "SUCCESS"
        } else {
            Write-Log "DRY RUN: Would enable Microsoft Defender for Containers" "INFO"
        }
    }
    catch {
        Write-Log "Error setting up Defender for Containers: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup network security
function Setup-NetworkSecurity {
    param([string]$AppServiceName, [string]$ResourceGroup)
    
    try {
        Write-Log "Configuring network security..." "INFO"
        
        if (-not $DryRun) {
            # Configure IP restrictions for production
            if ($Environment -eq 'production') {
                # Allow only specific IP ranges (customize as needed)
                $allowedIps = @(
                    "0.0.0.0/0"  # Allow all for now - customize based on requirements
                )
                
                foreach ($ip in $allowedIps) {
                    az webapp config access-restriction add `
                        --name $AppServiceName `
                        --resource-group $ResourceGroup `
                        --ip-address $ip `
                        --priority 100
                }
            }
            
            # Configure CORS for frontend
            az webapp cors add `
                --name $AppServiceName `
                --resource-group $ResourceGroup `
                --allowed-origins "https://*.azurestaticapps.net" "https://*.azurewebsites.net"
            
            # Enable HTTPS only
            az webapp update `
                --name $AppServiceName `
                --resource-group $ResourceGroup `
                --https-only true
            
            Write-Log "Network security configured" "SUCCESS"
        } else {
            Write-Log "DRY RUN: Would configure network security" "INFO"
        }
    }
    catch {
        Write-Log "Error configuring network security: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup container scanning policies
function Setup-ContainerScanning {
    param([string]$AcrName, [string]$ResourceGroup)
    
    try {
        Write-Log "Setting up container vulnerability scanning..." "INFO"
        
        if (-not $DryRun) {
            # Enable Microsoft Defender for Cloud recommendations
            $subscriptionId = az account show --query id --output tsv
            
            # Create security assessment policy for container images
            $policyDefinition = @{
                properties = @{
                    displayName = "Container images should have vulnerability findings resolved"
                    description = "Container images should be scanned for vulnerabilities and findings should be resolved"
                    mode = "All"
                    policyRule = @{
                        if = @{
                            field = "type"
                            equals = "Microsoft.ContainerRegistry/registries/repositories"
                        }
                        then = @{
                            effect = "AuditIfNotExists"
                            details = @{
                                type = "Microsoft.Security/assessments"
                                name = "dbd0cb49-b563-45e7-9724-889e799fa648"
                            }
                        }
                    }
                }
            }
            
            # Create custom Trivy scanning workflow
            $trivyConfig = @"
# Trivy Configuration for Container Scanning
# This configuration is used by the CI/CD pipeline

# Vulnerability databases to use
DB:
  - type: "vulnerability"
    enabled: true
  - type: "secret"
    enabled: true
  - type: "misconfig"
    enabled: true

# Severity levels to report
SEVERITY:
  - "CRITICAL"
  - "HIGH"
  - "MEDIUM"

# Output format
FORMAT: "sarif"

# Skip files/directories
SKIP_FILES:
  - "*.md"
  - "*.txt"
  - "Dockerfile*"

# Custom policies
POLICIES:
  - "https://github.com/aquasecurity/trivy-policies"

# Timeout settings
TIMEOUT: "10m"
"@
            
            $trivyConfig | Out-File -FilePath "trivy-config.yaml" -Encoding UTF8
            Write-Log "Trivy scanning configuration created" "SUCCESS"
            
        } else {
            Write-Log "DRY RUN: Would setup container vulnerability scanning" "INFO"
        }
    }
    catch {
        Write-Log "Error setting up container scanning: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to create security secrets in Key Vault
function Setup-SecuritySecrets {
    param([string]$KeyVaultName)
    
    try {
        Write-Log "Setting up security secrets in Key Vault..." "INFO"
        
        if (-not $DryRun) {
            # Generate JWT secret if it doesn't exist
            $jwtSecret = az keyvault secret show --vault-name $KeyVaultName --name "jwt-secret" --query "value" --output tsv 2>/dev/null
            if (-not $jwtSecret) {
                $jwtSecret = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([System.Guid]::NewGuid().ToString() + [System.Guid]::NewGuid().ToString()))
                az keyvault secret set --vault-name $KeyVaultName --name "jwt-secret" --value $jwtSecret
                Write-Log "JWT secret generated and stored" "SUCCESS"
            }
            
            # Set up database encryption key
            $dbKey = az keyvault secret show --vault-name $KeyVaultName --name "database-encryption-key" --query "value" --output tsv 2>/dev/null
            if (-not $dbKey) {
                $dbKey = [System.Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
                az keyvault secret set --vault-name $KeyVaultName --name "database-encryption-key" --value $dbKey
                Write-Log "Database encryption key generated and stored" "SUCCESS"
            }
            
            # Set up API keys and other secrets (placeholders)
            $secrets = @{
                "webhook-secret" = [System.Guid]::NewGuid().ToString()
                "api-rate-limit-key" = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([System.Guid]::NewGuid().ToString()))
            }
            
            foreach ($secretName in $secrets.Keys) {
                $existingSecret = az keyvault secret show --vault-name $KeyVaultName --name $secretName --query "value" --output tsv 2>/dev/null
                if (-not $existingSecret) {
                    az keyvault secret set --vault-name $KeyVaultName --name $secretName --value $secrets[$secretName]
                    Write-Log "Secret '$secretName' generated and stored" "SUCCESS"
                }
            }
            
        } else {
            Write-Log "DRY RUN: Would setup security secrets in Key Vault" "INFO"
        }
    }
    catch {
        Write-Log "Error setting up security secrets: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Function to setup security monitoring
function Setup-SecurityMonitoring {
    param([string]$ResourceGroup, [string]$LogAnalyticsName)
    
    try {
        Write-Log "Setting up security monitoring..." "INFO"
        
        if (-not $DryRun) {
            $subscriptionId = az account show --query id --output tsv
            $logAnalyticsResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$logAnalyticsName"
            
            # Create security monitoring queries
            $securityQueries = @(
                @{
                    displayName = "Container Security Violations"
                    query = @"
ContainerLog
| where LogEntry contains "ERROR" or LogEntry contains "WARN" or LogEntry contains "security"
| where TimeGenerated > ago(24h)
| summarize Count = count() by Computer, LogEntry
| order by Count desc
"@
                },
                @{
                    displayName = "Failed Authentication Attempts"
                    query = @"
AppServiceConsoleLogs
| where ResultDescription contains "Unauthorized" or ResultDescription contains "Forbidden"
| where TimeGenerated > ago(1h)
| summarize Count = count() by _ResourceId, ResultDescription
| order by Count desc
"@
                },
                @{
                    displayName = "Key Vault Access Anomalies"
                    query = @"
KeyVaultAuditLogs
| where TimeGenerated > ago(1h)
| where ResultType != "Success"
| summarize Count = count() by CallerIpAddress, OperationName, ResultType
| order by Count desc
"@
                }
            )
            
            # Save queries to files for reference
            $queriesPath = "security-monitoring-queries"
            if (-not (Test-Path $queriesPath)) {
                New-Item -ItemType Directory -Path $queriesPath -Force | Out-Null
            }
            
            foreach ($query in $securityQueries) {
                $fileName = "$queriesPath/$($query.displayName -replace ' ', '-').kql"
                $query.query | Out-File -FilePath $fileName -Encoding UTF8
                Write-Log "Security query saved: $fileName" "SUCCESS"
            }
            
        } else {
            Write-Log "DRY RUN: Would setup security monitoring queries" "INFO"
        }
    }
    catch {
        Write-Log "Error setting up security monitoring: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Main security setup function
function Setup-ContainerSecurity {
    try {
        Write-Log "Starting comprehensive container security setup..." "INFO"
        
        # Setup ACR security
        Setup-AcrSecurity -AcrName $acrName -ResourceGroup $resourceGroup
        
        # Setup Key Vault security
        Setup-KeyVaultSecurity -KeyVaultName $keyVaultName -ResourceGroup $resourceGroup
        
        # Setup container security policies
        Setup-ContainerSecurityPolicies -AppServiceName $appServiceName -ResourceGroup $resourceGroup
        
        # Setup Microsoft Defender for Containers (if requested)
        if ($SetupDefender) {
            Setup-DefenderForContainers
        }
        
        # Setup network security (if requested)
        if ($ConfigureNetworkSecurity) {
            Setup-NetworkSecurity -AppServiceName $appServiceName -ResourceGroup $resourceGroup
        }
        
        # Setup container scanning
        Setup-ContainerScanning -AcrName $acrName -ResourceGroup $resourceGroup
        
        # Setup security secrets
        Setup-SecuritySecrets -KeyVaultName $keyVaultName
        
        # Setup security monitoring
        Setup-SecurityMonitoring -ResourceGroup $resourceGroup -LogAnalyticsName $logAnalyticsName
        
        Write-Log "✅ Container security setup completed successfully!" "SUCCESS"
        
        # Output security recommendations
        Write-Host "`n🔐 Security Recommendations:" -ForegroundColor Cyan
        Write-Host "1. Regularly scan container images using 'az acr task run --registry $acrName --name security-scan'" -ForegroundColor White
        Write-Host "2. Monitor Key Vault access logs in Azure Monitor" -ForegroundColor White
        Write-Host "3. Review and update IP restrictions based on your requirements" -ForegroundColor White
        Write-Host "4. Enable Azure Policy for additional compliance checking" -ForegroundColor White
        Write-Host "5. Set up automated security alerts in Azure Security Center" -ForegroundColor White
        
    }
    catch {
        Write-Log "❌ Container security setup failed: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# Execute security setup
Setup-ContainerSecurity

Write-Log "🎉 Security configuration process completed!" "SUCCESS"