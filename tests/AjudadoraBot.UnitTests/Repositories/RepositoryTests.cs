using Xunit;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using AjudadoraBot.Core.Models;
using AjudadoraBot.Infrastructure.Repositories;
using AjudadoraBot.UnitTests.TestBase;
using System.Linq.Expressions;

namespace AjudadoraBot.UnitTests.Repositories;

public class RepositoryTests : IClassFixture<TestDatabaseFixture>
{
    private readonly TestDatabaseFixture _fixture;

    public RepositoryTests(TestDatabaseFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public async Task GetByIdAsync_ShouldReturnEntity_WhenEntityExists()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var user = TestDataFactory.CreateUser();
        
        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.GetByIdAsync(user.Id);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be(user.Id);
        result.TelegramId.Should().Be(user.TelegramId);
        result.Username.Should().Be(user.Username);
    }

    [Fact]
    public async Task GetByIdAsync_ShouldReturnNull_WhenEntityDoesNotExist()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var nonExistentId = Guid.NewGuid();

        // Act
        var result = await repository.GetByIdAsync(nonExistentId);

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetFirstOrDefaultAsync_ShouldReturnEntity_WhenPredicateMatches()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(3);
        var targetUser = users[1];
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.GetFirstOrDefaultAsync(u => u.TelegramId == targetUser.TelegramId);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be(targetUser.Id);
        result.TelegramId.Should().Be(targetUser.TelegramId);
    }

    [Fact]
    public async Task GetFirstOrDefaultAsync_ShouldReturnNull_WhenPredicateDoesNotMatch()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(3);
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.GetFirstOrDefaultAsync(u => u.TelegramId == 999999999L);

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetAllAsync_ShouldReturnAllEntities()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(5);
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.GetAllAsync();

        // Assert
        result.Should().NotBeNull();
        result.Should().HaveCount(5);
        
        var resultList = result.ToList();
        foreach (var user in users)
        {
            resultList.Should().ContainSingle(u => u.Id == user.Id);
        }
    }

    [Fact]
    public async Task FindAsync_ShouldReturnMatchingEntities()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(5, u => u.IsBlocked = false);
        users[0].IsBlocked = true;
        users[1].IsBlocked = true;
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.FindAsync(u => u.IsBlocked == true);

        // Assert
        result.Should().NotBeNull();
        result.Should().HaveCount(2);
        result.Should().OnlyContain(u => u.IsBlocked == true);
    }

    [Fact]
    public async Task GetPagedAsync_ShouldReturnCorrectPagedResults()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(20);
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.GetPagedAsync<DateTime>(
            filter: u => !u.IsBlocked,
            orderBy: u => u.CreatedAt,
            ascending: true,
            pageNumber: 2,
            pageSize: 5);

        // Assert
        result.Items.Should().NotBeNull();
        result.Items.Should().HaveCount(5);
        result.TotalCount.Should().Be(20);
        
        var itemsList = result.Items.ToList();
        itemsList.Should().OnlyContain(u => !u.IsBlocked);
        itemsList.Should().BeInAscendingOrder(u => u.CreatedAt);
    }

    [Fact]
    public async Task GetPagedAsync_WithIncludes_ShouldIncludeRelatedEntities()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var (user, interactions) = TestDataFactory.CreateUserWithInteractions(3);
        
        await context.Users.AddAsync(user);
        await context.Interactions.AddRangeAsync(interactions);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.GetPagedAsync<DateTime>(
            filter: u => u.Id == user.Id,
            orderBy: u => u.CreatedAt,
            pageNumber: 1,
            pageSize: 10,
            includes: u => u.Interactions);

        // Assert
        result.Items.Should().HaveCount(1);
        var retrievedUser = result.Items.First();
        retrievedUser.Interactions.Should().HaveCount(3);
    }

    [Fact]
    public async Task AddAsync_ShouldAddEntityToDatabase()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var user = TestDataFactory.CreateUser();

        // Act
        var result = await repository.AddAsync(user);
        await context.SaveChangesAsync();

        // Assert
        result.Should().NotBeNull();
        result.Id.Should().Be(user.Id);

        var savedUser = await context.Users.FindAsync(user.Id);
        savedUser.Should().NotBeNull();
        savedUser!.TelegramId.Should().Be(user.TelegramId);
    }

    [Fact]
    public async Task AddRangeAsync_ShouldAddMultipleEntitiesToDatabase()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(3);

        // Act
        var result = await repository.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Assert
        result.Should().NotBeNull();
        result.Should().HaveCount(3);

        var savedUsers = await context.Users.ToListAsync();
        savedUsers.Should().HaveCount(3);
        
        foreach (var user in users)
        {
            savedUsers.Should().ContainSingle(u => u.Id == user.Id);
        }
    }

    [Fact]
    public async Task UpdateAsync_ShouldUpdateEntityInDatabase()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var user = TestDataFactory.CreateUser();
        
        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        // Modify the user
        user.Username = "updated_username";
        user.UpdatedAt = DateTime.UtcNow;

        // Act
        await repository.UpdateAsync(user);
        await context.SaveChangesAsync();

        // Assert
        var updatedUser = await context.Users.FindAsync(user.Id);
        updatedUser.Should().NotBeNull();
        updatedUser!.Username.Should().Be("updated_username");
        updatedUser.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }

    [Fact]
    public async Task DeleteAsync_ShouldRemoveEntityFromDatabase()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var user = TestDataFactory.CreateUser();
        
        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        // Act
        await repository.DeleteAsync(user);
        await context.SaveChangesAsync();

        // Assert
        var deletedUser = await context.Users.FindAsync(user.Id);
        deletedUser.Should().BeNull();
    }

    [Fact]
    public async Task DeleteRangeAsync_ShouldRemoveMultipleEntitiesFromDatabase()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(3);
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        await repository.DeleteRangeAsync(users);
        await context.SaveChangesAsync();

        // Assert
        var remainingUsers = await context.Users.ToListAsync();
        remainingUsers.Should().BeEmpty();
    }

    [Fact]
    public async Task CountAsync_WithoutPredicate_ShouldReturnTotalCount()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(7);
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.CountAsync();

        // Assert
        result.Should().Be(7);
    }

    [Fact]
    public async Task CountAsync_WithPredicate_ShouldReturnFilteredCount()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(10, u => u.IsBlocked = false);
        users[0].IsBlocked = true;
        users[1].IsBlocked = true;
        users[2].IsBlocked = true;
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.CountAsync(u => u.IsBlocked == true);

        // Assert
        result.Should().Be(3);
    }

    [Fact]
    public async Task ExistsAsync_ShouldReturnTrue_WhenEntityExists()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var user = TestDataFactory.CreateUser();
        
        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        // Act
        var result = await repository.ExistsAsync(u => u.TelegramId == user.TelegramId);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public async Task ExistsAsync_ShouldReturnFalse_WhenEntityDoesNotExist()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);

        // Act
        var result = await repository.ExistsAsync(u => u.TelegramId == 999999999L);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task Repository_ShouldHandleConcurrentOperations()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(10);

        // Act - Simulate concurrent operations
        var tasks = users.Select(async user =>
        {
            await repository.AddAsync(user);
        });

        await Task.WhenAll(tasks);
        await context.SaveChangesAsync();

        // Assert
        var result = await repository.GetAllAsync();
        result.Should().HaveCount(10);
    }

    [Fact]
    public async Task Repository_ShouldHandleComplexQueries()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var users = TestDataFactory.CreateUsers(20);
        
        // Set up different scenarios
        for (int i = 0; i < users.Count; i++)
        {
            users[i].IsBlocked = i % 3 == 0;
            users[i].InteractionCount = i * 10;
            users[i].CreatedAt = DateTime.UtcNow.AddDays(-i);
        }
        
        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();

        // Act - Complex query with multiple conditions
        Expression<Func<User, bool>> complexFilter = u => 
            !u.IsBlocked && 
            u.InteractionCount > 50 && 
            u.CreatedAt > DateTime.UtcNow.AddDays(-15);

        var result = await repository.GetPagedAsync(
            filter: complexFilter,
            orderBy: u => u.InteractionCount,
            ascending: false,
            pageNumber: 1,
            pageSize: 5);

        // Assert
        result.Items.Should().NotBeEmpty();
        result.Items.Should().OnlyContain(u => !u.IsBlocked && u.InteractionCount > 50);
        result.Items.Should().BeInDescendingOrder(u => u.InteractionCount);
    }

    [Fact]
    public async Task Repository_ShouldMaintainEntityState()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        var repository = new Repository<User>(context);
        var user = TestDataFactory.CreateUser();

        // Act & Assert - Track entity lifecycle
        
        // 1. Add entity
        await repository.AddAsync(user);
        context.Entry(user).State.Should().Be(EntityState.Added);
        
        await context.SaveChangesAsync();
        context.Entry(user).State.Should().Be(EntityState.Unchanged);
        
        // 2. Update entity
        user.Username = "updated";
        await repository.UpdateAsync(user);
        context.Entry(user).State.Should().Be(EntityState.Modified);
        
        await context.SaveChangesAsync();
        context.Entry(user).State.Should().Be(EntityState.Unchanged);
        
        // 3. Delete entity
        await repository.DeleteAsync(user);
        context.Entry(user).State.Should().Be(EntityState.Deleted);
    }
}