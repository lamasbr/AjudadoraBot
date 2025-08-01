using Microsoft.EntityFrameworkCore.Storage;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Infrastructure.Data;

namespace AjudadoraBot.Infrastructure.Repositories;

public class UnitOfWork : IUnitOfWork
{
    private readonly AjudadoraBotDbContext _context;
    private readonly Dictionary<Type, object> _repositories = new();
    private IDbContextTransaction? _transaction;

    public UnitOfWork(AjudadoraBotDbContext context)
    {
        _context = context;
    }

    public IRepository<T> Repository<T>() where T : class
    {
        var type = typeof(T);
        
        if (_repositories.TryGetValue(type, out var existingRepository))
        {
            return (IRepository<T>)existingRepository;
        }

        var repository = new Repository<T>(_context);
        _repositories[type] = repository;
        return repository;
    }

    public async Task<int> SaveChangesAsync()
    {
        return await _context.SaveChangesAsync();
    }

    public async Task BeginTransactionAsync()
    {
        _transaction = await _context.Database.BeginTransactionAsync();
    }

    public async Task CommitTransactionAsync()
    {
        if (_transaction != null)
        {
            await _transaction.CommitAsync();
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async Task RollbackTransactionAsync()
    {
        if (_transaction != null)
        {
            await _transaction.RollbackAsync();
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public void Dispose()
    {
        _transaction?.Dispose();
        _context.Dispose();
    }
}