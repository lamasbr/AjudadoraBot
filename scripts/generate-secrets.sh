#!/bin/bash
# AjudadoraBot Secrets Generation Script
# Generates secure secrets for production deployment

set -euo pipefail

# Configuration
SECRETS_DIR="${SECRETS_DIR:-./secrets}"
ENVIRONMENT="${ENVIRONMENT:-production}"
KEY_LENGTH="${KEY_LENGTH:-32}"
PASSWORD_LENGTH="${PASSWORD_LENGTH:-24}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Generate random string
generate_random() {
    local length=$1
    local charset="${2:-A-Za-z0-9}"
    
    if command -v openssl &> /dev/null; then
        openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-$length
    elif [[ -e /dev/urandom ]]; then
        tr -dc "$charset" < /dev/urandom | head -c $length
    else
        error "No secure random generator available"
        exit 1
    fi
}

# Generate JWT secret
generate_jwt_secret() {
    generate_random 64 'A-Za-z0-9+/='
}

# Generate encryption key
generate_encryption_key() {
    generate_random $KEY_LENGTH 'A-Za-z0-9'
}

# Generate password
generate_password() {
    generate_random $PASSWORD_LENGTH 'A-Za-z0-9!@#$%^&*'
}

# Generate webhook secret token
generate_webhook_secret() {
    generate_random 32 'A-Za-z0-9'
}

# Create secrets directory
create_secrets_dir() {
    if [[ ! -d "$SECRETS_DIR" ]]; then
        mkdir -p "$SECRETS_DIR"
        chmod 700 "$SECRETS_DIR"
        log "Created secrets directory: $SECRETS_DIR"
    fi
}

# Generate environment file
generate_env_file() {
    local env_file="$SECRETS_DIR/.env.$ENVIRONMENT"
    
    log "Generating environment file: $env_file"
    
    cat > "$env_file" << EOF
# AjudadoraBot Environment Variables - $ENVIRONMENT
# Generated on $(date)
# DO NOT COMMIT THIS FILE TO VERSION CONTROL

# Environment
ASPNETCORE_ENVIRONMENT=$ENVIRONMENT
ASPNETCORE_URLS=http://+:8080

# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=
WEBHOOK_URL=
WEBHOOK_SECRET_TOKEN=$(generate_webhook_secret)

# JWT Configuration
JWT_SECRET=$(generate_jwt_secret)
JWT_ISSUER=AjudadoraBot
JWT_AUDIENCE=AjudadoraBot-Users
JWT_EXPIRATION_MINUTES=1440

# Database Configuration
DATABASE_CONNECTION_STRING=Data Source=/app/data/ajudadorabot.db
POSTGRES_DB=ajudadorabot
POSTGRES_USER=ajudadorabot
POSTGRES_PASSWORD=$(generate_password)

# Redis Configuration
REDIS_CONNECTION_STRING=redis:6379
REDIS_PASSWORD=$(generate_password)

# Security Configuration
ENCRYPTION_KEY=$(generate_encryption_key)
HSTS_MAX_AGE=31536000
ENABLE_HTTPS_REDIRECT=true

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM_ADDRESS=noreply@ajudadorabot.com
SMTP_FROM_NAME=AjudadoraBot

# Storage Configuration
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=us-east-1
AWS_S3_BUCKET=ajudadorabot-$ENVIRONMENT

# Monitoring Configuration
GRAFANA_USER=admin
GRAFANA_PASSWORD=$(generate_password)

# Alert Configuration
SLACK_WEBHOOK_URL=
DISCORD_WEBHOOK_URL=

# Additional Security
SESSION_SECRET=$(generate_encryption_key)
COOKIE_SECRET=$(generate_encryption_key)
API_KEY=$(generate_random 40 'A-Za-z0-9')

EOF

    chmod 600 "$env_file"
    success "Environment file generated: $env_file"
}

# Generate Kubernetes secrets YAML
generate_k8s_secrets() {
    local k8s_file="$SECRETS_DIR/k8s-secrets-$ENVIRONMENT.yaml"
    
    log "Generating Kubernetes secrets file: $k8s_file"
    
    # Generate secrets
    local jwt_secret=$(generate_jwt_secret)
    local webhook_secret=$(generate_webhook_secret)
    local encryption_key=$(generate_encryption_key)
    local postgres_password=$(generate_password)
    local redis_password=$(generate_password)
    local grafana_password=$(generate_password)
    
    # Base64 encode secrets
    local jwt_secret_b64=$(echo -n "$jwt_secret" | base64 -w 0)
    local webhook_secret_b64=$(echo -n "$webhook_secret" | base64 -w 0)
    local encryption_key_b64=$(echo -n "$encryption_key" | base64 -w 0)
    local postgres_password_b64=$(echo -n "$postgres_password" | base64 -w 0)
    local redis_password_b64=$(echo -n "$redis_password" | base64 -w 0)
    local grafana_password_b64=$(echo -n "$grafana_password" | base64 -w 0)
    
    cat > "$k8s_file" << EOF
# Kubernetes Secrets for AjudadoraBot - $ENVIRONMENT
# Generated on $(date)
# DO NOT COMMIT THIS FILE TO VERSION CONTROL

apiVersion: v1
kind: Secret
metadata:
  name: ajudadorabot-secrets
  namespace: ajudadorabot-$ENVIRONMENT
  labels:
    app.kubernetes.io/name: ajudadorabot
    app.kubernetes.io/component: secrets
    environment: $ENVIRONMENT
type: Opaque
data:
  # JWT Configuration
  jwt-secret: $jwt_secret_b64
  
  # Telegram Bot Configuration  
  webhook-secret-token: $webhook_secret_b64
  
  # Database Configuration
  postgres-password: $postgres_password_b64
  
  # Redis Configuration
  redis-password: $redis_password_b64
  
  # Security
  encryption-key: $encryption_key_b64
  
  # Monitoring
  grafana-admin-password: $grafana_password_b64
  
---
# Plain text values for reference (delete this section after use)
# jwt-secret: $jwt_secret
# webhook-secret-token: $webhook_secret
# postgres-password: $postgres_password
# redis-password: $redis_password
# encryption-key: $encryption_key
# grafana-admin-password: $grafana_password

EOF

    chmod 600 "$k8s_file"
    success "Kubernetes secrets file generated: $k8s_file"
    
    # Create separate file with plain text values
    local plain_file="$SECRETS_DIR/secrets-plain-$ENVIRONMENT.txt"
    cat > "$plain_file" << EOF
# Plain text secrets for $ENVIRONMENT - $(date)
# Store these securely and delete this file after copying to secret management system

JWT_SECRET=$jwt_secret
WEBHOOK_SECRET_TOKEN=$webhook_secret
POSTGRES_PASSWORD=$postgres_password
REDIS_PASSWORD=$redis_password
ENCRYPTION_KEY=$encryption_key
GRAFANA_ADMIN_PASSWORD=$grafana_password

EOF
    chmod 600 "$plain_file"
    success "Plain text secrets file generated: $plain_file"
}

# Generate TLS certificates (self-signed for development)
generate_tls_certs() {
    local certs_dir="$SECRETS_DIR/tls"
    
    if [[ "$ENVIRONMENT" == "production" ]]; then
        warning "Skipping TLS certificate generation for production (use cert-manager or external CA)"
        return 0
    fi
    
    log "Generating self-signed TLS certificates for development..."
    
    mkdir -p "$certs_dir"
    
    # Generate private key
    openssl genrsa -out "$certs_dir/server.key" 2048
    
    # Generate certificate signing request
    openssl req -new -key "$certs_dir/server.key" -out "$certs_dir/server.csr" -subj "/C=US/ST=CA/L=San Francisco/O=AjudadoraBot/CN=localhost"
    
    # Generate self-signed certificate
    openssl x509 -req -days 365 -in "$certs_dir/server.csr" -signkey "$certs_dir/server.key" -out "$certs_dir/server.crt"
    
    # Generate DH parameters
    openssl dhparam -out "$certs_dir/dhparam.pem" 2048
    
    chmod 600 "$certs_dir"/*
    
    success "TLS certificates generated in: $certs_dir"
}

# Generate Docker Compose secrets
generate_docker_secrets() {
    local docker_env="$SECRETS_DIR/.env.docker"
    
    log "Generating Docker Compose environment file: $docker_env"
    
    cat > "$docker_env" << EOF
# Docker Compose Environment Variables
# Generated on $(date)

# Basic Configuration
TELEGRAM_BOT_TOKEN=
WEBHOOK_URL=http://localhost:8080/webhook
WEBHOOK_SECRET_TOKEN=$(generate_webhook_secret)
JWT_SECRET=$(generate_jwt_secret)

# Database
POSTGRES_DB=ajudadorabot
POSTGRES_USER=ajudadorabot
POSTGRES_PASSWORD=$(generate_password)

# Redis
REDIS_PASSWORD=$(generate_password)

# Monitoring
GRAFANA_USER=admin
GRAFANA_PASSWORD=$(generate_password)

# Security
ENCRYPTION_KEY=$(generate_encryption_key)

EOF

    chmod 600 "$docker_env"
    success "Docker Compose environment file generated: $docker_env"
}

# Generate AWS Secrets Manager JSON
generate_aws_secrets() {
    local aws_file="$SECRETS_DIR/aws-secrets-$ENVIRONMENT.json"
    
    log "Generating AWS Secrets Manager JSON: $aws_file"
    
    cat > "$aws_file" << EOF
{
  "telegram": {
    "bot_token": "",
    "webhook_url": "",
    "webhook_secret_token": "$(generate_webhook_secret)"
  },
  "auth": {
    "jwt_secret": "$(generate_jwt_secret)"
  },
  "database": {
    "postgres_host": "",
    "postgres_db": "ajudadorabot",
    "postgres_user": "ajudadorabot", 
    "postgres_password": "$(generate_password)"
  },
  "redis": {
    "host": "",
    "port": "6379",
    "password": "$(generate_password)"
  },
  "smtp": {
    "username": "",
    "password": ""
  },
  "monitoring": {
    "grafana_admin_password": "$(generate_password)"
  },
  "notifications": {
    "slack_webhook_url": "",
    "discord_webhook_url": ""
  },
  "aws": {
    "access_key_id": "",
    "secret_access_key": ""
  },
  "security": {
    "encryption_key": "$(generate_encryption_key)"
  }
}
EOF

    chmod 600 "$aws_file"
    success "AWS Secrets Manager JSON generated: $aws_file"
}

# Main function
main() {
    log "Starting secrets generation for environment: $ENVIRONMENT"
    
    create_secrets_dir
    
    case "${1:-all}" in
        "env")
            generate_env_file
            ;;
        "k8s")
            generate_k8s_secrets
            ;;
        "tls")
            generate_tls_certs
            ;;
        "docker")
            generate_docker_secrets
            ;;
        "aws")
            generate_aws_secrets
            ;;
        "all")
            generate_env_file
            generate_k8s_secrets
            generate_tls_certs
            generate_docker_secrets
            generate_aws_secrets
            ;;
        *)
            cat << EOF
Usage: $0 <command> [environment]

Commands:
  env      Generate environment file (.env)
  k8s      Generate Kubernetes secrets YAML
  tls      Generate TLS certificates (dev only)
  docker   Generate Docker Compose secrets
  aws      Generate AWS Secrets Manager JSON
  all      Generate all secrets (default)

Environment variables:
  ENVIRONMENT=production|staging|development (default: production)
  SECRETS_DIR=./secrets (default)
  KEY_LENGTH=32 (default)
  PASSWORD_LENGTH=24 (default)

Examples:
  $0 all
  ENVIRONMENT=staging $0 k8s
  SECRETS_DIR=/secure/path $0 env
EOF
            exit 1
            ;;
    esac
    
    echo ""
    success "Secrets generation completed!"
    echo ""
    warning "IMPORTANT SECURITY NOTES:"
    warning "1. Review all generated files before use"
    warning "2. Set actual values for empty fields (marked with '')"
    warning "3. Store secrets securely (never commit to version control)"
    warning "4. Use proper secret management systems in production"
    warning "5. Rotate secrets regularly"
    warning "6. Delete plain text secret files after copying to secure storage"
    echo ""
    log "Generated files location: $SECRETS_DIR"
    ls -la "$SECRETS_DIR"
}

# Run main function with all arguments
main "$@"