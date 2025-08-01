using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace AjudadoraBot.Core.Models;

[Table("Users")]
public class User
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("telegram_id")]
    public long TelegramId { get; set; }

    [MaxLength(100)]
    [Column("username")]
    public string? Username { get; set; }

    [MaxLength(100)]
    [Column("first_name")]
    public string? FirstName { get; set; }

    [MaxLength(100)]
    [Column("last_name")]
    public string? LastName { get; set; }

    [MaxLength(10)]
    [Column("language_code")]
    public string? LanguageCode { get; set; }

    [Column("is_bot")]
    public bool IsBot { get; set; }

    [Column("is_blocked")]
    public bool IsBlocked { get; set; }

    [MaxLength(500)]
    [Column("block_reason")]
    public string? BlockReason { get; set; }

    [Column("first_seen")]
    public DateTime FirstSeen { get; set; } = DateTime.UtcNow;

    [Column("last_seen")]
    public DateTime LastSeen { get; set; } = DateTime.UtcNow;

    [Column("interaction_count")]
    public int InteractionCount { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public virtual ICollection<Interaction> Interactions { get; set; } = new List<Interaction>();
    public virtual ICollection<UserSession> Sessions { get; set; } = new List<UserSession>();
}