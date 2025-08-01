namespace AjudadoraBot.Core.Enums;

public enum InteractionType
{
    Message = 1,
    Command = 2,
    CallbackQuery = 3,
    InlineQuery = 4,
    PreCheckoutQuery = 5,
    ShippingQuery = 6,
    ChosenInlineResult = 7,
    PollAnswer = 8,
    MyChatMember = 9,
    ChatMember = 10,
    ChatJoinRequest = 11
}

public enum ConfigurationType
{
    String = 1,
    Integer = 2,
    Boolean = 3,
    Json = 4,
    Encrypted = 5
}

public enum ErrorType
{
    TelegramApi = 1,
    Database = 2,
    Validation = 3,
    Authentication = 4,
    Authorization = 5,
    Network = 6,
    Parsing = 7,
    Business = 8,
    System = 9,
    Unknown = 10
}

public enum ErrorSeverity
{
    Info = 1,
    Warning = 2,
    Error = 3,
    Critical = 4,
    Fatal = 5
}

public enum StatisticsPeriod
{
    LastHour = 1,
    Last24Hours = 2,
    Last7Days = 3,
    Last30Days = 4,
    Last90Days = 5,
    LastYear = 6,
    Custom = 7
}

public enum ActivityGranularity
{
    Hourly = 1,
    Daily = 2,
    Weekly = 3,
    Monthly = 4
}

public enum BotMode
{
    Polling = 1,
    Webhook = 2
}