using Microsoft.EntityFrameworkCore;
using AjudadoraBot.Core.Models;

namespace AjudadoraBot.Infrastructure.Data;

public class AjudadoraBotDbContext : DbContext
{
    public AjudadoraBotDbContext(DbContextOptions<AjudadoraBotDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<Interaction> Interactions { get; set; }
    public DbSet<BotConfiguration> BotConfigurations { get; set; }
    public DbSet<UserSession> UserSessions { get; set; }
    public DbSet<ErrorLog> ErrorLogs { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User entity configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(e => e.TelegramId)
                .IsUnique()
                .HasDatabaseName("IX_Users_TelegramId");

            entity.HasIndex(e => e.Username)
                .HasDatabaseName("IX_Users_Username");

            entity.HasIndex(e => new { e.IsBlocked, e.LastSeen })
                .HasDatabaseName("IX_Users_IsBlocked_LastSeen");

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("datetime('now')");

            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("datetime('now')");

            entity.Property(e => e.FirstSeen)
                .HasDefaultValueSql("datetime('now')");

            entity.Property(e => e.LastSeen)
                .HasDefaultValueSql("datetime('now')");
        });

        // Interaction entity configuration
        modelBuilder.Entity<Interaction>(entity =>
        {
            entity.HasIndex(e => e.UserId)
                .HasDatabaseName("IX_Interactions_UserId");

            entity.HasIndex(e => e.TelegramUserId)
                .HasDatabaseName("IX_Interactions_TelegramUserId");

            entity.HasIndex(e => e.Timestamp)
                .HasDatabaseName("IX_Interactions_Timestamp");

            entity.HasIndex(e => new { e.Type, e.Timestamp })
                .HasDatabaseName("IX_Interactions_Type_Timestamp");

            entity.HasIndex(e => new { e.Command, e.Timestamp })
                .HasDatabaseName("IX_Interactions_Command_Timestamp");

            entity.HasIndex(e => new { e.IsSuccessful, e.Timestamp })
                .HasDatabaseName("IX_Interactions_IsSuccessful_Timestamp");

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("datetime('now')");

            entity.Property(e => e.Timestamp)
                .HasDefaultValueSql("datetime('now')");

            entity.HasOne(d => d.User)
                .WithMany(p => p.Interactions)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // BotConfiguration entity configuration
        modelBuilder.Entity<BotConfiguration>(entity =>
        {
            entity.HasIndex(e => e.Key)
                .IsUnique()
                .HasDatabaseName("IX_BotConfigurations_Key");

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("datetime('now')");

            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("datetime('now')");
        });

        // UserSession entity configuration
        modelBuilder.Entity<UserSession>(entity =>
        {
            entity.HasIndex(e => e.SessionToken)
                .IsUnique()
                .HasDatabaseName("IX_UserSessions_SessionToken");

            entity.HasIndex(e => e.UserId)
                .HasDatabaseName("IX_UserSessions_UserId");

            entity.HasIndex(e => e.TelegramUserId)
                .HasDatabaseName("IX_UserSessions_TelegramUserId");

            entity.HasIndex(e => new { e.IsActive, e.ExpiresAt })
                .HasDatabaseName("IX_UserSessions_IsActive_ExpiresAt");

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("datetime('now')");

            entity.Property(e => e.LastAccessed)
                .HasDefaultValueSql("datetime('now')");

            entity.Property(e => e.ExpiresAt)
                .HasDefaultValueSql("datetime('now', '+24 hours')");

            entity.HasOne(d => d.User)
                .WithMany(p => p.Sessions)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // ErrorLog entity configuration
        modelBuilder.Entity<ErrorLog>(entity =>
        {
            entity.HasIndex(e => e.UserId)
                .HasDatabaseName("IX_ErrorLogs_UserId");

            entity.HasIndex(e => e.InteractionId)
                .HasDatabaseName("IX_ErrorLogs_InteractionId");

            entity.HasIndex(e => e.Timestamp)
                .HasDatabaseName("IX_ErrorLogs_Timestamp");

            entity.HasIndex(e => new { e.ErrorType, e.Timestamp })
                .HasDatabaseName("IX_ErrorLogs_ErrorType_Timestamp");

            entity.HasIndex(e => new { e.Severity, e.Timestamp })
                .HasDatabaseName("IX_ErrorLogs_Severity_Timestamp");

            entity.Property(e => e.Timestamp)
                .HasDefaultValueSql("datetime('now')");

            entity.HasOne(d => d.User)
                .WithMany()
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(d => d.Interaction)
                .WithMany()
                .HasForeignKey(d => d.InteractionId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Seed initial bot configurations
        SeedBotConfigurations(modelBuilder);
    }

    private static void SeedBotConfigurations(ModelBuilder modelBuilder)
    {
        var configurations = new[]
        {
            new BotConfiguration
            {
                Id = Guid.NewGuid(),
                Key = "BotToken",
                Description = "Telegram Bot API Token",
                IsSensitive = true,
                Type = Core.Enums.ConfigurationType.Encrypted
            },
            new BotConfiguration
            {
                Id = Guid.NewGuid(),
                Key = "WebhookUrl",
                Description = "Webhook URL for receiving updates",
                IsSensitive = false,
                Type = Core.Enums.ConfigurationType.String
            },
            new BotConfiguration
            {
                Id = Guid.NewGuid(),
                Key = "WebhookSecretToken",
                Description = "Secret token for webhook verification",
                IsSensitive = true,
                Type = Core.Enums.ConfigurationType.Encrypted
            },
            new BotConfiguration
            {
                Id = Guid.NewGuid(),
                Key = "BotMode",
                Value = "Polling",
                Description = "Bot operation mode (Polling or Webhook)",
                IsSensitive = false,
                Type = Core.Enums.ConfigurationType.String
            },
            new BotConfiguration
            {
                Id = Guid.NewGuid(),
                Key = "MaxRetryAttempts",
                Value = "3",
                Description = "Maximum retry attempts for failed operations",
                IsSensitive = false,
                Type = Core.Enums.ConfigurationType.Integer
            },
            new BotConfiguration
            {
                Id = Guid.NewGuid(),
                Key = "SessionTimeout",
                Value = "1440",
                Description = "Session timeout in minutes",
                IsSensitive = false,
                Type = Core.Enums.ConfigurationType.Integer
            },
            new BotConfiguration
            {
                Id = Guid.NewGuid(),
                Key = "EnableAnalytics",
                Value = "true",
                Description = "Enable analytics and statistics collection",
                IsSensitive = false,
                Type = Core.Enums.ConfigurationType.Boolean
            }
        };

        modelBuilder.Entity<BotConfiguration>().HasData(configurations);
    }
}