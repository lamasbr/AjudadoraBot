# Azure Free Tier Deployment Guide

This guide provides comprehensive instructions for deploying AjudadoraBot using Azure's free tier resources, optimized for zero or minimal cost while maintaining production capability.

## 🎯 Overview

This deployment strategy maximizes functionality while staying within Azure free tier limits using:

- **Azure App Service F1** (Free tier): 60 minutes/day compute, 1GB storage, 165MB/day bandwidth
- **Azure Key Vault** (Free tier): 25,000 operations/month
- **GitHub Container Registry** (Free): Unlimited public repositories
- **Datadog Free Tier**: Up to 5 hosts, 1-day retention
- **Terraform** for Infrastructure as Code

## 📊 Free Tier Limits & Constraints

### Azure App Service (F1 Plan)
| Resource | Limit | Impact |
|----------|-------|--------|
| Compute Time | 60 minutes/day | App sleeps after limit |
| Storage | 1 GB | Includes app + SQLite database |
| Bandwidth | 165 MB/day outbound | Monitor static asset delivery |
| Custom Domains | 0 | Use `*.azurewebsites.net` |
| SSL Certificates | Shared only | No custom SSL |
| Always On | Not available | App may sleep when idle |
| Deployment Slots | 0 | No staging environment |

### Azure Key Vault (Standard)
| Resource | Limit | Impact |
|----------|-------|--------|
| Operations | 25,000/month | ~833 operations/day |
| Secret Storage | Unlimited | Cost per secret stored |

### GitHub Container Registry
| Resource | Limit | Impact |
|----------|-------|--------|
| Public Repositories | Unlimited | Free for public repos |
| Private Repositories | 500MB | Paid for private repos |
| Bandwidth | Unlimited | Free for public repos |

### Datadog Free Tier
| Resource | Limit | Impact |
|----------|-------|--------|
| Hosts | 5 maximum | Single host deployment |
| Log Retention | 1 day | Limited historical data |
| Custom Metrics | 100 | Focus on essential metrics |
| APM Traces | 1 million spans/month | Monitor trace volume |

## 🏗️ Architecture

```
Internet
    ↓
[Azure Load Balancer (Free)]
    ↓
[App Service F1 - Combined Container]
    ├── .NET 9 Web API (Backend)
    ├── Static Files (Frontend)
    └── SQLite Database (Local Storage)
    ↓
[Azure Key Vault (Free Tier)]
    ├── Telegram Bot Token
    ├── JWT Secret
    └── Datadog API Key
    ↓
[Datadog (Free Tier)]
    ├── APM Monitoring
    ├── Log Aggregation
    └── Custom Metrics
```

## 🚀 Quick Start

### Prerequisites

1. **Azure Account** with active free tier benefits
2. **GitHub Account** for container registry
3. **Datadog Account** (free tier)
4. **Telegram Bot Token** from @BotFather
5. **Local Tools**:
   - Azure CLI (`az`)
   - Terraform (`>= 1.5`)
   - Docker
   - Git

### 1. Clone and Configure

```bash
git clone https://github.com/yourusername/ajudadorabot.git
cd ajudadorabot

# Copy Terraform variables template
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

### 2. Configure Terraform Variables

Edit `terraform/terraform.tfvars`:

```hcl
# Application Configuration
app_name    = "ajudadorabot"
environment = "production"
location    = "East US"  # Choose cheapest region

# GitHub Container Registry (Free)
ghcr_username = "your-github-username"
ghcr_token    = "ghp_your_github_token_here"  # Needs read:packages scope

# Telegram Bot Configuration
telegram_bot_token = "1234567890:ABCDEF..."  # From @BotFather

# Datadog Configuration (Free tier)
datadog_api_key = "your_datadog_api_key"
datadog_site    = "datadoghq.com"

# Cost optimization
create_storage_account = false  # Use local storage to save costs
enable_cost_alerts     = true
alert_email           = "your-email@example.com"
```

### 3. Deploy Infrastructure

```bash
# Login to Azure
az login

# Deploy with PowerShell script (Windows)
.\scripts\deploy-free-tier.ps1 -SubscriptionId "your-subscription-id" -AlertEmail "your-email@example.com"

# Or deploy manually with Terraform
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Configure GitHub Actions

1. **Set Repository Secrets**:
   - `AZURE_CREDENTIALS` - Service principal JSON
   - `AZURE_CLIENT_ID` - Service principal client ID
   - `AZURE_CLIENT_SECRET` - Service principal secret
   - `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
   - `AZURE_TENANT_ID` - Azure tenant ID
   - `TELEGRAM_BOT_TOKEN` - Telegram bot token
   - `DATADOG_API_KEY` - Datadog API key
   - `ALERT_EMAIL` - Email for cost alerts

2. **Enable GitHub Container Registry**:
   - Go to Settings > Developer settings > Personal access tokens
   - Create token with `read:packages` and `write:packages` scopes

### 5. Deploy Application

```bash
# Push to main branch to trigger deployment
git add .
git commit -m "Initial free tier deployment"
git push origin main
```

## 📊 Monitoring & Cost Management

### Daily Monitoring

Run the monitoring script daily:

```bash
# Linux/macOS
./scripts/monitor-free-tier.sh

# Windows PowerShell
.\scripts\deploy-free-tier.ps1 -MonitorOnly
```

### Key Metrics to Monitor

1. **Compute Time**: Stay under 60 minutes/day
2. **Bandwidth**: Monitor data out (165MB/day limit)
3. **Storage**: SQLite database size (1GB total limit)
4. **Key Vault Operations**: Track secret access (25K/month limit)
5. **Datadog Hosts**: Ensure single host reporting

### Cost Alerts

Configured alerts will notify you when approaching limits:

- CPU usage > 70%
- Memory usage > 80%
- Bandwidth usage > 70% of daily limit
- HTTP 5xx errors > 5 in 5 minutes
- Response time > 5 seconds

## 🎛️ Configuration Management

### Environment Variables

The application uses these key environment variables:

```bash
# Core Application
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://+:8080

# Database (SQLite local storage)
ConnectionStrings__DefaultConnection="Data Source=/home/data/ajudadorabot.db"

# Datadog Monitoring
DD_API_KEY="@Microsoft.KeyVault(...)"
DD_SITE="datadoghq.com"
DD_SERVICE="ajudadorabot"
DD_ENV="production"
DD_LOGS_ENABLED="true"
DD_APM_ENABLED="true"

# Telegram Bot
TelegramBot__Token="@Microsoft.KeyVault(...)"
TelegramBot__WebhookUrl="https://your-app.azurewebsites.net/webhook"

# JWT Authentication
MiniApp__JwtSecret="@Microsoft.KeyVault(...)"
MiniApp__JwtIssuer="ajudadorabot-production"
```

### Telegram Mini App Configuration

1. **Set Bot Commands** via @BotFather:
```
start - Start using the bot
help - Get help and commands
webapp - Open Mini App
```

2. **Configure Web App** in @BotFather:
   - URL: `https://your-app.azurewebsites.net`
   - Domain: `your-app.azurewebsites.net`

3. **Set Webhook**:
```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -d "url=https://your-app.azurewebsites.net/webhook"
```

## 🔧 Performance Optimization

### Container Optimization

The combined Dockerfile optimizes for F1 tier:

1. **Multi-stage build** to minimize image size
2. **Alpine Linux** base for smaller footprint
3. **Compressed static assets** (gzip)
4. **Memory limits** configured for 1GB constraint
5. **64-bit worker process** for better performance

### Application Optimization

1. **SQLite Database**: Optimal for free tier vs. Azure SQL
2. **Local Storage**: Uses App Service storage vs. separate storage account
3. **Static File Caching**: 1-year cache for assets, no-cache for HTML
4. **Rate Limiting**: Reduced limits to prevent resource exhaustion
5. **Logging**: Minimal retention (3 days) to save space

### Database Performance

```csharp
// SQLite optimizations in DbContext
options.UseSqlite(connectionString, options =>
{
    options.CommandTimeout(30);
});

// Connection string optimizations
"Data Source=/home/data/ajudadorabot.db;Cache=Shared;Journal Mode=WAL;Synchronous=Normal"
```

## 🔒 Security Considerations

### Free Tier Security Features

1. **HTTPS Only**: Enforced via Azure App Service
2. **Managed Identity**: For Key Vault access
3. **Key Vault Integration**: All secrets stored securely
4. **Minimum TLS 1.2**: Enforced for all connections
5. **FTPS Disabled**: Only HTTPS deployment allowed

### Limitations

1. **No WAF**: Web Application Firewall not available on F1
2. **No VNet**: Virtual network integration not available
3. **Shared SSL**: Custom SSL certificates not supported
4. **Basic Authentication**: No Azure AD integration on F1

## 🚨 Troubleshooting

### Common Issues

#### App Service Stops Responding
- **Cause**: Exceeded 60-minute daily compute limit
- **Solution**: Wait for daily reset or optimize for less compute usage
- **Prevention**: Monitor compute time, implement efficient caching

#### High Memory Usage
- **Cause**: Memory leak or inefficient queries
- **Solution**: Restart app service, review database queries
- **Prevention**: Monitor memory metrics, implement connection pooling

#### Bandwidth Limit Exceeded
- **Cause**: Large file downloads or uncompressed assets
- **Solution**: Optimize static assets, implement CDN
- **Prevention**: Monitor bandwidth usage, compress responses

#### Database Connection Issues
- **Cause**: SQLite file locking or corruption
- **Solution**: Restart app service, restore from backup
- **Prevention**: Use WAL mode, implement connection retry logic

### Monitoring Commands

```bash
# Check app service status
az webapp show --name "ajudadorabot-production-app" --resource-group "ajudadorabot-production-rg"

# View application logs
az webapp log tail --name "ajudadorabot-production-app" --resource-group "ajudadorabot-production-rg"

# Check metrics
az monitor metrics list --resource "/subscriptions/.../resourceGroups/ajudadorabot-production-rg/providers/Microsoft.Web/sites/ajudadorabot-production-app" --metric "CpuPercentage"

# Test health endpoint
curl https://ajudadorabot-production-app.azurewebsites.net/health
```

## 📈 Scaling Considerations

### When to Upgrade from Free Tier

Consider upgrading when you hit these limits consistently:

1. **Daily compute time** > 45 minutes regularly
2. **Bandwidth usage** > 120MB/day regularly  
3. **Storage needs** > 800MB
4. **Response times** consistently > 3 seconds
5. **Need for custom domains** or SSL certificates

### Upgrade Path

1. **Basic B1**: $13.14/month
   - Always On available
   - Custom domains supported
   - 1.75GB RAM, 10GB storage
   - No daily compute limits

2. **Standard S1**: $56.94/month
   - 5 deployment slots
   - Auto-scaling
   - Custom SSL certificates
   - Traffic manager integration

## 📋 Maintenance Checklist

### Daily
- [ ] Check application health
- [ ] Monitor bandwidth usage
- [ ] Review error logs

### Weekly
- [ ] Run cost monitoring script
- [ ] Check database size growth
- [ ] Review Datadog metrics
- [ ] Update container if needed

### Monthly
- [ ] Review Azure cost analysis
- [ ] Check Key Vault operation usage
- [ ] Update dependencies
- [ ] Backup database
- [ ] Review security alerts

## 🆘 Support & Resources

### Documentation
- [Azure App Service Free Tier Limits](https://docs.microsoft.com/en-us/azure/app-service/overview-hosting-plans)
- [Datadog Free Tier Details](https://docs.datadoghq.com/account_management/billing/)
- [Telegram Bot API](https://core.telegram.org/bots/api)

### Monitoring Tools
- Azure Portal: Monitor metrics and costs
- Datadog Dashboard: Application performance
- GitHub Actions: Deployment status

### Cost Tracking
- Azure Cost Management: Track spending
- Free tier usage notifications
- Resource usage alerts

---

## 💡 Pro Tips

1. **Use Azure Calculator**: Estimate costs before scaling up
2. **Monitor Daily**: Set calendar reminders for usage checks
3. **Optimize Images**: Compress static assets to save bandwidth
4. **Database Cleanup**: Regularly archive old data
5. **Cache Everything**: Implement aggressive caching for static content
6. **Use CDN**: Consider Azure CDN for global deployment (paid)
7. **Schedule Deployments**: Deploy during low-traffic periods
8. **Test Locally**: Minimize cloud testing to save compute time

Remember: The free tier is designed for development and light production workloads. Monitor usage closely to avoid unexpected charges!