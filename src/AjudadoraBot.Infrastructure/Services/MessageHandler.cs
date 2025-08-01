using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Telegram.Bot;
using Telegram.Bot.Types;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.Enums;

namespace AjudadoraBot.Infrastructure.Services;

public class MessageHandler : IMessageHandler
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ITelegramBotClient _botClient;
    private readonly ILogger<MessageHandler> _logger;

    public MessageHandler(
        IServiceProvider serviceProvider,
        ITelegramBotClient botClient,
        ILogger<MessageHandler> logger)
    {
        _serviceProvider = serviceProvider;
        _botClient = botClient;
        _logger = logger;
    }

    public async Task HandleMessageAsync(Message message)
    {
        if (message.From == null)
        {
            _logger.LogWarning("Received message without sender information");
            return;
        }

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var userService = scope.ServiceProvider.GetRequiredService<IUserService>();
            var commandProcessor = scope.ServiceProvider.GetRequiredService<ICommandProcessor>();
            var analyticsService = scope.ServiceProvider.GetRequiredService<IAnalyticsService>();

            var stopwatch = System.Diagnostics.Stopwatch.StartNew();

            // Create or update user
            var user = await userService.CreateOrUpdateUserAsync(message.From);
            
            // Check if user is blocked
            if (await userService.IsUserBlockedAsync(user.TelegramId))
            {
                _logger.LogInformation("Ignored message from blocked user {UserId}", user.TelegramId);
                return;
            }

            // Update last seen
            await userService.UpdateLastSeenAsync(user.TelegramId);

            bool isCommand = false;
            string? command = null;

            // Try to process as command first
            if (message.Text?.StartsWith('/') == true)
            {
                isCommand = await commandProcessor.ProcessCommandAsync(message);
                if (isCommand)
                {
                    command = ExtractCommand(message.Text);
                }
            }

            // If not a command or command failed, handle as regular message
            if (!isCommand)
            {
                await HandleRegularMessageAsync(message, user);
            }

            stopwatch.Stop();

            // Record interaction analytics
            await analyticsService.RecordInteractionAsync(
                user.Id,
                user.TelegramId,
                message.Chat.Id,
                isCommand ? InteractionType.Command : InteractionType.Message,
                command,
                isSuccessful: true,
                processingTimeMs: stopwatch.ElapsedMilliseconds);

            _logger.LogDebug("Successfully handled message from user {UserId} in {ElapsedMs}ms", 
                user.TelegramId, stopwatch.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling message from user {UserId}: {Message}", 
                message.From?.Id, ex.Message);

            using var scope = _serviceProvider.CreateScope();
            var analyticsService = scope.ServiceProvider.GetRequiredService<IAnalyticsService>();
            
            await analyticsService.RecordErrorAsync(
                ErrorType.Business,
                ex.Message,
                telegramUserId: message.From?.Id,
                stackTrace: ex.StackTrace);

            // Send error message to user
            try
            {
                await _botClient.SendTextMessageAsync(
                    chatId: message.Chat.Id,
                    text: "❌ Desculpe, ocorreu um erro ao processar sua mensagem. Tente novamente mais tarde.");
            }
            catch (Exception sendEx)
            {
                _logger.LogError(sendEx, "Failed to send error message to user {UserId}", message.From?.Id);
            }
        }
    }

    public async Task HandleCallbackQueryAsync(CallbackQuery callbackQuery)
    {
        if (callbackQuery.From == null || callbackQuery.Data == null)
        {
            _logger.LogWarning("Received callback query without sender or data");
            return;
        }

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var userService = scope.ServiceProvider.GetRequiredService<IUserService>();
            var analyticsService = scope.ServiceProvider.GetRequiredService<IAnalyticsService>();

            var stopwatch = System.Diagnostics.Stopwatch.StartNew();

            // Create or update user
            var user = await userService.CreateOrUpdateUserAsync(callbackQuery.From);
            
            // Check if user is blocked
            if (await userService.IsUserBlockedAsync(user.TelegramId))
            {
                await _botClient.AnswerCallbackQueryAsync(
                    callbackQueryId: callbackQuery.Id,
                    text: "❌ Você foi bloqueado.");
                return;
            }

            // Update last seen
            await userService.UpdateLastSeenAsync(user.TelegramId);

            // Process callback data
            await ProcessCallbackDataAsync(callbackQuery, user);

            stopwatch.Stop();

            // Record interaction analytics
            await analyticsService.RecordInteractionAsync(
                user.Id,
                user.TelegramId,
                callbackQuery.Message?.Chat?.Id ?? 0,
                InteractionType.CallbackQuery,
                isSuccessful: true,
                processingTimeMs: stopwatch.ElapsedMilliseconds);

            _logger.LogDebug("Successfully handled callback query from user {UserId} in {ElapsedMs}ms", 
                user.TelegramId, stopwatch.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling callback query from user {UserId}: {Message}", 
                callbackQuery.From?.Id, ex.Message);

            await _botClient.AnswerCallbackQueryAsync(
                callbackQueryId: callbackQuery.Id,
                text: "❌ Erro ao processar solicitação.");
        }
    }

    public async Task HandleInlineQueryAsync(InlineQuery inlineQuery)
    {
        if (inlineQuery.From == null)
        {
            _logger.LogWarning("Received inline query without sender information");
            return;
        }

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var userService = scope.ServiceProvider.GetRequiredService<IUserService>();

            // Create or update user
            var user = await userService.CreateOrUpdateUserAsync(inlineQuery.From);
            
            // Check if user is blocked
            if (await userService.IsUserBlockedAsync(user.TelegramId))
            {
                await _botClient.AnswerInlineQueryAsync(
                    inlineQueryId: inlineQuery.Id,
                    results: Array.Empty<Telegram.Bot.Types.InlineQueryResults.InlineQueryResult>());
                return;
            }

            // For now, return empty results
            await _botClient.AnswerInlineQueryAsync(
                inlineQueryId: inlineQuery.Id,
                results: Array.Empty<Telegram.Bot.Types.InlineQueryResults.InlineQueryResult>());

            _logger.LogDebug("Handled inline query from user {UserId}", user.TelegramId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling inline query from user {UserId}", inlineQuery.From?.Id);
        }
    }

    public async Task HandlePreCheckoutQueryAsync(PreCheckoutQuery preCheckoutQuery)
    {
        if (preCheckoutQuery.From == null)
        {
            _logger.LogWarning("Received pre-checkout query without sender information");
            return;
        }

        try
        {
            // For now, approve all pre-checkout queries
            await _botClient.AnswerPreCheckoutQueryAsync(
                preCheckoutQueryId: preCheckoutQuery.Id,
                ok: true);

            _logger.LogDebug("Handled pre-checkout query from user {UserId}", preCheckoutQuery.From.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling pre-checkout query from user {UserId}", preCheckoutQuery.From?.Id);
        }
    }

    public async Task HandleShippingQueryAsync(ShippingQuery shippingQuery)
    {
        if (shippingQuery.From == null)
        {
            _logger.LogWarning("Received shipping query without sender information");
            return;
        }

        try
        {
            // For now, return empty shipping options
            await _botClient.AnswerShippingQueryAsync(
                shippingQueryId: shippingQuery.Id,
                ok: true,
                shippingOptions: Array.Empty<Telegram.Bot.Types.Payments.ShippingOption>());

            _logger.LogDebug("Handled shipping query from user {UserId}", shippingQuery.From.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling shipping query from user {UserId}", shippingQuery.From?.Id);
        }
    }

    public async Task HandleChosenInlineResultAsync(ChosenInlineResult chosenInlineResult)
    {
        if (chosenInlineResult.From == null)
        {
            _logger.LogWarning("Received chosen inline result without sender information");
            return;
        }

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var analyticsService = scope.ServiceProvider.GetRequiredService<IAnalyticsService>();

            // Record analytics for chosen inline result
            await analyticsService.RecordInteractionAsync(
                Guid.Empty, // We don't have user ID here
                chosenInlineResult.From.Id,
                0, // No chat ID for inline results
                InteractionType.ChosenInlineResult);

            _logger.LogDebug("Handled chosen inline result from user {UserId}", chosenInlineResult.From.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling chosen inline result from user {UserId}", chosenInlineResult.From?.Id);
        }
    }

    public async Task HandlePollAnswerAsync(PollAnswer pollAnswer)
    {
        if (pollAnswer.User == null)
        {
            _logger.LogWarning("Received poll answer without user information");
            return;
        }

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var analyticsService = scope.ServiceProvider.GetRequiredService<IAnalyticsService>();

            // Record analytics for poll answer
            await analyticsService.RecordInteractionAsync(
                Guid.Empty, // We don't have user ID here
                pollAnswer.User.Id,
                0, // No chat ID for poll answers
                InteractionType.PollAnswer);

            _logger.LogDebug("Handled poll answer from user {UserId}", pollAnswer.User.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling poll answer from user {UserId}", pollAnswer.User?.Id);
        }
    }

    public async Task HandleMyChatMemberAsync(ChatMemberUpdated myChatMember)
    {
        try
        {
            _logger.LogInformation("Bot chat member status updated in chat {ChatId}: {Status}", 
                myChatMember.Chat.Id, myChatMember.NewChatMember.Status);

            // Handle bot being added/removed from chats
            // Implementation depends on your bot's requirements
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling my chat member update in chat {ChatId}", myChatMember.Chat?.Id);
        }
    }

    public async Task HandleChatMemberAsync(ChatMemberUpdated chatMember)
    {
        try
        {
            _logger.LogDebug("Chat member updated in chat {ChatId}: {UserId}", 
                chatMember.Chat.Id, chatMember.NewChatMember.User.Id);

            // Handle other chat member updates
            // Implementation depends on your bot's requirements
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling chat member update in chat {ChatId}", chatMember.Chat?.Id);
        }
    }

    public async Task HandleChatJoinRequestAsync(ChatJoinRequest chatJoinRequest)
    {
        try
        {
            _logger.LogDebug("Chat join request from user {UserId} in chat {ChatId}", 
                chatJoinRequest.From.Id, chatJoinRequest.Chat.Id);

            // Handle chat join requests
            // Implementation depends on your bot's requirements
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling chat join request from user {UserId}", chatJoinRequest.From?.Id);
        }
    }

    private async Task HandleRegularMessageAsync(Message message, Core.Models.User user)
    {
        // Simple echo bot behavior for regular messages
        var responseText = $"🤔 Você disse: \"{message.Text}\"\n\n" +
                          "💡 Dica: Use /help para ver os comandos disponíveis!";

        await _botClient.SendTextMessageAsync(
            chatId: message.Chat.Id,
            text: responseText,
            replyToMessageId: message.MessageId);

        _logger.LogDebug("Sent echo response to user {UserId}", user.TelegramId);
    }

    private async Task ProcessCallbackDataAsync(CallbackQuery callbackQuery, Core.Models.User user)
    {
        var data = callbackQuery.Data;
        
        switch (data)
        {
            case "help":
                await _botClient.AnswerCallbackQueryAsync(callbackQuery.Id, "📋 Carregando ajuda...");
                
                var helpText = """
                    📋 <b>Comandos Disponíveis:</b>
                    
                    /start - Iniciar o bot
                    /help - Mostrar esta ajuda
                    /status - Ver status do bot
                    /settings - Configurações
                    
                    💡 <i>Use os botões inline para navegação mais fácil!</i>
                    """;
                
                await _botClient.SendTextMessageAsync(
                    chatId: callbackQuery.Message!.Chat.Id,
                    text: helpText,
                    parseMode: Telegram.Bot.Types.Enums.ParseMode.Html);
                break;

            case "settings":
                await _botClient.AnswerCallbackQueryAsync(callbackQuery.Id, "⚙️ Abrindo configurações...");
                
                var settingsText = $"""
                    ⚙️ <b>Configurações do Usuário</b>
                    
                    👤 <b>Perfil:</b>
                    • ID: <code>{user.TelegramId}</code>
                    • Nome: {user.FirstName}
                    • Username: @{user.Username ?? "não definido"}
                    • Idioma: {user.LanguageCode ?? "não definido"}
                    
                    📊 <b>Estatísticas:</b>
                    • Primeira interação: {user.FirstSeen:dd/MM/yyyy}
                    • Última interação: {user.LastSeen:dd/MM/yyyy}
                    • Total de interações: {user.InteractionCount}
                    """;
                
                await _botClient.SendTextMessageAsync(
                    chatId: callbackQuery.Message!.Chat.Id,
                    text: settingsText,
                    parseMode: Telegram.Bot.Types.Enums.ParseMode.Html);
                break;

            default:
                await _botClient.AnswerCallbackQueryAsync(callbackQuery.Id, "❓ Ação não reconhecida");
                break;
        }
    }

    private static string ExtractCommand(string text)
    {
        var parts = text.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var command = parts[0].TrimStart('/');
        
        // Handle bot username in command (e.g., /start@botname)
        var atIndex = command.IndexOf('@');
        if (atIndex > 0)
        {
            command = command[..atIndex];
        }
        
        return command;
    }
}