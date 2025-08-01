using System.ComponentModel.DataAnnotations;

namespace AjudadoraBot.Core.Configuration;

public class TelegramBotOptions
{
    public const string SectionName = "TelegramBot";

    [Required]
    public string Token { get; set; } = string.Empty;

    public string WebhookUrl { get; set; } = string.Empty;

    public string SecretToken { get; set; } = string.Empty;

    [Required]
    public string Mode { get; set; } = "Polling";

    [Range(1, 10)]
    public int MaxRetryAttempts { get; set; } = 3;

    [Range(1, 300)]
    public int TimeoutSeconds { get; set; } = 30;

    [Range(100, 10000)]
    public int PollingIntervalMs { get; set; } = 1000;

    public bool IsPollingMode => Mode.Equals("Polling", StringComparison.OrdinalIgnoreCase);
    public bool IsWebhookMode => Mode.Equals("Webhook", StringComparison.OrdinalIgnoreCase);
}