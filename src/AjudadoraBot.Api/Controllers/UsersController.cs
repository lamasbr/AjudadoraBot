using Microsoft.AspNetCore.Mvc;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Models;

namespace AjudadoraBot.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly ILogger<UsersController> _logger;

    public UsersController(IUserService userService, ILogger<UsersController> logger)
    {
        _userService = userService;
        _logger = logger;
    }

    /// <summary>
    /// Get paginated list of bot users
    /// </summary>
    /// <param name="pageNumber">Page number (default: 1)</param>
    /// <param name="pageSize">Page size (default: 20, max: 100)</param>
    /// <param name="search">Search term for username or first name</param>
    /// <returns>Paginated list of users</returns>
    [HttpGet]
    [ProducesResponseType<PaginatedResponse<UserResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<PaginatedResponse<UserResponse>>> GetUsers(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null)
    {
        if (pageNumber < 1 || pageSize < 1 || pageSize > 100)
            return BadRequest(new ErrorResponse("Invalid pagination parameters"));

        try
        {
            var users = await _userService.GetUsersAsync(pageNumber, pageSize, search);
            return Ok(users);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting users");
            return StatusCode(500, new ErrorResponse("Failed to get users"));
        }
    }

    /// <summary>
    /// Get specific user by Telegram ID
    /// </summary>
    /// <param name="telegramId">Telegram user ID</param>
    /// <returns>User details</returns>
    [HttpGet("{telegramId:long}")]
    [ProducesResponseType<UserResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<UserResponse>> GetUser(long telegramId)
    {
        try
        {
            var user = await _userService.GetUserByTelegramIdAsync(telegramId);
            if (user == null)
                return NotFound(new ErrorResponse("User not found"));

            return Ok(user);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting user {TelegramId}", telegramId);
            return StatusCode(500, new ErrorResponse("Failed to get user"));
        }
    }

    /// <summary>
    /// Block/unblock a user
    /// </summary>
    /// <param name="telegramId">Telegram user ID</param>
    /// <param name="request">Block status request</param>
    /// <returns>Operation result</returns>
    [HttpPatch("{telegramId:long}/block-status")]
    [ProducesResponseType<OperationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<OperationResponse>> UpdateBlockStatus(
        long telegramId, 
        [FromBody] UpdateBlockStatusRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(new ErrorResponse("Invalid request data"));

        try
        {
            var result = await _userService.UpdateBlockStatusAsync(telegramId, request.IsBlocked, request.Reason);
            if (!result.Success)
                return NotFound(new ErrorResponse("User not found"));

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating block status for user {TelegramId}", telegramId);
            return StatusCode(500, new ErrorResponse("Failed to update block status"));
        }
    }

    /// <summary>
    /// Get user interaction history
    /// </summary>
    /// <param name="telegramId">Telegram user ID</param>
    /// <param name="pageNumber">Page number (default: 1)</param>
    /// <param name="pageSize">Page size (default: 20, max: 50)</param>
    /// <returns>Paginated interaction history</returns>
    [HttpGet("{telegramId:long}/interactions")]
    [ProducesResponseType<PaginatedResponse<InteractionResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<PaginatedResponse<InteractionResponse>>> GetUserInteractions(
        long telegramId,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 20)
    {
        if (pageNumber < 1 || pageSize < 1 || pageSize > 50)
            return BadRequest(new ErrorResponse("Invalid pagination parameters"));

        try
        {
            var interactions = await _userService.GetUserInteractionsAsync(telegramId, pageNumber, pageSize);
            return Ok(interactions);
        }
        catch (ArgumentException ex)
        {
            return NotFound(new ErrorResponse(ex.Message));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting interactions for user {TelegramId}", telegramId);
            return StatusCode(500, new ErrorResponse("Failed to get user interactions"));
        }
    }
}