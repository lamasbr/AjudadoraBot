# AjudadoraBot Production Deployment Guide

This comprehensive guide covers deploying AjudadoraBot to production with high availability, security, and monitoring.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Options](#deployment-options)
- [Environment Configuration](#environment-configuration)
- [Security Setup](#security-setup)
- [Monitoring & Observability](#monitoring--observability)
- [Backup & Recovery](#backup--recovery)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## Overview

AjudadoraBot is deployed as a containerized .NET 9 application with:
- **Backend**: ASP.NET Core Web API
- **Frontend**: Telegram Mini App (HTML/CSS/JavaScript)
- **Database**: SQLite with optional PostgreSQL support
- **Cache**: Redis (optional)
- **Reverse Proxy**: NGINX
- **Monitoring**: Prometheus + Grafana
- **Orchestration**: Kubernetes or Docker Compose

## Prerequisites

### Required Tools
- Docker 24.0+
- Kubernetes 1.28+ (for K8s deployment)
- kubectl
- Helm 3.0+ (recommended)
- Git

### Infrastructure Requirements
- **Minimum**: 2 vCPU, 4GB RAM, 20GB storage
- **Production**: 4 vCPU, 8GB RAM, 100GB storage
- **Network**: HTTPS/SSL certificate, domain name
- **External Services**: Telegram Bot Token

### Access Requirements
- Container registry access (GitHub Container Registry)
- Kubernetes cluster admin access (for K8s deployment)
- DNS management access
- Secret management system access

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/AjudadoraBot.git
cd AjudadoraBot
```

### 2. Generate Secrets
```bash
chmod +x scripts/generate-secrets.sh
ENVIRONMENT=production ./scripts/generate-secrets.sh all
```

### 3. Configure Environment
```bash
# Copy and edit environment file
cp .env.production.example .env.production
nano .env.production  # Set your actual values
```

### 4. Deploy with Docker Compose (Recommended for initial setup)
```bash
# Production deployment
docker-compose -f docker-compose.yml -f docker-compose.production.yml up -d
```

### 5. Verify Deployment
```bash
# Check health
curl -f http://localhost/health

# View logs
docker-compose logs -f ajudadorabot-api
```

## Deployment Options

### Option 1: Docker Compose (Recommended for small-medium scale)

#### Development
```bash
docker-compose up -d
```

#### Staging
```bash
docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d
```

#### Production
```bash
docker-compose -f docker-compose.yml -f docker-compose.production.yml up -d
```

### Option 2: Kubernetes (Recommended for enterprise scale)

#### Prerequisites
```bash
# Install required operators
kubectl apply -f https://github.com/external-secrets/external-secrets/releases/latest/download/bundle.yaml
kubectl apply -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.yaml
```

#### Deploy to Staging
```bash
kubectl apply -k k8s/staging/
kubectl rollout status deployment/ajudadorabot-api -n ajudadorabot-staging
```

#### Deploy to Production
```bash
kubectl apply -k k8s/production/
kubectl rollout status deployment/ajudadorabot-api -n ajudadorabot-production
```

### Option 3: Cloud Platforms

#### AWS ECS
```bash
# Build and push image
docker build -f Dockerfile.production -t ajudadorabot:latest .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ECR_URI
docker tag ajudadorabot:latest YOUR_ECR_URI/ajudadorabot:latest
docker push YOUR_ECR_URI/ajudadorabot:latest

# Deploy with ECS CLI or CloudFormation
```

#### Google Cloud Run
```bash
# Build and push to GCR
gcloud builds submit --tag gcr.io/YOUR_PROJECT/ajudadorabot

# Deploy to Cloud Run
gcloud run deploy ajudadorabot \
  --image gcr.io/YOUR_PROJECT/ajudadorabot \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

#### Azure Container Apps
```bash
# Create container app
az containerapp create \
  --name ajudadorabot \
  --resource-group myResourceGroup \
  --environment myContainerAppEnv \
  --image ajudadorabot:latest \
  --target-port 8080 \
  --ingress external
```

## Environment Configuration

### Required Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `TELEGRAM_BOT_TOKEN` | Telegram Bot API token | Yes | - |
| `WEBHOOK_URL` | Public webhook URL | Yes | - |
| `JWT_SECRET` | JWT signing secret | Yes | - |
| `DATABASE_CONNECTION_STRING` | Database connection | No | SQLite |
| `REDIS_CONNECTION_STRING` | Redis connection | No | - |

### Configuration Files

#### appsettings.Production.json
```json
{
  "TelegramBot": {
    "Token": "${TELEGRAM_BOT_TOKEN}",
    "WebhookUrl": "${WEBHOOK_URL}",
    "Mode": "Webhook"
  },
  "MiniApp": {
    "JwtSecret": "${JWT_SECRET}",
    "AllowedOrigins": ["https://yourdomain.com", "https://t.me"]
  }
}
```

#### Environment-specific overrides
- **Development**: `appsettings.Development.json`
- **Staging**: `appsettings.Staging.json`
- **Production**: `appsettings.Production.json`

## Security Setup

### 1. Secrets Management

#### Kubernetes Secrets
```bash
# Generate secrets
./scripts/generate-secrets.sh k8s

# Apply secrets (review first!)
kubectl apply -f secrets/k8s-secrets-production.yaml
```

#### External Secrets Operator (Recommended)
```bash
# Configure external secret store
kubectl apply -f k8s/base/external-secrets.yaml

# Secrets are automatically synced from AWS Secrets Manager/Azure Key Vault/etc.
```

### 2. TLS/SSL Configuration

#### Let's Encrypt with cert-manager (Kubernetes)
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

#### Manual SSL Setup (Docker Compose)
```bash
# Place certificates in nginx/ssl/
cp your-domain.crt nginx/ssl/cert.pem
cp your-domain.key nginx/ssl/key.pem
```

### 3. Network Security

#### Firewall Rules
```bash
# Allow only necessary ports
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw allow 22/tcp   # SSH (admin only)
ufw deny incoming
ufw allow outgoing
ufw enable
```

#### NGINX Security Headers
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

### 4. Rate Limiting

#### Application Level
```json
{
  "RateLimiting": {
    "Enabled": true,
    "PermitLimit": 100,
    "WindowMinutes": 1,
    "QueueLimit": 10
  }
}
```

#### NGINX Level
```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=webhook:10m rate=100r/s;
```

## Monitoring & Observability

### 1. Health Checks

#### Application Health Check
```bash
curl -f http://localhost:8080/health
```

#### Kubernetes Health Check
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 30
```

### 2. Metrics & Monitoring

#### Prometheus Configuration
```yaml
scrape_configs:
- job_name: 'ajudadorabot-api'
  static_configs:
  - targets: ['ajudadorabot-api:8080']
  metrics_path: /metrics
  scrape_interval: 15s
```

#### Grafana Dashboards
- System metrics (CPU, Memory, Disk)
- Application metrics (Requests, Errors, Latency)
- Business metrics (Users, Messages, Bot interactions)

### 3. Logging

#### Structured Logging
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "AjudadoraBot": "Information"
    },
    "Console": {
      "FormatterName": "json"
    }
  }
}
```

#### Log Aggregation
- **Docker**: Use fluentd or promtail
- **Kubernetes**: Use built-in logging or ELK stack
- **Cloud**: Use cloud-native logging (CloudWatch, Stackdriver)

### 4. Alerting

#### Critical Alerts
- Application down
- High error rate (>5%)
- Database connectivity issues
- High response time (>2s)

#### Alert Channels
- Email notifications
- Slack integration
- PagerDuty (for critical issues)

## Backup & Recovery

### 1. Database Backup

#### Automated Backup
```bash
# Schedule backup (cron example)
0 2 * * * /app/scripts/backup.sh backup

# Manual backup
./scripts/backup.sh backup
```

#### Backup to Cloud Storage
```bash
# Configure AWS CLI
aws configure set aws_access_key_id YOUR_KEY
aws configure set aws_secret_access_key YOUR_SECRET

# Enable cloud backup
export CLOUD_BACKUP_ENABLED=true
export AWS_S3_BUCKET=ajudadorabot-backups
./scripts/backup.sh backup
```

### 2. Database Recovery

#### List Available Backups
```bash
./scripts/restore.sh list
```

#### Interactive Restore
```bash
./scripts/restore.sh interactive
```

#### Point-in-Time Recovery
```bash
./scripts/restore.sh point-in-time "2024-01-01 12:00:00"
```

#### Restore from Cloud
```bash
./scripts/restore.sh cloud backup-filename.db.gz.enc
```

### 3. Disaster Recovery Plan

#### Recovery Time Objectives (RTO)
- **Database restore**: < 30 minutes
- **Application deployment**: < 15 minutes
- **Full service recovery**: < 1 hour

#### Recovery Point Objectives (RPO)
- **Database backups**: Every 6 hours
- **Configuration backups**: Daily
- **Maximum data loss**: 6 hours

#### Recovery Procedures
1. Assess the situation
2. Activate incident response team
3. Restore from latest backup
4. Verify data integrity
5. Resume normal operations
6. Conduct post-incident review

## Troubleshooting

### Common Issues

#### 1. Application Won't Start
```bash
# Check logs
docker logs ajudadorabot-api
kubectl logs deployment/ajudadorabot-api

# Common causes:
# - Missing environment variables
# - Database connection issues
# - Port conflicts
# - Resource constraints
```

#### 2. Database Connection Errors
```bash
# Check database status
sqlite3 /app/data/ajudadorabot.db "PRAGMA integrity_check;"

# Check permissions
ls -la /app/data/
```

#### 3. Webhook Not Working
```bash
# Test webhook endpoint
curl -X POST https://yourdomain.com/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": true}'

# Check Telegram webhook configuration
curl "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"
```

#### 4. High Memory Usage
```bash
# Check memory usage
docker stats
kubectl top pods

# Possible solutions:
# - Increase memory limits
# - Enable database query optimization
# - Implement request rate limiting
```

#### 5. SSL Certificate Issues
```bash
# Check certificate validity
openssl x509 -in cert.pem -text -noout

# Renew Let's Encrypt certificate
certbot renew --nginx
```

### Debugging Commands

#### Docker Compose
```bash
# View all services
docker-compose ps

# View logs
docker-compose logs -f service-name

# Execute shell in container
docker-compose exec ajudadorabot-api /bin/bash

# Restart service
docker-compose restart ajudadorabot-api
```

#### Kubernetes
```bash
# View pods
kubectl get pods -n ajudadorabot-production

# View logs
kubectl logs -f deployment/ajudadorabot-api -n ajudadorabot-production

# Execute shell in pod
kubectl exec -it deployment/ajudadorabot-api -n ajudadorabot-production -- /bin/bash

# Describe resource
kubectl describe pod pod-name -n ajudadorabot-production
```

### Performance Optimization

#### 1. Database Optimization
```bash
# Run database maintenance
./scripts/cleanup.sh database

# Enable query optimization
sqlite3 /app/data/ajudadorabot.db "PRAGMA optimize;"
```

#### 2. Caching
```bash
# Enable Redis caching
export REDIS_CONNECTION_STRING=redis:6379
export USE_DISTRIBUTED_CACHE=true
```

#### 3. Resource Tuning
```yaml
# Kubernetes resource limits
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

## Maintenance

### Regular Tasks

#### Daily
- [ ] Check application health
- [ ] Review error logs
- [ ] Monitor resource usage
- [ ] Verify backup completion

#### Weekly
- [ ] Update dependencies
- [ ] Review security alerts
- [ ] Performance analysis
- [ ] Clean up old logs

#### Monthly
- [ ] Security audit
- [ ] Backup restore testing
- [ ] Disaster recovery drill
- [ ] Performance optimization review

### Maintenance Scripts

#### System Cleanup
```bash
# Full cleanup
./scripts/cleanup.sh full

# Specific cleanup
./scripts/cleanup.sh logs
./scripts/cleanup.sh temp
./scripts/cleanup.sh database
```

#### Health Check
```bash
# Application health
./scripts/healthcheck.sh

# System health
./scripts/cleanup.sh health
```

### Update Procedures

#### Application Updates
```bash
# Docker Compose
docker-compose pull
docker-compose up -d

# Kubernetes
kubectl set image deployment/ajudadorabot-api ajudadorabot-api=ghcr.io/yourusername/ajudadorabot:v1.2.0
kubectl rollout status deployment/ajudadorabot-api
```

#### Rollback Procedures
```bash
# Docker Compose
docker-compose down
docker-compose up -d

# Kubernetes
kubectl rollout undo deployment/ajudadorabot-api
kubectl rollout status deployment/ajudadorabot-api
```

### Security Updates

#### Dependency Updates
```bash
# Update .NET packages
dotnet update

# Update Node.js packages
cd frontend && npm update

# Update container base images
docker pull mcr.microsoft.com/dotnet/aspnet:9.0-alpine
```

#### Secret Rotation
```bash
# Generate new secrets
./scripts/generate-secrets.sh all

# Update secrets in deployment
kubectl create secret generic ajudadorabot-secrets --from-env-file=.env.production --dry-run=client -o yaml | kubectl apply -f -

# Restart application to use new secrets
kubectl rollout restart deployment/ajudadorabot-api
```

## Support & Contact

- **Documentation**: [GitHub Wiki](https://github.com/yourusername/AjudadoraBot/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/AjudadoraBot/issues)
- **Security**: security@ajudadorabot.com
- **Support**: support@ajudadorabot.com

---

**Note**: This deployment guide assumes familiarity with containerization, orchestration platforms, and DevOps practices. Always test in a staging environment before deploying to production.