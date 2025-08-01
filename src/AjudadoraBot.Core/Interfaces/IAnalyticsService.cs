using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Enums;

namespace AjudadoraBot.Core.Interfaces;

public interface IAnalyticsService
{
    Task<BotStatisticsResponse> GetStatisticsAsync(StatisticsPeriod period, DateTime? startDate = null, DateTime? endDate = null);
    Task<TopCommandsResponse> GetTopCommandsAsync(StatisticsPeriod period, int limit = 10);
    Task<UserActivityResponse> GetUserActivityAsync(StatisticsPeriod period, ActivityGranularity granularity = ActivityGranularity.Daily);
    Task<ErrorStatisticsResponse> GetErrorStatisticsAsync(StatisticsPeriod period, int limit = 10);
    Task RecordInteractionAsync(Guid userId, long telegramUserId, long chatId, InteractionType type, string? command = null, bool isSuccessful = true, long? processingTimeMs = null);
    Task RecordErrorAsync(ErrorType errorType, string message, Guid? userId = null, long? telegramUserId = null, string? stackTrace = null, ErrorSeverity severity = ErrorSeverity.Error);
}