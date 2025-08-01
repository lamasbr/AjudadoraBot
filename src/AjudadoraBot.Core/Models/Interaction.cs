using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using AjudadoraBot.Core.Enums;

namespace AjudadoraBot.Core.Models;

[Table("Interactions")]
public class Interaction
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("user_id")]
    public Guid UserId { get; set; }

    [Required]
    [Column("telegram_user_id")]
    public long TelegramUserId { get; set; }

    [Required]
    [Column("chat_id")]
    public long ChatId { get; set; }

    [Column("message_id")]
    public int? MessageId { get; set; }

    [Required]
    [Column("interaction_type")]
    public InteractionType Type { get; set; }

    [MaxLength(100)]
    [Column("command")]
    public string? Command { get; set; }

    [Column("message_text")]
    public string? MessageText { get; set; }

    [Column("callback_data")]
    public string? CallbackData { get; set; }

    [Column("response_text")]
    public string? ResponseText { get; set; }

    [Column("is_successful")]
    public bool IsSuccessful { get; set; } = true;

    [Column("error_message")]
    public string? ErrorMessage { get; set; }

    [Column("processing_time_ms")]
    public long? ProcessingTimeMs { get; set; }

    [Column("timestamp")]
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey(nameof(UserId))]
    public virtual User User { get; set; } = null!;

    public TimeSpan? ProcessingTime => ProcessingTimeMs.HasValue 
        ? TimeSpan.FromMilliseconds(ProcessingTimeMs.Value) 
        : null;
}