using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Telegram.Bot;
using Telegram.Bot.Types;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.Models;

namespace AjudadoraBot.Infrastructure.Services;

public class CommandProcessor : ICommandProcessor
{
    private readonly Dictionary<string, ICommandHandler> _commands = new();
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<CommandProcessor> _logger;

    public CommandProcessor(IServiceProvider serviceProvider, ILogger<CommandProcessor> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    public async Task<bool> ProcessCommandAsync(Message message)
    {
        if (message?.Text == null || !message.Text.StartsWith('/'))
            return false;

        try
        {
            var commandText = ExtractCommand(message.Text);
            
            if (!_commands.TryGetValue(commandText.ToLowerInvariant(), out var handler))
            {
                _logger.LogDebug("Unknown command: {Command}", commandText);
                return false;
            }

            using var scope = _serviceProvider.CreateScope();
            var userService = scope.ServiceProvider.GetRequiredService<IUserService>();
            
            // Get or create user
            var user = await userService.CreateOrUpdateUserAsync(message.From!);
            
            // Check if user can execute the command
            if (!await handler.CanExecuteAsync(message, user))
            {
                _logger.LogWarning("User {UserId} cannot execute command {Command}", 
                    user.TelegramId, commandText);
                return false;
            }

            // Execute the command
            await handler.ExecuteAsync(message, user);
            
            _logger.LogInformation("Successfully executed command {Command} for user {UserId}", 
                commandText, user.TelegramId);
            
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing command {Command}: {Message}", 
                message.Text, ex.Message);
            throw;
        }
    }

    public Task RegisterCommandAsync(string command, ICommandHandler handler)
    {
        var normalizedCommand = command.ToLowerInvariant().TrimStart('/');
        _commands[normalizedCommand] = handler;
        
        _logger.LogInformation("Registered command: {Command}", normalizedCommand);
        return Task.CompletedTask;
    }

    public Task<IEnumerable<string>> GetAvailableCommandsAsync()
    {
        return Task.FromResult(_commands.Keys.AsEnumerable());
    }

    public Task<string?> GetCommandHelpAsync(string command)
    {
        var normalizedCommand = command.ToLowerInvariant().TrimStart('/');
        
        if (_commands.TryGetValue(normalizedCommand, out var handler))
        {
            return Task.FromResult<string?>(handler.Description);
        }
        
        return Task.FromResult<string?>(null);
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