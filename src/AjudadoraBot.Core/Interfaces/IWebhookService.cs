using Telegram.Bot.Types;

namespace AjudadoraBot.Core.Interfaces;

public interface IWebhookService
{
    Task<bool> VerifySecretTokenAsync(string secretToken);
    Task ProcessUpdateAsync(Update update);
    Task<bool> SetWebhookAsync(string url, string? secretToken = null);
    Task<bool> RemoveWebhookAsync();
}