using AjudadoraBot.Core.DTOs;

namespace AjudadoraBot.Core.Interfaces;

public interface IBotService
{
    Task<BotInfoResponse> GetBotInfoAsync();
    Task<OperationResponse> StartBotAsync();
    Task<OperationResponse> StopBotAsync();
    Task<OperationResponse> SetWebhookAsync(string url, string? secretToken = null);
    Task<OperationResponse> RemoveWebhookAsync();
    Task<MessageResponse> SendMessageAsync(SendMessageRequest request);
    Task<OperationResponse> RestartBotAsync();
    Task<bool> IsBotRunningAsync();
}