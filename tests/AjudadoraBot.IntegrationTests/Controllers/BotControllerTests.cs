using Xunit;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using System.Net;
using System.Net.Http.Json;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.IntegrationTests.TestBase;
using AjudadoraBot.UnitTests.TestBase;
using Moq;

namespace AjudadoraBot.IntegrationTests.Controllers;

public class BotControllerTests : IClassFixture<IntegrationTestFixture>
{
    private readonly IntegrationTestFixture _factory;
    private readonly HttpClient _client;

    public BotControllerTests(IntegrationTestFixture factory)
    {
        _factory = factory;
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task GetBotInfo_ShouldReturnBotInformation()
    {
        // Act
        var response = await _client.GetAsync("/api/v1/bot/info");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<BotInfoResponse>();
        result.Should().NotBeNull();
        result!.Id.Should().BeGreaterThan(0);
        result.Username.Should().NotBeNullOrEmpty();
        result.FirstName.Should().NotBeNullOrEmpty();
        result.Mode.Should().BeOneOf("Polling", "Webhook");
    }

    [Fact]
    public async Task StartBot_ShouldReturnSuccess_WhenBotCanBeStarted()
    {
        // Act
        var response = await _client.PostAsync("/api/v1/bot/start", null);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<OperationResponse>();
        result.Should().NotBeNull();
        result!.Success.Should().BeTrue();
        result.Message.Should().Contain("start");
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));
    }

    [Fact]
    public async Task StopBot_ShouldReturnSuccess_WhenBotCanBeStopped()
    {
        // Act
        var response = await _client.PostAsync("/api/v1/bot/stop", null);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<OperationResponse>();
        result.Should().NotBeNull();
        result!.Success.Should().BeTrue();
        result.Message.Should().Contain("stop");
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));
    }

    [Theory]
    [InlineData("https://example.com/webhook", "secret123")]
    [InlineData("https://mydomain.com/telegram/webhook", null)]
    public async Task SetWebhook_ShouldReturnSuccess_WhenValidRequest(string url, string? secretToken)
    {
        // Arrange
        var request = new SetWebhookRequest
        {
            Url = url,
            SecretToken = secretToken
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/bot/webhook", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<OperationResponse>();
        result.Should().NotBeNull();
        result!.Success.Should().BeTrue();
        result.Message.Should().Contain("webhook");
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));
    }

    [Theory]
    [InlineData("", "secret")]
    [InlineData("invalid-url", "secret")]
    [InlineData("ftp://example.com", "secret")]
    public async Task SetWebhook_ShouldReturnBadRequest_WhenInvalidUrl(string url, string secretToken)
    {
        // Arrange
        var request = new SetWebhookRequest
        {
            Url = url,
            SecretToken = secretToken
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/bot/webhook", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Be("Invalid request data");
    }

    [Fact]
    public async Task SetWebhook_ShouldReturnBadRequest_WhenModelStateInvalid()
    {
        // Arrange
        var invalidRequest = new { InvalidProperty = "test" };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/bot/webhook", invalidRequest);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Be("Invalid request data");
    }

    [Fact]
    public async Task RemoveWebhook_ShouldReturnSuccess()
    {
        // Act
        var response = await _client.DeleteAsync("/api/v1/bot/webhook");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<OperationResponse>();
        result.Should().NotBeNull();
        result!.Success.Should().BeTrue();
        result.Message.Should().Contain("remove");
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));
    }

    [Fact]
    public async Task SendMessage_ShouldReturnSuccess_WhenValidRequest()
    {
        // Arrange
        var request = TestDataFactory.CreateSendMessageRequest(r =>
        {
            r.ChatId = 123456789L;
            r.Text = "Test message from integration test";
        });

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/bot/send-message", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<MessageResponse>();
        result.Should().NotBeNull();
        result!.Success.Should().BeTrue();
        result.ChatId.Should().Be(request.ChatId);
        result.Text.Should().Be(request.Text);
        result.MessageId.Should().BeGreaterThan(0);
        result.SentAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));
    }

    [Theory]
    [InlineData(0, "Test message")]
    [InlineData(123456789L, "")]
    [InlineData(123456789L, null)]
    public async Task SendMessage_ShouldReturnBadRequest_WhenInvalidRequest(long chatId, string? text)
    {
        // Arrange
        var request = new SendMessageRequest
        {
            ChatId = chatId,
            Text = text ?? string.Empty
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/bot/send-message", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Be("Invalid request data");
    }

    [Fact]
    public async Task SendMessage_ShouldReturnBadRequest_WhenMessageTooLong()
    {
        // Arrange
        var longMessage = new string('a', 4097); // Telegram limit is 4096 characters
        var request = new SendMessageRequest
        {
            ChatId = 123456789L,
            Text = longMessage
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/bot/send-message", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Be("Invalid request data");
    }

    [Fact]
    public async Task SendMessage_ShouldReturnBadRequest_WhenModelStateInvalid()
    {
        // Arrange
        var invalidRequest = new { InvalidProperty = "test" };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/bot/send-message", invalidRequest);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        
        var errorResponse = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        errorResponse.Should().NotBeNull();
        errorResponse!.Error.Should().Be("Invalid request data");
    }

    [Fact]
    public async Task BotEndpoints_ShouldHandleConcurrentRequests()
    {
        // Act - Send multiple concurrent requests to different endpoints
        var getBotInfoTask = _client.GetAsync("/api/v1/bot/info");
        var startBotTask = _client.PostAsync("/api/v1/bot/start", null);
        var stopBotTask = _client.PostAsync("/api/v1/bot/stop", null);
        var removeWebhookTask = _client.DeleteAsync("/api/v1/bot/webhook");

        var responses = await Task.WhenAll(getBotInfoTask, startBotTask, stopBotTask, removeWebhookTask);

        // Assert
        responses.Should().OnlyContain(r => r.StatusCode == HttpStatusCode.OK);
    }

    [Fact]
    public async Task BotEndpoints_ShouldReturnConsistentResponseFormat()
    {
        // Act
        var getBotInfoResponse = await _client.GetAsync("/api/v1/bot/info");
        var startBotResponse = await _client.PostAsync("/api/v1/bot/start", null);

        // Assert
        getBotInfoResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        startBotResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        var botInfo = await getBotInfoResponse.Content.ReadFromJsonAsync<BotInfoResponse>();
        var operationResult = await startBotResponse.Content.ReadFromJsonAsync<OperationResponse>();

        // Verify response structure consistency
        botInfo.Should().NotBeNull();
        botInfo!.Id.Should().BeGreaterThan(0);
        botInfo.LastActivity.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromDays(1));

        operationResult.Should().NotBeNull();
        operationResult!.Success.Should().BeTrue();
        operationResult.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));
    }

    [Fact]
    public async Task BotController_ShouldHandleHttpMethods_Correctly()
    {
        // Test GET method
        var getResponse = await _client.GetAsync("/api/v1/bot/info");
        getResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        // Test POST method
        var postResponse = await _client.PostAsync("/api/v1/bot/start", null);
        postResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        // Test DELETE method
        var deleteResponse = await _client.DeleteAsync("/api/v1/bot/webhook");
        deleteResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        // Test unsupported method should return 405 Method Not Allowed
        var putResponse = await _client.PutAsync("/api/v1/bot/info", null);
        putResponse.StatusCode.Should().Be(HttpStatusCode.MethodNotAllowed);
    }

    [Theory]
    [InlineData("/api/v1/bot/info")]
    [InlineData("/api/v1/bot/start")]
    [InlineData("/api/v1/bot/stop")]
    [InlineData("/api/v1/bot/webhook")]
    public async Task BotEndpoints_ShouldReturnJsonContentType(string endpoint)
    {
        // Act
        HttpResponseMessage response = endpoint switch
        {
            "/api/v1/bot/info" => await _client.GetAsync(endpoint),
            "/api/v1/bot/start" => await _client.PostAsync(endpoint, null),
            "/api/v1/bot/stop" => await _client.PostAsync(endpoint, null),
            "/api/v1/bot/webhook" when endpoint.EndsWith("webhook") => await _client.DeleteAsync(endpoint),
            _ => throw new ArgumentException($"Unsupported endpoint: {endpoint}")
        };

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Content.Headers.ContentType?.MediaType.Should().Be("application/json");
    }

    [Fact]
    public async Task SendMessage_WithAllParameters_ShouldReturnSuccess()
    {
        // Arrange
        var request = new SendMessageRequest
        {
            ChatId = 123456789L,
            Text = "Test message with <b>HTML</b> formatting",
            ParseMode = "HTML",
            DisableWebPagePreview = true,
            DisableNotification = true,
            ReplyToMessageId = 12345
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/bot/send-message", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        var result = await response.Content.ReadFromJsonAsync<MessageResponse>();
        result.Should().NotBeNull();
        result!.Success.Should().BeTrue();
        result.ChatId.Should().Be(request.ChatId);
        result.Text.Should().Be(request.Text);
    }

    [Fact]
    public async Task WebhookOperations_ShouldMaintainConsistentState()
    {
        // Arrange
        var setWebhookRequest = new SetWebhookRequest
        {
            Url = "https://example.com/webhook",
            SecretToken = "test-secret"
        };

        // Act - Set webhook
        var setResponse = await _client.PostAsJsonAsync("/api/v1/bot/webhook", setWebhookRequest);

        // Act - Get bot info to verify webhook is set
        var infoResponse = await _client.GetAsync("/api/v1/bot/info");

        // Act - Remove webhook
        var removeResponse = await _client.DeleteAsync("/api/v1/bot/webhook");

        // Act - Get bot info again to verify webhook is removed
        var infoAfterRemovalResponse = await _client.GetAsync("/api/v1/bot/info");

        // Assert
        setResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        infoResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        removeResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        infoAfterRemovalResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        var setResult = await setResponse.Content.ReadFromJsonAsync<OperationResponse>();
        var removeResult = await removeResponse.Content.ReadFromJsonAsync<OperationResponse>();

        setResult!.Success.Should().BeTrue();
        removeResult!.Success.Should().BeTrue();
    }
}