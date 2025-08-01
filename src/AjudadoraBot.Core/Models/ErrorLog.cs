using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using AjudadoraBot.Core.Enums;

namespace AjudadoraBot.Core.Models;

[Table("ErrorLogs")]
public class ErrorLog
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Column("user_id")]
    public Guid? UserId { get; set; }

    [Column("telegram_user_id")]
    public long? TelegramUserId { get; set; }

    [Column("interaction_id")]
    public Guid? InteractionId { get; set; }

    [Required]
    [Column("error_type")]
    public ErrorType ErrorType { get; set; }

    [Required]
    [MaxLength(500)]
    [Column("message")]
    public string Message { get; set; } = string.Empty;

    [Column("stack_trace")]
    public string? StackTrace { get; set; }

    [Column("additional_data")]
    public string? AdditionalData { get; set; }

    [MaxLength(100)]
    [Column("source")]
    public string? Source { get; set; }

    [Column("severity")]
    public ErrorSeverity Severity { get; set; } = ErrorSeverity.Error;

    [Column("timestamp")]
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

    [Column("is_resolved")]
    public bool IsResolved { get; set; }

    [Column("resolution_notes")]
    public string? ResolutionNotes { get; set; }

    // Navigation properties
    [ForeignKey(nameof(UserId))]
    public virtual User? User { get; set; }

    [ForeignKey(nameof(InteractionId))]
    public virtual Interaction? Interaction { get; set; }
}