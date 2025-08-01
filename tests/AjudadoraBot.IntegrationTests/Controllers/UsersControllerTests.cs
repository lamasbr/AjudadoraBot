using Xunit;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using System.Net;
using System.Net.Http.Json;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Models;
using AjudadoraBot.Infrastructure.Data;
using AjudadoraBot.IntegrationTests.TestBase;
using AjudadoraBot.UnitTests.TestBase;

namespace AjudadoraBot.IntegrationTests.Controllers;

public class UsersControllerTests : IClassFixture<IntegrationTestFixture>
{
    private readonly IntegrationTestFixture _factory;
    private readonly HttpClient _client;

    public UsersControllerTests(IntegrationTestFixture factory)
    {
        _factory = factory;
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task GetUsers_ShouldReturnPaginatedUsers_WhenUsersExist()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        var users = TestDataFactory.CreateUsers(15);
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        var response = await _client.GetAsync("/api/v1/users?pageNumber=1&pageSize=10");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<PaginatedResponse<UserResponse>>();
        result.Should().NotBeNull();
        result!.Data.Should().HaveCount(10);
        result.PageNumber.Should().Be(1);
        result.PageSize.Should().Be(10);
        result.TotalCount.Should().Be(15);
        result.TotalPages.Should().Be(2);
        result.HasNextPage.Should().BeTrue();
        result.HasPreviousPage.Should().BeFalse();
    }

    [Fact]
    public async Task GetUsers_ShouldReturnFilteredUsers_WhenSearchTermProvided()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        var users = TestDataFactory.CreateUsers(5);
        users[0].Username = "testuser1";
        users[1].Username = "testuser2";
        users[2].FirstName = "TestName";
        users[3].Username = "normaluser";
        users[4].FirstName = "Regular";
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        var response = await _client.GetAsync("/api/v1/users?search=test");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<PaginatedResponse<UserResponse>>();
        result.Should().NotBeNull();
        result!.Data.Should().HaveCount(3); // testuser1, testuser2, TestName
        result.Data.Should().OnlyContain(u => 
            (u.Username != null && u.Username.Contains("test", StringComparison.OrdinalIgnoreCase)) ||
            (u.FirstName != null && u.FirstName.Contains("test", StringComparison.OrdinalIgnoreCase)));
    }

    [Theory]
    [InlineData(0, 10, HttpStatusCode.BadRequest)]
    [InlineData(1, 0, HttpStatusCode.BadRequest)]
    [InlineData(1, 101, HttpStatusCode.BadRequest)]
    [InlineData(-1, 20, HttpStatusCode.BadRequest)]
    public async Task GetUsers_ShouldReturnBadRequest_WhenInvalidPaginationParameters(
        int pageNumber, int pageSize, HttpStatusCode expectedStatusCode)
    {
        // Act
        var response = await _client.GetAsync($"/api/v1/users?pageNumber={pageNumber}&pageSize={pageSize}");

        // Assert
        response.StatusCode.Should().Be(expectedStatusCode);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Contain("Invalid pagination parameters");
    }

    [Fact]
    public async Task GetUser_ShouldReturnUser_WhenUserExists()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        var user = TestDataFactory.CreateUser();
        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        // Act
        var response = await _client.GetAsync($"/api/v1/users/{user.TelegramId}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<UserResponse>();
        result.Should().NotBeNull();
        result!.TelegramId.Should().Be(user.TelegramId);
        result.Username.Should().Be(user.Username);
        result.FirstName.Should().Be(user.FirstName);
        result.LastName.Should().Be(user.LastName);
    }

    [Fact]
    public async Task GetUser_ShouldReturnNotFound_WhenUserDoesNotExist()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        var nonExistentTelegramId = 999999999L;

        // Act
        var response = await _client.GetAsync($"/api/v1/users/{nonExistentTelegramId}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Be("User not found");
    }

    [Fact]
    public async Task UpdateBlockStatus_ShouldBlockUser_WhenUserExists()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        var user = TestDataFactory.CreateUser(u => u.IsBlocked = false);
        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        var request = new UpdateBlockStatusRequest
        {
            IsBlocked = true,
            Reason = "Spam behavior"
        };

        // Act
        var response = await _client.PatchAsJsonAsync($"/api/v1/users/{user.TelegramId}/block-status", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<OperationResponse>();
        result.Should().NotBeNull();
        result!.Success.Should().BeTrue();
        result.Message.Should().Contain("blocked");

        // Verify in database
        var updatedUser = await context.Users.FindAsync(user.Id);
        updatedUser.Should().NotBeNull();
        updatedUser!.IsBlocked.Should().BeTrue();
        updatedUser.BlockReason.Should().Be("Spam behavior");
    }

    [Fact]
    public async Task UpdateBlockStatus_ShouldUnblockUser_WhenUserIsBlocked()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        var user = TestDataFactory.CreateUser(u => 
        {
            u.IsBlocked = true;
            u.BlockReason = "Previous violation";
        });
        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        var request = new UpdateBlockStatusRequest
        {
            IsBlocked = false
        };

        // Act
        var response = await _client.PatchAsJsonAsync($"/api/v1/users/{user.TelegramId}/block-status", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<OperationResponse>();
        result.Should().NotBeNull();
        result!.Success.Should().BeTrue();
        result.Message.Should().Contain("unblocked");

        // Verify in database
        var updatedUser = await context.Users.FindAsync(user.Id);
        updatedUser.Should().NotBeNull();
        updatedUser!.IsBlocked.Should().BeFalse();
        updatedUser.BlockReason.Should().BeNull();
    }

    [Fact]
    public async Task UpdateBlockStatus_ShouldReturnNotFound_WhenUserDoesNotExist()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        var nonExistentTelegramId = 999999999L;
        var request = new UpdateBlockStatusRequest { IsBlocked = true };

        // Act
        var response = await _client.PatchAsJsonAsync($"/api/v1/users/{nonExistentTelegramId}/block-status", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Be("User not found");
    }

    [Fact]
    public async Task UpdateBlockStatus_ShouldReturnBadRequest_WhenModelStateInvalid()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        var telegramId = 123456789L;
        var invalidRequest = new { InvalidProperty = "test" };

        // Act
        var response = await _client.PatchAsJsonAsync($"/api/v1/users/{telegramId}/block-status", invalidRequest);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Be("Invalid request data");
    }

    [Fact]
    public async Task GetUserInteractions_ShouldReturnPaginatedInteractions_WhenUserExists()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        var (user, interactions) = TestDataFactory.CreateUserWithInteractions(15);
        await context.Users.AddAsync(user);
        await context.Interactions.AddRangeAsync(interactions);
        await context.SaveChangesAsync();

        // Act
        var response = await _client.GetAsync($"/api/v1/users/{user.TelegramId}/interactions?pageNumber=1&pageSize=10");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<PaginatedResponse<InteractionResponse>>();
        result.Should().NotBeNull();
        result!.Data.Should().HaveCount(10);
        result.PageNumber.Should().Be(1);
        result.PageSize.Should().Be(10);
        result.TotalCount.Should().Be(15);
        result.TotalPages.Should().Be(2);
        result.HasNextPage.Should().BeTrue();
        result.HasPreviousPage.Should().BeFalse();
    }

    [Theory]
    [InlineData(0, 10, HttpStatusCode.BadRequest)]
    [InlineData(1, 0, HttpStatusCode.BadRequest)]
    [InlineData(1, 51, HttpStatusCode.BadRequest)]
    [InlineData(-1, 20, HttpStatusCode.BadRequest)]
    public async Task GetUserInteractions_ShouldReturnBadRequest_WhenInvalidPaginationParameters(
        int pageNumber, int pageSize, HttpStatusCode expectedStatusCode)
    {
        // Arrange
        var telegramId = 123456789L;

        // Act
        var response = await _client.GetAsync($"/api/v1/users/{telegramId}/interactions?pageNumber={pageNumber}&pageSize={pageSize}");

        // Assert
        response.StatusCode.Should().Be(expectedStatusCode);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Contain("Invalid pagination parameters");
    }

    [Fact]
    public async Task GetUserInteractions_ShouldReturnNotFound_WhenUserDoesNotExist()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        var nonExistentTelegramId = 999999999L;

        // Act
        var response = await _client.GetAsync($"/api/v1/users/{nonExistentTelegramId}/interactions");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task GetUsers_ShouldHandleConcurrentRequests()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        var users = TestDataFactory.CreateUsers(50);
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act - Send multiple concurrent requests
        var tasks = Enumerable.Range(1, 5).Select(pageNumber =>
            _client.GetAsync($"/api/v1/users?pageNumber={pageNumber}&pageSize=10")
        );

        var responses = await Task.WhenAll(tasks);

        // Assert
        responses.Should().OnlyContain(r => r.StatusCode == HttpStatusCode.OK);
        
        var results = new List<PaginatedResponse<UserResponse>>();
        foreach (var response in responses)
        {
            var result = await response.Content.ReadFromJsonAsync<PaginatedResponse<UserResponse>>();
            result.Should().NotBeNull();
            results.Add(result!);
        }

        // Verify all pages have correct data
        results.Should().HaveCount(5);
        results.SelectMany(r => r.Data).Should().HaveCount(50);
        results.Should().OnlyContain(r => r.TotalCount == 50);
    }

    [Fact]
    public async Task Controllers_ShouldReturnConsistentErrorFormat()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Act - Test different error scenarios
        var notFoundResponse = await _client.GetAsync("/api/v1/users/999999999");
        var badRequestResponse = await _client.GetAsync("/api/v1/users?pageNumber=0&pageSize=10");

        // Assert
        notFoundResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);
        badRequestResponse.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var notFoundError = await notFoundResponse.Content.ReadFromJsonAsync<ErrorResponse>();
        var badRequestError = await badRequestResponse.Content.ReadFromJsonAsync<ErrorResponse>();

        // Verify consistent error response structure
        notFoundError.Should().NotBeNull();
        notFoundError!.Error.Should().NotBeNullOrEmpty();
        notFoundError.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));

        badRequestError.Should().NotBeNull();
        badRequestError!.Error.Should().NotBeNullOrEmpty();
        badRequestError.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));
    }
}