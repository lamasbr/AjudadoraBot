using Microsoft.Extensions.Logging;
using Telegram.Bot;
using Telegram.Bot.Types;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.Models;

namespace AjudadoraBot.Infrastructure.Commands;

public class HelpCommand : ICommandHandler
{
    private readonly ITelegramBotClient _botClient;
    private readonly ICommandProcessor _commandProcessor;
    private readonly ILogger<HelpCommand> _logger;

    public string Command => "help";
    public string Description => "Show available commands and their descriptions";

    public HelpCommand(
        ITelegramBotClient botClient, 
        ICommandProcessor commandProcessor,
        ILogger<HelpCommand> logger)
    {
        _botClient = botClient;
        _commandProcessor = commandProcessor;
        _logger = logger;
    }

    public Task<bool> CanExecuteAsync(Message message, User user)
    {
        // Everyone can execute the help command
        return Task.FromResult(true);
    }

    public async Task ExecuteAsync(Message message, User user)
    {
        try
        {
            var commands = await _commandProcessor.GetAvailableCommandsAsync();
            var helpText = "📋 <b>Comandos Disponíveis:</b>\n\n";

            foreach (var cmd in commands)
            {
                var description = await _commandProcessor.GetCommandHelpAsync(cmd);
                helpText += $"/{cmd} - {description ?? "Sem descrição"}\n";
            }

            helpText += "\n💡 <i>Dica: Você também pode usar os botões inline para navegar mais facilmente!</i>";

            await _botClient.SendTextMessageAsync(
                chatId: message.Chat.Id,
                text: helpText,
                parseMode: Telegram.Bot.Types.Enums.ParseMode.Html);

            _logger.LogInformation("Help command executed for user {UserId}", user.TelegramId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing help command for user {UserId}", user.TelegramId);
            throw;
        }
    }
}