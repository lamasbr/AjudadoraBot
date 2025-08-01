using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using Telegram.Bot;
using Telegram.Bot.Types;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.Configuration;

namespace AjudadoraBot.Infrastructure.Services;

public class WebhookService : IWebhookService
{
    private readonly ITelegramBotClient _botClient;
    private readonly IMessageHandler _messageHandler;
    private readonly IConfigurationService _configurationService;
    private readonly ILogger<WebhookService> _logger;
    private readonly TelegramBotOptions _botOptions;

    public WebhookService(
        ITelegramBotClient botClient,
        IMessageHandler messageHandler,
        IConfigurationService configurationService,
        IOptions<TelegramBotOptions> botOptions,
        ILogger<WebhookService> logger)
    {
        _botClient = botClient;
        _messageHandler = messageHandler;
        _configurationService = configurationService;
        _logger = logger;
        _botOptions = botOptions.Value;
    }

    public async Task<bool> VerifySecretTokenAsync(string secretToken)
    {
        try
        {
            var storedToken = await _configurationService.GetStringAsync(ConfigurationKeys.WebhookSecretToken);
            
            if (string.IsNullOrEmpty(storedToken))
            {
                _logger.LogWarning("No webhook secret token configured");
                return false;
            }

            return storedToken.Equals(secretToken, StringComparison.Ordinal);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error verifying secret token");
            return false;
        }
    }

    public async Task ProcessUpdateAsync(Update update)
    {
        try
        {
            _logger.LogDebug("Processing update {UpdateId} of type {UpdateType}", 
                update.Id, update.Type);

            switch (update.Type)
            {
                case Telegram.Bot.Types.Enums.UpdateType.Message:
                    if (update.Message != null)
                        await _messageHandler.HandleMessageAsync(update.Message);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.CallbackQuery:
                    if (update.CallbackQuery != null)
                        await _messageHandler.HandleCallbackQueryAsync(update.CallbackQuery);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.InlineQuery:
                    if (update.InlineQuery != null)
                        await _messageHandler.HandleInlineQueryAsync(update.InlineQuery);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.PreCheckoutQuery:
                    if (update.PreCheckoutQuery != null)
                        await _messageHandler.HandlePreCheckoutQueryAsync(update.PreCheckoutQuery);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.ShippingQuery:
                    if (update.ShippingQuery != null)
                        await _messageHandler.HandleShippingQueryAsync(update.ShippingQuery);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.ChosenInlineResult:
                    if (update.ChosenInlineResult != null)
                        await _messageHandler.HandleChosenInlineResultAsync(update.ChosenInlineResult);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.PollAnswer:
                    if (update.PollAnswer != null)
                        await _messageHandler.HandlePollAnswerAsync(update.PollAnswer);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.MyChatMember:
                    if (update.MyChatMember != null)
                        await _messageHandler.HandleMyChatMemberAsync(update.MyChatMember);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.ChatMember:
                    if (update.ChatMember != null)
                        await _messageHandler.HandleChatMemberAsync(update.ChatMember);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.ChatJoinRequest:
                    if (update.ChatJoinRequest != null)
                        await _messageHandler.HandleChatJoinRequestAsync(update.ChatJoinRequest);
                    break;

                default:
                    _logger.LogWarning("Unhandled update type: {UpdateType}", update.Type);
                    break;
            }

            _logger.LogDebug("Successfully processed update {UpdateId}", update.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing update {UpdateId}: {Message}", 
                update.Id, ex.Message);
            throw;
        }
    }

    public async Task<bool> SetWebhookAsync(string url, string? secretToken = null)
    {
        try
        {
            // Generate secret token if not provided
            if (string.IsNullOrEmpty(secretToken))
            {
                secretToken = GenerateSecretToken();
            }

            await _botClient.SetWebhookAsync(
                url: url,
                secretToken: secretToken,
                maxConnections: 100,
                allowedUpdates: new[]
                {
                    Telegram.Bot.Types.Enums.UpdateType.Message,
                    Telegram.Bot.Types.Enums.UpdateType.CallbackQuery,
                    Telegram.Bot.Types.Enums.UpdateType.InlineQuery,
                    Telegram.Bot.Types.Enums.UpdateType.PreCheckoutQuery,
                    Telegram.Bot.Types.Enums.UpdateType.ShippingQuery,
                    Telegram.Bot.Types.Enums.UpdateType.ChosenInlineResult,
                    Telegram.Bot.Types.Enums.UpdateType.PollAnswer,
                    Telegram.Bot.Types.Enums.UpdateType.MyChatMember,
                    Telegram.Bot.Types.Enums.UpdateType.ChatMember,
                    Telegram.Bot.Types.Enums.UpdateType.ChatJoinRequest
                });

            // Store webhook configuration
            await _configurationService.SetValueAsync(ConfigurationKeys.WebhookUrl, url);
            await _configurationService.SetValueAsync(ConfigurationKeys.WebhookSecretToken, secretToken, 
                Core.Enums.ConfigurationType.Encrypted, true);
            await _configurationService.SetValueAsync(ConfigurationKeys.BotMode, "Webhook");

            _logger.LogInformation("Webhook set successfully to {Url}", url);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error setting webhook to {Url}: {Message}", url, ex.Message);
            return false;
        }
    }

    public async Task<bool> RemoveWebhookAsync()
    {
        try
        {
            await _botClient.DeleteWebhookAsync();

            // Update configuration
            await _configurationService.SetValueAsync(ConfigurationKeys.WebhookUrl, string.Empty);
            await _configurationService.SetValueAsync(ConfigurationKeys.WebhookSecretToken, string.Empty);
            await _configurationService.SetValueAsync(ConfigurationKeys.BotMode, "Polling");

            _logger.LogInformation("Webhook removed successfully");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing webhook: {Message}", ex.Message);
            return false;
        }
    }

    private static string GenerateSecretToken()
    {
        const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        var random = new Random();
        return new string(Enumerable.Repeat(chars, 32)
            .Select(s => s[random.Next(s.Length)]).ToArray());
    }
}