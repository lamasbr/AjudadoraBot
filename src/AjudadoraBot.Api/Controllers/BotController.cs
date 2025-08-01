using Microsoft.AspNetCore.Mvc;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Models;

namespace AjudadoraBot.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class BotController : ControllerBase
{
    private readonly IBotService _botService;
    private readonly ILogger<BotController> _logger;

    public BotController(IBotService botService, ILogger<BotController> logger)
    {
        _botService = botService;
        _logger = logger;
    }

    /// <summary>
    /// Get bot information and status
    /// </summary>
    /// <returns>Bot information</returns>
    [HttpGet("info")]
    [ProducesResponseType<BotInfoResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<BotInfoResponse>> GetBotInfo()
    {
        try
        {
            var botInfo = await _botService.GetBotInfoAsync();
            return Ok(botInfo);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting bot info");
            return StatusCode(500, new ErrorResponse("Failed to get bot information"));
        }
    }

    /// <summary>
    /// Start the bot (polling mode)
    /// </summary>
    /// <returns>Operation result</returns>
    [HttpPost("start")]
    [ProducesResponseType<OperationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<OperationResponse>> StartBot()
    {
        try
        {
            var result = await _botService.StartBotAsync();
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ErrorResponse(ex.Message));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error starting bot");
            return StatusCode(500, new ErrorResponse("Failed to start bot"));
        }
    }

    /// <summary>
    /// Stop the bot
    /// </summary>
    /// <returns>Operation result</returns>
    [HttpPost("stop")]
    [ProducesResponseType<OperationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<OperationResponse>> StopBot()
    {
        try
        {
            var result = await _botService.StopBotAsync();
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error stopping bot");
            return StatusCode(500, new ErrorResponse("Failed to stop bot"));
        }
    }

    /// <summary>
    /// Set webhook URL for the bot
    /// </summary>
    /// <param name="request">Webhook configuration</param>
    /// <returns>Operation result</returns>
    [HttpPost("webhook")]
    [ProducesResponseType<OperationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<OperationResponse>> SetWebhook([FromBody] SetWebhookRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(new ErrorResponse("Invalid request data"));

        try
        {
            var result = await _botService.SetWebhookAsync(request.Url, request.SecretToken);
            return Ok(result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new ErrorResponse(ex.Message));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error setting webhook");
            return StatusCode(500, new ErrorResponse("Failed to set webhook"));
        }
    }

    /// <summary>
    /// Remove webhook and switch to polling mode
    /// </summary>
    /// <returns>Operation result</returns>
    [HttpDelete("webhook")]
    [ProducesResponseType<OperationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<OperationResponse>> RemoveWebhook()
    {
        try
        {
            var result = await _botService.RemoveWebhookAsync();
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing webhook");
            return StatusCode(500, new ErrorResponse("Failed to remove webhook"));
        }
    }

    /// <summary>
    /// Send a message to a specific chat
    /// </summary>
    /// <param name="request">Message details</param>
    /// <returns>Sent message information</returns>
    [HttpPost("send-message")]
    [ProducesResponseType<MessageResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<MessageResponse>> SendMessage([FromBody] SendMessageRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(new ErrorResponse("Invalid request data"));

        try
        {
            var result = await _botService.SendMessageAsync(request);
            return Ok(result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new ErrorResponse(ex.Message));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending message");
            return StatusCode(500, new ErrorResponse("Failed to send message"));
        }
    }
}