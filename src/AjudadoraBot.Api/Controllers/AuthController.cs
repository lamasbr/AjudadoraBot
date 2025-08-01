using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Security.Cryptography;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.DTOs;
using AjudadoraBot.Core.Configuration;

namespace AjudadoraBot.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class AuthController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly ISessionService _sessionService;
    private readonly ILogger<AuthController> _logger;
    private readonly MiniAppOptions _miniAppOptions;

    public AuthController(
        IUserService userService,
        ISessionService sessionService,
        IOptions<MiniAppOptions> miniAppOptions,
        ILogger<AuthController> logger)
    {
        _userService = userService;
        _sessionService = sessionService;
        _miniAppOptions = miniAppOptions.Value;
        _logger = logger;
    }

    /// <summary>
    /// Authenticate user using Telegram Web App data
    /// </summary>
    /// <param name="request">Telegram Web App authentication data</param>
    /// <returns>JWT token and user information</returns>
    [HttpPost("telegram-webapp")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<AuthResponse>> AuthenticateWebApp([FromBody] TelegramWebAppAuthRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(new ErrorResponse("Invalid request data"));

        try
        {
            // Verify Telegram Web App data
            if (!VerifyTelegramWebAppData(request.InitData, request.Hash))
            {
                _logger.LogWarning("Invalid Telegram Web App data hash");
                return Unauthorized(new ErrorResponse("Invalid authentication data"));
            }

            // Parse user data from init data
            var userData = ParseTelegramWebAppData(request.InitData);
            if (userData == null)
            {
                return BadRequest(new ErrorResponse("Invalid user data"));
            }

            // Get or create user
            var user = await _userService.CreateOrUpdateUserAsync(userData);
            
            // Check if user is blocked
            if (await _userService.IsUserBlockedAsync(user.TelegramId))
            {
                return Unauthorized(new ErrorResponse("User is blocked"));
            }

            // Create session
            var session = await _sessionService.CreateSessionAsync(
                user.Id, 
                user.TelegramId, 
                _miniAppOptions.JwtExpiration);

            // Generate JWT token
            var token = GenerateJwtToken(user, session.SessionToken);

            var response = new AuthResponse
            {
                AccessToken = token,
                TokenType = "Bearer",
                ExpiresIn = (int)_miniAppOptions.JwtExpiration.TotalSeconds,
                User = new UserResponse
                {
                    Id = user.Id,
                    TelegramId = user.TelegramId,
                    Username = user.Username,
                    FirstName = user.FirstName,
                    LastName = user.LastName,
                    LanguageCode = user.LanguageCode,
                    IsBot = user.IsBot,
                    IsBlocked = user.IsBlocked,
                    FirstSeen = user.FirstSeen,
                    LastSeen = user.LastSeen,
                    InteractionCount = user.InteractionCount
                }
            };

            _logger.LogInformation("User {UserId} authenticated successfully via Telegram Web App", user.TelegramId);
            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error authenticating Telegram Web App user");
            return StatusCode(500, new ErrorResponse("Authentication failed"));
        }
    }

    /// <summary>
    /// Refresh JWT token using session token
    /// </summary>
    /// <param name="request">Token refresh request</param>
    /// <returns>New JWT token</returns>
    [HttpPost("refresh")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<AuthResponse>> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(new ErrorResponse("Invalid request data"));

        try
        {
            // Validate session
            var session = await _sessionService.GetSessionAsync(request.SessionToken);
            if (session == null || !session.IsActive || session.IsExpired)
            {
                return Unauthorized(new ErrorResponse("Invalid or expired session"));
            }

            // Get user
            var userResponse = await _userService.GetUserByTelegramIdAsync(session.TelegramUserId);
            if (userResponse == null)
            {
                return Unauthorized(new ErrorResponse("User not found"));
            }

            // Check if user is blocked
            if (await _userService.IsUserBlockedAsync(session.TelegramUserId))
            {
                return Unauthorized(new ErrorResponse("User is blocked"));
            }

            // Refresh session
            if (!await _sessionService.RefreshSessionAsync(request.SessionToken))
            {
                return Unauthorized(new ErrorResponse("Failed to refresh session"));
            }

            // Generate new JWT token
            var user = new Core.Models.User
            {
                Id = userResponse.Id,
                TelegramId = userResponse.TelegramId,
                Username = userResponse.Username,
                FirstName = userResponse.FirstName,
                LastName = userResponse.LastName,
                LanguageCode = userResponse.LanguageCode
            };

            var token = GenerateJwtToken(user, request.SessionToken);

            var response = new AuthResponse
            {
                AccessToken = token,
                TokenType = "Bearer",
                ExpiresIn = (int)_miniAppOptions.JwtExpiration.TotalSeconds,
                User = userResponse
            };

            _logger.LogInformation("Token refreshed for user {UserId}", session.TelegramUserId);
            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error refreshing token");
            return StatusCode(500, new ErrorResponse("Token refresh failed"));
        }
    }

    /// <summary>
    /// Logout user and invalidate session
    /// </summary>
    /// <param name="request">Logout request</param>
    /// <returns>Logout result</returns>
    [HttpPost("logout")]
    [ProducesResponseType<OperationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponse>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<OperationResponse>> Logout([FromBody] LogoutRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(new ErrorResponse("Invalid request data"));

        try
        {
            await _sessionService.InvalidateSessionAsync(request.SessionToken);

            var response = new OperationResponse
            {
                Success = true,
                Message = "Logged out successfully"
            };

            _logger.LogInformation("User logged out with session token {SessionToken}", request.SessionToken);
            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during logout");
            return StatusCode(500, new ErrorResponse("Logout failed"));
        }
    }

    private bool VerifyTelegramWebAppData(string initData, string hash)
    {
        try
        {
            // Get bot token from configuration
            // This would need to be implemented to get the actual bot token
            var botToken = "YOUR_BOT_TOKEN"; // This should come from configuration

            // Create data check string
            var dataCheckString = string.Join("\n", 
                initData.Split('&')
                    .Where(x => !x.StartsWith("hash="))
                    .OrderBy(x => x.Split('=')[0])
                    .Select(x => x));

            // Calculate HMAC-SHA256
            var secretKey = HMACSHA256.HashData(Encoding.UTF8.GetBytes("WebAppData"), Encoding.UTF8.GetBytes(botToken));
            var calculatedHash = HMACSHA256.HashData(secretKey, Encoding.UTF8.GetBytes(dataCheckString));
            var calculatedHashHex = Convert.ToHexString(calculatedHash).ToLowerInvariant();

            return calculatedHashHex == hash.ToLowerInvariant();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error verifying Telegram Web App data");
            return false;
        }
    }

    private static Telegram.Bot.Types.User? ParseTelegramWebAppData(string initData)
    {
        try
        {
            var parameters = initData.Split('&')
                .Select(x => x.Split('='))
                .Where(x => x.Length == 2)
                .ToDictionary(x => Uri.UnescapeDataString(x[0]), x => Uri.UnescapeDataString(x[1]));

            if (!parameters.TryGetValue("user", out var userJson))
                return null;

            // Parse user JSON (this is a simplified version)
            // In a real implementation, you'd use System.Text.Json or Newtonsoft.Json
            // For now, return a mock user
            return new Telegram.Bot.Types.User
            {
                Id = 123456789,
                FirstName = "Test User",
                Username = "testuser",
                LanguageCode = "en"
            };
        }
        catch
        {
            return null;
        }
    }

    private string GenerateJwtToken(Core.Models.User user, string sessionToken)
    {
        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.UTF8.GetBytes(_miniAppOptions.JwtSecret);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new("telegram_id", user.TelegramId.ToString()),
            new("session_token", sessionToken),
            new(ClaimTypes.Name, user.FirstName ?? string.Empty)
        };

        if (!string.IsNullOrEmpty(user.Username))
        {
            claims.Add(new Claim("username", user.Username));
        }

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.Add(_miniAppOptions.JwtExpiration),
            Issuer = _miniAppOptions.JwtIssuer,
            Audience = _miniAppOptions.JwtAudience,
            SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
        };

        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}