# Security Policy for AjudadoraBot

## Table of Contents
- [Security Overview](#security-overview)
- [Reporting Security Vulnerabilities](#reporting-security-vulnerabilities)
- [Security Best Practices](#security-best-practices)
- [Authentication & Authorization](#authentication--authorization)
- [Data Protection](#data-protection)
- [Infrastructure Security](#infrastructure-security)
- [Security Monitoring](#security-monitoring)
- [Incident Response](#incident-response)
- [Compliance](#compliance)

## Security Overview

AjudadoraBot implements defense-in-depth security measures across all layers:

- **Application Security**: Input validation, output encoding, secure coding practices
- **Infrastructure Security**: Network segmentation, access controls, encryption
- **Data Security**: Encryption at rest and in transit, secure data handling
- **Operational Security**: Monitoring, logging, incident response procedures

## Reporting Security Vulnerabilities

### Responsible Disclosure

If you discover a security vulnerability, please report it responsibly:

**Email**: security@ajudadorabot.com  
**Response Time**: 24 hours for acknowledgment, 72 hours for initial assessment

### What to Include

- Detailed description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Suggested remediation (if known)
- Your contact information

### What NOT to Include

- Do not publicly disclose the vulnerability
- Do not attempt to access unauthorized data
- Do not perform destructive testing
- Do not social engineer our staff

### Bug Bounty Program

We currently do not offer monetary rewards, but we will:
- Acknowledge your contribution publicly (if desired)
- Provide updates on remediation progress
- Credit you in our security acknowledgments

## Security Best Practices

### Secure Development

#### Code Security
```csharp
// Input validation
public IActionResult ProcessMessage([Required] string message)
{
    if (string.IsNullOrWhiteSpace(message))
        return BadRequest("Message is required");
    
    // Sanitize input
    message = HtmlEncoder.Default.Encode(message);
    
    // Process safely
    return Ok(ProcessSafeMessage(message));
}

// SQL Injection prevention (using parameterized queries)
var users = await _context.Users
    .Where(u => u.TelegramId == telegramId)
    .FirstOrDefaultAsync();
```

#### Dependency Management
```bash
# Regular security scanning
dotnet list package --vulnerable
npm audit

# Update dependencies
dotnet update
npm update

# Use specific versions in production
# Avoid wildcards in package versions
```

### Configuration Security

#### Environment Variables
```bash
# Use strong, unique secrets
JWT_SECRET=$(openssl rand -base64 64)
ENCRYPTION_KEY=$(openssl rand -hex 32)

# Never hardcode secrets in source code
# Use environment variables or secret management systems
```

#### HTTPS Configuration
```nginx
# Force HTTPS
server {
    listen 80;
    return 301 https://$server_name$request_uri;
}

# Strong SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;

# Security headers
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

## Authentication & Authorization

### JWT Token Security

#### Token Generation
```csharp
public string GenerateJwtToken(User user)
{
    var tokenHandler = new JwtSecurityTokenHandler();
    var key = Encoding.UTF8.GetBytes(_jwtSecret);
    
    var tokenDescriptor = new SecurityTokenDescriptor
    {
        Subject = new ClaimsIdentity(new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name, user.Username),
            new Claim("telegram_id", user.TelegramId.ToString())
        }),
        Expires = DateTime.UtcNow.AddMinutes(_jwtExpirationMinutes),
        SigningCredentials = new SigningCredentials(
            new SymmetricSecurityKey(key), 
            SecurityAlgorithms.HmacSha256Signature)
    };
    
    var token = tokenHandler.CreateToken(tokenDescriptor);
    return tokenHandler.WriteToken(token);
}
```

#### Token Validation
```csharp
[Authorize]
[TelegramAuth] // Custom attribute for Telegram-specific validation
public class SecureController : ControllerBase
{
    [HttpGet]
    public IActionResult GetUserData()
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        // Process authenticated request
    }
}
```

### Telegram Authentication

#### WebApp Data Validation
```csharp
public bool ValidateTelegramWebAppData(string initData, string botToken)
{
    var data = ParseInitData(initData);
    var hash = data["hash"];
    data.Remove("hash");
    
    var dataCheckString = string.Join("\n", 
        data.OrderBy(x => x.Key).Select(x => $"{x.Key}={x.Value}"));
    
    var secretKey = HMACSHA256.HashData(Encoding.UTF8.GetBytes("WebAppData"), 
        Encoding.UTF8.GetBytes(botToken));
    
    var calculatedHash = HMACSHA256.HashData(secretKey, 
        Encoding.UTF8.GetBytes(dataCheckString));
    
    return calculatedHash.SequenceEqual(
        Convert.FromHexString(hash));
}
```

## Data Protection

### Encryption

#### Data at Rest
```csharp
public class EncryptionService
{
    private readonly byte[] _key;
    
    public string Encrypt(string plainText)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.GenerateIV();
        
        using var encryptor = aes.CreateEncryptor();
        var encrypted = encryptor.TransformFinalBlock(
            Encoding.UTF8.GetBytes(plainText), 0, 
            Encoding.UTF8.GetBytes(plainText).Length);
        
        var result = new byte[aes.IV.Length + encrypted.Length];
        Array.Copy(aes.IV, 0, result, 0, aes.IV.Length);
        Array.Copy(encrypted, 0, result, aes.IV.Length, encrypted.Length);
        
        return Convert.ToBase64String(result);
    }
}
```

#### Data in Transit
```csharp
// HTTP Client configuration
services.AddHttpClient<TelegramBotClient>(client =>
{
    client.BaseAddress = new Uri("https://api.telegram.org/");
})
.ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler()
{
    ClientCertificateOptions = ClientCertificateOption.Manual,
    ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
});
```

### Data Minimization

#### User Data Collection
```csharp
public class UserDto
{
    public long TelegramId { get; set; }
    public string? FirstName { get; set; }
    public string? Username { get; set; }
    // Do not store: last_name, photo_url, auth_date unless necessary
}

// Automatic data cleanup
public async Task CleanupExpiredData()
{
    var cutoffDate = DateTime.UtcNow.AddDays(-_retentionDays);
    
    // Remove old interactions
    await _context.Interactions
        .Where(i => i.CreatedAt < cutoffDate)
        .ExecuteDeleteAsync();
        
    // Remove expired sessions
    await _context.UserSessions
        .Where(s => s.ExpiresAt < DateTime.UtcNow)
        .ExecuteDeleteAsync();
}
```

### GDPR Compliance

#### Data Subject Rights
```csharp
[HttpGet("export")]
public async Task<IActionResult> ExportUserData(long telegramId)
{
    var userData = await _userService.GetAllUserDataAsync(telegramId);
    var json = JsonSerializer.Serialize(userData, new JsonSerializerOptions
    {
        WriteIndented = true
    });
    
    return File(Encoding.UTF8.GetBytes(json), "application/json", 
        $"user-data-{telegramId}.json");
}

[HttpDelete("delete")]
public async Task<IActionResult> DeleteUserData(long telegramId)
{
    await _userService.DeleteAllUserDataAsync(telegramId);
    return Ok("User data deleted successfully");
}
```

## Infrastructure Security

### Container Security

#### Dockerfile Security
```dockerfile
# Use specific version tags
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine

# Run as non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Set security-focused environment variables
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_ENABLE_DIAGNOSTICS=0

USER appuser

# Use HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

#### Kubernetes Security

##### Pod Security Standards
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ajudadorabot-api
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    runAsGroup: 1001
    fsGroup: 1001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: api
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: false  # SQLite needs write access
      runAsNonRoot: true
      runAsUser: 1001
      capabilities:
        drop:
        - ALL
```

##### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ajudadorabot-network-policy
spec:
  podSelector:
    matchLabels:
      app: ajudadorabot
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to: []  # Allow all outbound (for Telegram API)
    ports:
    - protocol: TCP
      port: 443
```

### Secret Management

#### Kubernetes Secrets
```bash
# Generate secure secrets
./scripts/generate-secrets.sh k8s

# Apply with proper permissions
kubectl apply -f secrets/k8s-secrets-production.yaml
kubectl patch secret ajudadorabot-secrets -p '{"metadata":{"labels":{"app":"ajudadorabot"}}}'

# Rotate secrets regularly
kubectl create secret generic ajudadorabot-secrets-new --from-env-file=.env.production
kubectl patch deployment ajudadorabot-api -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","env":[{"name":"SECRET_VERSION","value":"new"}]}]}}}}'
```

#### External Secret Management
```yaml
# AWS Secrets Manager integration
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ajudadorabot-external-secret
spec:
  refreshInterval: 5m
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: ajudadorabot-secrets
    creationPolicy: Owner
```

## Security Monitoring

### Logging Security Events

#### Security Event Logging
```csharp
public class SecurityEventLogger
{
    private readonly ILogger<SecurityEventLogger> _logger;
    
    public void LogSecurityEvent(string eventType, string details, string? userId = null)
    {
        _logger.LogWarning("Security Event: {EventType} | User: {UserId} | Details: {Details} | IP: {IP} | Timestamp: {Timestamp}",
            eventType, userId, details, GetClientIP(), DateTime.UtcNow);
    }
}

// Usage examples
_securityLogger.LogSecurityEvent("AUTH_FAILURE", "Invalid JWT token", userId);
_securityLogger.LogSecurityEvent("RATE_LIMIT_EXCEEDED", $"IP: {clientIP}", userId);
_securityLogger.LogSecurityEvent("SUSPICIOUS_ACTIVITY", "Multiple failed login attempts", userId);
```

#### Audit Logging
```csharp
public class AuditMiddleware
{
    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        if (ShouldAudit(context.Request))
        {
            var auditLog = new AuditLog
            {
                UserId = context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value,
                Action = $"{context.Request.Method} {context.Request.Path}",
                IPAddress = context.Connection.RemoteIpAddress?.ToString(),
                UserAgent = context.Request.Headers["User-Agent"],
                Timestamp = DateTime.UtcNow
            };
            
            await _auditService.LogAuditEventAsync(auditLog);
        }
        
        await next(context);
    }
}
```

### Monitoring & Alerting

#### Security Metrics
```csharp
// Custom metrics for security monitoring
public class SecurityMetrics
{
    private readonly Counter _authFailures = Metrics
        .CreateCounter("auth_failures_total", "Total authentication failures");
        
    private readonly Counter _rateLimitExceeded = Metrics
        .CreateCounter("rate_limit_exceeded_total", "Rate limit violations");
        
    private readonly Histogram _requestDuration = Metrics
        .CreateHistogram("security_check_duration_seconds", "Security check duration");
        
    public void RecordAuthFailure(string reason)
    {
        _authFailures.WithTags("reason", reason).Inc();
    }
}
```

#### Prometheus Alerts
```yaml
# Alert rules for security events
groups:
- name: security.rules
  rules:
  - alert: HighAuthenticationFailures
    expr: rate(auth_failures_total[5m]) > 10
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High number of authentication failures"
      
  - alert: RateLimitingExceeded
    expr: rate(rate_limit_exceeded_total[5m]) > 50
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Rate limiting frequently exceeded"
```

## Incident Response

### Security Incident Classification

#### Severity Levels

**Critical (P0)**
- Data breach or unauthorized access to user data
- Service compromise with potential for data loss
- Active attack in progress

**High (P1)**
- Attempted unauthorized access
- Vulnerability exploitation attempts
- Denial of service attacks

**Medium (P2)**
- Security policy violations
- Suspicious activity patterns
- Non-critical security misconfigurations

**Low (P3)**
- Security warnings from automated tools
- Minor policy violations
- Security awareness issues

### Response Procedures

#### Immediate Response (0-30 minutes)
```bash
# 1. Identify and isolate affected systems
kubectl scale deployment ajudadorabot-api --replicas=0  # If necessary

# 2. Preserve evidence
kubectl logs deployment/ajudadorabot-api > incident-logs-$(date +%Y%m%d-%H%M%S).log

# 3. Assess scope and impact
grep -i "security\|auth\|error" incident-logs-*.log

# 4. Notify security team
# Send to security@ajudadorabot.com with:
# - Incident type and severity
# - Affected systems
# - Initial assessment
# - Actions taken
```

#### Investigation Phase (30 minutes - 4 hours)
```bash
# 1. Collect additional logs
kubectl logs deployment/ajudadorabot-api --previous
kubectl get events --sort-by='.lastTimestamp'

# 2. Check for compromise indicators
# Review authentication logs
# Check for unusual API calls
# Verify data integrity

# 3. Document findings
# Create incident report
# Timeline of events
# Evidence collected
```

#### Containment & Recovery
```bash
# 1. Apply security patches
kubectl set image deployment/ajudadorabot-api api=ajudadorabot:patched-version

# 2. Reset compromised credentials
./scripts/generate-secrets.sh all
kubectl apply -f secrets/k8s-secrets-production.yaml
kubectl rollout restart deployment/ajudadorabot-api

# 3. Verify system integrity
./scripts/backup.sh verify
curl -f https://ajudadorabot.com/health

# 4. Monitor for continued threats
# Enhanced monitoring for 48 hours
# Review logs for suspicious activity
```

### Post-Incident Activities

#### Incident Report Template
```markdown
# Security Incident Report

**Incident ID**: SEC-2024-001
**Date**: 2024-01-01
**Severity**: High
**Status**: Resolved

## Summary
Brief description of the incident.

## Timeline
- 14:00 UTC: Initial detection
- 14:05 UTC: Incident declared
- 14:15 UTC: Containment measures applied
- 16:00 UTC: Resolution confirmed

## Root Cause
Detailed analysis of what caused the incident.

## Impact Assessment
- Systems affected
- Data involved
- User impact
- Downtime duration

## Actions Taken
- Immediate response actions
- Containment measures
- Recovery steps

## Lessons Learned
- What worked well
- What could be improved
- Process changes needed

## Follow-up Actions
- [ ] Security control improvements
- [ ] Process updates
- [ ] Training requirements
- [ ] System hardening
```

## Compliance

### Data Protection Compliance

#### GDPR Requirements
- **Data Processing Basis**: Legitimate interest for bot functionality
- **Data Retention**: Automatic cleanup after 90 days of inactivity
- **User Rights**: Export and deletion capabilities implemented
- **Data Protection Impact Assessment**: Completed annually

#### Privacy by Design
```csharp
public class PrivacyService
{
    // Implement data minimization
    public UserProfile CreateMinimalProfile(TelegramUser telegramUser)
    {
        return new UserProfile
        {
            TelegramId = telegramUser.Id,
            FirstName = telegramUser.FirstName,  // Required for functionality
            // LastName omitted - not needed
            // ProfilePhoto omitted - not needed
            CreatedAt = DateTime.UtcNow
        };
    }
    
    // Implement purpose limitation
    public async Task<bool> CanProcessDataForPurpose(long userId, DataProcessingPurpose purpose)
    {
        var consent = await _context.UserConsents
            .FirstOrDefaultAsync(c => c.UserId == userId && c.Purpose == purpose);
        
        return consent?.IsValid() ?? false;
    }
}
```

### Security Audit Checklist

#### Monthly Security Review
- [ ] Review access logs for anomalies
- [ ] Check for unused user accounts
- [ ] Verify SSL certificate expiration dates
- [ ] Review and rotate API keys
- [ ] Update security scanning tools
- [ ] Review firewall rules
- [ ] Check backup integrity
- [ ] Review incident response procedures

#### Quarterly Security Assessment
- [ ] Penetration testing
- [ ] Vulnerability assessment
- [ ] Security architecture review
- [ ] Access control audit
- [ ] Business continuity testing
- [ ] Security training updates
- [ ] Compliance gap analysis
- [ ] Third-party security reviews

---

**Contact Information**:
- **Security Team**: security@ajudadorabot.com  
- **Emergency Contact**: +1-555-SECURITY
- **Bug Reports**: https://github.com/yourusername/AjudadoraBot/security

This security policy is reviewed quarterly and updated as needed to address evolving threats and compliance requirements.