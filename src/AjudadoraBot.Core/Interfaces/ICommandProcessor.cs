using Telegram.Bot.Types;

namespace AjudadoraBot.Core.Interfaces;

public interface ICommandProcessor
{
    Task<bool> ProcessCommandAsync(Message message);
    Task RegisterCommandAsync(string command, ICommandHandler handler);
    Task<IEnumerable<string>> GetAvailableCommandsAsync();
    Task<string?> GetCommandHelpAsync(string command);
}

public interface ICommandHandler
{
    string Command { get; }
    string Description { get; }
    Task<bool> CanExecuteAsync(Message message, User user);
    Task ExecuteAsync(Message message, User user);
}