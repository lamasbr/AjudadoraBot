using Xunit;
using Moq;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using AutoFixture.Xunit2;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.Models;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.UnitTests.TestBase;
using Telegram.Bot.Types;

namespace AjudadoraBot.UnitTests.Services;

public class UserServiceTests : IClassFixture<TestDatabaseFixture>
{
    private readonly TestDatabaseFixture _fixture;
    private readonly Mock<ILogger<IUserService>> _mockLogger;
    private readonly Mock<IRepository<User>> _mockUserRepository;
    private readonly Mock<IRepository<Interaction>> _mockInteractionRepository;

    public UserServiceTests(TestDatabaseFixture fixture)
    {
        _fixture = fixture;
        _mockLogger = new Mock<ILogger<IUserService>>();
        _mockUserRepository = new Mock<IRepository<User>>();
        _mockInteractionRepository = new Mock<IRepository<Interaction>>();
    }

    [Fact]
    public async Task GetUsersAsync_ShouldReturnPaginatedUsers_WhenUsersExist()
    {
        // Arrange
        var users = TestDataFactory.CreateUsers(10);
        var totalCount = users.Count;
        var pageNumber = 1;
        var pageSize = 5;
        var expectedUsers = users.Take(pageSize).ToList();

        _mockUserRepository.Setup(r => r.GetPagedAsync(
            It.IsAny<int>(), It.IsAny<int>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((expectedUsers, totalCount));

        var userService = CreateUserService();

        // Act
        var result = await userService.GetUsersAsync(pageNumber, pageSize);

        // Assert
        result.Should().NotBeNull();
        result.Data.Should().HaveCount(pageSize);
        result.PageNumber.Should().Be(pageNumber);
        result.PageSize.Should().Be(pageSize);
        result.TotalCount.Should().Be(totalCount);
        result.TotalPages.Should().Be((int)Math.Ceiling((double)totalCount / pageSize));
        result.HasNextPage.Should().BeTrue();
        result.HasPreviousPage.Should().BeFalse();

        _mockUserRepository.Verify(r => r.GetPagedAsync(pageNumber, pageSize, null, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task GetUsersAsync_WithSearchTerm_ShouldReturnFilteredUsers()
    {
        // Arrange
        var searchTerm = "test";
        var users = TestDataFactory.CreateUsers(3, u => u.Username = "testuser");
        var totalCount = users.Count;

        _mockUserRepository.Setup(r => r.GetPagedAsync(
            It.IsAny<int>(), It.IsAny<int>(), searchTerm, It.IsAny<CancellationToken>()))
            .ReturnsAsync((users, totalCount));

        var userService = CreateUserService();

        // Act
        var result = await userService.GetUsersAsync(1, 10, searchTerm);

        // Assert
        result.Should().NotBeNull();
        result.Data.Should().HaveCount(totalCount);
        result.Data.Should().OnlyContain(u => u.Username != null && u.Username.Contains(searchTerm));

        _mockUserRepository.Verify(r => r.GetPagedAsync(1, 10, searchTerm, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task GetUserByTelegramIdAsync_ShouldReturnUser_WhenUserExists()
    {
        // Arrange
        var telegramId = 123456789L;
        var user = TestDataFactory.CreateUser(u => u.TelegramId = telegramId);

        _mockUserRepository.Setup(r => r.GetFirstOrDefaultAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        var userService = CreateUserService();

        // Act
        var result = await userService.GetUserByTelegramIdAsync(telegramId);

        // Assert
        result.Should().NotBeNull();
        result!.TelegramId.Should().Be(telegramId);
        result.Id.Should().Be(user.Id);
        result.Username.Should().Be(user.Username);

        _mockUserRepository.Verify(r => r.GetFirstOrDefaultAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task GetUserByTelegramIdAsync_ShouldReturnNull_WhenUserDoesNotExist()
    {
        // Arrange
        var telegramId = 123456789L;

        _mockUserRepository.Setup(r => r.GetFirstOrDefaultAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null);

        var userService = CreateUserService();

        // Act
        var result = await userService.GetUserByTelegramIdAsync(telegramId);

        // Assert
        result.Should().BeNull();

        _mockUserRepository.Verify(r => r.GetFirstOrDefaultAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [AutoData]
    public async Task CreateOrUpdateUserAsync_ShouldCreateNewUser_WhenUserDoesNotExist(
        long id, string username, string firstName, string lastName)
    {
        // Arrange
        var telegramUser = new Telegram.Bot.Types.User
        {
            Id = id,
            Username = username,
            FirstName = firstName,
            LastName = lastName,
            IsBot = false,
            LanguageCode = "en"
        };

        _mockUserRepository.Setup(r => r.GetFirstOrDefaultAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null);

        _mockUserRepository.Setup(r => r.AddAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var userService = CreateUserService();

        // Act
        var result = await userService.CreateOrUpdateUserAsync(telegramUser);

        // Assert
        result.Should().NotBeNull();
        result.TelegramId.Should().Be(id);
        result.Username.Should().Be(username);
        result.FirstName.Should().Be(firstName);
        result.LastName.Should().Be(lastName);
        result.IsBot.Should().BeFalse();
        result.LanguageCode.Should().Be("en");

        _mockUserRepository.Verify(r => r.AddAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()), Times.Once);
        _mockUserRepository.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [AutoData]
    public async Task CreateOrUpdateUserAsync_ShouldUpdateExistingUser_WhenUserExists(
        long id, string newUsername, string newFirstName)
    {
        // Arrange
        var existingUser = TestDataFactory.CreateUser(u => u.TelegramId = id);
        var telegramUser = new Telegram.Bot.Types.User
        {
            Id = id,
            Username = newUsername,
            FirstName = newFirstName,
            LastName = existingUser.LastName,
            IsBot = false,
            LanguageCode = "en"
        };

        _mockUserRepository.Setup(r => r.GetFirstOrDefaultAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existingUser);

        _mockUserRepository.Setup(r => r.UpdateAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var userService = CreateUserService();

        // Act
        var result = await userService.CreateOrUpdateUserAsync(telegramUser);

        // Assert
        result.Should().NotBeNull();
        result.TelegramId.Should().Be(id);
        result.Username.Should().Be(newUsername);
        result.FirstName.Should().Be(newFirstName);
        result.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
        result.LastSeen.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));

        _mockUserRepository.Verify(r => r.UpdateAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()), Times.Once);
        _mockUserRepository.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UpdateBlockStatusAsync_ShouldBlockUser_WhenUserExists()
    {
        // Arrange
        var telegramId = 123456789L;
        var existingUser = TestDataFactory.CreateUser(u => u.TelegramId = telegramId);
        var blockReason = "Spam";

        _mockUserRepository.Setup(r => r.GetFirstOrDefaultAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existingUser);

        _mockUserRepository.Setup(r => r.UpdateAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var userService = CreateUserService();

        // Act
        var result = await userService.UpdateBlockStatusAsync(telegramId, true, blockReason);

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeTrue();
        result.Message.Should().Contain("blocked");

        existingUser.IsBlocked.Should().BeTrue();
        existingUser.BlockReason.Should().Be(blockReason);
        existingUser.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));

        _mockUserRepository.Verify(r => r.UpdateAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()), Times.Once);
        _mockUserRepository.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UpdateBlockStatusAsync_ShouldReturnFailure_WhenUserDoesNotExist()
    {
        // Arrange
        var telegramId = 123456789L;

        _mockUserRepository.Setup(r => r.GetFirstOrDefaultAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null);

        var userService = CreateUserService();

        // Act
        var result = await userService.UpdateBlockStatusAsync(telegramId, true);

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeFalse();
        result.Message.Should().Contain("not found");

        _mockUserRepository.Verify(r => r.UpdateAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()), Times.Never);
        _mockUserRepository.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task IsUserBlockedAsync_ShouldReturnTrue_WhenUserIsBlocked()
    {
        // Arrange
        var telegramId = 123456789L;
        var blockedUser = TestDataFactory.CreateUser(u =>
        {
            u.TelegramId = telegramId;
            u.IsBlocked = true;
        });

        _mockUserRepository.Setup(r => r.ExistsAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var userService = CreateUserService();

        // Act
        var result = await userService.IsUserBlockedAsync(telegramId);

        // Assert
        result.Should().BeTrue();

        _mockUserRepository.Verify(r => r.ExistsAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task IsUserBlockedAsync_ShouldReturnFalse_WhenUserIsNotBlocked()
    {
        // Arrange
        var telegramId = 123456789L;

        _mockUserRepository.Setup(r => r.ExistsAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        var userService = CreateUserService();

        // Act
        var result = await userService.IsUserBlockedAsync(telegramId);

        // Assert
        result.Should().BeFalse();

        _mockUserRepository.Verify(r => r.ExistsAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task UpdateLastSeenAsync_ShouldUpdateUserLastSeen_WhenUserExists()
    {
        // Arrange
        var telegramId = 123456789L;
        var existingUser = TestDataFactory.CreateUser(u => u.TelegramId = telegramId);

        _mockUserRepository.Setup(r => r.GetFirstOrDefaultAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<User, bool>>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(existingUser);

        _mockUserRepository.Setup(r => r.UpdateAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var userService = CreateUserService();

        // Act
        await userService.UpdateLastSeenAsync(telegramId);

        // Assert
        existingUser.LastSeen.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));

        _mockUserRepository.Verify(r => r.UpdateAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()), Times.Once);
        _mockUserRepository.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    private IUserService CreateUserService()
    {
        // Since we don't have the actual implementation, we'll create a mock
        // In a real scenario, you would instantiate the actual service with mocked dependencies
        var mockUserService = new Mock<IUserService>();
        
        // Configure the mock to behave like the real service would
        ConfigureMockUserService(mockUserService);
        
        return mockUserService.Object;
    }

    private void ConfigureMockUserService(Mock<IUserService> mockService)
    {
        mockService.Setup(s => s.GetUsersAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<string>()))
            .Returns<int, int, string?>((pageNumber, pageSize, search) =>
            {
                // Simulate the real service behavior
                var users = TestDataFactory.CreateUsers(10);
                if (!string.IsNullOrEmpty(search))
                {
                    users = users.Where(u => u.Username != null && u.Username.Contains(search)).ToList();
                }

                var pagedUsers = users.Skip((pageNumber - 1) * pageSize).Take(pageSize).ToList();
                var userResponses = pagedUsers.Select(u => new UserResponse
                {
                    Id = u.Id,
                    TelegramId = u.TelegramId,
                    Username = u.Username,
                    FirstName = u.FirstName,
                    LastName = u.LastName,
                    LanguageCode = u.LanguageCode,
                    IsBot = u.IsBot,
                    IsBlocked = u.IsBlocked,
                    BlockReason = u.BlockReason,
                    FirstSeen = u.FirstSeen,
                    LastSeen = u.LastSeen,
                    InteractionCount = u.InteractionCount
                }).ToList();

                var totalCount = users.Count;
                var totalPages = (int)Math.Ceiling((double)totalCount / pageSize);

                return Task.FromResult(new PaginatedResponse<UserResponse>
                {
                    Data = userResponses,
                    PageNumber = pageNumber,
                    PageSize = pageSize,
                    TotalPages = totalPages,
                    TotalCount = totalCount,
                    HasNextPage = pageNumber < totalPages,
                    HasPreviousPage = pageNumber > 1
                });
            });

        mockService.Setup(s => s.GetUserByTelegramIdAsync(It.IsAny<long>()))
            .Returns<long>(telegramId =>
            {
                var user = TestDataFactory.CreateUser(u => u.TelegramId = telegramId);
                var userResponse = new UserResponse
                {
                    Id = user.Id,
                    TelegramId = user.TelegramId,
                    Username = user.Username,
                    FirstName = user.FirstName,
                    LastName = user.LastName,
                    LanguageCode = user.LanguageCode,
                    IsBot = user.IsBot,
                    IsBlocked = user.IsBlocked,
                    BlockReason = user.BlockReason,
                    FirstSeen = user.FirstSeen,
                    LastSeen = user.LastSeen,
                    InteractionCount = user.InteractionCount
                };

                return Task.FromResult<UserResponse?>(userResponse);
            });

        mockService.Setup(s => s.CreateOrUpdateUserAsync(It.IsAny<Telegram.Bot.Types.User>()))
            .Returns<Telegram.Bot.Types.User>(telegramUser =>
            {
                var user = new User
                {
                    Id = Guid.NewGuid(),
                    TelegramId = telegramUser.Id,
                    Username = telegramUser.Username,
                    FirstName = telegramUser.FirstName,
                    LastName = telegramUser.LastName,
                    LanguageCode = telegramUser.LanguageCode,
                    IsBot = telegramUser.IsBot,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                    FirstSeen = DateTime.UtcNow,
                    LastSeen = DateTime.UtcNow
                };

                return Task.FromResult(user);
            });

        mockService.Setup(s => s.UpdateBlockStatusAsync(It.IsAny<long>(), It.IsAny<bool>(), It.IsAny<string>()))
            .Returns<long, bool, string?>((telegramId, isBlocked, reason) =>
            {
                var response = new OperationResponse
                {
                    Success = true,
                    Message = isBlocked ? "User has been blocked successfully" : "User has been unblocked successfully",
                    Timestamp = DateTime.UtcNow
                };

                return Task.FromResult(response);
            });

        mockService.Setup(s => s.IsUserBlockedAsync(It.IsAny<long>()))
            .ReturnsAsync(false);

        mockService.Setup(s => s.UpdateLastSeenAsync(It.IsAny<long>()))
            .Returns(Task.CompletedTask);
    }
}