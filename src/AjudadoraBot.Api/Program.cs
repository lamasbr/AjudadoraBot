using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using AjudadoraBot.Infrastructure.Data;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Infrastructure.Repositories;
using AjudadoraBot.Core.Configuration;
using System.Text.Json.Serialization;
using Microsoft.Extensions.FileProviders;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    });

// Configure options
builder.Services.Configure<TelegramBotOptions>(
    builder.Configuration.GetSection(TelegramBotOptions.SectionName));
builder.Services.Configure<MiniAppOptions>(
    builder.Configuration.GetSection(MiniAppOptions.SectionName));
builder.Services.Configure<AnalyticsOptions>(
    builder.Configuration.GetSection(AnalyticsOptions.SectionName));
builder.Services.Configure<BackgroundServicesOptions>(
    builder.Configuration.GetSection(BackgroundServicesOptions.SectionName));

// Database configuration with environment variable support
builder.Services.AddDbContext<AjudadoraBotDbContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    
    // Allow override via environment variable for Azure App Service flexibility
    var envConnectionString = Environment.GetEnvironmentVariable("DATABASE_CONNECTION_STRING");
    if (!string.IsNullOrEmpty(envConnectionString))
    {
        connectionString = envConnectionString;
    }
    
    // For Azure App Service, ensure we use the correct writable directory
    if (connectionString?.Contains("/app/data/") == true && Directory.Exists("/home/data"))
    {
        connectionString = connectionString.Replace("/app/data/", "/home/data/");
    }

    options.UseSqlite(connectionString);
    options.EnableSensitiveDataLogging(builder.Environment.IsDevelopment());
    options.EnableDetailedErrors(builder.Environment.IsDevelopment());
});

// Repository pattern
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
builder.Services.AddScoped(typeof(IRepository<>), typeof(Repository<>));

// Services - These would be implemented in the Infrastructure layer
// builder.Services.AddScoped<IBotService, BotService>();
// builder.Services.AddScoped<IWebhookService, WebhookService>();
// builder.Services.AddScoped<IUserService, UserService>();
// builder.Services.AddScoped<IAnalyticsService, AnalyticsService>();
// builder.Services.AddScoped<IMessageHandler, MessageHandler>();
// builder.Services.AddScoped<ICommandProcessor, CommandProcessor>();
// builder.Services.AddScoped<ISessionService, SessionService>();
// builder.Services.AddScoped<IConfigurationService, ConfigurationService>();

// Telegram Bot
// builder.Services.AddSingleton<ITelegramBotClient>(provider =>
// {
//     var options = provider.GetRequiredService<IOptions<TelegramBotOptions>>().Value;
//     return new TelegramBotClient(options.Token);
// });

// JWT Authentication
var miniAppOptions = builder.Configuration.GetSection(MiniAppOptions.SectionName).Get<MiniAppOptions>();
if (miniAppOptions != null)
{
    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = miniAppOptions.JwtIssuer,
                ValidAudience = miniAppOptions.JwtAudience,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(miniAppOptions.JwtSecret))
            };
        });
}

builder.Services.AddAuthorization();

// Rate Limiting
builder.Services.AddRateLimiter(options =>
{
    options.AddPolicy("ApiPolicy", context =>
    {
        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.Id ?? "anonymous",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = builder.Configuration.GetValue<int>("RateLimiting:PermitLimit", 100),
                Window = TimeSpan.FromMinutes(builder.Configuration.GetValue<int>("RateLimiting:WindowMinutes", 1)),
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = builder.Configuration.GetValue<int>("RateLimiting:QueueLimit", 10)
            });
    });
});

// CORS
if (miniAppOptions?.AllowedOrigins.Any() == true)
{
    builder.Services.AddCors(options =>
    {
        options.AddDefaultPolicy(policy =>
        {
            policy.WithOrigins(miniAppOptions.AllowedOrigins.ToArray())
                  .AllowAnyMethod()
                  .AllowAnyHeader()
                  .AllowCredentials();
        });
    });
}

// Health checks with enhanced error reporting
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AjudadoraBotDbContext>(name: "AjudadoraBotDbContext", tags: new[] { "database", "sqlite" })
    .AddCheck("database_write", () =>
    {
        try
        {
            var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
            if (string.IsNullOrEmpty(connectionString))
                return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Unhealthy("Connection string not configured");

            // Extract file path from connection string
            var match = System.Text.RegularExpressions.Regex.Match(connectionString, @"Data Source=([^;]+)");
            if (!match.Success)
                return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Unhealthy("Invalid connection string format");

            var dbPath = match.Groups[1].Value;
            var dbDirectory = Path.GetDirectoryName(dbPath);
            
            if (!Directory.Exists(dbDirectory))
            {
                Directory.CreateDirectory(dbDirectory);
            }

            // Test write permissions
            var testFile = Path.Combine(dbDirectory, "write_test.tmp");
            File.WriteAllText(testFile, "test");
            File.Delete(testFile);

            return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy($"Database directory writable: {dbDirectory}");
        }
        catch (Exception ex)
        {
            return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Unhealthy($"Database write check failed: {ex.Message}");
        }
    }, tags: new[] { "database", "filesystem" });

// Swagger/OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    var swaggerTitle = builder.Configuration.GetValue<string>("Swagger:Title", "AjudadoraBot API");
    var swaggerVersion = builder.Configuration.GetValue<string>("Swagger:Version", "v1");
    var swaggerDescription = builder.Configuration.GetValue<string>("Swagger:Description", "REST API for managing a Telegram bot");

    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = swaggerTitle,
        Version = swaggerVersion,
        Description = swaggerDescription,
        Contact = new OpenApiContact
        {
            Name = builder.Configuration.GetValue<string>("Swagger:ContactName", "API Support"),
            Email = builder.Configuration.GetValue<string>("Swagger:ContactEmail", "support@example.com")
        }
    });

    // JWT Bearer token authentication
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Example: \"Bearer {token}\"",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });

    // Include XML comments if available
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }
});

// Logging configuration (Datadog is configured via environment variables in container)
builder.Services.AddLogging(logging =>
{
    logging.AddConsole();
    if (builder.Environment.IsDevelopment())
    {
        logging.AddDebug();
    }
    // Datadog automatic instrumentation handles APM and logging via environment variables
});

var app = builder.Build();

// Configure the HTTP request pipeline
// Static files configuration for combined frontend+backend deployment
var staticFilesPath = Path.Combine(app.Environment.ContentRootPath, "wwwroot");
if (Directory.Exists(staticFilesPath))
{
    app.UseDefaultFiles(); // Serve index.html as default
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(staticFilesPath),
        OnPrepareResponse = ctx =>
        {
            // Cache static assets for better performance on F1 tier
            if (ctx.File.Name.EndsWith(".js") || ctx.File.Name.EndsWith(".css") || 
                ctx.File.Name.EndsWith(".png") || ctx.File.Name.EndsWith(".jpg") ||
                ctx.File.Name.EndsWith(".ico") || ctx.File.Name.EndsWith(".svg"))
            {
                ctx.Context.Response.Headers.Append("Cache-Control", "public,max-age=31536000"); // 1 year
            }
            else if (ctx.File.Name.EndsWith(".html"))
            {
                ctx.Context.Response.Headers.Append("Cache-Control", "no-cache, no-store, must-revalidate");
            }
        }
    });
}

// Swagger/API documentation (always available for debugging)
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "AjudadoraBot API v1");
    c.RoutePrefix = "api-docs"; // Move to /api-docs to avoid conflict with frontend
});

app.UseHttpsRedirection();

// Rate limiting
app.UseRateLimiter();

// CORS
if (miniAppOptions?.AllowedOrigins.Any() == true)
{
    app.UseCors();
}

app.UseAuthentication();
app.UseAuthorization();

// Map API controllers with rate limiting
app.MapControllers()
   .RequireRateLimiting("ApiPolicy");

// Health checks
app.MapHealthChecks("/health");

// Fallback routing for SPA (Single Page Application)
// This ensures that client-side routing works properly
if (Directory.Exists(staticFilesPath))
{
    app.MapFallbackToFile("index.html");
}

// Database migration and seeding with enhanced error handling
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    
    try
    {
        var connectionString = app.Configuration.GetConnectionString("DefaultConnection");
        logger.LogInformation("Initializing database with connection string: {ConnectionString}", connectionString);
        
        // Ensure database directory exists
        if (connectionString?.Contains("Data Source=") == true)
        {
            var match = System.Text.RegularExpressions.Regex.Match(connectionString, @"Data Source=([^;]+)");
            if (match.Success)
            {
                var dbPath = match.Groups[1].Value;
                var dbDirectory = Path.GetDirectoryName(dbPath);
                if (!string.IsNullOrEmpty(dbDirectory) && !Directory.Exists(dbDirectory))
                {
                    logger.LogInformation("Creating database directory: {DatabaseDirectory}", dbDirectory);
                    Directory.CreateDirectory(dbDirectory);
                }
            }
        }

        // Test database connection
        var canConnect = await context.Database.CanConnectAsync();
        logger.LogInformation("Database connection test result: {CanConnect}", canConnect);

        if (!canConnect)
        {
            logger.LogInformation("Creating database...");
            await context.Database.EnsureCreatedAsync();
        }
        
        // Run migrations if needed
        var pendingMigrations = await context.Database.GetPendingMigrationsAsync();
        if (pendingMigrations.Any())
        {
            logger.LogInformation("Applying {MigrationCount} pending migrations: {Migrations}", 
                pendingMigrations.Count(), string.Join(", ", pendingMigrations));
            await context.Database.MigrateAsync();
        }
        
        logger.LogInformation("Database initialization completed successfully");
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Database initialization failed: {ErrorMessage}. Connection string: {ConnectionString}", 
            ex.Message, app.Configuration.GetConnectionString("DefaultConnection"));
        
        // Don't throw - let the app start but health checks will fail
        logger.LogWarning("Application will start but database health checks will fail until database issues are resolved");
    }
}

app.Run();