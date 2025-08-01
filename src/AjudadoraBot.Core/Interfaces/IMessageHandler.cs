using Telegram.Bot.Types;
using Telegram.Bot.Types.Payments;

namespace AjudadoraBot.Core.Interfaces;

public interface IMessageHandler
{
    Task HandleMessageAsync(Message message);
    Task HandleCallbackQueryAsync(CallbackQuery callbackQuery);
    Task HandleInlineQueryAsync(InlineQuery inlineQuery);
    Task HandlePreCheckoutQueryAsync(PreCheckoutQuery preCheckoutQuery);
    Task HandleShippingQueryAsync(ShippingQuery shippingQuery);
    Task HandleChosenInlineResultAsync(ChosenInlineResult chosenInlineResult);
    Task HandlePollAnswerAsync(PollAnswer pollAnswer);
    Task HandleMyChatMemberAsync(ChatMemberUpdated myChatMember);
    Task HandleChatMemberAsync(ChatMemberUpdated chatMember);
    Task HandleChatJoinRequestAsync(ChatJoinRequest chatJoinRequest);
}