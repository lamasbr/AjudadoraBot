// Staging environment parameters for AjudadoraBot
using '../main.bicep'

param environment = 'staging'
param appName = 'ajudadorabot'
param location = 'East US 2'
param appServicePlanSku = 'B1'
param keyVaultSku = 'standard'
param customDomain = ''
param sslCertificateThumbprint = ''