using NBomber.Contracts;
using NBomber.CSharp;
using NBomber.Http.CSharp;
using Xunit;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using AjudadoraBot.IntegrationTests.TestBase;
using AjudadoraBot.Infrastructure.Data;
using AjudadoraBot.UnitTests.TestBase;
using System.Text.Json;
using System.Text;

namespace AjudadoraBot.PerformanceTests;

public class LoadTests : IClassFixture<IntegrationTestFixture>
{
    private readonly IntegrationTestFixture _factory;
    private readonly string _baseUrl;

    public LoadTests(IntegrationTestFixture factory)
    {
        _factory = factory;
        _baseUrl = "https://localhost:5001"; // Should match your test server URL
    }

    [Fact]
    public async Task GetUsersEndpoint_ShouldHandleHighLoad()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        // Seed test data
        var users = TestDataFactory.CreateUsers(1000);
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Create HTTP scenario
        var httpClient = _factory.CreateClient();
        var scenario = Scenario.Create("get_users_scenario", async context =>
        {
            var response = await httpClient.GetAsync("/api/v1/users?pageNumber=1&pageSize=20");
            
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithLoadSimulations(
            Simulation.InjectPerSec(rate: 50, during: TimeSpan.FromMinutes(2))
        );

        // Act
        var stats = NBomberRunner
            .RegisterScenarios(scenario)
            .WithReportFolder("load-test-reports")
            .WithReportFormats(ReportFormat.Html, ReportFormat.Csv)
            .Run();

        // Assert
        var sceneStats = stats.AllOkCount;
        var failCount = stats.AllFailCount;
        var meanResponseTime = stats.ScenarioStats[0].Ok.Response.Mean;

        sceneStats.Should().BeGreaterThan(0);
        failCount.Should().BeLessThan(sceneStats * 0.01); // Less than 1% error rate
        meanResponseTime.Should().BeLessThan(TimeSpan.FromMilliseconds(500)); // Average response time under 500ms
    }

    [Fact]
    public async Task BotEndpoints_ShouldHandleConcurrentRequests()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        var httpClient = _factory.CreateClient();

        var getBotInfoScenario = Scenario.Create("get_bot_info", async context =>
        {
            var response = await httpClient.GetAsync("/api/v1/bot/info");
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithWeight(70) // 70% of requests
        .WithLoadSimulations(
            Simulation.KeepConstant(copies: 10, during: TimeSpan.FromMinutes(1))
        );

        var startBotScenario = Scenario.Create("start_bot", async context =>
        {
            var response = await httpClient.PostAsync("/api/v1/bot/start", null);
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithWeight(15) // 15% of requests
        .WithLoadSimulations(
            Simulation.KeepConstant(copies: 2, during: TimeSpan.FromMinutes(1))
        );

        var stopBotScenario = Scenario.Create("stop_bot", async context =>
        {
            var response = await httpClient.PostAsync("/api/v1/bot/stop", null);
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithWeight(15) // 15% of requests
        .WithLoadSimulations(
            Simulation.KeepConstant(copies: 2, during: TimeSpan.FromMinutes(1))
        );

        // Act
        var stats = NBomberRunner
            .RegisterScenarios(getBotInfoScenario, startBotScenario, stopBotScenario)
            .WithReportFolder("bot-endpoints-load-test")
            .WithReportFormats(ReportFormat.Html)
            .Run();

        // Assert
        foreach (var scenarioStats in stats.ScenarioStats)
        {
            scenarioStats.Ok.Response.Mean.Should().BeLessThan(TimeSpan.FromMilliseconds(1000));
            scenarioStats.Fail.Request.Count.Should().BeLessThan(scenarioStats.Ok.Request.Count * 0.05); // Less than 5% error rate
        }
    }

    [Fact]
    public async Task MessageSending_ShouldHandleHighThroughput()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        var httpClient = _factory.CreateClient();

        var sendMessageScenario = Scenario.Create("send_message", async context =>
        {
            var messageData = new
            {
                ChatId = 123456789L,
                Text = $"Load test message {context.InvocationNumber}",
                ParseMode = "HTML"
            };

            var json = JsonSerializer.Serialize(messageData);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            
            var response = await httpClient.PostAsync("/api/v1/bot/send-message", content);
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithLoadSimulations(
            Simulation.InjectPerSec(rate: 30, during: TimeSpan.FromMinutes(1))
        );

        // Act
        var stats = NBomberRunner
            .RegisterScenarios(sendMessageScenario)
            .WithReportFolder("message-sending-load-test")
            .WithReportFormats(ReportFormat.Html)
            .Run();

        // Assert
        var sceneStats = stats.ScenarioStats[0];
        sceneStats.Ok.Response.Mean.Should().BeLessThan(TimeSpan.FromMilliseconds(2000)); // Messages should send within 2 seconds
        sceneStats.Fail.Request.Count.Should().BeLessThan(sceneStats.Ok.Request.Count * 0.02); // Less than 2% error rate
    }

    [Fact]
    public async Task DatabaseOperations_ShouldMaintainPerformance()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        // Seed large dataset
        var users = TestDataFactory.CreateUsers(5000);
        await context.Users.AddRangeAsync(users);
        
        var interactions = new List<Core.Models.Interaction>();
        foreach (var user in users.Take(1000)) // Create interactions for first 1000 users
        {
            var userInteractions = TestDataFactory.CreateInteractions(10, i => 
            {
                i.UserId = user.Id;
                i.TelegramUserId = user.TelegramId;
            });
            interactions.AddRange(userInteractions);
        }
        
        await context.Interactions.AddRangeAsync(interactions);
        await context.SaveChangesAsync();

        var httpClient = _factory.CreateClient();

        // Create scenarios for different database operations
        var getUsersScenario = Scenario.Create("get_users_paginated", async context =>
        {
            var page = Random.Shared.Next(1, 100); // Random page between 1-100
            var response = await httpClient.GetAsync($"/api/v1/users?pageNumber={page}&pageSize=20");
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithWeight(40)
        .WithLoadSimulations(
            Simulation.KeepConstant(copies: 5, during: TimeSpan.FromMinutes(2))
        );

        var searchUsersScenario = Scenario.Create("search_users", async context =>
        {
            var searchTerms = new[] { "user", "test", "bot", "admin", "demo" };
            var searchTerm = searchTerms[Random.Shared.Next(searchTerms.Length)];
            var response = await httpClient.GetAsync($"/api/v1/users?search={searchTerm}&pageSize=10");
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithWeight(30)
        .WithLoadSimulations(
            Simulation.KeepConstant(copies: 3, during: TimeSpan.FromMinutes(2))
        );

        var getUserInteractionsScenario = Scenario.Create("get_user_interactions", async context =>
        {
            var randomUser = users[Random.Shared.Next(1000)]; // Pick from users with interactions
            var response = await httpClient.GetAsync($"/api/v1/users/{randomUser.TelegramId}/interactions?pageSize=10");
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithWeight(30)
        .WithLoadSimulations(
            Simulation.KeepConstant(copies: 3, during: TimeSpan.FromMinutes(2))
        );

        // Act
        var stats = NBomberRunner
            .RegisterScenarios(getUsersScenario, searchUsersScenario, getUserInteractionsScenario)
            .WithReportFolder("database-operations-load-test")
            .WithReportFormats(ReportFormat.Html)
            .Run();

        // Assert
        foreach (var scenarioStats in stats.ScenarioStats)
        {
            // Database operations should complete within reasonable time even with large dataset
            scenarioStats.Ok.Response.Mean.Should().BeLessThan(TimeSpan.FromMilliseconds(1500));
            
            // 95th percentile should be under 3 seconds
            scenarioStats.Ok.Response.Percentile95.Should().BeLessThan(TimeSpan.FromMilliseconds(3000));
            
            // Error rate should be very low
            scenarioStats.Fail.Request.Count.Should().BeLessThan(scenarioStats.Ok.Request.Count * 0.01);
        }
    }

    [Fact]
    public async Task AnalyticsEndpoints_ShouldHandleComplexQueries()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        // Create comprehensive test data for analytics
        var users = TestDataFactory.CreateUsers(2000);
        await context.Users.AddRangeAsync(users);
        
        var interactions = new List<Core.Models.Interaction>();
        var errorLogs = new List<Core.Models.ErrorLog>();
        
        foreach (var user in users)
        {
            // Create interactions with varied timestamps
            var userInteractions = TestDataFactory.CreateInteractions(
                Random.Shared.Next(5, 50), 
                i => 
                {
                    i.UserId = user.Id;
                    i.TelegramUserId = user.TelegramId;
                    i.Timestamp = DateTime.UtcNow.AddDays(-Random.Shared.Next(0, 30));
                }
            );
            interactions.AddRange(userInteractions);
            
            // Create some error logs
            if (Random.Shared.NextDouble() < 0.1) // 10% chance of errors per user
            {
                var userErrors = TestDataFactory.CreateErrorLogs(
                    Random.Shared.Next(1, 5),
                    e => 
                    {
                        e.UserId = user.Id;
                        e.TelegramUserId = user.TelegramId;
                        e.Timestamp = DateTime.UtcNow.AddDays(-Random.Shared.Next(0, 30));
                    }
                );
                errorLogs.AddRange(userErrors);
            }
        }
        
        await context.Interactions.AddRangeAsync(interactions);
        await context.ErrorLogs.AddRangeAsync(errorLogs);
        await context.SaveChangesAsync();

        var httpClient = _factory.CreateClient();

        var analyticsScenario = Scenario.Create("analytics_queries", async context =>
        {
            var endpoints = new[]
            {
                "/api/v1/analytics/stats?period=24h",
                "/api/v1/analytics/stats?period=7d",
                "/api/v1/analytics/stats?period=30d",
                "/api/v1/analytics/interactions?startDate=2023-01-01&endDate=2023-12-31"
            };
            
            var endpoint = endpoints[Random.Shared.Next(endpoints.Length)];
            var response = await httpClient.GetAsync(endpoint);
            
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithLoadSimulations(
            Simulation.InjectPerSec(rate: 20, during: TimeSpan.FromMinutes(1))
        );

        // Act
        var stats = NBomberRunner
            .RegisterScenarios(analyticsScenario)
            .WithReportFolder("analytics-load-test")
            .WithReportFormats(ReportFormat.Html)
            .Run();

        // Assert
        var sceneStats = stats.ScenarioStats[0];
        
        // Analytics queries can be complex, allow more time
        sceneStats.Ok.Response.Mean.Should().BeLessThan(TimeSpan.FromMilliseconds(2000));
        sceneStats.Ok.Response.Percentile95.Should().BeLessThan(TimeSpan.FromMilliseconds(5000));
        sceneStats.Fail.Request.Count.Should().BeLessThan(sceneStats.Ok.Request.Count * 0.02);
    }

    [Fact]
    public async Task WebhookEndpoint_ShouldHandleHighFrequencyUpdates()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        var httpClient = _factory.CreateClient();

        var webhookScenario = Scenario.Create("telegram_webhook", async context =>
        {
            // Simulate Telegram webhook payload
            var webhookData = new
            {
                update_id = context.InvocationNumber,
                message = new
                {
                    message_id = context.InvocationNumber,
                    from = new
                    {
                        id = 123456789,
                        is_bot = false,
                        first_name = "Test",
                        username = "testuser"
                    },
                    chat = new
                    {
                        id = 123456789,
                        type = "private"
                    },
                    date = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
                    text = $"/start {context.InvocationNumber}"
                }
            };

            var json = JsonSerializer.Serialize(webhookData);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            
            var response = await httpClient.PostAsync("/api/v1/webhook", content);
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithLoadSimulations(
            // Simulate high-frequency webhook updates
            Simulation.InjectPerSec(rate: 100, during: TimeSpan.FromMinutes(1))
        );

        // Act
        var stats = NBomberRunner
            .RegisterScenarios(webhookScenario)
            .WithReportFolder("webhook-load-test")
            .WithReportFormats(ReportFormat.Html)
            .Run();

        // Assert
        var sceneStats = stats.ScenarioStats[0];
        
        // Webhook processing should be very fast
        sceneStats.Ok.Response.Mean.Should().BeLessThan(TimeSpan.FromMilliseconds(100));
        sceneStats.Ok.Response.Percentile95.Should().BeLessThan(TimeSpan.FromMilliseconds(200));
        sceneStats.Fail.Request.Count.Should().BeLessThan(sceneStats.Ok.Request.Count * 0.01);
    }

    [Fact]
    public async Task MixedWorkload_ShouldMaintainPerformance()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        // Create realistic dataset
        var users = TestDataFactory.CreateUsers(1000);
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        var httpClient = _factory.CreateClient();

        // Create multiple scenarios that would run concurrently in production
        var readHeavyScenario = Scenario.Create("read_heavy_operations", async context =>
        {
            var operations = new Func<Task<HttpResponseMessage>>[]
            {
                () => httpClient.GetAsync("/api/v1/users?pageNumber=1&pageSize=10"),
                () => httpClient.GetAsync("/api/v1/bot/info"),
                () => httpClient.GetAsync("/api/v1/analytics/stats?period=24h"),
                () => httpClient.GetAsync($"/api/v1/users/{users[Random.Shared.Next(users.Count)].TelegramId}")
            };
            
            var operation = operations[Random.Shared.Next(operations.Length)];
            var response = await operation();
            
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithWeight(70) // 70% read operations
        .WithLoadSimulations(
            Simulation.KeepConstant(copies: 10, during: TimeSpan.FromMinutes(3))
        );

        var writeOperationsScenario = Scenario.Create("write_operations", async context =>
        {
            var operations = new Func<Task<HttpResponseMessage>>[]
            {
                () => httpClient.PostAsync("/api/v1/bot/start", null),
                () => httpClient.PostAsync("/api/v1/bot/stop", null),
                async () => {
                    var messageData = new
                    {
                        ChatId = 123456789L,
                        Text = $"Test message {context.InvocationNumber}"
                    };
                    var json = JsonSerializer.Serialize(messageData);
                    var content = new StringContent(json, Encoding.UTF8, "application/json");
                    return await httpClient.PostAsync("/api/v1/bot/send-message", content);
                }
            };
            
            var operation = operations[Random.Shared.Next(operations.Length)];
            var response = await operation();
            
            return response.IsSuccessStatusCode ? Response.Ok() : Response.Fail();
        })
        .WithWeight(30) // 30% write operations
        .WithLoadSimulations(
            Simulation.KeepConstant(copies: 3, during: TimeSpan.FromMinutes(3))
        );

        // Act
        var stats = NBomberRunner
            .RegisterScenarios(readHeavyScenario, writeOperationsScenario)
            .WithReportFolder("mixed-workload-test")
            .WithReportFormats(ReportFormat.Html, ReportFormat.Csv)
            .Run();

        // Assert
        var totalRequests = stats.AllOkCount + stats.AllFailCount;
        var errorRate = (double)stats.AllFailCount / totalRequests;
        
        totalRequests.Should().BeGreaterThan(1000); // Should have processed significant load
        errorRate.Should().BeLessThan(0.05); // Less than 5% error rate overall
        
        foreach (var scenarioStats in stats.ScenarioStats)
        {
            scenarioStats.Ok.Response.Mean.Should().BeLessThan(TimeSpan.FromMilliseconds(1000));
            scenarioStats.Ok.Response.Percentile95.Should().BeLessThan(TimeSpan.FromMilliseconds(2000));
        }
    }
}