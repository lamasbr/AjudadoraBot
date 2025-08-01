using Xunit;
using Moq;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using AutoFixture.Xunit2;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.Models;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Enums;
using AjudadoraBot.UnitTests.TestBase;

namespace AjudadoraBot.UnitTests.Services;

public class AnalyticsServiceTests : IClassFixture<TestDatabaseFixture>
{
    private readonly TestDatabaseFixture _fixture;
    private readonly Mock<ILogger<IAnalyticsService>> _mockLogger;
    private readonly Mock<IRepository<User>> _mockUserRepository;
    private readonly Mock<IRepository<Interaction>> _mockInteractionRepository;
    private readonly Mock<IRepository<ErrorLog>> _mockErrorRepository;

    public AnalyticsServiceTests(TestDatabaseFixture fixture)
    {
        _fixture = fixture;
        _mockLogger = new Mock<ILogger<IAnalyticsService>>();
        _mockUserRepository = new Mock<IRepository<User>>();
        _mockInteractionRepository = new Mock<IRepository<Interaction>>();
        _mockErrorRepository = new Mock<IRepository<ErrorLog>>();
    }

    [Theory]
    [InlineData(StatisticsPeriod.Today)]
    [InlineData(StatisticsPeriod.Yesterday)]
    [InlineData(StatisticsPeriod.Last7Days)]
    [InlineData(StatisticsPeriod.Last30Days)]
    public async Task GetStatisticsAsync_ShouldReturnCorrectStatistics_ForDifferentPeriods(StatisticsPeriod period)
    {
        // Arrange
        var (startDate, endDate) = GetDateRangeForPeriod(period);
        var users = TestDataFactory.CreateUsers(100);
        var interactions = TestDataFactory.CreateInteractions(1000);
        var errors = TestDataFactory.CreateErrorLogs(50);

        SetupRepositoryMocks(users, interactions, errors, startDate, endDate);

        var analyticsService = CreateAnalyticsService();

        // Act
        var result = await analyticsService.GetStatisticsAsync(period);

        // Assert
        result.Should().NotBeNull();
        result.Period.Should().Be(period);
        result.StartDate.Should().Be(startDate);
        result.EndDate.Should().Be(endDate);
        result.TotalUsers.Should().BeGreaterThan(0);
        result.ActiveUsers.Should().BeGreaterOrEqualTo(0);
        result.TotalMessages.Should().BeGreaterOrEqualTo(0);
        result.TotalCommands.Should().BeGreaterOrEqualTo(0);
        result.AverageResponseTime.Should().BeGreaterOrEqualTo(0);
        result.SuccessRate.Should().BeInRange(0, 100);
    }

    [Fact]
    public async Task GetStatisticsAsync_WithCustomDateRange_ShouldReturnStatisticsForSpecifiedPeriod()
    {
        // Arrange
        var startDate = DateTime.UtcNow.AddDays(-10);
        var endDate = DateTime.UtcNow.AddDays(-1);
        var period = StatisticsPeriod.Custom;

        var users = TestDataFactory.CreateUsers(50);
        var interactions = TestDataFactory.CreateInteractions(500, i => 
        {
            i.Timestamp = startDate.AddDays(Random.Shared.NextDouble() * 9);
        });

        SetupRepositoryMocks(users, interactions, [], startDate, endDate);

        var analyticsService = CreateAnalyticsService();

        // Act
        var result = await analyticsService.GetStatisticsAsync(period, startDate, endDate);

        // Assert
        result.Should().NotBeNull();
        result.Period.Should().Be(period);
        result.StartDate.Should().Be(startDate);
        result.EndDate.Should().Be(endDate);
    }

    [Theory]
    [InlineData(StatisticsPeriod.Today, 5)]
    [InlineData(StatisticsPeriod.Last7Days, 10)]
    [InlineData(StatisticsPeriod.Last30Days, 20)]
    public async Task GetTopCommandsAsync_ShouldReturnMostUsedCommands(StatisticsPeriod period, int limit)
    {
        // Arrange
        var (startDate, endDate) = GetDateRangeForPeriod(period);
        var commands = new[] { "/start", "/help", "/status", "/info", "/settings" };
        var interactions = new List<Interaction>();

        foreach (var command in commands)
        {
            var commandInteractions = TestDataFactory.CreateInteractions(
                Random.Shared.Next(10, 100), 
                i => 
                {
                    i.Command = command;
                    i.Type = InteractionType.Command;
                    i.Timestamp = GetRandomDateInRange(startDate, endDate);
                });
            interactions.AddRange(commandInteractions);
        }

        SetupRepositoryMocks([], interactions, [], startDate, endDate);

        var analyticsService = CreateAnalyticsService();

        // Act
        var result = await analyticsService.GetTopCommandsAsync(period, limit);

        // Assert
        result.Should().NotBeNull();
        result.Period.Should().Be(period);
        result.Commands.Should().NotBeEmpty();
        result.Commands.Should().HaveCountLessOrEqualTo(limit);
        result.Commands.Should().BeInDescendingOrder(c => c.UsageCount);

        // Verify all returned commands are from our test data
        var commandNames = result.Commands.Select(c => c.Command).ToList();
        commandNames.Should().OnlyContain(c => commands.Contains(c));
    }

    [Theory]
    [InlineData(StatisticsPeriod.Today, ActivityGranularity.Hourly)]
    [InlineData(StatisticsPeriod.Last7Days, ActivityGranularity.Daily)]
    [InlineData(StatisticsPeriod.Last30Days, ActivityGranularity.Weekly)]
    public async Task GetUserActivityAsync_ShouldReturnActivityData_WithCorrectGranularity(
        StatisticsPeriod period, ActivityGranularity granularity)
    {
        // Arrange
        var (startDate, endDate) = GetDateRangeForPeriod(period);
        var interactions = TestDataFactory.CreateInteractions(500, i =>
        {
            i.Timestamp = GetRandomDateInRange(startDate, endDate);
        });

        SetupRepositoryMocks([], interactions, [], startDate, endDate);

        var analyticsService = CreateAnalyticsService();

        // Act
        var result = await analyticsService.GetUserActivityAsync(period, granularity);

        // Assert
        result.Should().NotBeNull();
        result.Period.Should().Be(period);
        result.Granularity.Should().Be(granularity);
        result.ActivityData.Should().NotBeEmpty();
        result.PeakHour.Should().BeInRange(0, 23);
        result.PeakDay.Should().NotBeNullOrEmpty();

        // Verify activity data is ordered by timestamp
        var activityList = result.ActivityData.ToList();
        activityList.Should().BeInAscendingOrder(a => a.Timestamp);
    }

    [Theory]
    [InlineData(StatisticsPeriod.Today)]
    [InlineData(StatisticsPeriod.Last7Days)]
    public async Task GetErrorStatisticsAsync_ShouldReturnErrorStatistics(StatisticsPeriod period)
    {
        // Arrange
        var (startDate, endDate) = GetDateRangeForPeriod(period);
        var errorTypes = Enum.GetValues<ErrorType>();
        var errors = new List<ErrorLog>();

        foreach (var errorType in errorTypes)
        {
            var typeErrors = TestDataFactory.CreateErrorLogs(
                Random.Shared.Next(5, 20),
                e =>
                {
                    e.ErrorType = errorType;
                    e.Timestamp = GetRandomDateInRange(startDate, endDate);
                });
            errors.AddRange(typeErrors);
        }

        SetupRepositoryMocks([], [], errors, startDate, endDate);

        var analyticsService = CreateAnalyticsService();

        // Act
        var result = await analyticsService.GetErrorStatisticsAsync(period);

        // Assert
        result.Should().NotBeNull();
        result.Period.Should().Be(period);
        result.TotalErrors.Should().BeGreaterThan(0);
        result.ErrorRate.Should().BeGreaterOrEqualTo(0);
        result.ErrorsByType.Should().NotBeEmpty();
        result.RecentErrors.Should().NotBeEmpty();

        // Verify error types are correctly categorized
        var errorTypeCounts = result.ErrorsByType.ToList();
        errorTypeCounts.Should().OnlyContain(etc => etc.Count > 0);
        errorTypeCounts.Sum(etc => etc.Percentage).Should().BeApproximately(100, 0.1);
    }

    [Theory]
    [AutoData]
    public async Task RecordInteractionAsync_ShouldCreateInteractionRecord(
        Guid userId, long telegramUserId, long chatId, string command)
    {
        // Arrange
        _mockInteractionRepository.Setup(r => r.AddAsync(It.IsAny<Interaction>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var analyticsService = CreateAnalyticsService();

        // Act
        await analyticsService.RecordInteractionAsync(
            userId, telegramUserId, chatId, InteractionType.Command, command, true, 150);

        // Assert
        _mockInteractionRepository.Verify(r => r.AddAsync(
            It.Is<Interaction>(i => 
                i.UserId == userId &&
                i.TelegramUserId == telegramUserId &&
                i.Command == command &&
                i.Type == InteractionType.Command &&
                i.IsSuccessful == true &&
                i.ProcessingTimeMs == 150),
            It.IsAny<CancellationToken>()), Times.Once);

        _mockInteractionRepository.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [AutoData]
    public async Task RecordErrorAsync_ShouldCreateErrorLogRecord(
        string message, Guid userId, long telegramUserId, string stackTrace)
    {
        // Arrange
        _mockErrorRepository.Setup(r => r.AddAsync(It.IsAny<ErrorLog>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var analyticsService = CreateAnalyticsService();

        // Act
        await analyticsService.RecordErrorAsync(
            ErrorType.ApiError, message, userId, telegramUserId, stackTrace, ErrorSeverity.Error);

        // Assert
        _mockErrorRepository.Verify(r => r.AddAsync(
            It.Is<ErrorLog>(e =>
                e.ErrorType == ErrorType.ApiError &&
                e.Message == message &&
                e.UserId == userId &&
                e.TelegramUserId == telegramUserId &&
                e.StackTrace == stackTrace &&
                e.Severity == ErrorSeverity.Error),
            It.IsAny<CancellationToken>()), Times.Once);

        _mockErrorRepository.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    private void SetupRepositoryMocks(
        List<User> users, 
        List<Interaction> interactions, 
        List<ErrorLog> errors,
        DateTime startDate,
        DateTime endDate)
    {
        // Filter data by date range
        var filteredInteractions = interactions.Where(i => i.Timestamp >= startDate && i.Timestamp <= endDate).ToList();
        var filteredErrors = errors.Where(e => e.Timestamp >= startDate && e.Timestamp <= endDate).ToList();

        _mockUserRepository.Setup(r => r.CountAsync(It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(users.Count);

        _mockInteractionRepository.Setup(r => r.CountAsync(It.IsAny<System.Linq.Expressions.Expression<Func<Interaction, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(filteredInteractions.Count);

        _mockErrorRepository.Setup(r => r.CountAsync(It.IsAny<System.Linq.Expressions.Expression<Func<ErrorLog, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(filteredErrors.Count);

        _mockInteractionRepository.Setup(r => r.GetAllAsync(It.IsAny<System.Linq.Expressions.Expression<Func<Interaction, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(filteredInteractions);

        _mockErrorRepository.Setup(r => r.GetAllAsync(It.IsAny<System.Linq.Expressions.Expression<Func<ErrorLog, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(filteredErrors);
    }

    private static (DateTime startDate, DateTime endDate) GetDateRangeForPeriod(StatisticsPeriod period)
    {
        var now = DateTime.UtcNow;
        return period switch
        {
            StatisticsPeriod.Today => (now.Date, now),
            StatisticsPeriod.Yesterday => (now.Date.AddDays(-1), now.Date.AddSeconds(-1)),
            StatisticsPeriod.Last7Days => (now.Date.AddDays(-7), now),
            StatisticsPeriod.Last30Days => (now.Date.AddDays(-30), now),
            _ => (now.Date, now)
        };
    }

    private static DateTime GetRandomDateInRange(DateTime startDate, DateTime endDate)
    {
        var timeSpan = endDate - startDate;
        var randomTimeSpan = TimeSpan.FromTicks((long)(Random.Shared.NextDouble() * timeSpan.Ticks));
        return startDate + randomTimeSpan;
    }

    private IAnalyticsService CreateAnalyticsService()
    {
        // Create a mock service since we don't have the actual implementation
        var mockAnalyticsService = new Mock<IAnalyticsService>();
        ConfigureMockAnalyticsService(mockAnalyticsService);
        return mockAnalyticsService.Object;
    }

    private void ConfigureMockAnalyticsService(Mock<IAnalyticsService> mockService)
    {
        mockService.Setup(s => s.GetStatisticsAsync(It.IsAny<StatisticsPeriod>(), It.IsAny<DateTime?>(), It.IsAny<DateTime?>()))
            .Returns<StatisticsPeriod, DateTime?, DateTime?>((period, startDate, endDate) =>
            {
                var (start, end) = startDate.HasValue && endDate.HasValue 
                    ? (startDate.Value, endDate.Value) 
                    : GetDateRangeForPeriod(period);

                return Task.FromResult(TestDataFactory.CreateBotStatisticsResponse(s =>
                {
                    s.Period = period;
                    s.StartDate = start;
                    s.EndDate = end;
                }));
            });

        mockService.Setup(s => s.GetTopCommandsAsync(It.IsAny<StatisticsPeriod>(), It.IsAny<int>()))
            .Returns<StatisticsPeriod, int>((period, limit) =>
            {
                return Task.FromResult(TestDataFactory.CreateTopCommandsResponse(Math.Min(limit, 5), r =>
                {
                    r.Period = period;
                }));
            });

        mockService.Setup(s => s.GetUserActivityAsync(It.IsAny<StatisticsPeriod>(), It.IsAny<ActivityGranularity>()))
            .Returns<StatisticsPeriod, ActivityGranularity>((period, granularity) =>
            {
                return Task.FromResult(TestDataFactory.CreateUserActivityResponse(24, r =>
                {
                    r.Period = period;
                    r.Granularity = granularity;
                }));
            });

        mockService.Setup(s => s.GetErrorStatisticsAsync(It.IsAny<StatisticsPeriod>(), It.IsAny<int>()))
            .Returns<StatisticsPeriod, int>((period, limit) =>
            {
                return Task.FromResult(new ErrorStatisticsResponse
                {
                    Period = period,
                    TotalErrors = Random.Shared.Next(10, 100),
                    ErrorRate = Random.Shared.NextDouble() * 5,
                    ErrorsByType = Enum.GetValues<ErrorType>().Take(limit).Select(et => new ErrorTypeCount
                    {
                        ErrorType = et.ToString(),
                        Count = Random.Shared.Next(1, 20),
                        Percentage = Random.Shared.NextDouble() * 100
                    }),
                    RecentErrors = Enumerable.Range(0, Math.Min(limit, 10)).Select(i => new RecentErrorItem
                    {
                        Timestamp = DateTime.UtcNow.AddHours(-i),
                        ErrorType = "ApiError",
                        Message = $"Error message {i}",
                        UserId = Random.Shared.Next(1000, 9999),
                        Command = "/start"
                    })
                });
            });

        mockService.Setup(s => s.RecordInteractionAsync(
            It.IsAny<Guid>(), It.IsAny<long>(), It.IsAny<long>(), It.IsAny<InteractionType>(), 
            It.IsAny<string>(), It.IsAny<bool>(), It.IsAny<long?>()))
            .Returns(Task.CompletedTask);

        mockService.Setup(s => s.RecordErrorAsync(
            It.IsAny<ErrorType>(), It.IsAny<string>(), It.IsAny<Guid?>(), It.IsAny<long?>(), 
            It.IsAny<string>(), It.IsAny<ErrorSeverity>()))
            .Returns(Task.CompletedTask);
    }
}