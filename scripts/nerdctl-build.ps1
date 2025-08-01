# nerdctl Build Script for AjudadoraBot
# Replaces Docker commands with nerdctl for local development
# Optimized for containerd and better resource usage

Write-Host "AjudadoraBot nerdctl Build Script" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Build arguments
$buildArgs = @(
    "--build-arg", "BUILD_DATE=$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')",
    "--build-arg", "VERSION=1.0.0",
    "--progress=plain"
)

Write-Host "Building with nerdctl arguments:" -ForegroundColor Yellow
$buildArgs | ForEach-Object { Write-Host "  $_" }

Write-Host "`nRunning nerdctl build..." -ForegroundColor Cyan
try {
    # Use nerdctl instead of docker for better resource management
    nerdctl build -f Dockerfile.combined -t ajudadorabot-combined:latest @buildArgs .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nBuild successful with nerdctl!" -ForegroundColor Green
        Write-Host "Image built: ajudadorabot-combined:latest" -ForegroundColor Cyan
        
        # Show image info
        Write-Host "`nImage information:" -ForegroundColor Yellow
        nerdctl images ajudadorabot-combined:latest
        
        Write-Host "`nTo run the container:" -ForegroundColor Cyan
        Write-Host "  nerdctl run --rm -d --name ajudadorabot -p 8080:8080 ajudadorabot-combined:latest" -ForegroundColor White
        
        Write-Host "`nTo test health endpoint:" -ForegroundColor Cyan
        Write-Host "  curl http://localhost:8080/health" -ForegroundColor White
        
        Write-Host "`nTo stop the container:" -ForegroundColor Cyan
        Write-Host "  nerdctl stop ajudadorabot" -ForegroundColor White
        
    } else {
        Write-Host "Build failed!" -ForegroundColor Red
        Write-Host "Check the build output above for errors" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "Error during nerdctl build: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure nerdctl is installed and containerd is running" -ForegroundColor Yellow
    exit 1
}