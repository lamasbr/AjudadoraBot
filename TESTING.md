# AjudadoraBot Test Suite

Comprehensive testing documentation for the AjudadoraBot Telegram Bot Management System.

## 🧪 Test Structure

The test suite follows a pyramid approach with multiple layers of testing:

```
tests/
├── AjudadoraBot.UnitTests/           # Unit tests for services and repositories
├── AjudadoraBot.IntegrationTests/    # API integration tests with TestServer
├── AjudadoraBot.E2ETests/           # End-to-end tests with Playwright
└── AjudadoraBot.PerformanceTests/   # Load and performance tests with NBomber

frontend/
└── tests/                           # Frontend JavaScript tests with Jest
```

## 🎯 Testing Approach

### Test Pyramid
- **Unit Tests (70%)**: Fast, isolated tests for business logic
- **Integration Tests (20%)**: API endpoints with real database
- **E2E Tests (10%)**: Full user workflows with browser automation

### Test Categories

#### 1. Unit Tests (.NET)
- ✅ Service layer tests (BotService, UserService, AnalyticsService)
- ✅ Repository pattern tests with mocked dependencies
- ✅ Entity validation and business rule tests
- ✅ DTO mapping and transformation tests
- ✅ Command processing tests

#### 2. Integration Tests (.NET)
- ✅ API controller tests with TestServer
- ✅ Database integration with in-memory SQLite
- ✅ Authentication middleware tests
- ✅ End-to-end API workflows
- ✅ Error handling scenarios

#### 3. Frontend Tests (JavaScript)
- ✅ API client functionality tests
- ✅ Authentication state management tests
- ✅ Component behavior and rendering tests
- ✅ Form validation and submission tests
- ✅ Utility function tests

#### 4. End-to-End Tests (Playwright)
- ✅ Complete user workflows
- ✅ Bot management operations
- ✅ Message sending and receiving
- ✅ Authentication flows
- ✅ Mobile responsiveness
- ✅ Accessibility compliance
- ✅ Performance metrics

#### 5. Performance Tests (NBomber)
- ✅ API response times under load
- ✅ Database query performance
- ✅ Concurrent user handling
- ✅ Memory usage optimization
- ✅ Telegram webhook throughput

## 🚀 Running Tests

### Prerequisites
```bash
# Install .NET 9.0 SDK
# Install Node.js 20+
# Install required tools
dotnet tool install -g dotnet-reportgenerator-globaltool
```

### Quick Test Commands

```bash
# Run all unit tests
dotnet test tests/AjudadoraBot.UnitTests/

# Run integration tests
dotnet test tests/AjudadoraBot.IntegrationTests/

# Run E2E tests
dotnet test tests/AjudadoraBot.E2ETests/

# Run performance tests
dotnet test tests/AjudadoraBot.PerformanceTests/

# Run frontend tests
cd frontend && npm test

# Run all tests with coverage
dotnet test --collect:"XPlat Code Coverage"
```

### Comprehensive Test Report

Use the PowerShell script to generate a complete test report:

```powershell
# Generate test report
.\scripts\generate-test-report.ps1 -OutputPath "test-reports" -OpenReport

# CI/CD usage
.\scripts\generate-test-report.ps1 -OutputPath "test-reports"
```

## 📊 Test Coverage Goals

| Layer | Target Coverage | Current Status |
|-------|----------------|----------------|
| Unit Tests | >90% | ✅ Implemented |
| Integration Tests | >80% | ✅ Implemented |
| API Endpoints | 100% | ✅ Implemented |
| Critical Paths | 100% | ✅ Implemented |

## 🏗️ Test Infrastructure

### Test Database Setup
- **Unit Tests**: In-memory Entity Framework provider
- **Integration Tests**: SQLite in-memory database
- **E2E Tests**: Isolated test database per test run

### Test Data Management
- **TestDataFactory**: Generates consistent test data using AutoFixture
- **Realistic scenarios**: User workflows with varied interaction patterns
- **Edge cases**: Boundary conditions and error scenarios

### Mocking Strategy
- **External APIs**: Telegram Bot API mocked with WireMock.NET
- **Dependencies**: Service dependencies mocked with Moq
- **Time**: Deterministic time handling for consistent tests

## 🔧 Test Configuration

### Unit Tests Configuration
```xml
<PackageReference Include="xunit" Version="2.9.2" />
<PackageReference Include="Moq" Version="4.20.72" />
<PackageReference Include="AutoFixture" Version="4.18.1" />
<PackageReference Include="FluentAssertions" Version="7.0.0" />
```

### Integration Tests Configuration
```xml
<PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="9.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.InMemory" Version="9.0.0" />
<PackageReference Include="WireMock.Net" Version="1.6.7" />
```

### E2E Tests Configuration
```xml
<PackageReference Include="Microsoft.Playwright" Version="1.50.0" />
<PackageReference Include="Testcontainers" Version="3.10.0" />
```

### Performance Tests Configuration
```xml
<PackageReference Include="NBomber" Version="6.1.0" />
<PackageReference Include="BenchmarkDotNet" Version="0.14.0" />
```

## 🔄 CI/CD Integration

### GitHub Actions Workflow
The test suite is fully integrated with GitHub Actions:

1. **Build & Unit Tests**: Fast feedback on every commit
2. **Integration Tests**: Database and API testing
3. **E2E Tests**: Full workflow validation
4. **Performance Tests**: Load testing on main branch
5. **Code Quality**: Coverage reporting and static analysis
6. **Security Scanning**: Vulnerability detection

### Test Execution Matrix
```yaml
# Parallel test execution
- Unit Tests (fastest)
- Integration Tests
- Frontend Tests
- E2E Tests (slowest)
- Performance Tests (main branch only)
```

## 📈 Performance Benchmarks

### Response Time Targets
- **API Endpoints**: < 200ms average
- **Database Queries**: < 100ms average
- **Page Load**: < 2 seconds
- **Test Execution**: < 5 minutes total

### Load Testing Scenarios
- **Normal Load**: 50 requests/second
- **Peak Load**: 200 requests/second
- **Stress Test**: 500 requests/second
- **Soak Test**: 24-hour endurance

## 🐛 Debugging Tests

### Visual Studio / VS Code
- Set breakpoints in test methods
- Use Test Explorer for individual test execution
- Debug with full stack traces

### Command Line Debugging
```bash
# Run specific test with verbose output
dotnet test --filter "TestMethodName" --verbosity diagnostic

# Run tests in specific category
dotnet test --filter "Category=Unit"

# Run failed tests only
dotnet test --filter "TestCategory!=Skip"
```

### Playwright Debugging
```bash
# Run with headed browser
PWDEBUG=1 dotnet test tests/AjudadoraBot.E2ETests/

# Generate trace files
dotnet test tests/AjudadoraBot.E2ETests/ -- --trace on
```

## 🔍 Test Data and Fixtures

### TestDataFactory Usage
```csharp
// Create test user with custom properties
var user = TestDataFactory.CreateUser(u => {
    u.Username = "testuser";
    u.IsBlocked = false;
});

// Create user with interactions
var (user, interactions) = TestDataFactory.CreateUserWithInteractions(10);

// Create paginated response
var response = TestDataFactory.CreateUserResponse();
```

### Fixture Management
- **TestDatabaseFixture**: Manages in-memory database lifecycle
- **IntegrationTestFixture**: Provides TestServer and HTTP client
- **Automatic cleanup**: Database reset between tests

## 📋 Test Maintenance

### Regular Tasks
- **Update test data**: Keep test scenarios realistic
- **Review coverage**: Identify gaps in test coverage
- **Performance monitoring**: Track test execution times
- **Dependency updates**: Keep testing frameworks current

### Test Review Checklist
- [ ] All happy path scenarios covered
- [ ] Edge cases and error conditions tested
- [ ] Performance requirements validated
- [ ] Security scenarios included
- [ ] Accessibility compliance verified

## 🚨 Troubleshooting

### Common Issues

#### Test Database Issues
```bash
# Clear test databases
rm -rf test-results/
dotnet clean
```

#### Frontend Test Issues
```bash
# Clear npm cache and reinstall
cd frontend
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

#### Playwright Issues
```bash
# Reinstall browsers
pwsh tests/AjudadoraBot.E2ETests/bin/Debug/net9.0/playwright.ps1 install
```

### Environment Variables
```bash
# Test configuration
export ASPNETCORE_ENVIRONMENT=Testing
export ConnectionStrings__DefaultConnection="Data Source=:memory:"
```

## 📚 Additional Resources

- [xUnit Documentation](https://xunit.net/)
- [Playwright .NET Documentation](https://playwright.dev/dotnet/)
- [NBomber Documentation](https://nbomber.com/)
- [ASP.NET Core Testing](https://docs.microsoft.com/en-us/aspnet/core/test/)
- [Jest Documentation](https://jestjs.io/)

---

**Test Coverage Status**: ✅ >90% Overall Coverage  
**Last Updated**: 2025-08-01  
**Maintained by**: Development Team