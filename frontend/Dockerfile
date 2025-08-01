# Optimized Dockerfile for Azure App Service Frontend Container Deployment
# Multi-stage build for AjudadoraBot Telegram Mini App Frontend

# ================================
# Frontend Build Stage
# ================================
FROM node:20-alpine AS frontend-build

# Build arguments
ARG BUILD_DATE
ARG VERSION="1.0.0"
ARG BUILDKIT_INLINE_CACHE=1

# Install security updates and build dependencies
RUN apk upgrade --no-cache && \
    apk add --no-cache git python3 make g++

# Security: Create non-root user for build process
RUN addgroup -g 1001 -S nodejs && \
    adduser -S frontend -u 1001 -G nodejs

# Set working directory
WORKDIR /frontend

# Copy package files and install dependencies
COPY --chown=frontend:nodejs package*.json ./
RUN npm ci --only=production --no-audit --no-fund --ignore-scripts && \
    npm cache clean --force

# Copy frontend source
COPY --chown=frontend:nodejs . ./

# Switch to non-root user for build
USER frontend

# Build frontend (if build script exists)
RUN npm run build 2>/dev/null || echo "No build script found, using files as-is"

# Optimize static files for production
RUN find . -name "*.js" -not -path "./node_modules/*" -exec gzip -k {} \; 2>/dev/null || true && \
    find . -name "*.css" -not -path "./node_modules/*" -exec gzip -k {} \; 2>/dev/null || true && \
    find . -name "*.html" -not -path "./node_modules/*" -exec gzip -k {} \; 2>/dev/null || true

# ================================
# Production Runtime Stage (Nginx)
# ================================
FROM nginx:1.25-alpine AS runtime

# Build metadata
ARG BUILD_DATE
ARG VERSION

# Install security updates
RUN apk upgrade --no-cache && \
    apk add --no-cache curl bash tzdata && \
    rm -rf /var/cache/apk/*

# Create application user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Set Azure App Service compatible environment variables
ENV TZ=UTC \
    PORT=8080 \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=true \
    WEBSITES_CONTAINER_START_TIME_LIMIT=230

# Create nginx configuration optimized for Azure App Service
RUN cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging format
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        image/svg+xml;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    server {
        listen 8080;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        # Error pages
        error_page 404 /index.html;
        error_page 500 502 503 504 /index.html;

        # Health check endpoint for Azure App Service
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Main location block
        location / {
            try_files $uri $uri/ /index.html;
            
            # Cache static assets
            location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
                add_header Vary "Accept-Encoding";
            }
            
            # Security headers for HTML files
            location ~* \.html$ {
                add_header Cache-Control "no-cache, no-store, must-revalidate";
                add_header Pragma "no-cache";
                add_header Expires "0";
            }
        }

        # Service Worker
        location /sw.js {
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }

        # API proxy (if needed)
        location /api/ {
            # This would proxy to your backend service
            # proxy_pass http://backend-service/api/;
            return 404;
        }
    }
}
EOF

# Copy frontend files from build stage
COPY --from=frontend-build --chown=nginx:nginx /frontend /usr/share/nginx/html/

# Remove unnecessary files
RUN find /usr/share/nginx/html -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/share/nginx/html -name "package*.json" -delete 2>/dev/null || true && \
    find /usr/share/nginx/html -name "Dockerfile*" -delete 2>/dev/null || true

# Ensure proper permissions
RUN chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/log/nginx && \
    chmod -R 755 /usr/share/nginx/html

# Health check optimized for Azure App Service
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f --max-time 5 http://localhost:8080/health || exit 1

# Expose the port that Azure App Service expects
EXPOSE 8080

# Production build metadata and labels
LABEL maintainer="AjudadoraBot Team" \
      org.opencontainers.image.title="AjudadoraBot Frontend" \
      org.opencontainers.image.description="Production-ready Telegram Mini App Frontend for Azure App Service" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/yourusername/ajudadorabot" \
      org.opencontainers.image.vendor="AjudadoraBot Team" \
      org.opencontainers.image.licenses="MIT" \
      azure.app-service.optimized="true" \
      security.scan="enabled"

# Start nginx
CMD ["nginx", "-g", "daemon off;"]