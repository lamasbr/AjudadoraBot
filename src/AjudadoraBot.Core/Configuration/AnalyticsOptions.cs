using System.ComponentModel.DataAnnotations;

namespace AjudadoraBot.Core.Configuration;

public class AnalyticsOptions
{
    public const string SectionName = "Analytics";

    public bool Enabled { get; set; } = true;

    [Range(1, 365)]
    public int RetentionDays { get; set; } = 90;

    [Range(10, 1000)]
    public int BatchSize { get; set; } = 100;

    [Range(1, 60)]
    public int FlushIntervalMinutes { get; set; } = 5;

    public TimeSpan FlushInterval => TimeSpan.FromMinutes(FlushIntervalMinutes);
    public TimeSpan RetentionPeriod => TimeSpan.FromDays(RetentionDays);
}