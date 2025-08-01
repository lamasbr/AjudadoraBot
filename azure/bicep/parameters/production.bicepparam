// Production environment parameters for AjudadoraBot
using '../main.bicep'

param environment = 'production'
param appName = 'ajudadorabot'
param location = 'East US 2'
param appServicePlanSku = 'P1V3'
param keyVaultSku = 'standard'
param customDomain = 'api.ajudadorabot.com'
param sslCertificateThumbprint = '' // Will be populated after SSL certificate is uploaded