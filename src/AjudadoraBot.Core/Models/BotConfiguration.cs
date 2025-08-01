using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using AjudadoraBot.Core.Enums;

namespace AjudadoraBot.Core.Models;

[Table("BotConfigurations")]
public class BotConfiguration
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    [Column("key")]
    public string Key { get; set; } = string.Empty;

    [Column("value")]
    public string? Value { get; set; }

    [Column("description")]
    public string? Description { get; set; }

    [Column("is_sensitive")]
    public bool IsSensitive { get; set; }

    [Column("configuration_type")]
    public ConfigurationType Type { get; set; } = ConfigurationType.String;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}