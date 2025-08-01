using System.ComponentModel.DataAnnotations;

namespace AjudadoraBot.Core.DTOs;

public record UserResponse
{
    public Guid Id { get; init; }
    public long TelegramId { get; init; }
    public string? Username { get; init; }
    public string? FirstName { get; init; }
    public string? LastName { get; init; }
    public string? LanguageCode { get; init; }
    public bool IsBot { get; init; }
    public bool IsBlocked { get; init; }
    public string? BlockReason { get; init; }
    public DateTime FirstSeen { get; init; }
    public DateTime LastSeen { get; init; }
    public int InteractionCount { get; init; }
    public DateTime? LastInteraction { get; init; }
}

public record InteractionResponse
{
    public Guid Id { get; init; }
    public string Type { get; init; } = string.Empty; // "Message", "Command", "CallbackQuery", etc.
    public string? Command { get; init; }
    public string? MessageText { get; init; }
    public DateTime Timestamp { get; init; }
    public bool IsSuccessful { get; init; }
    public string? ErrorMessage { get; init; }
    public string? ResponseText { get; init; }
    public TimeSpan? ProcessingTime { get; init; }
}

public record UpdateBlockStatusRequest
{
    [Required]
    public bool IsBlocked { get; init; }
    
    [StringLength(500)]
    public string? Reason { get; init; }
}