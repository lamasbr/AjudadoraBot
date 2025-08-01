# AjudadoraBot Manager - Telegram Mini App Frontend

A comprehensive Telegram Mini App frontend for managing your Telegram bot. This modern, responsive web application provides a complete bot management interface that integrates seamlessly with Telegram's Mini App platform.

## Features

### 🚀 Core Features
- **Real-time Dashboard** - Bot statistics, analytics, and activity monitoring
- **User Management** - Browse users with search, pagination, and detailed profiles
- **Message Broadcasting** - Send messages to all users, active users, or specific users
- **Bot Configuration** - Switch between webhook/polling modes, manage settings
- **Analytics Dashboard** - Interaction charts, performance metrics, and insights

### 📱 Telegram Integration
- **Native Mini App Experience** - Full Telegram WebApp SDK integration
- **Theme Adaptation** - Automatic light/dark theme support
- **Haptic Feedback** - Touch feedback for enhanced user experience
- **Native Navigation** - MainButton and BackButton integration
- **Secure Authentication** - JWT token management with auto-refresh

### 💡 Technical Features
- **Progressive Web App** - Service worker for offline capabilities
- **Responsive Design** - Mobile-first design optimized for all screen sizes
- **Real-time Updates** - Live statistics and data refresh
- **Error Handling** - Comprehensive error states and recovery
- **Performance Optimized** - Lazy loading, debounced search, efficient rendering

## Project Structure

```
frontend/
├── index.html              # Main HTML structure with Telegram Mini App integration
├── css/
│   └── styles.css          # Complete CSS styling matching Telegram's design language
├── js/
│   ├── api.js              # API client with JWT authentication and error handling
│   ├── auth.js             # Telegram WebApp authentication manager
│   ├── utils.js            # Utility functions (toasts, dialogs, formatting)
│   ├── dashboard.js        # Dashboard component with real-time statistics
│   ├── users.js            # User management with search and pagination
│   ├── messages.js         # Message sending and history management
│   ├── settings.js         # Bot configuration and settings management
│   └── app.js              # Main application controller and navigation
├── sw.js                   # Service worker for offline capabilities
└── README.md               # This file
```

## API Integration

The frontend integrates with the following backend API endpoints:

### Authentication
- `POST /api/auth/telegram-login` - Authenticate with Telegram WebApp data
- `POST /api/auth/refresh` - Refresh JWT token

### Bot Management
- `GET /api/bot` - Get bot status and configuration
- `POST /api/bot/start` - Start the bot
- `POST /api/bot/stop` - Stop the bot
- `PUT /api/bot` - Update bot configuration
- `POST /api/bot/send-message` - Send message to users
- `GET /api/bot/updates` - Get recent bot updates/interactions

### User Management
- `GET /api/users` - Get users with pagination and search
- `GET /api/users/{id}` - Get detailed user information

### Analytics
- `GET /api/analytics/stats` - Get bot statistics
- `GET /api/analytics/interactions` - Get interaction analytics data

## Installation & Setup

### 1. Backend Integration

Ensure your backend API is running and accessible. The frontend expects the API to be available at `/api/*` endpoints (same origin) or configure CORS appropriately.

### 2. Telegram Bot Setup

1. Create a Telegram bot via [@BotFather](https://t.me/BotFather)
2. Get your bot token
3. Create a Mini App via [@BotFather]:
   ```
   /newapp
   Choose your bot
   App name: AjudadoraBot Manager
   Description: Comprehensive bot management interface
   Photo: Upload an icon (optional)
   Web App URL: https://your-domain.com/frontend/
   ```

### 3. Deploy Frontend

#### Option A: Serve with Backend
Place the `frontend` folder in your backend's static files directory so it's served from the same origin as your API.

#### Option B: Separate Hosting
If hosting separately, ensure CORS is properly configured on your backend:

```csharp
// In your backend startup/configuration
services.AddCors(options =>
{
    options.AddPolicy("AllowTelegramMiniApp", builder =>
    {
        builder.WithOrigins("https://your-frontend-domain.com")
               .AllowAnyMethod()
               .AllowAnyHeader()
               .AllowCredentials();
    });
});
```

### 4. Configuration

Update the API base URL in `js/api.js` if needed:

```javascript
constructor() {
    this.baseURL = 'https://your-api-domain.com/api'; // Update if different domain
    // ... rest of constructor
}
```

## Usage

### Opening the Mini App

Users can access the bot manager by:
1. Starting your bot in Telegram
2. Using the Mini App button/command
3. Or directly via the Mini App link

### Main Features

#### Dashboard
- Real-time bot statistics (users, interactions, uptime)
- Interactive charts showing activity over time
- Recent activity feed
- Bot status indicator

#### User Management
- Browse all bot users with search functionality
- Pagination for large user lists
- Detailed user profiles with interaction history
- User status indicators (active/inactive)

#### Message Broadcasting
- Send messages to all users or active users only
- Send targeted messages to specific users
- Message history and status tracking
- Character counter and validation

#### Settings & Configuration
- Start/stop bot with confirmation dialogs
- Switch between polling and webhook modes
- Configure webhook URLs with validation
- Secure bot token management

## Development

### Local Development

1. Serve the frontend files using a local server:
   ```bash
   # Using Python
   python -m http.server 8000
   
   # Using Node.js
   npx serve .
   
   # Using any other static file server
   ```

2. For Telegram Mini App testing, you'll need HTTPS. Use tools like:
   - ngrok: `ngrok http 8000`
   - Cloudflare Tunnel
   - Local SSL certificates

### Code Organization

The application follows a modular architecture:

- **api.js**: Handles all HTTP requests with automatic token refresh
- **auth.js**: Manages Telegram WebApp authentication
- **utils.js**: Provides common utilities (toasts, dialogs, formatting)
- **Component files**: Each major feature has its own module
- **app.js**: Coordinates all components and manages navigation

### Adding New Features

1. Create a new JavaScript module in `js/`
2. Add corresponding HTML structure in `index.html`
3. Add styles in `css/styles.css`
4. Register the module in `app.js`
5. Add navigation if needed

## Browser Compatibility

- Modern browsers supporting ES6+
- Service Workers (for offline functionality)
- CSS Grid and Flexbox
- Fetch API

Tested on:
- Chrome/Chromium 90+
- Safari 14+
- Firefox 88+
- Telegram WebView

## Security Considerations

- JWT tokens are stored securely in localStorage
- All API requests include proper authentication headers
- Input validation and XSS prevention
- CSRF protection through proper token handling
- Telegram WebApp data validation

## Performance Features

- Lazy loading of components
- Debounced search to reduce API calls
- Efficient DOM updates
- Service worker caching
- Responsive images and assets
- Memory leak prevention

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Ensure backend is running and accessible
   - Check Telegram WebApp integration
   - Verify bot token configuration

2. **API Requests Failing**
   - Check CORS configuration
   - Verify API endpoint URLs
   - Check network connectivity

3. **Styling Issues**
   - Ensure CSS files are loading correctly
   - Check for theme-specific variables
   - Verify responsive breakpoints

4. **Service Worker Issues**
   - Check browser console for registration errors
   - Ensure HTTPS is used for production
   - Clear browser cache if needed

### Debug Mode

Enable debug logging by adding to localStorage:
```javascript
localStorage.setItem('debug', 'true');
```

## Contributing

1. Follow the existing code style and patterns
2. Add proper error handling for new features
3. Update documentation for any new functionality
4. Test on multiple screen sizes and browsers
5. Ensure accessibility compliance

## License

This project is part of the AjudadoraBot system. See the main project license for details.

---

For backend setup and API documentation, see the main project README.