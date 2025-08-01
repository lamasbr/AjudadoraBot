using System.ComponentModel.DataAnnotations;

namespace AjudadoraBot.Core.DTOs;

// Response Models
public record BotInfoResponse
{
    public long Id { get; init; }
    public string Username { get; init; } = string.Empty;
    public string FirstName { get; init; } = string.Empty;
    public bool IsActive { get; init; }
    public string Mode { get; init; } = string.Empty; // "Polling" or "Webhook"
    public string? WebhookUrl { get; init; }
    public DateTime LastActivity { get; init; }
    public int TotalUsers { get; init; }
    public int ActiveUsers { get; init; }
}

public record OperationResponse
{
    public bool Success { get; init; }
    public string Message { get; init; } = string.Empty;
    public DateTime Timestamp { get; init; } = DateTime.UtcNow;
    public object? Data { get; init; }
}

public record MessageResponse
{
    public int MessageId { get; init; }
    public long ChatId { get; init; }
    public string Text { get; init; } = string.Empty;
    public DateTime SentAt { get; init; }
    public bool Success { get; init; }
}

public record ErrorResponse
{
    public string Error { get; init; } = string.Empty;
    public string? Details { get; init; }
    public DateTime Timestamp { get; init; } = DateTime.UtcNow;
    public string? TraceId { get; init; }

    public ErrorResponse(string error, string? details = null, string? traceId = null)
    {
        Error = error;
        Details = details;
        TraceId = traceId;
    }
}

public record HealthResponse
{
    public string Status { get; init; } = string.Empty;
    public DateTime Timestamp { get; init; }
    public string Service { get; init; } = string.Empty;
    public Dictionary<string, object>? AdditionalInfo { get; init; }
}

public record PaginatedResponse<T>
{
    public IEnumerable<T> Data { get; init; } = Enumerable.Empty<T>();
    public int PageNumber { get; init; }
    public int PageSize { get; init; }
    public int TotalPages { get; init; }
    public int TotalCount { get; init; }
    public bool HasNextPage { get; init; }
    public bool HasPreviousPage { get; init; }
}

// Request Models
public record SetWebhookRequest
{
    [Required]
    [Url]
    public string Url { get; init; } = string.Empty;
    
    public string? SecretToken { get; init; }
}

public record SendMessageRequest
{
    [Required]
    public long ChatId { get; init; }
    
    [Required]
    [StringLength(4096, MinimumLength = 1)]
    public string Text { get; init; } = string.Empty;
    
    public string ParseMode { get; init; } = "HTML";
    
    public bool DisableWebPagePreview { get; init; } = false;
    
    public bool DisableNotification { get; init; } = false;
    
    public int? ReplyToMessageId { get; init; }
}