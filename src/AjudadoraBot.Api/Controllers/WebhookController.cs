using Microsoft.AspNetCore.Mvc;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.DTOs;
using Telegram.Bot.Types;

namespace AjudadoraBot.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class WebhookController : ControllerBase
{
    private readonly IWebhookService _webhookService;
    private readonly ILogger<WebhookController> _logger;

    public WebhookController(IWebhookService webhookService, ILogger<WebhookController> logger)
    {
        _webhookService = webhookService;
        _logger = logger;
    }

    /// <summary>
    /// Handle incoming Telegram webhook updates
    /// </summary>
    /// <param name="update">Telegram update object</param>
    /// <param name="secretToken">Secret token for verification</param>
    /// <returns>Status result</returns>
    [HttpPost("telegram/{secretToken}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> HandleTelegramUpdate([FromBody] Update update, [FromRoute] string secretToken)
    {
        try
        {
            // Verify secret token
            if (!await _webhookService.VerifySecretTokenAsync(secretToken))
            {
                _logger.LogWarning("Invalid secret token received: {Token}", secretToken);
                return Unauthorized(new ErrorResponse("Invalid secret token"));
            }

            // Process the update
            await _webhookService.ProcessUpdateAsync(update);
            
            return Ok();
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("Invalid update received: {Message}", ex.Message);
            return BadRequest(new ErrorResponse(ex.Message));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing webhook update");
            return StatusCode(500, new ErrorResponse("Failed to process update"));
        }
    }

    /// <summary>
    /// Health check endpoint for webhook
    /// </summary>
    /// <returns>Health status</returns>
    [HttpGet("health")]
    [ProducesResponseType<HealthResponse>(StatusCodes.Status200OK)]
    public ActionResult<HealthResponse> GetHealth()
    {
        return Ok(new HealthResponse
        {
            Status = "Healthy",
            Timestamp = DateTime.UtcNow,
            Service = "Webhook Handler"
        });
    }
}