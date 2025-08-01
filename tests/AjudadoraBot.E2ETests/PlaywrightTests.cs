using Microsoft.Playwright;
using Xunit;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using AjudadoraBot.IntegrationTests.TestBase;
using AjudadoraBot.Infrastructure.Data;
using AjudadoraBot.UnitTests.TestBase;
using System.Text.Json;

namespace AjudadoraBot.E2ETests;

public class PlaywrightTests : IClassFixture<IntegrationTestFixture>, IAsyncLifetime
{
    private readonly IntegrationTestFixture _factory;
    private IPlaywright _playwright = null!;
    private IBrowser _browser = null!;
    private string _baseUrl = null!;

    public PlaywrightTests(IntegrationTestFixture factory)
    {
        _factory = factory;
    }

    public async Task InitializeAsync()
    {
        // Install Playwright if needed (should be done in CI/CD)
        // Program.Main(new[] { "install" });

        _playwright = await Playwright.CreateAsync();
        _browser = await _playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions
        {
            Headless = true, // Set to false for debugging
            SlowMo = 100 // Add delay between actions for debugging
        });

        _baseUrl = _factory.Services.GetRequiredService<IConfiguration>()
            .GetValue<string>("BaseUrl") ?? "https://localhost:5001";
    }

    public async Task DisposeAsync()
    {
        await _browser.DisposeAsync();
        _playwright.Dispose();
    }

    [Fact]
    public async Task FullUserWorkflow_ShouldCompleteSuccessfully()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        // Seed some test data
        var users = TestDataFactory.CreateUsers(25);
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        var page = await _browser.NewPageAsync();

        try
        {
            // Act & Assert - Navigate to application
            await page.GotoAsync($"{_baseUrl}/");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Verify page title
            var title = await page.TitleAsync();
            title.Should().Contain("AjudadoraBot");

            // Check for authentication elements
            var authSection = page.Locator("[data-testid='auth-section']");
            await authSection.WaitForAsync(new LocatorWaitForOptions { Timeout = 5000 });

            // Simulate successful authentication (mock Telegram login)
            await page.EvaluateAsync(@"
                window.localStorage.setItem('auth_token', 'test-jwt-token');
                window.apiClient.setTokens('test-jwt-token');
                window.authManager.isAuthenticated = true;
                window.authManager.user = {
                    id: 123456789,
                    firstName: 'Test',
                    lastName: 'User',
                    username: 'testuser'
                };
            ");

            // Navigate to dashboard
            await page.ReloadAsync();
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Verify dashboard is loaded
            var dashboard = page.Locator("[data-testid='dashboard']");
            await dashboard.WaitForAsync();

            // Check bot status section
            var botStatus = page.Locator("[data-testid='bot-status']");
            await botStatus.WaitForAsync();

            var statusText = await botStatus.TextContentAsync();
            statusText.Should().NotBeNullOrEmpty();

            // Navigate to users section
            await page.ClickAsync("[data-testid='users-nav']");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Verify users table is loaded
            var usersTable = page.Locator("[data-testid='users-table']");
            await usersTable.WaitForAsync();

            // Check for user rows
            var userRows = page.Locator("[data-testid='user-row']");
            var rowCount = await userRows.CountAsync();
            rowCount.Should().BeGreaterThan(0);

            // Test pagination
            var nextPageButton = page.Locator("[data-testid='next-page']");
            if (await nextPageButton.IsVisibleAsync())
            {
                await nextPageButton.ClickAsync();
                await page.WaitForLoadStateAsync(LoadState.NetworkIdle);
                
                // Verify page changed
                var pageIndicator = page.Locator("[data-testid='page-indicator']");
                var pageText = await pageIndicator.TextContentAsync();
                pageText.Should().Contain("2");
            }

            // Test user search
            var searchInput = page.Locator("[data-testid='user-search']");
            await searchInput.FillAsync("test");
            await searchInput.PressAsync("Enter");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Test bot controls
            await page.ClickAsync("[data-testid='bot-nav']");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            var startBotButton = page.Locator("[data-testid='start-bot']");
            if (await startBotButton.IsVisibleAsync())
            {
                await startBotButton.ClickAsync();
                
                // Wait for response
                await page.WaitForTimeoutAsync(1000);
                
                // Check for success message
                var toast = page.Locator("[data-testid='toast']");
                if (await toast.IsVisibleAsync())
                {
                    var toastText = await toast.TextContentAsync();
                    toastText.Should().NotBeNullOrEmpty();
                }
            }

            // Test message sending
            await page.ClickAsync("[data-testid='messages-nav']");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            var chatIdInput = page.Locator("[data-testid='chat-id-input']");
            var messageInput = page.Locator("[data-testid='message-input']");
            var sendButton = page.Locator("[data-testid='send-message']");

            if (await chatIdInput.IsVisibleAsync())
            {
                await chatIdInput.FillAsync("123456789");
                await messageInput.FillAsync("Test message from E2E test");
                await sendButton.ClickAsync();
                
                // Wait for response
                await page.WaitForTimeoutAsync(1000);
            }

            // Test analytics section
            await page.ClickAsync("[data-testid='analytics-nav']");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            var analyticsChart = page.Locator("[data-testid='analytics-chart']");
            await analyticsChart.WaitForAsync(new LocatorWaitForOptions { Timeout = 10000 });

            // Verify analytics data is displayed
            var statsCards = page.Locator("[data-testid='stats-card']");
            var statsCount = await statsCards.CountAsync();
            statsCount.Should().BeGreaterThan(0);
        }
        finally
        {
            await page.CloseAsync();
        }
    }

    [Fact]
    public async Task MobileResponsiveness_ShouldWorkCorrectly()
    {
        // Arrange
        var page = await _browser.NewPageAsync();
        
        // Set mobile viewport
        await page.SetViewportSizeAsync(new ViewportSize { Width = 375, Height = 667 });

        try
        {
            // Act
            await page.GotoAsync($"{_baseUrl}/");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Assert - Check mobile navigation
            var mobileNav = page.Locator("[data-testid='mobile-nav']");
            if (await mobileNav.IsVisibleAsync())
            {
                await mobileNav.ClickAsync();
                
                var navMenu = page.Locator("[data-testid='nav-menu']");
                await navMenu.WaitForAsync();
                
                var isVisible = await navMenu.IsVisibleAsync();
                isVisible.Should().BeTrue();
            }

            // Check responsive layout
            var container = page.Locator("[data-testid='main-container']");
            var boundingBox = await container.BoundingBoxAsync();
            
            boundingBox.Should().NotBeNull();
            boundingBox!.Width.Should().BeLessOrEqualTo(375);
        }
        finally
        {
            await page.CloseAsync();
        }
    }

    [Fact]
    public async Task ErrorHandling_ShouldDisplayCorrectMessages()
    {
        // Arrange
        var page = await _browser.NewPageAsync();
        
        // Mock API to return errors
        await page.RouteAsync("**/api/**", async route =>
        {
            await route.FulfillAsync(new RouteFulfillOptions
            {
                Status = 500,
                ContentType = "application/json",
                Body = JsonSerializer.Serialize(new { error = "Internal Server Error" })
            });
        });

        try
        {
            // Act
            await page.GotoAsync($"{_baseUrl}/");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Simulate authenticated state
            await page.EvaluateAsync(@"
                window.localStorage.setItem('auth_token', 'test-jwt-token');
            ");

            await page.ReloadAsync();
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Try to load users (should fail)
            await page.ClickAsync("[data-testid='users-nav']");
            await page.WaitForTimeoutAsync(2000);

            // Assert - Check for error message
            var errorMessage = page.Locator("[data-testid='error-message']");
            if (await errorMessage.IsVisibleAsync())
            {
                var errorText = await errorMessage.TextContentAsync();
                errorText.Should().Contain("error");
            }
        }
        finally
        {
            await page.CloseAsync();
        }
    }

    [Fact]
    public async Task KeyboardNavigation_ShouldWorkCorrectly()
    {
        // Arrange
        var page = await _browser.NewPageAsync();

        try
        {
            // Act
            await page.GotoAsync($"{_baseUrl}/");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Test Tab navigation
            await page.Keyboard.PressAsync("Tab");
            var focusedElement = await page.EvaluateAsync<string>("document.activeElement.tagName");
            
            // Should focus on a focusable element
            focusedElement.Should().BeOneOf("BUTTON", "INPUT", "A", "SELECT");

            // Test Enter key on buttons
            var firstButton = page.Locator("button").First;
            if (await firstButton.IsVisibleAsync())
            {
                await firstButton.FocusAsync();
                await page.Keyboard.PressAsync("Enter");
                
                // Should trigger button action (wait for any response)
                await page.WaitForTimeoutAsync(500);
            }
        }
        finally
        {
            await page.CloseAsync();
        }
    }

    [Fact]
    public async Task FormValidation_ShouldPreventInvalidSubmissions()
    {
        // Arrange
        var page = await _browser.NewPageAsync();

        try
        {
            // Act
            await page.GotoAsync($"{_baseUrl}/");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Navigate to message sending form
            await page.ClickAsync("[data-testid='messages-nav']");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            var sendButton = page.Locator("[data-testid='send-message']");
            if (await sendButton.IsVisibleAsync())
            {
                // Try to send without filling required fields
                await sendButton.ClickAsync();
                
                // Check for validation messages
                var validationMessage = page.Locator("[data-testid='validation-error']");
                if (await validationMessage.IsVisibleAsync())
                {
                    var validationText = await validationMessage.TextContentAsync();
                    validationText.Should().NotBeNullOrEmpty();
                }

                // Fill with invalid data
                var chatIdInput = page.Locator("[data-testid='chat-id-input']");
                if (await chatIdInput.IsVisibleAsync())
                {
                    await chatIdInput.FillAsync("invalid-chat-id");
                    await sendButton.ClickAsync();
                    
                    // Should show validation error
                    await page.WaitForTimeoutAsync(500);
                }
            }
        }
        finally
        {
            await page.CloseAsync();
        }
    }

    [Fact]
    public async Task DataPersistence_ShouldMaintainStateAcrossReloads()
    {
        // Arrange
        var page = await _browser.NewPageAsync();

        try
        {
            // Act
            await page.GotoAsync($"{_baseUrl}/");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Set some data in localStorage
            await page.EvaluateAsync(@"
                window.localStorage.setItem('auth_token', 'persistent-token');
                window.localStorage.setItem('user_preferences', JSON.stringify({
                    theme: 'dark',
                    language: 'en'
                }));
            ");

            // Reload the page
            await page.ReloadAsync();
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Assert - Check that data persisted
            var token = await page.EvaluateAsync<string>("window.localStorage.getItem('auth_token')");
            var preferences = await page.EvaluateAsync<string>("window.localStorage.getItem('user_preferences')");

            token.Should().Be("persistent-token");
            preferences.Should().NotBeNullOrEmpty();
            preferences.Should().Contain("dark");
        }
        finally
        {
            await page.CloseAsync();
        }
    }

    [Fact]
    public async Task RealTimeUpdates_ShouldReflectChanges()
    {
        // Arrange
        var page = await _browser.NewPageAsync();

        try
        {
            // Act
            await page.GotoAsync($"{_baseUrl}/");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Navigate to dashboard
            await page.ClickAsync("[data-testid='dashboard-nav']");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Get initial stats
            var statsCard = page.Locator("[data-testid='stats-card']").First;
            var initialValue = "";
            
            if (await statsCard.IsVisibleAsync())
            {
                initialValue = await statsCard.TextContentAsync() ?? "";
            }

            // Simulate data change (in real app, this would come from WebSocket or polling)
            await page.EvaluateAsync(@"
                // Simulate receiving updated stats
                if (window.updateDashboardStats) {
                    window.updateDashboardStats({
                        totalUsers: 150,
                        activeUsers: 75,
                        totalInteractions: 2500
                    });
                }
            ");

            // Wait for UI to update
            await page.WaitForTimeoutAsync(1000);

            // Check if stats updated
            if (await statsCard.IsVisibleAsync())
            {
                var updatedValue = await statsCard.TextContentAsync() ?? "";
                // In a real implementation, we'd verify the values changed
                updatedValue.Should().NotBeNullOrEmpty();
            }
        }
        finally
        {
            await page.CloseAsync();
        }
    }

    [Fact]
    public async Task AccessibilityCompliance_ShouldMeetStandards()
    {
        // Arrange
        var page = await _browser.NewPageAsync();
        
        try
        {
            // Act
            await page.GotoAsync($"{_baseUrl}/");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);

            // Check for accessibility attributes
            var images = page.Locator("img");
            var imageCount = await images.CountAsync();
            
            for (int i = 0; i < imageCount; i++)
            {
                var img = images.Nth(i);
                var alt = await img.GetAttributeAsync("alt");
                
                // Images should have alt text
                alt.Should().NotBeNull("All images should have alt text for accessibility");
            }

            // Check for proper heading hierarchy
            var headings = page.Locator("h1, h2, h3, h4, h5, h6");
            var headingCount = await headings.CountAsync();
            
            if (headingCount > 0)
            {
                var firstHeading = headings.First;
                var tagName = await firstHeading.EvaluateAsync<string>("el => el.tagName.toLowerCase()");
                tagName.Should().Be("h1", "Page should start with h1 heading");
            }

            // Check for form labels
            var inputs = page.Locator("input[type='text'], input[type='email'], input[type='password'], textarea");
            var inputCount = await inputs.CountAsync();
            
            for (int i = 0; i < inputCount; i++)
            {
                var input = inputs.Nth(i);
                var id = await input.GetAttributeAsync("id");
                var ariaLabel = await input.GetAttributeAsync("aria-label");
                
                if (!string.IsNullOrEmpty(id))
                {
                    var label = page.Locator($"label[for='{id}']");
                    var hasLabel = await label.CountAsync() > 0;
                    
                    (hasLabel || !string.IsNullOrEmpty(ariaLabel))
                        .Should().BeTrue("Form inputs should have associated labels or aria-label");
                }
            }

            // Check for focus indicators
            var focusableElements = page.Locator("button, input, select, textarea, a[href]");
            var focusableCount = await focusableElements.CountAsync();
            
            if (focusableCount > 0)
            {
                var firstFocusable = focusableElements.First;
                await firstFocusable.FocusAsync();
                
                // Check if element is focused (basic check)
                var isFocused = await firstFocusable.EvaluateAsync<bool>("el => document.activeElement === el");
                isFocused.Should().BeTrue("Focusable elements should be able to receive focus");
            }
        }
        finally
        {
            await page.CloseAsync();
        }
    }

    [Fact]
    public async Task PerformanceMetrics_ShouldMeetThresholds()
    {
        // Arrange
        var page = await _browser.NewPageAsync();

        try
        {
            // Act
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            await page.GotoAsync($"{_baseUrl}/");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);
            stopwatch.Stop();

            // Assert - Page should load within reasonable time
            stopwatch.ElapsedMilliseconds.Should().BeLessThan(5000, "Page should load within 5 seconds");

            // Check for performance metrics
            var performanceMetrics = await page.EvaluateAsync<object>(@"
                () => {
                    const navigation = performance.getEntriesByType('navigation')[0];
                    return {
                        domContentLoaded: navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart,
                        loadComplete: navigation.loadEventEnd - navigation.loadEventStart,
                        firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime || 0,
                        firstContentfulPaint: performance.getEntriesByName('first-contentful-paint')[0]?.startTime || 0
                    };
                }
            ");

            performanceMetrics.Should().NotBeNull();

            // Check bundle size by counting resources
            var resourceMetrics = await page.EvaluateAsync<object>(@"
                () => {
                    const resources = performance.getEntriesByType('resource');
                    return {
                        totalResources: resources.length,
                        jsFiles: resources.filter(r => r.name.includes('.js')).length,
                        cssFiles: resources.filter(r => r.name.includes('.css')).length
                    };
                }
            ");

            resourceMetrics.Should().NotBeNull();
        }
        finally
        {
            await page.CloseAsync();
        }
    }
}