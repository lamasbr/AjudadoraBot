# AjudadoraBot - Telegram Bot Management System

[![.NET 9](https://img.shields.io/badge/.NET-9.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Supported-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![Azure](https://img.shields.io/badge/Azure-Optimized-0078D4?logo=microsoft-azure)](https://azure.microsoft.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/Tests-90%25%20Coverage-brightgreen)](./TESTING.md)

> **🤖 Professional Telegram Bot Management Platform** - A comprehensive, production-ready system for managing Telegram bots with a modern web interface, robust API, and enterprise-grade deployment options.

## 📋 Table of Contents

- [Features](#-features)
- [Technology Stack](#️-technology-stack)
- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Installation & Setup](#️-installation--setup)
- [Configuration](#️-configuration)
- [Usage](#-usage)
- [API Documentation](#-api-documentation)
- [Deployment](#-deployment)
- [Testing](#-testing)
- [Contributing](#-contributing)
- [Security](#-security)
- [Support](#-support)
- [License](#-license)

## ✨ Features

### 🎯 Core Functionality
- **Telegram Bot Management**: Complete bot lifecycle management with webhook and polling support
- **Mini App Interface**: Interactive Telegram Mini App for bot management
- **User Management**: Track and manage bot users with interaction analytics
- **Message Broadcasting**: Send messages to all users or specific user groups
- **Real-time Analytics**: Monitor bot performance, user engagement, and system metrics

### 🔧 Technical Features
- **.NET 9 Backend**: Modern ASP.NET Core Web API with clean architecture
- **SQLite Database**: Lightweight, serverless database with optional PostgreSQL support
- **JWT Authentication**: Secure authentication for Mini App integration
- **Rate Limiting**: Built-in API rate limiting and abuse protection
- **Health Checks**: Comprehensive health monitoring endpoints
- **Swagger/OpenAPI**: Complete API documentation with interactive testing

### 🚀 DevOps & Deployment
- **Docker Support**: Multi-stage containers optimized for production
- **Kubernetes Ready**: Complete K8s manifests with staging/production environments
- **Azure Optimized**: Special free-tier deployment configuration
- **CI/CD Pipeline**: GitHub Actions workflow with automated testing and deployment
- **Monitoring Stack**: Prometheus, Grafana, and Datadog integration
- **Security First**: Comprehensive security measures and vulnerability scanning

### 💰 Cost Optimization
- **Azure Free Tier**: Deploy for $0/month using Azure's free tier limits
- **Resource Efficient**: Optimized for minimal resource consumption
- **Combined Container**: Single container deployment to reduce costs
- **Smart Caching**: Redis integration for improved performance

## 🛠️ Technology Stack

### Backend
- **Framework**: ASP.NET Core 9.0
- **Language**: C# with nullable reference types
- **Database**: SQLite (primary), PostgreSQL (optional)
- **Cache**: Redis (optional)
- **Authentication**: JWT Bearer tokens
- **Testing**: xUnit, Moq, AutoFixture, FluentAssertions

### Frontend
- **Technology**: Vanilla JavaScript (ES6+)
- **UI Framework**: Telegram Mini App APIs
- **Testing**: Jest with JSDOM
- **Build Tools**: NPM scripts, ESLint
- **PWA**: Service Worker for offline functionality

### Infrastructure
- **Containerization**: Docker with multi-stage builds
- **Orchestration**: Kubernetes with Kustomize
- **Reverse Proxy**: NGINX
- **Cloud Platform**: Azure (optimized), AWS, GCP compatible
- **Monitoring**: Prometheus, Grafana, Datadog
- **CI/CD**: GitHub Actions

### Development Tools
- **IDE**: Visual Studio 2022, VS Code
- **Code Quality**: SonarQube, EditorConfig
- **Security**: OWASP ZAP, dependency scanning
- **Documentation**: Swagger/OpenAPI, Markdown

## 🚀 Quick Start

### 1-Minute Setup (Docker)

```bash
# Clone the repository
git clone https://github.com/yourusername/AjudadoraBot.git
cd AjudadoraBot

# Set up environment variables
cp .env.example .env
# Edit .env with your Telegram bot token

# Start with Docker Compose
docker-compose up -d

# Verify deployment
curl http://localhost:8080/health
```

### Azure Free Tier Deployment

Deploy to Azure for **$0/month** using our optimized configuration:

```bash
# Deploy with one command
./scripts/deploy-free-tier.ps1 -SubscriptionId "your-subscription-id"
```

See [Azure Free Tier Guide](./README_FREE_TIER.md) for detailed instructions.

## 📁 Project Structure

```
AjudadoraBot/
├── 📁 src/                          # Source code
│   ├── AjudadoraBot.Api/            # Web API project
│   ├── AjudadoraBot.Core/           # Domain models & interfaces
│   └── AjudadoraBot.Infrastructure/ # Data access & services
├── 📁 frontend/                     # Telegram Mini App
│   ├── css/                        # Styles
│   ├── js/                         # JavaScript modules
│   └── tests/                      # Frontend tests
├── 📁 tests/                       # Test suite
│   ├── AjudadoraBot.UnitTests/     # Unit tests
│   ├── AjudadoraBot.IntegrationTests/ # API integration tests
│   ├── AjudadoraBot.E2ETests/      # End-to-end tests
│   └── AjudadoraBot.PerformanceTests/ # Load tests
├── 📁 k8s/                         # Kubernetes manifests
│   ├── base/                       # Base configuration
│   ├── staging/                    # Staging environment
│   └── production/                 # Production environment
├── 📁 azure/                       # Azure deployment
│   ├── bicep/                      # Infrastructure as Code
│   └── scripts/                    # Deployment scripts
├── 📁 terraform/                   # Terraform configuration
├── 📁 monitoring/                  # Monitoring configuration
├── 📁 scripts/                     # Utility scripts
├── 📁 docs/                        # Additional documentation
├── 🐳 docker-compose.yml           # Local development
├── 🐳 Dockerfile                   # Production container
└── 📄 README.md                    # This file
```

## 📋 Prerequisites

### Required
- **.NET 9.0 SDK** - [Download](https://dotnet.microsoft.com/download)
- **Docker 24.0+** - [Download](https://www.docker.com/get-started)
- **Node.js 20+** - [Download](https://nodejs.org/) (for frontend development)
- **Telegram Bot Token** - Get from [@BotFather](https://t.me/botfather)

### Optional (for advanced deployment)
- **Kubernetes** - For production orchestration
- **Azure CLI** - For Azure deployment
- **Terraform** - For infrastructure provisioning
- **kubectl** - For Kubernetes management

### Development Tools
- **Visual Studio 2022** or **VS Code** - Recommended IDEs
- **Git** - Version control
- **Postman** - API testing (optional, Swagger UI included)

## ⚙️ Installation & Setup

### Development Environment

1. **Clone and setup the repository**:
   ```bash
   git clone https://github.com/yourusername/AjudadoraBot.git
   cd AjudadoraBot
   ```

2. **Backend setup**:
   ```bash
   # Restore NuGet packages
   dotnet restore
   
   # Setup database
   dotnet ef database update --project src/AjudadoraBot.Infrastructure
   
   # Run the API
   dotnet run --project src/AjudadoraBot.Api
   ```

3. **Frontend setup**:
   ```bash
   cd frontend
   npm install
   npm run serve  # Starts development server
   ```

4. **Environment configuration**:
   ```bash
   # Create environment file
   cp .env.example .env
   
   # Edit with your values
   nano .env
   ```

### Docker Development

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f ajudadorabot-api

# Stop services
docker-compose down
```

### Production Setup

See [Deployment Guide](./DEPLOYMENT.md) for comprehensive production deployment instructions.

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather | ✅ | - |
| `WEBHOOK_URL` | Public webhook URL | ⚠️ | - |
| `JWT_SECRET` | JWT signing secret | ✅ | - |
| `DATABASE_CONNECTION_STRING` | Database connection | ❌ | SQLite |
| `REDIS_CONNECTION_STRING` | Redis connection | ❌ | - |
| `ASPNETCORE_ENVIRONMENT` | Environment (Development/Staging/Production) | ❌ | Development |

### Configuration Files

- **appsettings.json** - Base configuration
- **appsettings.Development.json** - Development overrides
- **appsettings.Production.json** - Production overrides
- **.env** - Environment variables (local development)

### Bot Configuration

```json
{
  "TelegramBot": {
    "Token": "YOUR_BOT_TOKEN",
    "WebhookUrl": "https://yourdomain.com/webhook",
    "Mode": "Webhook",
    "MaxRetryAttempts": 3
  },
  "MiniApp": {
    "JwtSecret": "your-secure-secret",
    "JwtExpirationMinutes": 1440,
    "AllowedOrigins": ["https://yourdomain.com", "https://t.me"]
  }
}
```

## 🎯 Usage

### Bot Management

1. **Start your bot**: Send `/start` to your bot on Telegram
2. **Open Mini App**: Use the bot's web app button or send `/webapp`
3. **Dashboard**: View bot statistics, user metrics, and system health
4. **User Management**: Browse users, view interaction history
5. **Send Messages**: Broadcast messages to all users or specific groups
6. **Configure Settings**: Update bot settings and configuration

### API Usage

```bash
# Health check
curl https://yourdomain.com/health

# Get users (requires authentication)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     https://yourdomain.com/api/users

# Send message
curl -X POST https://yourdomain.com/api/messages \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -d '{"text": "Hello from AjudadoraBot!", "recipientType": "all"}'
```

### Mini App Features

- **📊 Dashboard**: Real-time statistics and charts
- **👥 User Management**: Search, filter, and manage bot users
- **💬 Messaging**: Send broadcasts and manage message history
- **⚙️ Settings**: Configure bot behavior and preferences
- **📱 Mobile Optimized**: Responsive design for mobile devices
- **🔄 Offline Support**: Works offline with service worker

## 📚 API Documentation

### Interactive Documentation

- **Swagger UI**: Available at `/api-docs` when running the application
- **OpenAPI Spec**: Available at `/swagger/v1/swagger.json`

### Key Endpoints

#### Authentication
```
POST /api/auth/login       # Authenticate user
POST /api/auth/refresh     # Refresh JWT token
```

#### Users
```
GET    /api/users          # Get paginated users
GET    /api/users/{id}     # Get specific user
POST   /api/users/{id}/block   # Block user
DELETE /api/users/{id}/block   # Unblock user
```

#### Messages
```
POST   /api/messages       # Send message
GET    /api/messages       # Get message history
```

#### Analytics
```
GET    /api/analytics/stats      # Get bot statistics
GET    /api/analytics/interactions # Get interaction data
```

#### System
```
GET    /health             # Health check
GET    /metrics            # Prometheus metrics
```

### Authentication

The API uses JWT Bearer token authentication:

```javascript
// Get token from Telegram Mini App
const initData = window.Telegram.WebApp.initData;

// Use token in API calls
fetch('/api/users', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
});
```

## 🚀 Deployment

### Deployment Options

| Method | Best For | Cost | Complexity |
|--------|----------|------|------------|
| **Azure Free Tier** | Personal projects, demos | Free | Low |
| **Docker Compose** | Small teams, simple setups | Low | Medium |
| **Kubernetes** | Enterprise, scalable deployments | Medium-High | High |
| **Cloud Services** | Managed solutions | Medium | Low-Medium |

### Quick Deployment

#### Azure Free Tier (Recommended for getting started)
```bash
# One-click deployment
./scripts/deploy-free-tier.ps1 -SubscriptionId "your-sub-id"
```
See [Azure Free Tier Guide](./README_FREE_TIER.md)

#### Docker Compose
```bash
# Production deployment
docker-compose -f docker-compose.yml -f docker-compose.production.yml up -d
```

#### Kubernetes
```bash
# Deploy to production
kubectl apply -k k8s/production/
```

### Detailed Guides

- **[📋 Complete Deployment Guide](./DEPLOYMENT.md)** - Comprehensive deployment instructions
- **[💰 Azure Free Tier Setup](./README_FREE_TIER.md)** - Deploy for free on Azure
- **[☁️ Azure Container Deployment](./AZURE_CONTAINER_DEPLOYMENT_GUIDE.md)** - Enterprise Azure setup
- **[📖 Operations Runbook](./RUNBOOK.md)** - Day-to-day operations

## 🧪 Testing

### Test Suite Overview

Our comprehensive test suite includes:

- **Unit Tests**: 90%+ code coverage
- **Integration Tests**: Full API testing
- **End-to-End Tests**: Browser automation with Playwright
- **Performance Tests**: Load testing with NBomber
- **Frontend Tests**: JavaScript testing with Jest

### Running Tests

```bash
# Run all tests
dotnet test

# Run specific test categories
dotnet test --filter Category=Unit
dotnet test --filter Category=Integration

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Frontend tests
cd frontend && npm test

# Generate comprehensive test report
./scripts/generate-test-report.ps1
```

### Test Configuration

Tests use:
- **In-memory databases** for isolation
- **Test containers** for integration tests
- **Mock services** for external dependencies
- **Automated CI/CD** pipeline testing

See [Testing Guide](./TESTING.md) for detailed information.

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Make** your changes and add tests
4. **Run** the test suite: `dotnet test && cd frontend && npm test`
5. **Commit** your changes: `git commit -m 'Add amazing feature'`
6. **Push** to the branch: `git push origin feature/amazing-feature`
7. **Open** a Pull Request

### Code Standards

- Follow **C# coding conventions** and **JavaScript ES6+ standards**
- Maintain **90%+ test coverage** for new code
- Use **semantic commit messages**
- Update **documentation** for user-facing changes
- Ensure **security best practices**

### Development Setup

```bash
# Setup pre-commit hooks
git config core.hooksPath .githooks
chmod +x .githooks/*

# Run code quality checks
dotnet format
npm run lint
```

## 🔒 Security

Security is a top priority for AjudadoraBot. We implement multiple layers of protection:

### Security Features

- **🔐 JWT Authentication** with secure token handling
- **🛡️ Input Validation** and output encoding
- **🔒 HTTPS Enforcement** in production
- **⚡ Rate Limiting** to prevent abuse
- **🏷️ Security Headers** for web protection
- **🔍 Dependency Scanning** for vulnerabilities
- **📝 Audit Logging** for security events

### Reporting Security Issues

If you discover a security vulnerability, please report it responsibly:

- **Email**: security@ajudadorabot.com
- **Response Time**: 24 hours acknowledgment
- **Scope**: Include detailed description and reproduction steps

Do **not** create public GitHub issues for security vulnerabilities.

See [Security Policy](./SECURITY.md) for complete security information.

## 📞 Support

### Documentation

- **[📋 Deployment Guide](./DEPLOYMENT.md)** - Production deployment
- **[🧪 Testing Guide](./TESTING.md)** - Test suite documentation
- **[🔒 Security Policy](./SECURITY.md)** - Security guidelines
- **[📖 Operations Runbook](./RUNBOOK.md)** - Day-to-day operations
- **[💰 Free Tier Guide](./README_FREE_TIER.md)** - Zero-cost deployment

### Get Help

- **🐛 Bug Reports**: [GitHub Issues](https://github.com/yourusername/AjudadoraBot/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/yourusername/AjudadoraBot/discussions)
- **📧 Email Support**: support@ajudadorabot.com
- **📖 API Documentation**: Available at `/api-docs` endpoint

### Community

- **⭐ Star** this repository if you find it helpful
- **🍴 Fork** to create your own version
- **👥 Follow** for updates and announcements
- **📢 Share** with others who might benefit

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 AjudadoraBot Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

<div align="center">

**⚡ Built with .NET 9 | 🤖 Powered by Telegram | 📊 Monitored by Datadog | ☁️ Deployed on Azure**

*Deploy a production-ready Telegram bot management system in minutes!*

[⭐ Star this repo](https://github.com/yourusername/AjudadoraBot) • [📋 Report Bug](https://github.com/yourusername/AjudadoraBot/issues) • [💡 Request Feature](https://github.com/yourusername/AjudadoraBot/discussions)

</div>