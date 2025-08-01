using Microsoft.Extensions.Logging;
using Telegram.Bot;
using Telegram.Bot.Types;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.Models;

namespace AjudadoraBot.Infrastructure.Commands;

public class StatusCommand : ICommandHandler
{
    private readonly ITelegramBotClient _botClient;
    private readonly IBotService _botService;
    private readonly ILogger<StatusCommand> _logger;

    public string Command => "status";
    public string Description => "Show bot status and information";

    public StatusCommand(
        ITelegramBotClient botClient,
        IBotService botService,
        ILogger<StatusCommand> logger)
    {
        _botClient = botClient;
        _botService = botService;
        _logger = logger;
    }

    public Task<bool> CanExecuteAsync(Message message, User user)
    {
        // Everyone can execute the status command
        return Task.FromResult(true);
    }

    public async Task ExecuteAsync(Message message, User user)
    {
        try
        {
            var botInfo = await _botService.GetBotInfoAsync();
            
            var statusText = $"""
                🤖 <b>Status do Bot</b>
                
                📊 <b>Informações Gerais:</b>
                • ID: <code>{botInfo.Id}</code>
                • Username: @{botInfo.Username}
                • Nome: {botInfo.FirstName}
                • Status: {(botInfo.IsActive ? "🟢 Ativo" : "🔴 Inativo")}
                • Modo: {botInfo.Mode}
                
                👥 <b>Usuários:</b>
                • Total: {botInfo.TotalUsers}
                • Ativos: {botInfo.ActiveUsers}
                
                🕐 <b>Última Atividade:</b>
                {botInfo.LastActivity:dd/MM/yyyy HH:mm:ss}
                """;

            if (!string.IsNullOrEmpty(botInfo.WebhookUrl))
            {
                statusText += $"\n🔗 <b>Webhook:</b> {botInfo.WebhookUrl}";
            }

            await _botClient.SendTextMessageAsync(
                chatId: message.Chat.Id,
                text: statusText,
                parseMode: Telegram.Bot.Types.Enums.ParseMode.Html);

            _logger.LogInformation("Status command executed for user {UserId}", user.TelegramId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing status command for user {UserId}", user.TelegramId);
            
            // Send error message to user
            await _botClient.SendTextMessageAsync(
                chatId: message.Chat.Id,
                text: "❌ Erro ao obter status do bot. Tente novamente mais tarde.");
        }
    }
}