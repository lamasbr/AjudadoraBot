using System.ComponentModel.DataAnnotations;

namespace AjudadoraBot.Core.Configuration;

public class BackgroundServicesOptions
{
    public const string SectionName = "BackgroundServices";

    [Range(1, 1440)] // 1 minute to 1 day
    public int SessionCleanupIntervalMinutes { get; set; } = 60;

    [Range(1, 60)] // 1 minute to 1 hour
    public int AnalyticsFlushIntervalMinutes { get; set; } = 5;

    [Range(1, 168)] // 1 hour to 1 week
    public int ErrorLogCleanupIntervalHours { get; set; } = 24;

    public TimeSpan SessionCleanupInterval => TimeSpan.FromMinutes(SessionCleanupIntervalMinutes);
    public TimeSpan AnalyticsFlushInterval => TimeSpan.FromMinutes(AnalyticsFlushIntervalMinutes);
    public TimeSpan ErrorLogCleanupInterval => TimeSpan.FromHours(ErrorLogCleanupIntervalHours);
}