using AjudadoraBot.Core.Enums;

namespace AjudadoraBot.Core.Interfaces;

public interface IConfigurationService
{
    Task<T?> GetValueAsync<T>(string key);
    Task<string?> GetStringAsync(string key, string? defaultValue = null);
    Task<int> GetIntAsync(string key, int defaultValue = 0);
    Task<bool> GetBoolAsync(string key, bool defaultValue = false);
    Task SetValueAsync<T>(string key, T value, ConfigurationType type = ConfigurationType.String, bool isSensitive = false);
    Task<bool> ExistsAsync(string key);
    Task DeleteAsync(string key);
    Task<IDictionary<string, object?>> GetAllAsync(bool includeSensitive = false);
}

public static class ConfigurationKeys
{
    public const string BotToken = "BotToken";
    public const string WebhookUrl = "WebhookUrl";
    public const string WebhookSecretToken = "WebhookSecretToken";
    public const string BotMode = "BotMode";
    public const string MaxRetryAttempts = "MaxRetryAttempts";
    public const string SessionTimeout = "SessionTimeout";
    public const string EnableAnalytics = "EnableAnalytics";
}