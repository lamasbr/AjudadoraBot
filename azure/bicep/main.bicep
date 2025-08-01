// Main Bicep template for AjudadoraBot Azure infrastructure
@description('Environment name (staging, production)')
param environment string = 'staging'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Application name')
param appName string = 'ajudadorabot'

@description('App Service Plan SKU')
param appServicePlanSku string = environment == 'production' ? 'P1V3' : 'B1'

@description('Key Vault SKU')
param keyVaultSku string = 'standard'

@description('Custom domain name (optional)')
param customDomain string = ''

@description('SSL certificate thumbprint for custom domain (optional)')
param sslCertificateThumbprint string = ''

// Variables
var resourcePrefix = '${appName}-${environment}'
var acrName = replace('${resourcePrefix}registry', '-', '')
var tags = {
  Environment: environment
  Application: appName
  ManagedBy: 'Bicep'
  CostCenter: 'Development'
}

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: environment == 'production' ? 'Premium' : 'Standard'
  }
  properties: {
    adminUserEnabled: true
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: environment == 'production' ? 'enabled' : 'disabled'
      }
      retentionPolicy: {
        days: environment == 'production' ? 30 : 7
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: environment == 'production'
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// App Service Plan for backend API
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourcePrefix}-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
    tier: appServicePlanSku == 'B1' ? 'Basic' : 'PremiumV3'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux App Service Plan
  }
}

// App Service for backend API
resource backendAppService 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourcePrefix}-api'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.properties.loginServer}/${appName}-backend:latest'
      alwaysOn: appServicePlanSku != 'B1' // AlwaysOn not available on Basic tier
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      http20Enabled: true
      healthCheckPath: '/health'
      acrUseManagedIdentityCreds: false
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environment == 'production' ? 'Production' : 'Staging'
        }
        {
          name: 'ASPNETCORE_URLS'
          value: 'http://+:8080'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'KeyVault__VaultUrl'
          value: keyVault.properties.vaultUri
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'true'
        }
        {
          name: 'WEBSITES_CONTAINER_START_TIME_LIMIT'
          value: '230'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.properties.loginServer}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistry.properties.adminUserEnabled ? containerRegistry.name : ''
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.properties.adminUserEnabled ? containerRegistry.listCredentials().passwords[0].value : ''
        }
        {
          name: 'WEBSITE_HTTPLOGGING_RETENTION_DAYS'
          value: '7'
        }
        {
          name: 'WEBSITE_PULL_IMAGE_OVER_VNET'
          value: 'false'
        }
      ]
      connectionStrings: [
        {
          name: 'DefaultConnection'
          connectionString: 'Data Source=/home/data/ajudadorabot.db'
          type: 'SQLite'
        }
      ]
    }
  }
}

// App Service deployment slots for blue-green deployment
resource backendStagingSlot 'Microsoft.Web/sites/slots@2023-01-01' = if (environment == 'production') {
  parent: backendAppService
  name: 'staging'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.properties.loginServer}/${appName}-backend:latest'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      http20Enabled: true
      healthCheckPath: '/health'
      acrUseManagedIdentityCreds: false
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Staging'
        }
        {
          name: 'ASPNETCORE_URLS'
          value: 'http://+:8080'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'KeyVault__VaultUrl'
          value: keyVault.properties.vaultUri
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'true'
        }
        {
          name: 'WEBSITES_CONTAINER_START_TIME_LIMIT'
          value: '230'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.properties.loginServer}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistry.properties.adminUserEnabled ? containerRegistry.name : ''
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.properties.adminUserEnabled ? containerRegistry.listCredentials().passwords[0].value : ''
        }
      ]
    }
  }
}

// Static Web App for frontend (Alternative 1 - recommended for static content)
resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: '${resourcePrefix}-frontend'
  location: location
  tags: tags
  sku: {
    name: environment == 'production' ? 'Standard' : 'Free'
    tier: environment == 'production' ? 'Standard' : 'Free'
  }
  properties: {
    buildProperties: {
      skipGithubActionWorkflowGeneration: true
    }
    stagingEnvironmentPolicy: 'Enabled'
  }
}

// Storage Account for SQLite database persistence
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: replace('${resourcePrefix}storage', '-', '')
  location: location
  tags: tags
  sku: {
    name: environment == 'production' ? 'Standard_LRS' : 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow' // Could be restricted to specific IPs/VNets in production
    }
  }
}

// File Share for SQLite database
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/database'
  properties: {
    shareQuota: 100 // 100 GB quota
    enabledProtocols: 'SMB'
  }
}

// Key Vault for secrets management
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${resourcePrefix}-kv'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: keyVaultSku
    }
    tenantId: subscription().tenantId
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: environment == 'production'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${resourcePrefix}-logs'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: environment == 'production' ? 90 : 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${resourcePrefix}-insights'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Role assignment for backend app service to access Key Vault
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, backendAppService.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: backendAppService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment for staging slot to access Key Vault (production only)
resource keyVaultSecretsUserRoleStaging 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (environment == 'production') {
  name: guid(keyVault.id, backendStagingSlot.id, 'Key Vault Secrets User Staging')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: backendStagingSlot.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment for backend app service to pull from ACR
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, backendAppService.id, 'AcrPull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: backendAppService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment for staging slot to pull from ACR (production only)
resource acrPullRoleAssignmentStaging 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (environment == 'production') {
  name: guid(containerRegistry.id, backendStagingSlot.id, 'AcrPull Staging')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: backendStagingSlot.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Custom domain binding (if provided)
resource customDomainBinding 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = if (!empty(customDomain)) {
  parent: backendAppService
  name: customDomain
  properties: {
    hostNameType: 'Verified'
    sslState: !empty(sslCertificateThumbprint) ? 'SniEnabled' : 'Disabled'
    thumbprint: sslCertificateThumbprint
  }
}

// Action Groups for alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${resourcePrefix}-alerts'
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: 'AjudBot'
    enabled: true
    emailReceivers: [
      {
        name: 'DevTeam'
        emailAddress: 'devteam@yourdomain.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Metric Alert for high CPU usage
resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${resourcePrefix}-cpu-alert'
  location: 'Global'
  tags: tags
  properties: {
    description: 'Alert when CPU usage is high'
    severity: 2
    enabled: true
    scopes: [
      backendAppService.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'CpuPercentage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Metric Alert for high memory usage
resource memoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${resourcePrefix}-memory-alert'
  location: 'Global'
  tags: tags
  properties: {
    description: 'Alert when memory usage is high'
    severity: 2
    enabled: true
    scopes: [
      backendAppService.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighMemory'
          metricName: 'MemoryPercentage'
          operator: 'GreaterThan'
          threshold: 85
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Outputs
output backendAppServiceName string = backendAppService.name
output backendAppServiceUrl string = 'https://${backendAppService.properties.defaultHostName}'
output staticWebAppName string = staticWebApp.name
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'
output keyVaultName string = keyVault.name
output keyVaultUrl string = keyVault.properties.vaultUri
output applicationInsightsName string = applicationInsights.name
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output storageAccountName string = storageAccount.name
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output resourceGroupName string = resourceGroup().name

// Container Registry Outputs
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output containerRegistryId string = containerRegistry.id