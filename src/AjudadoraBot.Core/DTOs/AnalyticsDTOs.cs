using AjudadoraBot.Core.Enums;

namespace AjudadoraBot.Core.DTOs;

public record BotStatisticsResponse
{
    public StatisticsPeriod Period { get; init; }
    public DateTime StartDate { get; init; }
    public DateTime EndDate { get; init; }
    public int TotalUsers { get; init; }
    public int NewUsers { get; init; }
    public int ActiveUsers { get; init; }
    public int TotalMessages { get; init; }
    public int TotalCommands { get; init; }
    public int BlockedUsers { get; init; }
    public double AverageResponseTime { get; init; }
    public int SuccessfulInteractions { get; init; }
    public int FailedInteractions { get; init; }
    public double SuccessRate { get; init; }
}

public record TopCommandsResponse
{
    public StatisticsPeriod Period { get; init; }
    public IEnumerable<CommandUsageItem> Commands { get; init; } = Enumerable.Empty<CommandUsageItem>();
}

public record CommandUsageItem
{
    public string Command { get; init; } = string.Empty;
    public int UsageCount { get; init; }
    public int UniqueUsers { get; init; }
    public double AverageResponseTime { get; init; }
    public double SuccessRate { get; init; }
}

public record UserActivityResponse
{
    public StatisticsPeriod Period { get; init; }
    public ActivityGranularity Granularity { get; init; }
    public IEnumerable<ActivityDataPoint> ActivityData { get; init; } = Enumerable.Empty<ActivityDataPoint>();
    public int PeakHour { get; init; }
    public string PeakDay { get; init; } = string.Empty;
}

public record ActivityDataPoint
{
    public DateTime Timestamp { get; init; }
    public int MessageCount { get; init; }
    public int ActiveUsers { get; init; }
    public int CommandCount { get; init; }
}

public record ErrorStatisticsResponse
{
    public StatisticsPeriod Period { get; init; }
    public int TotalErrors { get; init; }
    public double ErrorRate { get; init; }
    public IEnumerable<ErrorTypeCount> ErrorsByType { get; init; } = Enumerable.Empty<ErrorTypeCount>();
    public IEnumerable<RecentErrorItem> RecentErrors { get; init; } = Enumerable.Empty<RecentErrorItem>();
}

public record ErrorTypeCount
{
    public string ErrorType { get; init; } = string.Empty;
    public int Count { get; init; }
    public double Percentage { get; init; }
}

public record RecentErrorItem
{
    public DateTime Timestamp { get; init; }
    public string ErrorType { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
    public long? UserId { get; init; }
    public string? Command { get; init; }
}