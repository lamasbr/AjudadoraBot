using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using AjudadoraBot.Infrastructure.Data;
using AjudadoraBot.Api;
using System.Data.Common;
using Microsoft.Data.Sqlite;

namespace AjudadoraBot.IntegrationTests.TestBase;

public class IntegrationTestFixture : WebApplicationFactory<Program>, IAsyncLifetime
{
    private DbConnection? _connection;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Remove the existing DbContext registration
            var dbContextDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AjudadoraBotDbContext>));
            
            if (dbContextDescriptor != null)
                services.Remove(dbContextDescriptor);

            // Create and open a connection for in-memory SQLite database
            _connection = new SqliteConnection("DataSource=:memory:");
            _connection.Open();

            // Add DbContext using the in-memory database
            services.AddDbContext<AjudadoraBotDbContext>(options =>
            {
                options.UseSqlite(_connection);
                options.EnableSensitiveDataLogging();
                options.EnableDetailedErrors();
            });

            // Build the service provider
            var serviceProvider = services.BuildServiceProvider();

            // Create the database and apply migrations
            using var scope = serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
            context.Database.EnsureCreated();
        });

        builder.UseEnvironment("Testing");
        
        // Suppress logging during tests
        builder.ConfigureLogging(logging =>
        {
            logging.ClearProviders();
            logging.AddFilter("Microsoft", LogLevel.Warning);
            logging.AddFilter("System", LogLevel.Warning);
        });
    }

    public async Task InitializeAsync()
    {
        // Additional initialization if needed
        await Task.CompletedTask;
    }

    public new async Task DisposeAsync()
    {
        _connection?.Dispose();
        await base.DisposeAsync();
    }

    public async Task ResetDatabaseAsync()
    {
        using var scope = Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        // Clear all data
        context.ErrorLogs.RemoveRange(context.ErrorLogs);
        context.UserSessions.RemoveRange(context.UserSessions);
        context.Interactions.RemoveRange(context.Interactions);
        context.Users.RemoveRange(context.Users);
        context.BotConfigurations.RemoveRange(context.BotConfigurations);
        
        await context.SaveChangesAsync();
        
        // Re-seed initial data if needed
        await context.Database.EnsureCreatedAsync();
    }
}