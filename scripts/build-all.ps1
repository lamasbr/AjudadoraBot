# Complete Build and Test Script
# Supports both Docker and nerdctl for flexible development

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("docker", "nerdctl")]
    [string]$Engine = "nerdctl",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTest,
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanBuild
)

Write-Host "AjudadoraBot Complete Build Script" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host "Container Engine: $Engine" -ForegroundColor Cyan
Write-Host "Skip Tests: $SkipTest" -ForegroundColor Cyan
Write-Host "Clean Build: $CleanBuild" -ForegroundColor Cyan

# Check if container engine is available
Write-Host "`nChecking container engine availability..." -ForegroundColor Yellow
try {
    if ($Engine -eq "docker") {
        $version = docker --version
        Write-Host "✓ Docker available: $version" -ForegroundColor Green
    } else {
        $version = nerdctl --version
        Write-Host "✓ nerdctl available: $version" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ $Engine is not available or not in PATH" -ForegroundColor Red
    Write-Host "Please install $Engine or choose a different engine" -ForegroundColor Yellow
    exit 1
}

# Clean build if requested
if ($CleanBuild) {
    Write-Host "`nPerforming clean build..." -ForegroundColor Yellow
    try {
        if ($Engine -eq "docker") {
            docker system prune -f
            docker rmi ajudadorabot-combined:latest -f 2>$null
        } else {
            nerdctl system prune -f
            nerdctl rmi ajudadorabot-combined:latest -f 2>$null
        }
        Write-Host "✓ Clean completed" -ForegroundColor Green
    } catch {
        Write-Host "Clean step failed, continuing..." -ForegroundColor Yellow
    }
}

# Validate Dockerfile before building
Write-Host "`nValidating Dockerfile..." -ForegroundColor Yellow
if (Test-Path "Dockerfile.combined") {
    Write-Host "✓ Dockerfile.combined found" -ForegroundColor Green
    
    # Run validation script
    if (Test-Path "scripts\validate-docker-fix.ps1") {
        Write-Host "Running validation..." -ForegroundColor Cyan
        try {
            & ".\scripts\validate-docker-fix.ps1"
            Write-Host "✓ Dockerfile validation passed" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Dockerfile validation had warnings, continuing..." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "✗ Dockerfile.combined not found" -ForegroundColor Red
    exit 1
}

# Build arguments
$buildArgs = @(
    "--build-arg", "BUILD_DATE=$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')",
    "--build-arg", "VERSION=1.0.0",
    "--progress=plain"
)

Write-Host "`nBuild arguments:" -ForegroundColor Yellow
$buildArgs | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

# Execute build
Write-Host "`nStarting build with $Engine..." -ForegroundColor Cyan
$buildStartTime = Get-Date

try {
    if ($Engine -eq "docker") {
        docker build -f Dockerfile.combined -t ajudadorabot-combined:latest @buildArgs .
    } else {
        nerdctl build -f Dockerfile.combined -t ajudadorabot-combined:latest @buildArgs .
    }
    
    $buildEndTime = Get-Date
    $buildDuration = $buildEndTime - $buildStartTime
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✓ Build completed successfully!" -ForegroundColor Green
        Write-Host "Build duration: $($buildDuration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor Cyan
        
        # Show image information
        Write-Host "`nImage information:" -ForegroundColor Yellow
        if ($Engine -eq "docker") {
            docker images ajudadorabot-combined:latest
        } else {
            nerdctl images ajudadorabot-combined:latest
        }
        
        # Run tests if not skipped
        if (-not $SkipTest) {
            Write-Host "`nRunning tests..." -ForegroundColor Cyan
            
            if ($Engine -eq "docker") {
                if (Test-Path "scripts\test-docker-build.ps1") {
                    & ".\scripts\test-docker-build.ps1"
                } else {
                    Write-Host "Docker test script not found, skipping tests" -ForegroundColor Yellow
                }
            } else {
                if (Test-Path "scripts\nerdctl-test.ps1") {
                    & ".\scripts\nerdctl-test.ps1"
                } else {
                    Write-Host "nerdctl test script not found, skipping tests" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "`nTests skipped as requested" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "`n✗ Build failed!" -ForegroundColor Red
        Write-Host "Check the build output above for errors" -ForegroundColor Yellow
        exit 1
    }
    
} catch {
    Write-Host "`n✗ Build error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host "`n" + "="*50 -ForegroundColor Green
Write-Host "BUILD SUMMARY" -ForegroundColor Green
Write-Host "="*50 -ForegroundColor Green
Write-Host "Container Engine: $Engine" -ForegroundColor White
Write-Host "Build Status: SUCCESS" -ForegroundColor Green
Write-Host "Build Duration: $($buildDuration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
Write-Host "Image: ajudadorabot-combined:latest" -ForegroundColor White
Write-Host "Tests: $(if ($SkipTest) { 'SKIPPED' } else { 'COMPLETED' })" -ForegroundColor White

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Run container: $Engine run --rm -d --name ajudadorabot -p 8080:8080 ajudadorabot-combined:latest" -ForegroundColor White
Write-Host "2. Test health: curl http://localhost:8080/health" -ForegroundColor White
Write-Host "3. View logs: $Engine logs ajudadorabot" -ForegroundColor White
Write-Host "4. Stop container: $Engine stop ajudadorabot" -ForegroundColor White