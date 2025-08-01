using Microsoft.Extensions.Logging;
using Telegram.Bot;
using Telegram.Bot.Types;
using Telegram.Bot.Types.ReplyMarkups;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.Models;

namespace AjudadoraBot.Infrastructure.Commands;

public class StartCommand : ICommandHandler
{
    private readonly ITelegramBotClient _botClient;
    private readonly ILogger<StartCommand> _logger;

    public string Command => "start";
    public string Description => "Start the bot and show welcome message";

    public StartCommand(ITelegramBotClient botClient, ILogger<StartCommand> logger)
    {
        _botClient = botClient;
        _logger = logger;
    }

    public Task<bool> CanExecuteAsync(Message message, User user)
    {
        // Everyone can execute the start command
        return Task.FromResult(true);
    }

    public async Task ExecuteAsync(Message message, User user)
    {
        try
        {
            var welcomeText = $"""
                🤖 Olá, {user.FirstName ?? "usuário"}! Bem-vindo ao AjudadoraBot!
                
                Eu sou seu assistente virtual e estou aqui para ajudar você.
                
                📋 Comandos disponíveis:
                /help - Mostrar lista de comandos
                /status - Ver status do bot
                /settings - Configurações do usuário
                
                🚀 Para começar, experimente alguns comandos ou simplesmente envie uma mensagem!
                """;

            var keyboard = new InlineKeyboardMarkup(new[]
            {
                new[]
                {
                    InlineKeyboardButton.WithCallbackData("📋 Ajuda", "help"),
                    InlineKeyboardButton.WithCallbackData("⚙️ Configurações", "settings")
                },
                new[]
                {
                    InlineKeyboardButton.WithWebApp("🌐 Mini App", 
                        new WebAppInfo { Url = "https://your-domain.com/miniapp" })
                }
            });

            await _botClient.SendTextMessageAsync(
                chatId: message.Chat.Id,
                text: welcomeText,
                replyMarkup: keyboard,
                parseMode: Telegram.Bot.Types.Enums.ParseMode.Html);

            _logger.LogInformation("Start command executed for user {UserId} ({Username})", 
                user.TelegramId, user.Username);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing start command for user {UserId}", user.TelegramId);
            throw;
        }
    }
}