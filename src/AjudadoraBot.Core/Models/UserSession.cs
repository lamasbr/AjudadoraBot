using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AjudadoraBot.Core.Models;

[Table("UserSessions")]
public class UserSession
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
    [MaxLength(500)]
    [Column("session_token")]
    public string SessionToken { get; set; } = string.Empty;

    [Column("session_data")]
    public string? SessionData { get; set; }

    [Column("expires_at")]
    public DateTime ExpiresAt { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("last_accessed")]
    public DateTime LastAccessed { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey(nameof(UserId))]
    public virtual User User { get; set; } = null!;

    public bool IsExpired => DateTime.UtcNow > ExpiresAt;
}