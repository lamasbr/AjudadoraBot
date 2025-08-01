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

// Database configuration
builder.Services.AddDbContext<AjudadoraBotDbContext>(options =>
{
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection"));
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

// Health checks
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AjudadoraBotDbContext>();

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

// Database migration and seeding
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<AjudadoraBotDbContext>();
    
    try
    {
        await context.Database.EnsureCreatedAsync();
        
        // Run migrations if needed
        if (context.Database.GetPendingMigrations().Any())
        {
            await context.Database.MigrateAsync();
        }
    }
    catch (Exception ex)
    {
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "An error occurred while migrating the database");
    }
}

app.Run();