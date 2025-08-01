# PowerShell script to generate comprehensive test reports
param(
    [string]$OutputPath = "test-reports",
    [switch]$OpenReport = $false
)

Write-Host "🧪 Generating Comprehensive Test Report for AjudadoraBot" -ForegroundColor Green

# Create output directory
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Function to run command and capture output
function Invoke-TestCommand {
    param([string]$Command, [string]$Description)
    
    Write-Host "📋 $Description..." -ForegroundColor Yellow
    try {
        $result = Invoke-Expression $Command 2>&1
        return @{
            Success = $LASTEXITCODE -eq 0
            Output = $result
            Command = $Command
        }
    }
    catch {
        return @{
            Success = $false
            Output = $_.Exception.Message
            Command = $Command
        }
    }
}

# Initialize report
$reportData = @{
    Timestamp = Get-Date
    TestResults = @{}
    Summary = @{}
}

Write-Host "🏗️ Building solution..." -ForegroundColor Blue
$buildResult = Invoke-TestCommand "dotnet build AjudadoraBot.sln --configuration Release" "Building solution"
$reportData.TestResults.Build = $buildResult

if ($buildResult.Success) {
    Write-Host "✅ Build successful" -ForegroundColor Green
    
    # Run Unit Tests
    Write-Host "🔬 Running Unit Tests..." -ForegroundColor Blue
    $unitTestResult = Invoke-TestCommand `
        "dotnet test tests/AjudadoraBot.UnitTests/AjudadoraBot.UnitTests.csproj --configuration Release --collect:'XPlat Code Coverage' --results-directory $OutputPath/unit --logger 'trx;LogFileName=unit-tests.trx' --logger console" `
        "Running Unit Tests"
    $reportData.TestResults.UnitTests = $unitTestResult
    
    # Run Integration Tests
    Write-Host "🔗 Running Integration Tests..." -ForegroundColor Blue
    $integrationTestResult = Invoke-TestCommand `
        "dotnet test tests/AjudadoraBot.IntegrationTests/AjudadoraBot.IntegrationTests.csproj --configuration Release --collect:'XPlat Code Coverage' --results-directory $OutputPath/integration --logger 'trx;LogFileName=integration-tests.trx' --logger console" `
        "Running Integration Tests"
    $reportData.TestResults.IntegrationTests = $integrationTestResult
    
    # Run Frontend Tests
    Write-Host "🌐 Running Frontend Tests..." -ForegroundColor Blue
    if (Test-Path "frontend/package.json") {
        Set-Location frontend
        $frontendInstallResult = Invoke-TestCommand "npm install" "Installing frontend dependencies"
        if ($frontendInstallResult.Success) {
            $frontendTestResult = Invoke-TestCommand "npm run test:coverage" "Running frontend tests with coverage"
            $reportData.TestResults.FrontendTests = $frontendTestResult
        }
        Set-Location ..
    }
    
    # Generate Coverage Report
    Write-Host "📊 Generating Coverage Report..." -ForegroundColor Blue
    try {
        # Install report generator if not present
        dotnet tool install -g dotnet-reportgenerator-globaltool 2>$null
        
        $coverageCommand = "reportgenerator -reports:'$OutputPath/**/coverage.cobertura.xml' -targetdir:'$OutputPath/coverage-report' -reporttypes:'Html;TextSummary;Badges'"
        $coverageResult = Invoke-TestCommand $coverageCommand "Generating coverage report"
        $reportData.TestResults.Coverage = $coverageResult
    }
    catch {
        Write-Host "⚠️ Could not generate coverage report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Parse test results
    Write-Host "📈 Analyzing test results..." -ForegroundColor Blue
    $summary = @{
        UnitTests = @{ Passed = 0; Failed = 0; Skipped = 0 }
        IntegrationTests = @{ Passed = 0; Failed = 0; Skipped = 0 }
        FrontendTests = @{ Passed = 0; Failed = 0; Skipped = 0 }
        TotalTests = 0
        TotalPassed = 0
        TotalFailed = 0
        Coverage = "N/A"
    }
    
    # Parse TRX files for detailed results
    $trxFiles = Get-ChildItem -Path $OutputPath -Filter "*.trx" -Recurse
    foreach ($trxFile in $trxFiles) {
        try {
            [xml]$trxContent = Get-Content $trxFile.FullName
            $testType = if ($trxFile.Name.Contains("unit")) { "UnitTests" } else { "IntegrationTests" }
            
            $counters = $trxContent.TestRun.ResultSummary.Counters
            if ($counters) {
                $summary[$testType].Passed = [int]$counters.passed
                $summary[$testType].Failed = [int]$counters.failed
                $summary[$testType].Skipped = [int]$counters.notExecuted
            }
        }
        catch {
            Write-Host "⚠️ Could not parse $($trxFile.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Parse frontend test results (Jest output)
    if (Test-Path "frontend/coverage/lcov-report/index.html") {
        try {
            $frontendCoverage = Get-Content "frontend/coverage/coverage-summary.json" | ConvertFrom-Json
            $summary.FrontendCoverage = [math]::Round($frontendCoverage.total.lines.pct, 2)
        }
        catch {
            $summary.FrontendCoverage = "N/A"
        }
    }
    
    # Calculate totals
    $summary.TotalPassed = $summary.UnitTests.Passed + $summary.IntegrationTests.Passed + $summary.FrontendTests.Passed
    $summary.TotalFailed = $summary.UnitTests.Failed + $summary.IntegrationTests.Failed + $summary.FrontendTests.Failed
    $summary.TotalTests = $summary.TotalPassed + $summary.TotalFailed
    
    # Extract coverage percentage
    if (Test-Path "$OutputPath/coverage-report/Summary.txt") {
        $coverageText = Get-Content "$OutputPath/coverage-report/Summary.txt" -Raw
        if ($coverageText -match "Line coverage:\s*(\d+\.?\d*)%") {
            $summary.Coverage = "$($matches[1])%"
        }
    }
    
    $reportData.Summary = $summary
}
else {
    Write-Host "❌ Build failed. Skipping tests." -ForegroundColor Red
}

# Generate HTML Report
Write-Host "📝 Generating HTML report..." -ForegroundColor Blue

$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>AjudadoraBot Test Report</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; font-size: 2.5em; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; }
        .content { padding: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 40px; }
        .card { background: #f8f9fa; border-radius: 8px; padding: 20px; border-left: 4px solid #28a745; }
        .card.warning { border-left-color: #ffc107; }
        .card.error { border-left-color: #dc3545; }
        .card h3 { margin: 0 0 10px 0; color: #495057; }
        .card .value { font-size: 2em; font-weight: bold; color: #28a745; }
        .card.warning .value { color: #ffc107; }
        .card.error .value { color: #dc3545; }
        .section { margin-bottom: 40px; }
        .section h2 { color: #495057; border-bottom: 2px solid #e9ecef; padding-bottom: 10px; }
        .test-result { background: #f8f9fa; border-radius: 8px; padding: 20px; margin-bottom: 20px; }
        .test-result.success { border-left: 4px solid #28a745; }
        .test-result.failure { border-left: 4px solid #dc3545; }
        .test-result h4 { margin: 0 0 15px 0; color: #495057; }
        .test-stats { display: flex; gap: 20px; }
        .stat { text-align: center; }
        .stat .number { font-size: 1.5em; font-weight: bold; }
        .stat .label { font-size: 0.9em; color: #6c757d; }
        .passed { color: #28a745; }
        .failed { color: #dc3545; }
        .skipped { color: #ffc107; }
        .footer { background: #f8f9fa; padding: 20px; border-radius: 0 0 8px 8px; text-align: center; color: #6c757d; }
        .badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 0.8em; font-weight: bold; color: white; }
        .badge.success { background: #28a745; }
        .badge.failure { background: #dc3545; }
        .badge.warning { background: #ffc107; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 4px; overflow-x: auto; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 AjudadoraBot Test Report</h1>
            <p>Generated on $($reportData.Timestamp.ToString("yyyy-MM-dd HH:mm:ss UTC"))</p>
        </div>
        
        <div class="content">
            <div class="section">
                <h2>📊 Summary</h2>
                <div class="summary">
                    <div class="card $(if($reportData.Summary.TotalFailed -eq 0){''}else{'error'})">
                        <h3>Total Tests</h3>
                        <div class="value">$($reportData.Summary.TotalTests)</div>
                    </div>
                    <div class="card">
                        <h3>Passed</h3>
                        <div class="value">$($reportData.Summary.TotalPassed)</div>
                    </div>
                    <div class="card $(if($reportData.Summary.TotalFailed -eq 0){''}else{'error'})">
                        <h3>Failed</h3>
                        <div class="value">$($reportData.Summary.TotalFailed)</div>
                    </div>
                    <div class="card">
                        <h3>Code Coverage</h3>
                        <div class="value">$($reportData.Summary.Coverage)</div>
                    </div>
                </div>
            </div>

            <div class="section">
                <h2>🔬 Unit Tests</h2>
                <div class="test-result $(if($reportData.TestResults.UnitTests.Success){'success'}else{'failure'})">
                    <h4>Unit Test Results <span class="badge $(if($reportData.TestResults.UnitTests.Success){'success'}else{'failure'})">$(if($reportData.TestResults.UnitTests.Success){'PASSED'}else{'FAILED'})</span></h4>
                    <div class="test-stats">
                        <div class="stat">
                            <div class="number passed">$($reportData.Summary.UnitTests.Passed)</div>
                            <div class="label">Passed</div>
                        </div>
                        <div class="stat">
                            <div class="number failed">$($reportData.Summary.UnitTests.Failed)</div>
                            <div class="label">Failed</div>
                        </div>
                        <div class="stat">
                            <div class="number skipped">$($reportData.Summary.UnitTests.Skipped)</div>
                            <div class="label">Skipped</div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="section">
                <h2>🔗 Integration Tests</h2>
                <div class="test-result $(if($reportData.TestResults.IntegrationTests.Success){'success'}else{'failure'})">
                    <h4>Integration Test Results <span class="badge $(if($reportData.TestResults.IntegrationTests.Success){'success'}else{'failure'})">$(if($reportData.TestResults.IntegrationTests.Success){'PASSED'}else{'FAILED'})</span></h4>
                    <div class="test-stats">
                        <div class="stat">
                            <div class="number passed">$($reportData.Summary.IntegrationTests.Passed)</div>
                            <div class="label">Passed</div>
                        </div>
                        <div class="stat">
                            <div class="number failed">$($reportData.Summary.IntegrationTests.Failed)</div>
                            <div class="label">Failed</div>
                        </div>
                        <div class="stat">
                            <div class="number skipped">$($reportData.Summary.IntegrationTests.Skipped)</div>
                            <div class="label">Skipped</div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="section">
                <h2>🌐 Frontend Tests</h2>
                <div class="test-result $(if($reportData.TestResults.FrontendTests.Success){'success'}else{'failure'})">
                    <h4>Frontend Test Results <span class="badge $(if($reportData.TestResults.FrontendTests.Success){'success'}else{'failure'})">$(if($reportData.TestResults.FrontendTests.Success){'PASSED'}else{'FAILED'})</span></h4>
                    <div class="test-stats">
                        <div class="stat">
                            <div class="number passed">$($reportData.Summary.FrontendTests.Passed)</div>
                            <div class="label">Passed</div>
                        </div>
                        <div class="stat">
                            <div class="number failed">$($reportData.Summary.FrontendTests.Failed)</div>
                            <div class="label">Failed</div>
                        </div>
                        <div class="stat">
                            <div class="number">$($reportData.Summary.FrontendCoverage)%</div>
                            <div class="label">Coverage</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Report generated by AjudadoraBot Test Suite | Version 1.0.0</p>
        </div>
    </div>
</body>
</html>
"@

$reportPath = Join-Path $OutputPath "test-report.html"
$htmlReport | Out-File -FilePath $reportPath -Encoding UTF8

# Generate JSON report for CI/CD
$jsonReport = $reportData | ConvertTo-Json -Depth 10
$jsonReportPath = Join-Path $OutputPath "test-report.json"
$jsonReport | Out-File -FilePath $jsonReportPath -Encoding UTF8

Write-Host ""
Write-Host "✅ Test report generated successfully!" -ForegroundColor Green
Write-Host "📄 HTML Report: $reportPath" -ForegroundColor Cyan
Write-Host "📊 JSON Report: $jsonReportPath" -ForegroundColor Cyan

if (Test-Path "$OutputPath/coverage-report/index.html") {
    Write-Host "📈 Coverage Report: $OutputPath/coverage-report/index.html" -ForegroundColor Cyan
}

# Display summary
Write-Host ""
Write-Host "📋 Test Summary:" -ForegroundColor Yellow
Write-Host "  Total Tests: $($reportData.Summary.TotalTests)" -ForegroundColor White
Write-Host "  Passed: $($reportData.Summary.TotalPassed)" -ForegroundColor Green
Write-Host "  Failed: $($reportData.Summary.TotalFailed)" -ForegroundColor $(if($reportData.Summary.TotalFailed -eq 0){'Green'}else{'Red'})
Write-Host "  Coverage: $($reportData.Summary.Coverage)" -ForegroundColor White

if ($OpenReport) {
    Write-Host ""
    Write-Host "🌐 Opening test report in browser..." -ForegroundColor Blue
    Start-Process $reportPath
}

# Exit with appropriate code
if ($reportData.Summary.TotalFailed -gt 0) {
    Write-Host ""
    Write-Host "❌ Some tests failed. Please review the results." -ForegroundColor Red
    exit 1
}
else {
    Write-Host ""
    Write-Host "🎉 All tests passed!" -ForegroundColor Green
    exit 0
}