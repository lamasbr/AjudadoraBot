using AjudadoraBot.Core.Models;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Enums;
using AutoFixture;

namespace AjudadoraBot.UnitTests.TestBase;

public static class TestDataFactory
{
    private static readonly Fixture _fixture = new();

    static TestDataFactory()
    {
        // Configure AutoFixture customizations
        _fixture.Customize<User>(composer => composer
            .With(u => u.Id, () => Guid.NewGuid())
            .With(u => u.TelegramId, () => _fixture.Create<long>())
            .With(u => u.Username, () => $"user_{_fixture.Create<string>()[..8]}")
            .With(u => u.FirstName, () => _fixture.Create<string>()[..10])
            .With(u => u.LastName, () => _fixture.Create<string>()[..10])
            .With(u => u.LanguageCode, "en")
            .With(u => u.IsBot, false)
            .With(u => u.IsBlocked, false)
            .With(u => u.CreatedAt, DateTime.UtcNow)
            .With(u => u.UpdatedAt, DateTime.UtcNow)
            .With(u => u.FirstSeen, DateTime.UtcNow)
            .With(u => u.LastSeen, DateTime.UtcNow)
            .With(u => u.InteractionCount, () => _fixture.Create<int>() % 100)
            .Without(u => u.Interactions)
            .Without(u => u.Sessions));

        _fixture.Customize<Interaction>(composer => composer
            .With(i => i.Id, () => Guid.NewGuid())
            .With(i => i.UserId, () => Guid.NewGuid())
            .With(i => i.TelegramUserId, () => _fixture.Create<long>())
            .With(i => i.Type, InteractionType.Message)
            .With(i => i.MessageText, () => _fixture.Create<string>()[..100])
            .With(i => i.ResponseText, () => _fixture.Create<string>()[..200])
            .With(i => i.Command, () => "/start")
            .With(i => i.IsSuccessful, true)
            .With(i => i.ProcessingTimeMs, () => _fixture.Create<int>() % 1000)
            .With(i => i.Timestamp, DateTime.UtcNow)
            .With(i => i.CreatedAt, DateTime.UtcNow)
            .Without(i => i.User));

        _fixture.Customize<BotConfiguration>(composer => composer
            .With(bc => bc.Id, () => Guid.NewGuid())
            .With(bc => bc.Key, () => $"Config_{_fixture.Create<string>()[..8]}")
            .With(bc => bc.Value, () => _fixture.Create<string>()[..50])
            .With(bc => bc.Description, () => _fixture.Create<string>()[..100])
            .With(bc => bc.Type, ConfigurationType.String)
            .With(bc => bc.IsSensitive, false)
            .With(bc => bc.CreatedAt, DateTime.UtcNow)
            .With(bc => bc.UpdatedAt, DateTime.UtcNow));

        _fixture.Customize<UserSession>(composer => composer
            .With(us => us.Id, () => Guid.NewGuid())
            .With(us => us.UserId, () => Guid.NewGuid())
            .With(us => us.TelegramUserId, () => _fixture.Create<long>())
            .With(us => us.SessionToken, () => Guid.NewGuid().ToString())
            .With(us => us.IsActive, true)
            .With(us => us.ExpiresAt, DateTime.UtcNow.AddHours(24))
            .With(us => us.CreatedAt, DateTime.UtcNow)
            .With(us => us.LastAccessed, DateTime.UtcNow)
            .Without(us => us.User));

        _fixture.Customize<ErrorLog>(composer => composer
            .With(el => el.Id, () => Guid.NewGuid())
            .With(el => el.UserId, () => Guid.NewGuid())
            .With(el => el.InteractionId, () => Guid.NewGuid())
            .With(el => el.ErrorType, ErrorType.ValidationError)
            .With(el => el.Severity, ErrorSeverity.Warning)
            .With(el => el.Message, () => _fixture.Create<string>()[..200])
            .With(el => el.Details, () => _fixture.Create<string>()[..500])
            .With(el => el.Timestamp, DateTime.UtcNow)
            .Without(el => el.User)
            .Without(el => el.Interaction));
    }

    public static User CreateUser(Action<User>? customize = null)
    {
        var user = _fixture.Create<User>();
        customize?.Invoke(user);
        return user;
    }

    public static List<User> CreateUsers(int count, Action<User>? customize = null)
    {
        return Enumerable.Range(0, count)
                        .Select(_ => CreateUser(customize))
                        .ToList();
    }

    public static Interaction CreateInteraction(Action<Interaction>? customize = null)
    {
        var interaction = _fixture.Create<Interaction>();
        customize?.Invoke(interaction);
        return interaction;
    }

    public static List<Interaction> CreateInteractions(int count, Action<Interaction>? customize = null)
    {
        return Enumerable.Range(0, count)
                        .Select(_ => CreateInteraction(customize))
                        .ToList();
    }

    public static BotConfiguration CreateBotConfiguration(Action<BotConfiguration>? customize = null)
    {
        var config = _fixture.Create<BotConfiguration>();
        customize?.Invoke(config);
        return config;
    }

    public static UserSession CreateUserSession(Action<UserSession>? customize = null)
    {
        var session = _fixture.Create<UserSession>();
        customize?.Invoke(session);
        return session;
    }

    public static ErrorLog CreateErrorLog(Action<ErrorLog>? customize = null)
    {
        var errorLog = _fixture.Create<ErrorLog>();
        customize?.Invoke(errorLog);
        return errorLog;
    }

    // DTO Factories using actual DTOs from the project
    public static UserResponse CreateUserResponse(Action<UserResponse>? customize = null)
    {
        var userResponse = new UserResponse
        {
            Id = Guid.NewGuid(),
            TelegramId = _fixture.Create<long>(),
            Username = $"user_{_fixture.Create<string>()[..8]}",
            FirstName = _fixture.Create<string>()[..10],
            LastName = _fixture.Create<string>()[..10],
            LanguageCode = "en",
            IsBot = false,
            IsBlocked = false,
            InteractionCount = _fixture.Create<int>() % 100,
            FirstSeen = DateTime.UtcNow,
            LastSeen = DateTime.UtcNow,
            LastInteraction = DateTime.UtcNow.AddMinutes(-30)
        };

        customize?.Invoke(userResponse);
        return userResponse;
    }

    public static InteractionResponse CreateInteractionResponse(Action<InteractionResponse>? customize = null)
    {
        var interactionResponse = new InteractionResponse
        {
            Id = Guid.NewGuid(),
            Type = "Message",
            Command = "/start",
            MessageText = _fixture.Create<string>()[..100],
            Timestamp = DateTime.UtcNow,
            IsSuccessful = true,
            ResponseText = _fixture.Create<string>()[..200],
            ProcessingTime = TimeSpan.FromMilliseconds(_fixture.Create<int>() % 1000)
        };

        customize?.Invoke(interactionResponse);
        return interactionResponse;
    }

    public static UpdateBlockStatusRequest CreateUpdateBlockStatusRequest(Action<UpdateBlockStatusRequest>? customize = null)
    {
        var request = new UpdateBlockStatusRequest
        {
            IsBlocked = false,
            Reason = null
        };

        customize?.Invoke(request);
        return request;
    }

    public static BotStatisticsResponse CreateBotStatisticsResponse(Action<BotStatisticsResponse>? customize = null)
    {
        var statsResponse = new BotStatisticsResponse
        {
            Period = StatisticsPeriod.Today,
            StartDate = DateTime.UtcNow.Date,
            EndDate = DateTime.UtcNow,
            TotalUsers = _fixture.Create<int>() % 10000,
            NewUsers = _fixture.Create<int>() % 100,
            ActiveUsers = _fixture.Create<int>() % 1000,
            TotalMessages = _fixture.Create<int>() % 100000,
            TotalCommands = _fixture.Create<int>() % 10000,
            BlockedUsers = _fixture.Create<int>() % 100,
            AverageResponseTime = _fixture.Create<double>() % 1000,
            SuccessfulInteractions = _fixture.Create<int>() % 10000,
            FailedInteractions = _fixture.Create<int>() % 100,
            SuccessRate = 95.5
        };

        customize?.Invoke(statsResponse);
        return statsResponse;
    }

    public static TopCommandsResponse CreateTopCommandsResponse(int commandCount = 5, Action<TopCommandsResponse>? customize = null)
    {
        var response = new TopCommandsResponse
        {
            Period = StatisticsPeriod.Today,
            Commands = CreateCommandUsageItems(commandCount)
        };

        customize?.Invoke(response);
        return response;
    }

    public static List<CommandUsageItem> CreateCommandUsageItems(int count)
    {
        return Enumerable.Range(0, count)
                        .Select(i => new CommandUsageItem
                        {
                            Command = $"/command{i}",
                            UsageCount = _fixture.Create<int>() % 1000,
                            UniqueUsers = _fixture.Create<int>() % 100,
                            AverageResponseTime = _fixture.Create<double>() % 1000,
                            SuccessRate = _fixture.Create<double>() % 100
                        })
                        .ToList();
    }

    public static UserActivityResponse CreateUserActivityResponse(int dataPointCount = 24, Action<UserActivityResponse>? customize = null)
    {
        var response = new UserActivityResponse
        {
            Period = StatisticsPeriod.Today,
            Granularity = ActivityGranularity.Hourly,
            ActivityData = CreateActivityDataPoints(dataPointCount),
            PeakHour = 14,
            PeakDay = "Monday"
        };

        customize?.Invoke(response);
        return response;
    }

    public static List<ActivityDataPoint> CreateActivityDataPoints(int count)
    {
        return Enumerable.Range(0, count)
                        .Select(i => new ActivityDataPoint
                        {
                            Timestamp = DateTime.UtcNow.AddHours(-count + i),
                            MessageCount = _fixture.Create<int>() % 100,
                            ActiveUsers = _fixture.Create<int>() % 50,
                            CommandCount = _fixture.Create<int>() % 20
                        })
                        .ToList();
    }

    public static SendMessageRequest CreateSendMessageRequest(Action<SendMessageRequest>? customize = null)
    {
        var request = new SendMessageRequest
        {
            ChatId = _fixture.Create<long>(),
            Text = _fixture.Create<string>()[..100],
            ParseMode = "HTML",
            DisableWebPagePreview = false,
            DisableNotification = false
        };

        customize?.Invoke(request);
        return request;
    }

    public static SetWebhookRequest CreateSetWebhookRequest(Action<SetWebhookRequest>? customize = null)
    {
        var request = new SetWebhookRequest
        {
            Url = $"https://example.com/webhook/{Guid.NewGuid()}",
            SecretToken = Guid.NewGuid().ToString()
        };

        customize?.Invoke(request);
        return request;
    }

    // Helper methods for creating test scenarios
    public static (User user, List<Interaction> interactions) CreateUserWithInteractions(
        int interactionCount = 5,
        Action<User>? customizeUser = null,
        Action<Interaction>? customizeInteraction = null)
    {
        var user = CreateUser(customizeUser);
        var interactions = CreateInteractions(interactionCount, interaction =>
        {
            interaction.UserId = user.Id;
            interaction.TelegramUserId = user.TelegramId;
            customizeInteraction?.Invoke(interaction);
        });

        return (user, interactions);
    }

    public static (User user, UserSession session) CreateUserWithSession(
        Action<User>? customizeUser = null,
        Action<UserSession>? customizeSession = null)
    {
        var user = CreateUser(customizeUser);
        var session = CreateUserSession(userSession =>
        {
            userSession.UserId = user.Id;
            userSession.TelegramUserId = user.TelegramId;
            customizeSession?.Invoke(userSession);
        });

        return (user, session);
    }
}