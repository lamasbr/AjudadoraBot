using Xunit;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using AjudadoraBot.Core.Models;
using AjudadoraBot.Infrastructure.Repositories;
using AjudadoraBot.UnitTests.TestBase;

namespace AjudadoraBot.UnitTests.Repositories;

public class UnitOfWorkTests : IClassFixture<TestDatabaseFixture>
{
    private readonly TestDatabaseFixture _fixture;

    public UnitOfWorkTests(TestDatabaseFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public void Repository_ShouldReturnSameInstanceForSameType()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);

        // Act
        var userRepo1 = unitOfWork.Repository<User>();
        var userRepo2 = unitOfWork.Repository<User>();

        // Assert
        userRepo1.Should().BeSameAs(userRepo2);
    }

    [Fact]
    public void Repository_ShouldReturnDifferentInstancesForDifferentTypes()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);

        // Act
        var userRepo = unitOfWork.Repository<User>();
        var interactionRepo = unitOfWork.Repository<Interaction>();

        // Assert
        userRepo.Should().NotBeSameAs(interactionRepo);
    }

    [Fact]
    public async Task SaveChangesAsync_ShouldPersistChangesToDatabase()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);
        var userRepo = unitOfWork.Repository<User>();
        var user = TestDataFactory.CreateUser();

        // Act
        await userRepo.AddAsync(user);
        var saveResult = await unitOfWork.SaveChangesAsync();

        // Assert
        saveResult.Should().Be(1); // One entity saved
        
        var savedUser = await context.Users.FindAsync(user.Id);
        savedUser.Should().NotBeNull();
        savedUser!.TelegramId.Should().Be(user.TelegramId);
    }

    [Fact]
    public async Task SaveChangesAsync_ShouldReturnZero_WhenNoChanges()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);

        // Act
        var saveResult = await unitOfWork.SaveChangesAsync();

        // Assert
        saveResult.Should().Be(0);
    }

    [Fact]
    public async Task Transaction_ShouldCommitSuccessfully()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);
        var userRepo = unitOfWork.Repository<User>();
        var interactionRepo = unitOfWork.Repository<Interaction>();
        
        var user = TestDataFactory.CreateUser();
        var interaction = TestDataFactory.CreateInteraction(i => 
        {
            i.UserId = user.Id;
            i.TelegramUserId = user.TelegramId;
        });

        // Act
        await unitOfWork.BeginTransactionAsync();
        
        await userRepo.AddAsync(user);
        await interactionRepo.AddAsync(interaction);
        await unitOfWork.SaveChangesAsync();
        
        await unitOfWork.CommitTransactionAsync();

        // Assert
        var savedUser = await context.Users.FindAsync(user.Id);
        var savedInteraction = await context.Interactions.FindAsync(interaction.Id);
        
        savedUser.Should().NotBeNull();
        savedInteraction.Should().NotBeNull();
        savedInteraction!.UserId.Should().Be(user.Id);
    }

    [Fact]
    public async Task Transaction_ShouldRollbackOnError()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);
        var userRepo = unitOfWork.Repository<User>();
        
        var user1 = TestDataFactory.CreateUser();
        var user2 = TestDataFactory.CreateUser(u => u.TelegramId = user1.TelegramId); // Duplicate TelegramId

        // Act & Assert
        await unitOfWork.BeginTransactionAsync();
        
        await userRepo.AddAsync(user1);
        await unitOfWork.SaveChangesAsync(); // This should succeed
        
        await userRepo.AddAsync(user2);
        
        // This should fail due to unique constraint on TelegramId
        await Assert.ThrowsAsync<DbUpdateException>(async () =>
        {
            await unitOfWork.SaveChangesAsync();
        });

        await unitOfWork.RollbackTransactionAsync();

        // Verify rollback - neither user should exist
        var users = await context.Users.ToListAsync();
        users.Should().BeEmpty();
    }

    [Fact]
    public async Task Transaction_ShouldHandleNestedOperations()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);
        var userRepo = unitOfWork.Repository<User>();
        var interactionRepo = unitOfWork.Repository<Interaction>();
        var sessionRepo = unitOfWork.Repository<UserSession>();

        var user = TestDataFactory.CreateUser();
        var interactions = TestDataFactory.CreateInteractions(3, i => 
        {
            i.UserId = user.Id;
            i.TelegramUserId = user.TelegramId;
        });
        var session = TestDataFactory.CreateUserSession(s => 
        {
            s.UserId = user.Id;
            s.TelegramUserId = user.TelegramId;
        });

        // Act
        await unitOfWork.BeginTransactionAsync();

        // Add user first
        await userRepo.AddAsync(user);
        await unitOfWork.SaveChangesAsync();

        // Add related entities
        await interactionRepo.AddRangeAsync(interactions);
        await sessionRepo.AddAsync(session);
        await unitOfWork.SaveChangesAsync();

        await unitOfWork.CommitTransactionAsync();

        // Assert
        var savedUser = await context.Users
            .Include(u => u.Interactions)
            .Include(u => u.Sessions)
            .FirstOrDefaultAsync(u => u.Id == user.Id);

        savedUser.Should().NotBeNull();
        savedUser!.Interactions.Should().HaveCount(3);
        savedUser.Sessions.Should().HaveCount(1);
    }

    [Fact]
    public async Task Transaction_ShouldAllowMultipleCommits()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);
        var userRepo = unitOfWork.Repository<User>();

        // Act - First transaction
        await unitOfWork.BeginTransactionAsync();
        var user1 = TestDataFactory.CreateUser();
        await userRepo.AddAsync(user1);
        await unitOfWork.SaveChangesAsync();
        await unitOfWork.CommitTransactionAsync();

        // Act - Second transaction  
        await unitOfWork.BeginTransactionAsync();
        var user2 = TestDataFactory.CreateUser();
        await userRepo.AddAsync(user2);
        await unitOfWork.SaveChangesAsync();
        await unitOfWork.CommitTransactionAsync();

        // Assert
        var users = await context.Users.ToListAsync();
        users.Should().HaveCount(2);
        users.Should().Contain(u => u.Id == user1.Id);
        users.Should().Contain(u => u.Id == user2.Id);
    }

    [Fact]
    public async Task SaveChangesAsync_WithoutTransaction_ShouldStillWork()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);
        var userRepo = unitOfWork.Repository<User>();
        var users = TestDataFactory.CreateUsers(3);

        // Act - Without explicit transaction
        await userRepo.AddRangeAsync(users);
        var saveResult = await unitOfWork.SaveChangesAsync();

        // Assert
        saveResult.Should().Be(3);
        
        var savedUsers = await context.Users.ToListAsync();
        savedUsers.Should().HaveCount(3);
    }

    [Fact]
    public async Task UnitOfWork_ShouldMaintainConsistencyAcrossRepositories()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);
        var userRepo = unitOfWork.Repository<User>();
        var interactionRepo = unitOfWork.Repository<Interaction>();

        var user = TestDataFactory.CreateUser();
        var interaction = TestDataFactory.CreateInteraction(i => 
        {
            i.UserId = user.Id;
            i.TelegramUserId = user.TelegramId;
        });

        // Act
        await userRepo.AddAsync(user);
        await interactionRepo.AddAsync(interaction);
        
        // Save all changes in single transaction
        var saveResult = await unitOfWork.SaveChangesAsync();

        // Assert
        saveResult.Should().Be(2); // User + Interaction

        // Verify data consistency
        var savedUser = await context.Users.FindAsync(user.Id);
        var savedInteraction = await context.Interactions.FindAsync(interaction.Id);
        
        savedUser.Should().NotBeNull();
        savedInteraction.Should().NotBeNull();
        savedInteraction!.UserId.Should().Be(savedUser!.Id);
    }

    [Fact]
    public async Task Dispose_ShouldCleanupResources()
    {
        // Arrange
        var user = TestDataFactory.CreateUser();
        int savedChanges;

        // Act - Use UnitOfWork in using block
        using (var context = _fixture.CreateNewContext())
        {
            using var unitOfWork = new UnitOfWork(context);
            var userRepo = unitOfWork.Repository<User>();
            
            await unitOfWork.BeginTransactionAsync();
            await userRepo.AddAsync(user);
            savedChanges = await unitOfWork.SaveChangesAsync();
            await unitOfWork.CommitTransactionAsync();
        } // Dispose called here

        // Assert
        savedChanges.Should().Be(1);
        
        // Verify data was saved even after disposal
        using var verifyContext = _fixture.CreateNewContext();
        var savedUser = await verifyContext.Users.FindAsync(user.Id);
        savedUser.Should().NotBeNull();
    }

    [Fact]
    public async Task RollbackTransaction_ShouldRevertChanges()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);
        var userRepo = unitOfWork.Repository<User>();
        
        var existingUser = TestDataFactory.CreateUser();
        await userRepo.AddAsync(existingUser);
        await unitOfWork.SaveChangesAsync();

        // Act - Start transaction and make changes
        await unitOfWork.BeginTransactionAsync();
        
        existingUser.Username = "modified_username";
        await userRepo.UpdateAsync(existingUser);
        
        var newUser = TestDataFactory.CreateUser();
        await userRepo.AddAsync(newUser);
        
        await unitOfWork.SaveChangesAsync();
        
        // Rollback the transaction
        await unitOfWork.RollbackTransactionAsync();

        // Assert
        // Refresh context to see actual database state
        context.Entry(existingUser).Reload();
        
        existingUser.Username.Should().NotBe("modified_username");
        
        var userExists = await context.Users.AnyAsync(u => u.Id == newUser.Id);
        userExists.Should().BeFalse();
    }

    [Fact]
    public async Task MultipleRepositories_ShouldShareSameContext()
    {
        // Arrange
        using var context = _fixture.CreateNewContext();
        using var unitOfWork = new UnitOfWork(context);
        
        var userRepo = unitOfWork.Repository<User>();
        var interactionRepo = unitOfWork.Repository<Interaction>();
        var sessionRepo = unitOfWork.Repository<UserSession>();

        var user = TestDataFactory.CreateUser();

        // Act
        await userRepo.AddAsync(user);
        await unitOfWork.SaveChangesAsync();

        // Now query the user from different repositories using the same context
        var userFromUserRepo = await userRepo.GetByIdAsync(user.Id);
        var userFromInteractionRepo = await interactionRepo.GetFirstOrDefaultAsync<User>(u => u.Id == user.Id);

        // Assert
        userFromUserRepo.Should().NotBeNull();
        userFromUserRepo.Should().BeSameAs(userFromInteractionRepo);
    }
}