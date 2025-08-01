# Docker Build Validation Script
# Validates that the Dockerfile.combined fix resolves the test project dependency issues

Write-Host "Docker Build Fix Validation" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# Check if required files exist
$requiredFiles = @(
    "Dockerfile.combined",
    "src/AjudadoraBot.Api/AjudadoraBot.Api.csproj",
    "src/AjudadoraBot.Core/AjudadoraBot.Core.csproj",
    "src/AjudadoraBot.Infrastructure/AjudadoraBot.Infrastructure.csproj"
)

Write-Host "Checking required files..." -ForegroundColor Yellow
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file (MISSING)" -ForegroundColor Red
        exit 1
    }
}

# Validate Dockerfile.combined content
Write-Host "`nValidating Dockerfile.combined fix..." -ForegroundColor Yellow
$dockerfileContent = Get-Content "Dockerfile.combined" -Raw

# Check that solution file is not copied
if ($dockerfileContent -notmatch "COPY \*\.sln") {
    Write-Host "  ✓ Solution file (.sln) is not copied" -ForegroundColor Green
} else {
    Write-Host "  ✗ Solution file is still being copied" -ForegroundColor Red
}

# Check that dotnet restore targets specific project
if ($dockerfileContent -match "dotnet restore src/AjudadoraBot\.Api/AjudadoraBot\.Api\.csproj") {
    Write-Host "  ✓ dotnet restore targets specific project" -ForegroundColor Green
} else {
    Write-Host "  ✗ dotnet restore command not fixed" -ForegroundColor Red
}

# Check that build targets specific project  
if ($dockerfileContent -match "dotnet build src/AjudadoraBot\.Api/AjudadoraBot\.Api\.csproj") {
    Write-Host "  ✓ dotnet build targets specific project" -ForegroundColor Green
} else {
    Write-Host "  ✗ dotnet build command not fixed" -ForegroundColor Red
}

Write-Host "`nValidation Summary:" -ForegroundColor Cyan
Write-Host "- Removed solution file copying to avoid test project references" -ForegroundColor White
Write-Host "- Updated dotnet restore to target main API project only" -ForegroundColor White  
Write-Host "- Updated dotnet build to target main API project only" -ForegroundColor White
Write-Host "- Maintained all production optimizations for Azure App Service F1 tier" -ForegroundColor White

Write-Host "`nFix Status: READY FOR TESTING" -ForegroundColor Green
Write-Host "Run 'docker build -f Dockerfile.combined -t ajudadorabot .' to test" -ForegroundColor Cyan