using System.ComponentModel.DataAnnotations;

namespace AjudadoraBot.Core.DTOs;

public record TelegramWebAppAuthRequest
{
    [Required]
    public string InitData { get; init; } = string.Empty;
    
    [Required]
    public string Hash { get; init; } = string.Empty;
}

public record RefreshTokenRequest
{
    [Required]
    public string SessionToken { get; init; } = string.Empty;
}

public record LogoutRequest
{
    [Required]
    public string SessionToken { get; init; } = string.Empty;
}

public record AuthResponse
{
    public string AccessToken { get; init; } = string.Empty;
    public string TokenType { get; init; } = string.Empty;
    public int ExpiresIn { get; init; }
    public UserResponse User { get; init; } = new();
}

public record MiniAppUserResponse
{
    public Guid Id { get; init; }
    public long TelegramId { get; init; }
    public string? Username { get; init; }
    public string? FirstName { get; init; }
    public string? LastName { get; init; }
    public string? LanguageCode { get; init; }
    public bool HasActiveSession { get; init; }
    public DateTime LastSeen { get; init; }
    public int InteractionCount { get; init; }
    public IEnumerable<string> Permissions { get; init; } = Enumerable.Empty<string>();
}