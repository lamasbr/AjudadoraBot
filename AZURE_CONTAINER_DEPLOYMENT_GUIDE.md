# Azure Container Deployment Guide for AjudadoraBot

This guide provides comprehensive instructions for deploying the AjudadoraBot Telegram application to Azure App Service using containerized deployment with Azure Container Registry (ACR).

## Overview

The deployment architecture includes:
- **Azure Container Registry (ACR)** for container image storage
- **Azure App Service** for backend API container hosting
- **Azure Static Web Apps** for frontend hosting
- **Azure Key Vault** for secrets management
- **Application Insights** for monitoring and logging
- **Azure Storage** for SQLite database persistence

## Prerequisites

### Required Tools
- Azure CLI 2.50+ (`az --version`)
- Docker Desktop 4.20+
- PowerShell 7.0+ (for deployment scripts)
- Git
- .NET 9 SDK (for local development)

### Azure Permissions
- Contributor access to Azure subscription
- Ability to create resource groups and assign roles
- Access to create service principals for CI/CD

### GitHub Secrets Required
```
AZURE_CREDENTIALS_STAGING
AZURE_CREDENTIALS_PRODUCTION
ACR_USERNAME_STAGING
ACR_PASSWORD_STAGING
ACR_USERNAME_PRODUCTION
ACR_PASSWORD_PRODUCTION
SONAR_TOKEN
SLACK_WEBHOOK_URL (optional)
```

## Deployment Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│   GitHub Actions │───▶│  Azure Container│
│                 │    │                  │    │    Registry     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                          │
                                                          ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Static Web App │    │   App Service    │◄───│  Container Image│
│   (Frontend)    │    │   (Backend API)  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Key Vault     │    │ Application      │    │  Azure Storage  │
│   (Secrets)     │    │   Insights       │    │  (Database)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Step-by-Step Deployment

### 1. Infrastructure Setup

#### Deploy Azure Resources
```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Create resource groups
az group create --name "ajudadorabot-staging-rg" --location "East US"
az group create --name "ajudadorabot-production-rg" --location "East US"

# Deploy infrastructure using Bicep
az deployment group create \
  --resource-group "ajudadorabot-staging-rg" \
  --template-file "azure/bicep/main.bicep" \
  --parameters "@azure/bicep/parameters/staging.bicepparam"

az deployment group create \
  --resource-group "ajudadorabot-production-rg" \
  --template-file "azure/bicep/main.bicep" \
  --parameters "@azure/bicep/parameters/production.bicepparam"
```

#### Configure Service Principal for CI/CD
```bash
# Create service principal for staging
az ad sp create-for-rbac --name "ajudadorabot-staging-sp" \
  --role contributor \
  --scopes "/subscriptions/{subscription-id}/resourceGroups/ajudadorabot-staging-rg" \
  --sdk-auth

# Create service principal for production
az ad sp create-for-rbac --name "ajudadorabot-production-sp" \
  --role contributor \
  --scopes "/subscriptions/{subscription-id}/resourceGroups/ajudadorabot-production-rg" \
  --sdk-auth
```

### 2. Container Registry Setup

#### Configure ACR Credentials
```bash
# Get ACR credentials for staging
az acr credential show --name "ajudadorabotregistrystaging"

# Get ACR credentials for production
az acr credential show --name "ajudadorabotregistryproduction"

# Enable admin user (if not already enabled)
az acr update --name "ajudadorabotregistrystaging" --admin-enabled true
az acr update --name "ajudadorabotregistryproduction" --admin-enabled true
```

### 3. Security Configuration

#### Setup Container Security
```powershell
# Run security setup script
.\azure\scripts\setup-container-security.ps1 -Environment staging -SetupDefender -ConfigureNetworkSecurity

.\azure\scripts\setup-container-security.ps1 -Environment production -SetupDefender -ConfigureNetworkSecurity
```

#### Configure Key Vault Secrets
```bash
# Add Telegram Bot Token
az keyvault secret set --vault-name "ajudadorabot-staging-kv" \
  --name "telegram-bot-token" --value "your-telegram-bot-token"

# Add JWT Secret (generated automatically by security script)
# Add other required secrets as needed
```

### 4. Application Insights Setup

#### Configure Monitoring
```powershell
# Setup Application Insights monitoring
.\azure\scripts\setup-app-insights.ps1 -Environment staging -SetupAlerts -CreateDashboard -SetupLiveMetrics

.\azure\scripts\setup-app-insights.ps1 -Environment production -SetupAlerts -CreateDashboard -SetupLiveMetrics
```

### 5. GitHub Actions Configuration

#### Setup Repository Secrets
1. Go to GitHub repository → Settings → Secrets and variables → Actions
2. Add the following secrets:

```
AZURE_CREDENTIALS_STAGING: {output from staging service principal creation}
AZURE_CREDENTIALS_PRODUCTION: {output from production service principal creation}
ACR_USERNAME_STAGING: {from ACR credentials command}
ACR_PASSWORD_STAGING: {from ACR credentials command}
ACR_USERNAME_PRODUCTION: {from ACR credentials command}
ACR_PASSWORD_PRODUCTION: {from ACR credentials command}
```

#### Trigger First Deployment
```bash
# Push to develop branch for staging deployment
git checkout develop
git push origin develop

# Push to main branch or create release tag for production
git checkout main
git push origin main
# OR
git tag v1.0.0
git push origin v1.0.0
```

### 6. Manual Deployment (Alternative)

#### Build and Push Containers Manually
```bash
# Build backend container
docker build -f Dockerfile.backend -t ajudadorabotregistrystaging.azurecr.io/ajudadorabot-backend:latest .

# Build frontend container
docker build -f frontend/Dockerfile -t ajudadorabotregistrystaging.azurecr.io/ajudadorabot-frontend:latest ./frontend

# Login to ACR
az acr login --name ajudadorabotregistrystaging

# Push images
docker push ajudadorabotregistrystaging.azurecr.io/ajudadorabot-backend:latest
docker push ajudadorabotregistrystaging.azurecr.io/ajudadorabot-frontend:latest
```

#### Deploy Using PowerShell Script
```powershell
# Deploy to staging
.\azure\scripts\deploy-containers.ps1 -Environment staging -ImageTag latest

# Deploy to production
.\azure\scripts\deploy-containers.ps1 -Environment production -ImageTag latest
```

## Monitoring and Maintenance

### Health Checks
- **Backend Health**: `https://ajudadorabot-staging-api.azurewebsites.net/health`
- **Application Insights**: Monitor through Azure Portal
- **Container Logs**: Available in App Service logs

### Monitoring Scripts
```powershell
# Monitor container performance
.\azure\scripts\monitor-containers.ps1 -Environment both -GenerateReport

# Continuous monitoring
.\azure\scripts\monitor-containers.ps1 -Environment production -Continuous
```

### Rollback Procedures
```powershell
# Rollback to previous version
.\azure\scripts\rollback-containers.ps1 -Environment production -UseSlotSwap

# Rollback to specific image tag
.\azure\scripts\rollback-containers.ps1 -Environment production -TargetImageTag "v1.0.0"
```

## Cost Optimization

### Resource Scaling
- **Staging**: Basic App Service Plan (B1)
- **Production**: Premium App Service Plan (P1V3) with auto-scaling
- **ACR**: Standard tier for staging, Premium for production

### Storage Optimization
- Container images are automatically cleaned up after 30 days (production) / 7 days (staging)
- Database backups retained for 30 days (production) / 7 days (staging)

### Monitoring Costs
- Application Insights: Pay-per-GB ingestion model
- Log Analytics: Separate pricing for log retention

## Security Best Practices

### Container Security
- ✅ Regular vulnerability scanning with Trivy
- ✅ Non-root container execution
- ✅ Minimal base image (Alpine Linux)
- ✅ Multi-stage builds for smaller images

### Network Security
- ✅ HTTPS-only communication
- ✅ App Service managed certificates
- ✅ IP restrictions (configurable)
- ✅ CORS policy enforcement

### Secrets Management
- ✅ Azure Key Vault integration
- ✅ Managed Identity authentication
- ✅ No secrets in container images
- ✅ Automatic secret rotation support

## Troubleshooting

### Common Issues

#### Container Startup Issues
```bash
# Check container logs
az webapp log tail --name ajudadorabot-staging-api --resource-group ajudadorabot-staging-rg

# Check container configuration
az webapp config show --name ajudadorabot-staging-api --resource-group ajudadorabot-staging-rg
```

#### Database Connection Issues
```bash
# Verify storage mount
az webapp config storage-account list --name ajudadorabot-staging-api --resource-group ajudadorabot-staging-rg

# Check file share permissions
az storage share show --name database --account-name ajudadorabotregistrystaging
```

#### Image Pull Issues
```bash
# Verify ACR access
az acr check-health --name ajudadorabotregistrystaging

# Test image pull
docker pull ajudadorabotregistrystaging.azurecr.io/ajudadorabot-backend:latest
```

### Performance Issues
- Monitor Application Insights for slow requests
- Check container resource utilization
- Review database query performance
- Verify CDN configuration for static assets

### Log Analysis
```kql
// Container startup issues
ContainerLog
| where LogEntry contains "ERROR" or LogEntry contains "Failed"
| order by TimeGenerated desc

// Performance analysis
requests
| where timestamp > ago(1h)
| summarize avg(duration), percentile(duration, 95) by bin(timestamp, 5m)
```

## Support and Updates

### Deployment Updates
1. Test changes in staging environment
2. Run automated tests
3. Deploy to production using blue-green deployment
4. Monitor post-deployment metrics

### Version Management
- Use semantic versioning for releases
- Tag container images with version numbers
- Maintain rollback capability for at least 3 previous versions

### Maintenance Windows
- **Staging**: No restrictions
- **Production**: Prefer off-peak hours (2-4 AM UTC)
- **Emergency**: 24/7 rollback capability available

## Contact Information

For deployment issues or questions:
- GitHub Issues: [Repository Issues](https://github.com/yourusername/ajudadorabot/issues)
- DevOps Team: [Email](mailto:devops@yourdomain.com)
- On-call Support: Available for production issues

---

**Last Updated**: $(Get-Date -Format "yyyy-MM-dd")  
**Version**: 2.0.0  
**Environment**: Azure App Service Containers