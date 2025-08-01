using Microsoft.AspNetCore.Mvc;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Enums;

namespace AjudadoraBot.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class AnalyticsController : ControllerBase
{
    private readonly IAnalyticsService _analyticsService;
    private readonly ILogger<AnalyticsController> _logger;

    public AnalyticsController(IAnalyticsService analyticsService, ILogger<AnalyticsController> logger)
    {
        _analyticsService = analyticsService;
        _logger = logger;
    }

    /// <summary>
    /// Get bot usage statistics
    /// </summary>
    /// <param name="period">Time period for statistics</param>
    /// <param name="startDate">Start date (optional, defaults to period-based calculation)</param>
    /// <param name="endDate">End date (optional, defaults to now)</param>
    /// <returns>Bot statistics</returns>
    [HttpGet("statistics")]
    [ProducesResponseType<BotStatisticsResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<BotStatisticsResponse>> GetStatistics(
        [FromQuery] StatisticsPeriod period = StatisticsPeriod.Last7Days,
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null)
    {
        if (startDate.HasValue && endDate.HasValue && startDate > endDate)
            return BadRequest(new ErrorResponse("Start date cannot be greater than end date"));

        try
        {
            var statistics = await _analyticsService.GetStatisticsAsync(period, startDate, endDate);
            return Ok(statistics);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting statistics");
            return StatusCode(500, new ErrorResponse("Failed to get statistics"));
        }
    }

    /// <summary>
    /// Get most used commands
    /// </summary>
    /// <param name="period">Time period for statistics</param>
    /// <param name="limit">Number of top commands to return (default: 10, max: 50)</param>
    /// <returns>Top commands usage</returns>
    [HttpGet("top-commands")]
    [ProducesResponseType<TopCommandsResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<TopCommandsResponse>> GetTopCommands(
        [FromQuery] StatisticsPeriod period = StatisticsPeriod.Last7Days,
        [FromQuery] int limit = 10)
    {
        if (limit < 1 || limit > 50)
            return BadRequest(new ErrorResponse("Limit must be between 1 and 50"));

        try
        {
            var topCommands = await _analyticsService.GetTopCommandsAsync(period, limit);
            return Ok(topCommands);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting top commands");
            return StatusCode(500, new ErrorResponse("Failed to get top commands"));
        }
    }

    /// <summary>
    /// Get user activity over time
    /// </summary>
    /// <param name="period">Time period for activity</param>
    /// <param name="granularity">Data granularity (hourly/daily)</param>
    /// <returns>User activity timeline</returns>
    [HttpGet("user-activity")]
    [ProducesResponseType<UserActivityResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<UserActivityResponse>> GetUserActivity(
        [FromQuery] StatisticsPeriod period = StatisticsPeriod.Last7Days,
        [FromQuery] ActivityGranularity granularity = ActivityGranularity.Daily)
    {
        try
        {
            var activity = await _analyticsService.GetUserActivityAsync(period, granularity);
            return Ok(activity);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting user activity");
            return StatusCode(500, new ErrorResponse("Failed to get user activity"));
        }
    }

    /// <summary>
    /// Get error statistics and recent errors
    /// </summary>
    /// <param name="period">Time period for error statistics</param>
    /// <param name="limit">Number of recent errors to include (default: 10, max: 100)</param>
    /// <returns>Error statistics</returns>
    [HttpGet("errors")]
    [ProducesResponseType<ErrorStatisticsResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<ErrorStatisticsResponse>> GetErrorStatistics(
        [FromQuery] StatisticsPeriod period = StatisticsPeriod.Last7Days,
        [FromQuery] int limit = 10)
    {
        if (limit < 1 || limit > 100)
            return BadRequest(new ErrorResponse("Limit must be between 1 and 100"));

        try
        {
            var errorStats = await _analyticsService.GetErrorStatisticsAsync(period, limit);
            return Ok(errorStats);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting error statistics");
            return StatusCode(500, new ErrorResponse("Failed to get error statistics"));
        }
    }
}