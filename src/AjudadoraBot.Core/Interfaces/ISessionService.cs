using AjudadoraBot.Core.Models;

namespace AjudadoraBot.Core.Interfaces;

public interface ISessionService
{
    Task<UserSession> CreateSessionAsync(Guid userId, long telegramUserId, TimeSpan? expirationTime = null);
    Task<UserSession?> GetSessionAsync(string sessionToken);
    Task<bool> ValidateSessionAsync(string sessionToken);
    Task<bool> RefreshSessionAsync(string sessionToken);
    Task InvalidateSessionAsync(string sessionToken);
    Task InvalidateUserSessionsAsync(long telegramUserId);
    Task CleanupExpiredSessionsAsync();
    Task<T?> GetSessionDataAsync<T>(string sessionToken) where T : class;
    Task UpdateSessionDataAsync(string sessionToken, object data);
}