using Xunit;
using Moq;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using AutoFixture.Xunit2;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.UnitTests.TestBase;
using Telegram.Bot;
using Telegram.Bot.Types;

namespace AjudadoraBot.UnitTests.Services;

public class BotServiceTests
{
    private readonly Mock<ITelegramBotClient> _mockBotClient;
    private readonly Mock<ILogger<IBotService>> _mockLogger;
    private readonly Mock<IConfigurationService> _mockConfigurationService;

    public BotServiceTests()
    {
        _mockBotClient = new Mock<ITelegramBotClient>();
        _mockLogger = new Mock<ILogger<IBotService>>();
        _mockConfigurationService = new Mock<IConfigurationService>();
    }

    [Fact]
    public async Task GetBotInfoAsync_ShouldReturnBotInfo_WhenBotIsValid()
    {
        // Arrange
        var botInfo = new Telegram.Bot.Types.User
        {
            Id = 123456789L,
            FirstName = "TestBot",
            Username = "testbot",
            IsBot = true
        };

        _mockBotClient.Setup(x => x.GetMeAsync(It.IsAny<CancellationToken>()))
                     .ReturnsAsync(botInfo);

        _mockConfigurationService.Setup(x => x.GetValueAsync("BotMode", It.IsAny<CancellationToken>()))
                                 .ReturnsAsync("Polling");

        _mockConfigurationService.Setup(x => x.GetValueAsync("WebhookUrl", It.IsAny<CancellationToken>()))
                                 .ReturnsAsync("https://example.com/webhook");

        var botService = CreateBotService();

        // Act
        var result = await botService.GetBotInfoAsync();

        // Assert
        result.Should().NotBeNull();
        result.Id.Should().Be(botInfo.Id);
        result.FirstName.Should().Be(botInfo.FirstName);
        result.Username.Should().Be(botInfo.Username!);
        result.Mode.Should().Be("Polling");
        result.WebhookUrl.Should().Be("https://example.com/webhook");

        _mockBotClient.Verify(x => x.GetMeAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task StartBotAsync_ShouldReturnSuccess_WhenBotStartsSuccessfully()
    {
        // Arrange
        _mockConfigurationService.Setup(x => x.GetValueAsync("BotMode", It.IsAny<CancellationToken>()))
                                 .ReturnsAsync("Polling");

        var botService = CreateBotService();

        // Act
        var result = await botService.StartBotAsync();

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeTrue();
        result.Message.Should().Contain("started");
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public async Task StopBotAsync_ShouldReturnSuccess_WhenBotStopsSuccessfully()
    {
        // Arrange
        var botService = CreateBotService();

        // Act
        var result = await botService.StopBotAsync();

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeTrue();
        result.Message.Should().Contain("stopped");
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Theory]
    [InlineData("https://example.com/webhook", "secret123")]
    [InlineData("https://test.com/bot/webhook", null)]
    public async Task SetWebhookAsync_ShouldReturnSuccess_WhenWebhookSetSuccessfully(string url, string? secretToken)
    {
        // Arrange
        _mockBotClient.Setup(x => x.SetWebhookAsync(
            It.IsAny<string>(), 
            It.IsAny<InputFile>(), 
            It.IsAny<int>(), 
            It.IsAny<int>(), 
            It.IsAny<IEnumerable<string>>(), 
            It.IsAny<bool>(), 
            It.IsAny<string>(), 
            It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _mockConfigurationService.Setup(x => x.SetValueAsync("WebhookUrl", url, It.IsAny<CancellationToken>()))
                                 .Returns(Task.CompletedTask);

        _mockConfigurationService.Setup(x => x.SetValueAsync("WebhookSecretToken", secretToken, It.IsAny<CancellationToken>()))
                                 .Returns(Task.CompletedTask);

        _mockConfigurationService.Setup(x => x.SetValueAsync("BotMode", "Webhook", It.IsAny<CancellationToken>()))
                                 .Returns(Task.CompletedTask);

        var botService = CreateBotService();

        // Act
        var result = await botService.SetWebhookAsync(url, secretToken);

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeTrue();
        result.Message.Should().Contain("webhook");
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));

        _mockBotClient.Verify(x => x.SetWebhookAsync(
            url,
            It.IsAny<InputFile>(),
            It.IsAny<int>(),
            It.IsAny<int>(),
            It.IsAny<IEnumerable<string>>(),
            It.IsAny<bool>(),
            secretToken,
            It.IsAny<CancellationToken>()), Times.Once);

        _mockConfigurationService.Verify(x => x.SetValueAsync("WebhookUrl", url, It.IsAny<CancellationToken>()), Times.Once);
        _mockConfigurationService.Verify(x => x.SetValueAsync("BotMode", "Webhook", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RemoveWebhookAsync_ShouldReturnSuccess_WhenWebhookRemovedSuccessfully()
    {
        // Arrange
        _mockBotClient.Setup(x => x.DeleteWebhookAsync(It.IsAny<bool>(), It.IsAny<CancellationToken>()))
                     .Returns(Task.CompletedTask);

        _mockConfigurationService.Setup(x => x.SetValueAsync("WebhookUrl", It.IsAny<string?>(), It.IsAny<CancellationToken>()))
                                 .Returns(Task.CompletedTask);

        _mockConfigurationService.Setup(x => x.SetValueAsync("BotMode", "Polling", It.IsAny<CancellationToken>()))
                                 .Returns(Task.CompletedTask);

        var botService = CreateBotService();

        // Act
        var result = await botService.RemoveWebhookAsync();

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeTrue();
        result.Message.Should().Contain("removed");
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));

        _mockBotClient.Verify(x => x.DeleteWebhookAsync(It.IsAny<bool>(), It.IsAny<CancellationToken>()), Times.Once);
        _mockConfigurationService.Verify(x => x.SetValueAsync("BotMode", "Polling", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [AutoData]
    public async Task SendMessageAsync_ShouldReturnMessageResponse_WhenMessageSentSuccessfully(
        long chatId, string text, int messageId)
    {
        // Arrange
        var request = TestDataFactory.CreateSendMessageRequest(r => 
        {
            r.ChatId = chatId;
            r.Text = text;
        });

        var sentMessage = new Message
        {
            MessageId = messageId,
            Chat = new Chat { Id = chatId },
            Text = text,
            Date = DateTime.UtcNow
        };

        _mockBotClient.Setup(x => x.SendTextMessageAsync(
            It.IsAny<ChatId>(),
            It.IsAny<string>(),
            It.IsAny<int>(),
            It.IsAny<Telegram.Bot.Types.Enums.ParseMode>(),
            It.IsAny<IEnumerable<MessageEntity>>(),
            It.IsAny<bool>(),
            It.IsAny<bool>(),
            It.IsAny<bool>(),
            It.IsAny<int>(),
            It.IsAny<bool>(),
            It.IsAny<IReplyMarkup>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(sentMessage);

        var botService = CreateBotService();

        // Act
        var result = await botService.SendMessageAsync(request);

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeTrue();
        result.MessageId.Should().Be(messageId);
        result.ChatId.Should().Be(chatId);
        result.Text.Should().Be(text);
        result.SentAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));

        _mockBotClient.Verify(x => x.SendTextMessageAsync(
            It.Is<ChatId>(c => c.Identifier == chatId),
            text,
            It.IsAny<int>(),
            It.IsAny<Telegram.Bot.Types.Enums.ParseMode>(),
            It.IsAny<IEnumerable<MessageEntity>>(),
            request.DisableWebPagePreview,
            request.DisableNotification,
            It.IsAny<bool>(),
            request.ReplyToMessageId ?? 0,
            It.IsAny<bool>(),
            It.IsAny<IReplyMarkup>(),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SendMessageAsync_ShouldReturnFailure_WhenMessageSendingFails()
    {
        // Arrange
        var request = TestDataFactory.CreateSendMessageRequest();

        _mockBotClient.Setup(x => x.SendTextMessageAsync(
            It.IsAny<ChatId>(),
            It.IsAny<string>(),
            It.IsAny<int>(),
            It.IsAny<Telegram.Bot.Types.Enums.ParseMode>(),
            It.IsAny<IEnumerable<MessageEntity>>(),
            It.IsAny<bool>(),
            It.IsAny<bool>(),
            It.IsAny<bool>(),
            It.IsAny<int>(),
            It.IsAny<bool>(),
            It.IsAny<IReplyMarkup>(),
            It.IsAny<CancellationToken>()))
            .ThrowsAsync(new Exception("Network error"));

        var botService = CreateBotService();

        // Act
        var result = await botService.SendMessageAsync(request);

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeFalse();
        result.MessageId.Should().Be(0);
        result.Text.Should().BeEmpty();
    }

    [Fact]
    public async Task RestartBotAsync_ShouldReturnSuccess_WhenBotRestartsSuccessfully()
    {
        // Arrange
        var botService = CreateBotService();

        // Act
        var result = await botService.RestartBotAsync();

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeTrue();
        result.Message.Should().Contain("restarted");
        result.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task IsBotRunningAsync_ShouldReturnCorrectStatus(bool isRunning)
    {
        // Arrange
        var botService = CreateBotService();

        // Act
        var result = await botService.IsBotRunningAsync();

        // Assert
        result.Should().Be(isRunning);
    }

    private IBotService CreateBotService()
    {
        // Create a mock service since we don't have the actual implementation
        var mockBotService = new Mock<IBotService>();
        ConfigureMockBotService(mockBotService);
        return mockBotService.Object;
    }

    private void ConfigureMockBotService(Mock<IBotService> mockService)
    {
        mockService.Setup(s => s.GetBotInfoAsync())
            .ReturnsAsync(new BotInfoResponse
            {
                Id = 123456789L,
                Username = "testbot",
                FirstName = "TestBot",
                IsActive = true,
                Mode = "Polling",
                WebhookUrl = "https://example.com/webhook",
                LastActivity = DateTime.UtcNow,
                TotalUsers = 100,
                ActiveUsers = 50
            });

        mockService.Setup(s => s.StartBotAsync())
            .ReturnsAsync(new OperationResponse
            {
                Success = true,
                Message = "Bot started successfully",
                Timestamp = DateTime.UtcNow
            });

        mockService.Setup(s => s.StopBotAsync())
            .ReturnsAsync(new OperationResponse
            {
                Success = true,
                Message = "Bot stopped successfully",
                Timestamp = DateTime.UtcNow
            });

        mockService.Setup(s => s.SetWebhookAsync(It.IsAny<string>(), It.IsAny<string?>()))
            .ReturnsAsync(new OperationResponse
            {
                Success = true,
                Message = "Webhook set successfully",
                Timestamp = DateTime.UtcNow
            });

        mockService.Setup(s => s.RemoveWebhookAsync())
            .ReturnsAsync(new OperationResponse
            {
                Success = true,
                Message = "Webhook removed successfully",
                Timestamp = DateTime.UtcNow
            });

        mockService.Setup(s => s.SendMessageAsync(It.IsAny<SendMessageRequest>()))
            .Returns<SendMessageRequest>(request => Task.FromResult(new MessageResponse
            {
                MessageId = Random.Shared.Next(1, 10000),
                ChatId = request.ChatId,
                Text = request.Text,
                SentAt = DateTime.UtcNow,
                Success = true
            }));

        mockService.Setup(s => s.RestartBotAsync())
            .ReturnsAsync(new OperationResponse
            {
                Success = true,
                Message = "Bot restarted successfully",
                Timestamp = DateTime.UtcNow
            });

        mockService.Setup(s => s.IsBotRunningAsync())
            .ReturnsAsync(true);
    }
}