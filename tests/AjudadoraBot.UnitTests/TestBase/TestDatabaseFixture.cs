using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using AjudadoraBot.Infrastructure.Data;

namespace AjudadoraBot.UnitTests.TestBase;

public class TestDatabaseFixture : IDisposable
{
    public AjudadoraBotDbContext Context { get; private set; }
    public IServiceProvider ServiceProvider { get; private set; }

    public TestDatabaseFixture()
    {
        var services = new ServiceCollection();
        
        // Configure in-memory database with unique name per test run
        var databaseName = $"TestDb_{Guid.NewGuid()}";
        services.AddDbContext<AjudadoraBotDbContext>(options =>
            options.UseInMemoryDatabase(databaseName)
                   .EnableSensitiveDataLogging()
                   .EnableDetailedErrors());

        ServiceProvider = services.BuildServiceProvider();
        Context = ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        
        // Ensure database is created
        Context.Database.EnsureCreated();
    }

    public AjudadoraBotDbContext CreateNewContext()
    {
        return ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
    }

    public async Task<AjudadoraBotDbContext> CreateNewContextAsync()
    {
        var context = ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
        await context.Database.EnsureCreatedAsync();
        return context;
    }

    public void Dispose()
    {
        Context?.Dispose();
        if (ServiceProvider is IDisposable disposable)
            disposable.Dispose();
    }
}