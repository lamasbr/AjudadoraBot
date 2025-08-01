using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Telegram.Bot;
using Telegram.Bot.Polling;
using Telegram.Bot.Types;
using Telegram.Bot.Exceptions;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.Configuration;
using AjudadoraBot.Core.Enums;

namespace AjudadoraBot.Infrastructure.Services;

public class PollingService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ITelegramBotClient _botClient;
    private readonly ILogger<PollingService> _logger;
    private readonly TelegramBotOptions _botOptions;
    private CancellationTokenSource? _pollingCts;

    public PollingService(
        IServiceProvider serviceProvider,
        ITelegramBotClient botClient,
        IOptions<TelegramBotOptions> botOptions,
        ILogger<PollingService> logger)
    {
        _serviceProvider = serviceProvider;
        _botClient = botClient;
        _logger = logger;
        _botOptions = botOptions.Value;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var configService = scope.ServiceProvider.GetRequiredService<IConfigurationService>();
                
                var botMode = await configService.GetStringAsync(ConfigurationKeys.BotMode, "Polling");
                
                if (botMode.Equals("Polling", StringComparison.OrdinalIgnoreCase))
                {
                    await StartPollingAsync(stoppingToken);
                }
                else
                {
                    _logger.LogInformation("Bot is in webhook mode, polling disabled");
                    await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in polling service");
                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
            }
        }
    }

    private async Task StartPollingAsync(CancellationToken cancellationToken)
    {
        _pollingCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        
        var receiverOptions = new ReceiverOptions
        {
            AllowedUpdates = new[]
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
            },
            DropPendingUpdates = true,
            Limit = 100
        };

        _logger.LogInformation("Starting polling...");

        try
        {
            await _botClient.ReceiveAsync(
                updateHandler: HandleUpdateAsync,
                errorHandler: HandlePollingErrorAsync,
                receiverOptions: receiverOptions,
                cancellationToken: _pollingCts.Token);
        }
        catch (OperationCanceledException)
        {
            _logger.LogInformation("Polling cancelled");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during polling");
            throw;
        }
    }

    private async Task HandleUpdateAsync(ITelegramBotClient botClient, Update update, CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var messageHandler = scope.ServiceProvider.GetRequiredService<IMessageHandler>();
            var analyticsService = scope.ServiceProvider.GetRequiredService<IAnalyticsService>();

            var stopwatch = System.Diagnostics.Stopwatch.StartNew();

            // Process the update based on its type
            switch (update.Type)
            {
                case Telegram.Bot.Types.Enums.UpdateType.Message:
                    if (update.Message != null)
                        await messageHandler.HandleMessageAsync(update.Message);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.CallbackQuery:
                    if (update.CallbackQuery != null)
                        await messageHandler.HandleCallbackQueryAsync(update.CallbackQuery);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.InlineQuery:
                    if (update.InlineQuery != null)
                        await messageHandler.HandleInlineQueryAsync(update.InlineQuery);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.PreCheckoutQuery:
                    if (update.PreCheckoutQuery != null)
                        await messageHandler.HandlePreCheckoutQueryAsync(update.PreCheckoutQuery);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.ShippingQuery:
                    if (update.ShippingQuery != null)
                        await messageHandler.HandleShippingQueryAsync(update.ShippingQuery);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.ChosenInlineResult:
                    if (update.ChosenInlineResult != null)
                        await messageHandler.HandleChosenInlineResultAsync(update.ChosenInlineResult);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.PollAnswer:
                    if (update.PollAnswer != null)
                        await messageHandler.HandlePollAnswerAsync(update.PollAnswer);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.MyChatMember:
                    if (update.MyChatMember != null)
                        await messageHandler.HandleMyChatMemberAsync(update.MyChatMember);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.ChatMember:
                    if (update.ChatMember != null)
                        await messageHandler.HandleChatMemberAsync(update.ChatMember);
                    break;

                case Telegram.Bot.Types.Enums.UpdateType.ChatJoinRequest:
                    if (update.ChatJoinRequest != null)
                        await messageHandler.HandleChatJoinRequestAsync(update.ChatJoinRequest);
                    break;

                default:
                    _logger.LogWarning("Unhandled update type: {UpdateType}", update.Type);
                    break;
            }

            stopwatch.Stop();

            // Record successful interaction analytics
            var userId = GetUserIdFromUpdate(update);
            var telegramUserId = GetTelegramUserIdFromUpdate(update);
            
            if (userId.HasValue && telegramUserId.HasValue)
            {
                var interactionType = MapUpdateTypeToInteractionType(update.Type);
                await analyticsService.RecordInteractionAsync(
                    userId.Value, 
                    telegramUserId.Value, 
                    GetChatIdFromUpdate(update),
                    interactionType,
                    isSuccessful: true,
                    processingTimeMs: stopwatch.ElapsedMilliseconds);
            }

            _logger.LogDebug("Successfully processed update {UpdateId} in {ElapsedMs}ms", 
                update.Id, stopwatch.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling update {UpdateId}: {Message}", update.Id, ex.Message);
            
            // Record error analytics
            using var scope = _serviceProvider.CreateScope();
            var analyticsService = scope.ServiceProvider.GetRequiredService<IAnalyticsService>();
            
            await analyticsService.RecordErrorAsync(
                ErrorType.System,
                ex.Message,
                GetUserIdFromUpdate(update),
                GetTelegramUserIdFromUpdate(update),
                ex.StackTrace);
        }
    }

    private async Task HandlePollingErrorAsync(ITelegramBotClient botClient, Exception exception, CancellationToken cancellationToken)
    {
        var errorMessage = exception switch
        {
            ApiRequestException apiRequestException => 
                $"Telegram API Error: [{apiRequestException.ErrorCode}] {apiRequestException.Message}",
            _ => exception.Message
        };

        _logger.LogError(exception, "Polling error: {ErrorMessage}", errorMessage);

        // Record error analytics
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var analyticsService = scope.ServiceProvider.GetRequiredService<IAnalyticsService>();
            
            await analyticsService.RecordErrorAsync(
                exception is ApiRequestException ? ErrorType.TelegramApi : ErrorType.System,
                errorMessage,
                stackTrace: exception.StackTrace,
                severity: ErrorSeverity.Error);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to record polling error analytics");
        }

        // Wait before retrying
        if (exception is ApiRequestException { ErrorCode: 429 })
        {
            // Rate limit exceeded, wait longer
            await Task.Delay(TimeSpan.FromMinutes(1), cancellationToken);
        }
        else
        {
            await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
        }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Stopping polling service...");
        
        _pollingCts?.Cancel();
        
        await base.StopAsync(cancellationToken);
        
        _logger.LogInformation("Polling service stopped");
    }

    private static Guid? GetUserIdFromUpdate(Update update)
    {
        // This would need to be implemented to get the user ID from the database
        // based on the Telegram user ID from the update
        return null;
    }

    private static long? GetTelegramUserIdFromUpdate(Update update)
    {
        return update.Type switch
        {
            Telegram.Bot.Types.Enums.UpdateType.Message => update.Message?.From?.Id,
            Telegram.Bot.Types.Enums.UpdateType.CallbackQuery => update.CallbackQuery?.From?.Id,
            Telegram.Bot.Types.Enums.UpdateType.InlineQuery => update.InlineQuery?.From?.Id,
            Telegram.Bot.Types.Enums.UpdateType.PreCheckoutQuery => update.PreCheckoutQuery?.From?.Id,
            Telegram.Bot.Types.Enums.UpdateType.ShippingQuery => update.ShippingQuery?.From?.Id,
            Telegram.Bot.Types.Enums.UpdateType.ChosenInlineResult => update.ChosenInlineResult?.From?.Id,
            Telegram.Bot.Types.Enums.UpdateType.PollAnswer => update.PollAnswer?.User?.Id,
            Telegram.Bot.Types.Enums.UpdateType.MyChatMember => update.MyChatMember?.From?.Id,
            Telegram.Bot.Types.Enums.UpdateType.ChatMember => update.ChatMember?.From?.Id,
            Telegram.Bot.Types.Enums.UpdateType.ChatJoinRequest => update.ChatJoinRequest?.From?.Id,
            _ => null
        };
    }

    private static long GetChatIdFromUpdate(Update update)
    {
        return update.Type switch
        {
            Telegram.Bot.Types.Enums.UpdateType.Message => update.Message?.Chat?.Id ?? 0,
            Telegram.Bot.Types.Enums.UpdateType.CallbackQuery => update.CallbackQuery?.Message?.Chat?.Id ?? 0,
            Telegram.Bot.Types.Enums.UpdateType.MyChatMember => update.MyChatMember?.Chat?.Id ?? 0,
            Telegram.Bot.Types.Enums.UpdateType.ChatMember => update.ChatMember?.Chat?.Id ?? 0,
            Telegram.Bot.Types.Enums.UpdateType.ChatJoinRequest => update.ChatJoinRequest?.Chat?.Id ?? 0,
            _ => 0
        };
    }

    private static InteractionType MapUpdateTypeToInteractionType(Telegram.Bot.Types.Enums.UpdateType updateType)
    {
        return updateType switch
        {
            Telegram.Bot.Types.Enums.UpdateType.Message => InteractionType.Message,
            Telegram.Bot.Types.Enums.UpdateType.CallbackQuery => InteractionType.CallbackQuery,
            Telegram.Bot.Types.Enums.UpdateType.InlineQuery => InteractionType.InlineQuery,
            Telegram.Bot.Types.Enums.UpdateType.PreCheckoutQuery => InteractionType.PreCheckoutQuery,
            Telegram.Bot.Types.Enums.UpdateType.ShippingQuery => InteractionType.ShippingQuery,
            Telegram.Bot.Types.Enums.UpdateType.ChosenInlineResult => InteractionType.ChosenInlineResult,
            Telegram.Bot.Types.Enums.UpdateType.PollAnswer => InteractionType.PollAnswer,
            Telegram.Bot.Types.Enums.UpdateType.MyChatMember => InteractionType.MyChatMember,
            Telegram.Bot.Types.Enums.UpdateType.ChatMember => InteractionType.ChatMember,
            Telegram.Bot.Types.Enums.UpdateType.ChatJoinRequest => InteractionType.ChatJoinRequest,
            _ => InteractionType.Message
        };
    }
}