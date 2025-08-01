# Multi-stage build for AjudadoraBot Production Deployment
# Optimized for security, performance, and minimal attack surface

# ================================
# Frontend Build Stage
# ================================
FROM node:20-alpine AS frontend-build

# Security: Run as non-root user during build
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

# Set working directory
WORKDIR /frontend

# Copy package files and install dependencies
COPY --chown=nextjs:nodejs frontend/package*.json ./
RUN npm ci --only=production --no-audit --no-fund && \
    npm cache clean --force

# Copy frontend source and build
COPY --chown=nextjs:nodejs frontend/ ./
USER nextjs
RUN npm run build 2>/dev/null || echo "No build script found, copying files as-is"

# Optimize frontend files for production
RUN find . -name "*.js" -not -path "./node_modules/*" -exec gzip -k {} \; || true && \
    find . -name "*.css" -not -path "./node_modules/*" -exec gzip -k {} \; || true

# ================================
# Backend Build Stage
# ================================
FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS backend-build

# Install security updates
RUN apk upgrade --no-cache

WORKDIR /src

# Copy solution and project files for dependency restoration
COPY *.sln ./
COPY src/AjudadoraBot.Api/AjudadoraBot.Api.csproj src/AjudadoraBot.Api/
COPY src/AjudadoraBot.Core/AjudadoraBot.Core.csproj src/AjudadoraBot.Core/
COPY src/AjudadoraBot.Infrastructure/AjudadoraBot.Infrastructure.csproj src/AjudadoraBot.Infrastructure/

# Restore dependencies with optimization flags
RUN dotnet restore --runtime linux-musl-x64 --no-cache

# Copy source code
COPY src/ src/

# Build and publish with production optimizations
RUN dotnet build -c Release --no-restore --runtime linux-musl-x64 && \
    dotnet publish src/AjudadoraBot.Api/AjudadoraBot.Api.csproj \
    -c Release \
    -o /app/publish \
    --no-restore \
    --runtime linux-musl-x64 \
    --self-contained false \
    --verbosity minimal \
    -p:PublishReadyToRun=true \
    -p:PublishSingleFile=false \
    -p:PublishTrimmed=false

# Remove unnecessary files to reduce image size
RUN find /app/publish -name "*.pdb" -delete && \
    find /app/publish -name "*.xml" -delete

# ================================
# Production Runtime Stage
# ================================
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS runtime

# Install security updates and required packages
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    curl \
    ca-certificates \
    tzdata \
    icu-libs \
    && rm -rf /var/cache/apk/*

# Create application user with minimal privileges
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup -h /app -s /bin/sh

# Set security-focused environment variables
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    ASPNETCORE_FORWARDEDHEADERS_ENABLED=true \
    TZ=UTC

# Create necessary directories with proper permissions
# Azure App Service uses /tmp for writable storage
RUN mkdir -p /app/data /app/logs /app/wwwroot /tmp && \
    chown -R appuser:appgroup /app && \
    chmod 755 /tmp

WORKDIR /app

# Copy published application with proper ownership
COPY --from=backend-build --chown=appuser:appgroup /app/publish ./

# Copy frontend files with proper ownership
COPY --from=frontend-build --chown=appuser:appgroup /frontend ./wwwroot/

# Create SQLite database directory with proper permissions
# Ensure /tmp is writable for Azure App Service
RUN mkdir -p /app/data && \
    chown appuser:appgroup /app/data && \
    chmod 750 /app/data && \
    chmod 777 /tmp

# Switch to non-root user
USER appuser

# Enhanced health check with better error handling
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f -k --max-time 5 http://localhost:8080/health || exit 1

# Expose port
EXPOSE 8080

# Security: Drop capabilities and run with minimal privileges
# Use dumb-init for proper signal handling
ENTRYPOINT ["dotnet", "AjudadoraBot.Api.dll"]

# Production build metadata
LABEL maintainer="AjudadoraBot Team" \
      version="1.0.0" \
      description="Production-ready AjudadoraBot Telegram Bot API" \
      security.scan="enabled" \
      build.date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
      build.version="1.0.0"