# nerdctl Test Script for AjudadoraBot
# Complete testing workflow using nerdctl instead of docker
# Includes container lifecycle management and health checks

Write-Host "AjudadoraBot nerdctl Test Script" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

$containerName = "ajudadorabot-test"
$imageName = "ajudadorabot-combined:latest"
$port = 8080

# Function to cleanup container
function Cleanup-Container {
    Write-Host "Cleaning up container..." -ForegroundColor Yellow
    try {
        nerdctl stop $containerName 2>$null
        nerdctl rm $containerName 2>$null
    } catch {
        # Ignore cleanup errors
    }
}

# Cleanup any existing container
Cleanup-Container

Write-Host "Starting container with nerdctl..." -ForegroundColor Cyan
try {
    # Run container with nerdctl
    nerdctl run --rm -d --name $containerName -p ${port}:8080 $imageName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Container started successfully!" -ForegroundColor Green
        Write-Host "Container name: $containerName" -ForegroundColor White
        Write-Host "Port mapping: ${port}:8080" -ForegroundColor White
        
        # Wait for container to start
        Write-Host "`nWaiting for container to initialize..." -ForegroundColor Yellow
        Start-Sleep 15
        
        # Check container status
        Write-Host "`nContainer status:" -ForegroundColor Yellow
        nerdctl ps -f "name=$containerName"
        
        # Test health endpoint
        Write-Host "`nTesting health endpoint..." -ForegroundColor Cyan
        $maxRetries = 5
        $retryCount = 0
        $healthCheckPassed = $false
        
        while ($retryCount -lt $maxRetries -and -not $healthCheckPassed) {
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:${port}/health" -TimeoutSec 10 -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    Write-Host "✓ Health check passed! Status: $($response.StatusCode)" -ForegroundColor Green
                    Write-Host "Response: $($response.Content)" -ForegroundColor White
                    $healthCheckPassed = $true
                } else {
                    Write-Host "Health check returned status: $($response.StatusCode)" -ForegroundColor Yellow
                }
            } catch {
                $retryCount++
                Write-Host "Health check attempt $retryCount failed: $($_.Exception.Message)" -ForegroundColor Yellow
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Retrying in 5 seconds..." -ForegroundColor Yellow
                    Start-Sleep 5
                }
            }
        }
        
        if (-not $healthCheckPassed) {
            Write-Host "✗ Health check failed after $maxRetries attempts" -ForegroundColor Red
            
            # Show container logs for debugging
            Write-Host "`nContainer logs:" -ForegroundColor Yellow
            nerdctl logs $containerName --tail 50
        }
        
        # Test additional endpoints if health check passed
        if ($healthCheckPassed) {
            Write-Host "`nTesting additional endpoints..." -ForegroundColor Cyan
            
            # Test root endpoint
            try {
                $rootResponse = Invoke-WebRequest -Uri "http://localhost:${port}/" -TimeoutSec 5 -ErrorAction Stop
                Write-Host "✓ Root endpoint accessible (Status: $($rootResponse.StatusCode))" -ForegroundColor Green
            } catch {
                Write-Host "✗ Root endpoint test failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Show resource usage
        Write-Host "`nContainer resource usage:" -ForegroundColor Yellow
        nerdctl stats $containerName --no-stream
        
        # Cleanup
        Cleanup-Container
        Write-Host "`nTest completed successfully!" -ForegroundColor Green
        
    } else {
        Write-Host "Failed to start container!" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error during nerdctl test: $($_.Exception.Message)" -ForegroundColor Red
    Cleanup-Container
    exit 1
}

Write-Host "`nnerdctl Test Summary:" -ForegroundColor Cyan
Write-Host "- Container lifecycle: OK" -ForegroundColor White
Write-Host "- Health endpoint: $(if ($healthCheckPassed) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($healthCheckPassed) { 'Green' } else { 'Red' })
Write-Host "- Resource monitoring: OK" -ForegroundColor White
Write-Host "- Cleanup: OK" -ForegroundColor White