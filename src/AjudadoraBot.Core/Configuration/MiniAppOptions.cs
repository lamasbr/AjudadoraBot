using System.ComponentModel.DataAnnotations;

namespace AjudadoraBot.Core.Configuration;

public class MiniAppOptions
{
    public const string SectionName = "MiniApp";

    [Required]
    [MinLength(32)]
    public string JwtSecret { get; set; } = string.Empty;

    [Required]
    public string JwtIssuer { get; set; } = string.Empty;

    [Required]
    public string JwtAudience { get; set; } = string.Empty;

    [Range(1, 10080)] // 1 minute to 1 week
    public int JwtExpirationMinutes { get; set; } = 1440;

    public List<string> AllowedOrigins { get; set; } = new();

    public TimeSpan JwtExpiration => TimeSpan.FromMinutes(JwtExpirationMinutes);
}