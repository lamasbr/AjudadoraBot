# Test script for Docker build validation
# Run this script to test the fixed Dockerfile.combined build

Write-Host "Testing AjudadoraBot Combined Docker Build" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host "NOTE: For nerdctl usage, run .\nerdctl-test.ps1 instead" -ForegroundColor Yellow

$buildArgs = @(
    "--build-arg", "BUILD_DATE=$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')",
    "--build-arg", "VERSION=1.0.0"
)

Write-Host "Building with arguments:" -ForegroundColor Yellow
$buildArgs | ForEach-Object { Write-Host "  $_" }

Write-Host "`nRunning Docker build..." -ForegroundColor Cyan
try {
    docker build -f Dockerfile.combined -t ajudadorabot-combined:latest @buildArgs --progress=plain .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nBuild successful!" -ForegroundColor Green
        Write-Host "Testing container startup..." -ForegroundColor Cyan
        
        # Test container startup
        docker run --rm -d --name ajudadorabot-test -p 8080:8080 ajudadorabot-combined:latest
        Start-Sleep 10
        
        # Test health endpoint
        $response = Invoke-WebRequest -Uri "http://localhost:8080/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "Health check passed!" -ForegroundColor Green
        } else {
            Write-Host "Health check failed" -ForegroundColor Red
        }
        
        # Cleanup
        docker stop ajudadorabot-test
        Write-Host "Test completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Build failed!" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error during build: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}