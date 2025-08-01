# AjudadoraBot Operations Runbook

This runbook provides step-by-step procedures for common operational tasks, incident response, and troubleshooting for AjudadoraBot in production environments.

## Table of Contents
- [System Overview](#system-overview)
- [Emergency Contacts](#emergency-contacts)
- [Incident Response](#incident-response)
- [Common Operations](#common-operations)
- [Monitoring & Alerting](#monitoring--alerting)
- [Troubleshooting Procedures](#troubleshooting-procedures)
- [Maintenance Procedures](#maintenance-procedures)
- [Recovery Procedures](#recovery-procedures)

## System Overview

### Architecture Components
- **API Server**: ASP.NET Core 9.0 (ajudadorabot-api)
- **Web Server**: NGINX (reverse proxy, load balancer)
- **Database**: SQLite (with optional PostgreSQL)
- **Cache**: Redis (optional)
- **Monitoring**: Prometheus + Grafana
- **Logging**: Structured JSON logs

### Service Dependencies
```
Internet → NGINX → AjudadoraBot API → SQLite Database
                                  → Redis Cache (optional)
                                  → Telegram API
```

### Key URLs
- **Production**: https://ajudadorabot.com
- **Staging**: https://staging.ajudadorabot.com
- **Health Check**: https://ajudadorabot.com/health
- **Metrics**: https://ajudadorabot.com/metrics (internal only)
- **Grafana**: https://monitoring.ajudadorabot.com
- **API Docs**: https://ajudadorabot.com/swagger

## Emergency Contacts

### On-Call Rotation
- **Primary**: DevOps Team (+1-555-0123)
- **Secondary**: Backend Team (+1-555-0124)
- **Escalation**: Engineering Manager (+1-555-0125)

### External Services
- **Hosting Provider**: Support Portal / +1-800-XXX-XXXX
- **Telegram Support**: @BotSupport (for bot-related issues)
- **DNS Provider**: Control Panel / +1-800-XXX-XXXX

### Communication Channels
- **Slack**: #incidents (critical alerts)
- **Slack**: #devops (operational updates)
- **Email**: incidents@ajudadorabot.com
- **Status Page**: https://status.ajudadorabot.com

## Incident Response

### Severity Levels

#### P0 - Critical (Service Down)
- **Response Time**: 15 minutes
- **Resolution Time**: 2 hours
- **Examples**: Complete service outage, data loss, security breach

#### P1 - High (Degraded Service)
- **Response Time**: 30 minutes
- **Resolution Time**: 4 hours
- **Examples**: High error rates, significant performance degradation

#### P2 - Medium (Minor Issues)
- **Response Time**: 2 hours
- **Resolution Time**: 24 hours
- **Examples**: Non-critical feature failures, minor performance issues

#### P3 - Low (Maintenance)
- **Response Time**: 24 hours
- **Resolution Time**: 1 week
- **Examples**: Enhancement requests, minor bugs

### Incident Response Process

#### 1. Initial Response (0-15 minutes)
```bash
# Acknowledge the alert
# Check system status
curl -f https://ajudadorabot.com/health

# Check Grafana dashboard
# Open: https://monitoring.ajudadorabot.com

# Create incident channel
# Slack: /incident create "Brief description"

# Update status page
# Post initial update on status.ajudadorabot.com
```

#### 2. Assessment (15-30 minutes)
```bash
# Check application logs
kubectl logs -f deployment/ajudadorabot-api -n ajudadorabot-production --tail=100

# Check system metrics
kubectl top nodes
kubectl top pods -n ajudadorabot-production

# Check external dependencies
curl -f https://api.telegram.org/bot${BOT_TOKEN}/getMe

# Document findings in incident channel
```

#### 3. Mitigation (30+ minutes)
```bash
# Apply immediate fixes based on issue type
# See specific troubleshooting procedures below

# If critical, consider rollback
kubectl rollout undo deployment/ajudadorabot-api -n ajudadorabot-production

# Monitor the fix
watch kubectl get pods -n ajudadorabot-production
```

#### 4. Resolution & Post-Mortem
```bash
# Verify full recovery
curl -f https://ajudadorabot.com/health
# Test critical user flows

# Update status page with resolution
# Close incident channel

# Schedule post-mortem meeting within 24 hours
# Document lessons learned
```

## Common Operations

### Deployment Operations

#### Check Current Deployment Status
```bash
# Kubernetes
kubectl get deployments -n ajudadorabot-production
kubectl rollout status deployment/ajudadorabot-api -n ajudadorabot-production

# Docker Compose
docker-compose ps
docker-compose logs --tail=50 ajudadorabot-api
```

#### Deploy New Version
```bash
# Kubernetes - Rolling Update
kubectl set image deployment/ajudadorabot-api \
  api=ghcr.io/yourusername/ajudadorabot:v1.2.0 \
  -n ajudadorabot-production

# Monitor deployment
kubectl rollout status deployment/ajudadorabot-api -n ajudadorabot-production

# Verify health after deployment
curl -f https://ajudadorabot.com/health
```

#### Rollback Deployment
```bash
# Quick rollback to previous version
kubectl rollout undo deployment/ajudadorabot-api -n ajudadorabot-production

# Rollback to specific revision
kubectl rollout history deployment/ajudadorabot-api -n ajudadorabot-production
kubectl rollout undo deployment/ajudadorabot-api --to-revision=2 -n ajudadorabot-production

# Verify rollback
kubectl rollout status deployment/ajudadorabot-api -n ajudadorabot-production
```

### Scaling Operations

#### Manual Scaling
```bash
# Scale up for high traffic
kubectl scale deployment ajudadorabot-api --replicas=5 -n ajudadorabot-production

# Scale down during low traffic
kubectl scale deployment ajudadorabot-api --replicas=2 -n ajudadorabot-production

# Check HPA status
kubectl get hpa -n ajudadorabot-production
```

#### Auto-scaling Configuration
```bash
# Update HPA limits
kubectl patch hpa ajudadorabot-api-hpa -n ajudadorabot-production \
  -p '{"spec":{"maxReplicas":10}}'

# Check current auto-scaling metrics
kubectl describe hpa ajudadorabot-api-hpa -n ajudadorabot-production
```

### Configuration Updates

#### Update Environment Variables
```bash
# Update config map
kubectl create configmap ajudadorabot-config \
  --from-file=appsettings.json \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart deployment to pick up changes
kubectl rollout restart deployment/ajudadorabot-api -n ajudadorabot-production
```

#### Update Secrets
```bash
# Create new secret version
kubectl create secret generic ajudadorabot-secrets \
  --from-env-file=.env.production \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart to use new secrets
kubectl rollout restart deployment/ajudadorabot-api -n ajudadorabot-production
```

## Monitoring & Alerting

### Key Metrics to Monitor

#### Application Metrics
- **Request Rate**: http_requests_per_second
- **Error Rate**: http_requests_total{status="5xx"} / http_requests_total
- **Response Time**: http_request_duration_seconds (95th percentile)
- **Active Users**: telegram_active_users_total

#### System Metrics
- **CPU Usage**: container_cpu_usage_seconds_total
- **Memory Usage**: container_memory_usage_bytes
- **Disk Usage**: node_filesystem_avail_bytes
- **Network I/O**: container_network_receive_bytes_total

### Dashboard URLs
- **Application Overview**: https://monitoring.ajudadorabot.com/d/app-overview
- **System Health**: https://monitoring.ajudadorabot.com/d/system-health
- **Business Metrics**: https://monitoring.ajudadorabot.com/d/business-metrics

### Alert Investigation

#### High Error Rate Alert
```bash
# Check recent errors in logs
kubectl logs -f deployment/ajudadorabot-api -n ajudadorabot-production | grep ERROR

# Check error distribution by endpoint
# Use Grafana query: rate(http_requests_total{status=~"5.."}[5m]) by (method, route)

# Check for external service issues
curl -f https://api.telegram.org/bot${BOT_TOKEN}/getMe
```

#### High Response Time Alert
```bash
# Check system resources
kubectl top pods -n ajudadorabot-production

# Check for database issues
./scripts/cleanup.sh health

# Check for network issues
kubectl get endpoints -n ajudadorabot-production
```

#### Service Down Alert
```bash
# Check pod status
kubectl get pods -n ajudadorabot-production

# Check recent deployments
kubectl rollout history deployment/ajudadorabot-api -n ajudadorabot-production

# Check resource constraints
kubectl describe pods -n ajudadorabot-production
```

## Troubleshooting Procedures

### Application Issues

#### 1. Service Won't Start / Crashing
```bash
# Check pod events
kubectl describe pod <pod-name> -n ajudadorabot-production

# Check application logs
kubectl logs <pod-name> -n ajudadorabot-production --previous

# Common causes and solutions:
# - Missing environment variables: Check secrets and configmaps
# - Database connection: Verify database accessibility
# - Port conflicts: Check service configuration
# - Resource limits: Check and adjust CPU/memory limits
```

#### 2. Database Connection Issues
```bash
# Check database file exists and is accessible
kubectl exec deployment/ajudadorabot-api -n ajudadorabot-production -- \
  ls -la /app/data/

# Check database integrity
kubectl exec deployment/ajudadorabot-api -n ajudadorabot-production -- \
  sqlite3 /app/data/ajudadorabot.db "PRAGMA integrity_check;"

# Check permissions
kubectl exec deployment/ajudadorabot-api -n ajudadorabot-production -- \
  stat /app/data/ajudadorabot.db

# If corrupted, restore from backup
./scripts/restore.sh interactive
```

#### 3. Memory Issues / OOM Kills
```bash
# Check memory usage trends
# Grafana: container_memory_usage_bytes

# Check for memory leaks
kubectl top pods -n ajudadorabot-production

# Temporary fix: Restart application
kubectl rollout restart deployment/ajudadorabot-api -n ajudadorabot-production

# Long-term fix: Increase memory limits or optimize application
kubectl patch deployment ajudadorabot-api -n ajudadorabot-production \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","resources":{"limits":{"memory":"1Gi"}}}]}}}}'
```

### Infrastructure Issues

#### 1. Kubernetes Node Issues
```bash
# Check node status
kubectl get nodes

# Check node resources
kubectl describe node <node-name>

# If node is NotReady, cordon and drain
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Pods will be rescheduled to healthy nodes
```

#### 2. Storage Issues
```bash
# Check PVC status
kubectl get pvc -n ajudadorabot-production

# Check available storage
kubectl exec deployment/ajudadorabot-api -n ajudadorabot-production -- \
  df -h /app/data

# If storage is full, clean up old files
kubectl exec deployment/ajudadorabot-api -n ajudadorabot-production -- \
  /app/scripts/cleanup.sh full
```

#### 3. Network Issues
```bash
# Check service endpoints
kubectl get endpoints -n ajudadorabot-production

# Check ingress status
kubectl get ingress -n ajudadorabot-production

# Test internal connectivity
kubectl exec deployment/ajudadorabot-api -n ajudadorabot-production -- \
  curl -f http://ajudadorabot-api-service:8080/health

# Check external connectivity
kubectl exec deployment/ajudadorabot-api -n ajudadorabot-production -- \
  curl -f https://api.telegram.org/bot${BOT_TOKEN}/getMe
```

### External Service Issues

#### 1. Telegram API Issues
```bash
# Check Telegram API status
curl -f https://api.telegram.org/bot${BOT_TOKEN}/getMe

# Check webhook configuration
curl "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"

# Reset webhook if needed
curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -d "url=https://ajudadorabot.com/webhook" \
  -d "secret_token=${WEBHOOK_SECRET_TOKEN}"
```

#### 2. DNS Issues
```bash
# Check DNS resolution
nslookup ajudadorabot.com
dig ajudadorabot.com

# Check from inside cluster
kubectl exec deployment/ajudadorabot-api -n ajudadorabot-production -- \
  nslookup ajudadorabot.com
```

## Maintenance Procedures

### Scheduled Maintenance

#### Weekly Maintenance Window (Sundays 2-4 AM UTC)
```bash
# 1. Check system health
./scripts/cleanup.sh health

# 2. Run cleanup tasks
./scripts/cleanup.sh full

# 3. Check for security updates
kubectl get nodes -o wide  # Check node OS versions

# 4. Review monitoring dashboards
# - Check for any concerning trends
# - Verify all alerts are working

# 5. Test backup/restore procedures
./scripts/backup.sh backup
./scripts/restore.sh verify /path/to/recent/backup
```

#### Monthly Security Updates
```bash
# 1. Update container images
docker pull mcr.microsoft.com/dotnet/aspnet:9.0-alpine

# 2. Rebuild application image
docker build -f Dockerfile.production -t ajudadorabot:latest .

# 3. Security scan
docker scan ajudadorabot:latest

# 4. Deploy to staging first
kubectl set image deployment/ajudadorabot-api \
  api=ajudadorabot:latest \
  -n ajudadorabot-staging

# 5. Run tests in staging
curl -f https://staging.ajudadorabot.com/health

# 6. Deploy to production during maintenance window
kubectl set image deployment/ajudadorabot-api \
  api=ajudadorabot:latest \
  -n ajudadorabot-production
```

### Certificate Renewal

#### Let's Encrypt Certificate (Automated with cert-manager)
```bash
# Check certificate status
kubectl get certificates -n ajudadorabot-production

# Force renewal if needed
kubectl delete certificaterequest -n ajudadorabot-production --all

# Verify new certificate
openssl x509 -in <certificate-file> -text -noout | grep "Not After"
```

#### Manual Certificate Renewal
```bash
# Update certificate files
kubectl create secret tls ajudadorabot-tls \
  --cert=path/to/new/cert.pem \
  --key=path/to/new/key.pem \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart ingress controller if needed
kubectl rollout restart deployment/nginx-ingress-controller -n ingress-nginx
```

## Recovery Procedures

### Database Recovery

#### Scenario: Database Corruption
```bash
# 1. Stop the application
kubectl scale deployment ajudadorabot-api --replicas=0 -n ajudadorabot-production

# 2. Backup corrupted database (for analysis)
kubectl exec deployment/ajudadorabot-api -n ajudadorabot-production -- \
  cp /app/data/ajudadorabot.db /app/data/corrupted-$(date +%Y%m%d).db

# 3. List available backups
./scripts/restore.sh list

# 4. Restore from latest backup
./scripts/restore.sh interactive

# 5. Verify database integrity
sqlite3 /app/data/ajudadorabot.db "PRAGMA integrity_check;"

# 6. Restart application
kubectl scale deployment ajudadorabot-api --replicas=3 -n ajudadorabot-production

# 7. Verify service recovery
curl -f https://ajudadorabot.com/health
```

#### Scenario: Data Loss
```bash
# 1. Identify scope of data loss
# Check application logs for error patterns
kubectl logs deployment/ajudadorabot-api -n ajudadorabot-production --since=24h | grep ERROR

# 2. Find appropriate backup point
./scripts/restore.sh point-in-time "2024-01-01 10:00:00"

# 3. Calculate potential data loss
# Estimate time between backup and incident

# 4. Communicate with stakeholders about data loss scope

# 5. Proceed with restore if approved
./scripts/restore.sh point-in-time "2024-01-01 10:00:00"

# 6. Verify data consistency after restore
# Run data validation queries
```

### Service Recovery

#### Scenario: Complete Service Outage
```bash
# 1. Check all components
kubectl get all -n ajudadorabot-production

# 2. Check recent changes
kubectl rollout history deployment/ajudadorabot-api -n ajudadorabot-production

# 3. Quick rollback if recent deployment caused issue
kubectl rollout undo deployment/ajudadorabot-api -n ajudadorabot-production

# 4. If infrastructure issue, check nodes
kubectl get nodes
kubectl describe nodes

# 5. If persistent volume issue
kubectl get pv,pvc -n ajudadorabot-production

# 6. Emergency deployment to new cluster (if needed)
# Use backup infrastructure and restore from backup
```

#### Scenario: Partial Service Degradation
```bash
# 1. Identify affected components
kubectl get pods -n ajudadorabot-production

# 2. Check resource constraints
kubectl top pods -n ajudadorabot-production
kubectl describe pods -n ajudadorabot-production

# 3. Scale up if resource constrained
kubectl scale deployment ajudadorabot-api --replicas=5 -n ajudadorabot-production

# 4. Restart unhealthy pods
kubectl delete pod <unhealthy-pod> -n ajudadorabot-production

# 5. Monitor recovery
watch kubectl get pods -n ajudadorabot-production
```

### Disaster Recovery

#### Full Disaster Recovery (RTO: 1 hour, RPO: 6 hours)
```bash
# 1. Activate disaster recovery site
# Switch DNS to DR site
# Update DNS A records to point to DR cluster

# 2. Deploy application to DR cluster
kubectl apply -k k8s/production/ --kubeconfig=dr-cluster-config

# 3. Restore database from backup
# Download latest backup from cloud storage
aws s3 cp s3://ajudadorabot-backups/latest-backup.db.gz.enc .

# 4. Decrypt and restore
./scripts/restore.sh file latest-backup.db.gz.enc

# 5. Update configuration for DR environment
# Update webhook URL with new domain

# 6. Verify all systems operational
curl -f https://dr.ajudadorabot.com/health

# 7. Communicate service restoration to users
# Update status page
# Send notification to users
```

## Escalation Procedures

### When to Escalate

#### Immediate Escalation (P0)
- Complete service outage > 30 minutes
- Data breach or security incident
- Data loss affecting users
- External dependencies critical failure

#### Time-based Escalation (P1)
- Issue not resolved within 2 hours
- Multiple components failing
- Unable to identify root cause

### Escalation Contacts
1. **Engineering Manager**: +1-555-0125
2. **CTO**: +1-555-0126
3. **CEO**: +1-555-0127 (security incidents only)

### Communication Templates

#### Status Page Update
```
**INVESTIGATING**: We are investigating reports of [issue description]. 
We will provide updates as more information becomes available.
```

#### Resolution Update
```
**RESOLVED**: The issue with [component] has been resolved. 
All services are now operating normally. 
We apologize for any inconvenience.
```

---

**Remember**: 
- Document all actions taken during incidents
- Always verify fixes in staging before production
- Communicate proactively with stakeholders
- Conduct blameless post-mortems for all P0/P1 incidents