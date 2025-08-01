using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Models;

namespace AjudadoraBot.Core.Interfaces;

public interface IUserService
{
    Task<PaginatedResponse<UserResponse>> GetUsersAsync(int pageNumber, int pageSize, string? search = null);
    Task<UserResponse?> GetUserByTelegramIdAsync(long telegramId);
    Task<User> CreateOrUpdateUserAsync(Telegram.Bot.Types.User telegramUser);
    Task<OperationResponse> UpdateBlockStatusAsync(long telegramId, bool isBlocked, string? reason = null);
    Task<PaginatedResponse<InteractionResponse>> GetUserInteractionsAsync(long telegramId, int pageNumber, int pageSize);
    Task UpdateLastSeenAsync(long telegramId);
    Task<bool> IsUserBlockedAsync(long telegramId);
}