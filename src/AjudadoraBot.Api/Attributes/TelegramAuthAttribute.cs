using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using AjudadoraBot.Core.Interfaces;
using AjudadoraBot.Core.DTOs;

namespace AjudadoraBot.Api.Attributes;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class TelegramAuthAttribute : Attribute, IAsyncAuthorizationFilter
{
    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        // Check if the action has AllowAnonymous attribute
        if (context.ActionDescriptor.EndpointMetadata.Any(x => x is Microsoft.AspNetCore.Authorization.AllowAnonymousAttribute))
            return;

        var sessionService = context.HttpContext.RequestServices.GetRequiredService<ISessionService>();
        var userService = context.HttpContext.RequestServices.GetRequiredService<IUserService>();
        var logger = context.HttpContext.RequestServices.GetRequiredService<ILogger<TelegramAuthAttribute>>();

        try
        {
            // Get session token from claims (set by JWT middleware)
            var sessionToken = context.HttpContext.User.FindFirst("session_token")?.Value;
            
            if (string.IsNullOrEmpty(sessionToken))
            {
                context.Result = new UnauthorizedObjectResult(new ErrorResponse("No session token found"));
                return;
            }

            // Validate session
            var session = await sessionService.GetSessionAsync(sessionToken);
            if (session == null || !session.IsActive || session.IsExpired)
            {
                context.Result = new UnauthorizedObjectResult(new ErrorResponse("Invalid or expired session"));
                return;
            }

            // Check if user is blocked
            if (await userService.IsUserBlockedAsync(session.TelegramUserId))
            {
                context.Result = new UnauthorizedObjectResult(new ErrorResponse("User is blocked"));
                return;
            }

            // Update last accessed time
            session.LastAccessed = DateTime.UtcNow;
            
            // Add user information to HttpContext for use in controllers
            context.HttpContext.Items["UserId"] = session.UserId;
            context.HttpContext.Items["TelegramUserId"] = session.TelegramUserId;
            context.HttpContext.Items["SessionToken"] = sessionToken;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error during Telegram authentication");
            context.Result = new UnauthorizedObjectResult(new ErrorResponse("Authentication failed"));
        }
    }
}