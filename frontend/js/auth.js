/**
 * Authentication Module for Telegram Mini App
 * Handles Telegram WebApp authentication and JWT token management
 */

class AuthManager {
    constructor() {
        this.isAuthenticated = false;
        this.user = null;
        this.initPromise = null;
        
        // Bind event handlers
        this.handleAuthRequired = this.handleAuthRequired.bind(this);
        
        // Listen for auth-required events
        window.addEventListener('auth-required', this.handleAuthRequired);
    }

    /**
     * Initialize authentication
     */
    async init() {
        if (this.initPromise) {
            return this.initPromise;
        }

        this.initPromise = this._performInit();
        return this.initPromise;
    }

    async _performInit() {
        try {
            // Check if we're running in Telegram WebApp
            if (!window.Telegram?.WebApp) {
                throw new Error('Not running in Telegram WebApp environment');
            }

            const webApp = window.Telegram.WebApp;
            
            // Expand the WebApp to full height
            webApp.expand();
            
            // Enable closing confirmation
            webApp.enableClosingConfirmation();

            // Check for existing token
            const existingToken = window.apiClient.getToken();
            if (existingToken) {
                try {
                    // Validate existing token by making a test request
                    const botStatus = await window.apiClient.getBotStatus();
                    this.isAuthenticated = true;
                    
                    // Extract user info from WebApp data
                    this.user = this.extractUserFromWebApp(webApp);
                    
                    return { success: true, user: this.user };
                } catch (error) {
                    // Token is invalid, clear it
                    window.apiClient.clearTokens();
                }
            }

            // Perform Telegram authentication
            return await this.authenticateWithTelegram();
            
        } catch (error) {
            console.error('Authentication initialization failed:', error);
            throw error;
        }
    }

    /**
     * Authenticate using Telegram WebApp data
     */
    async authenticateWithTelegram() {
        const webApp = window.Telegram.WebApp;
        
        if (!webApp.initDataUnsafe?.user) {
            throw new Error('No user data available from Telegram');
        }

        try {
            // Prepare authentication data
            const authData = {
                initData: webApp.initData,
                user: webApp.initDataUnsafe.user,
                hash: webApp.initDataUnsafe.hash,
                authDate: webApp.initDataUnsafe.auth_date
            };

            // Send authentication request to backend
            const response = await window.apiClient.login(authData);
            
            if (response.success) {
                this.isAuthenticated = true;
                this.user = response.user || this.extractUserFromWebApp(webApp);
                
                // Set up auto-refresh for token
                this.scheduleTokenRefresh();
                
                return { success: true, user: this.user };
            } else {
                throw new Error(response.message || 'Authentication failed');
            }
            
        } catch (error) {
            console.error('Telegram authentication failed:', error);
            throw error;
        }
    }

    /**
     * Extract user information from Telegram WebApp
     */
    extractUserFromWebApp(webApp) {
        const user = webApp.initDataUnsafe?.user;
        if (!user) return null;

        return {
            id: user.id,
            firstName: user.first_name,
            lastName: user.last_name,
            username: user.username,
            languageCode: user.language_code,
            isPremium: user.is_premium,
            photoUrl: user.photo_url
        };
    }

    /**
     * Schedule automatic token refresh
     */
    scheduleTokenRefresh() {
        // Refresh token every 50 minutes (tokens typically expire in 1 hour)
        setInterval(async () => {
            try {
                await window.apiClient.refreshAuthToken();
            } catch (error) {
                console.error('Token refresh failed:', error);
                this.handleAuthRequired();
            }
        }, 50 * 60 * 1000);
    }

    /**
     * Handle authentication required event
     */
    handleAuthRequired() {
        this.isAuthenticated = false;
        this.user = null;
        
        // Show authentication error message
        window.showToast('Authentication required. Please restart the app.', 'error');
        
        // Close the WebApp after a delay
        setTimeout(() => {
            if (window.Telegram?.WebApp) {
                window.Telegram.WebApp.close();
            }
        }, 3000);
    }

    /**
     * Logout user
     */
    logout() {
        this.isAuthenticated = false;
        this.user = null;
        window.apiClient.clearTokens();
        
        // Close the WebApp
        if (window.Telegram?.WebApp) {
            window.Telegram.WebApp.close();
        }
    }

    /**
     * Check if user is authenticated
     */
    isUserAuthenticated() {
        return this.isAuthenticated && this.user !== null;
    }

    /**
     * Get current user
     */
    getCurrentUser() {
        return this.user;
    }

    /**
     * Verify user permissions (if needed)
     */
    async verifyPermissions() {
        if (!this.isAuthenticated) {
            throw new Error('User not authenticated');
        }

        // Add any additional permission checks here
        // For now, we assume all authenticated users have access
        return true;
    }
}

/**
 * Telegram WebApp Integration Helper
 */
class TelegramWebAppHelper {
    constructor() {
        this.webApp = window.Telegram?.WebApp;
        this.isReady = false;
    }

    /**
     * Initialize Telegram WebApp features
     */
    init() {
        if (!this.webApp) {
            console.warn('Telegram WebApp not available');
            return;
        }

        // Set up WebApp ready callback
        this.webApp.ready();
        this.isReady = true;

        // Apply theme
        this.applyTheme();
        
        // Set up main button if needed
        this.setupMainButton();
        
        // Set up back button
        this.setupBackButton();
        
        // Enable haptic feedback
        this.enableHapticFeedback();
    }

    /**
     * Apply Telegram theme to the app
     */
    applyTheme() {
        if (!this.webApp) return;

        const themeParams = this.webApp.themeParams;
        const root = document.documentElement;

        // Apply theme colors
        if (themeParams.bg_color) {
            root.style.setProperty('--tg-bg-color', themeParams.bg_color);
        }
        if (themeParams.text_color) {
            root.style.setProperty('--tg-text-color', themeParams.text_color);
        }
        if (themeParams.hint_color) {
            root.style.setProperty('--tg-hint-color', themeParams.hint_color);
        }
        if (themeParams.link_color) {
            root.style.setProperty('--tg-link-color', themeParams.link_color);
        }
        if (themeParams.button_color) {
            root.style.setProperty('--tg-button-color', themeParams.button_color);
        }
        if (themeParams.button_text_color) {
            root.style.setProperty('--tg-button-text-color', themeParams.button_text_color);
        }

        // Detect color scheme
        const isDark = this.webApp.colorScheme === 'dark';
        root.classList.toggle('dark-theme', isDark);
    }

    /**
     * Set up main button
     */
    setupMainButton() {
        if (!this.webApp?.MainButton) return;

        const mainButton = this.webApp.MainButton;
        
        // Hide main button by default
        mainButton.hide();
        
        // Set up click handler
        mainButton.onClick(() => {
            const event = new CustomEvent('main-button-click');
            window.dispatchEvent(event);
        });
    }

    /**
     * Set up back button
     */
    setupBackButton() {
        if (!this.webApp?.BackButton) return;

        const backButton = this.webApp.BackButton;
        
        // Set up click handler
        backButton.onClick(() => {
            const event = new CustomEvent('back-button-click');
            window.dispatchEvent(event);
        });
    }

    /**
     * Enable haptic feedback
     */
    enableHapticFeedback() {
        if (!this.webApp?.HapticFeedback) return;

        // Add haptic feedback to global functions
        window.hapticImpact = (style = 'light') => {
            this.webApp.HapticFeedback.impactOccurred(style);
        };

        window.hapticNotification = (type = 'success') => {
            this.webApp.HapticFeedback.notificationOccurred(type);
        };

        window.hapticSelection = () => {
            this.webApp.HapticFeedback.selectionChanged();
        };
    }

    /**
     * Show main button with text and callback
     */
    showMainButton(text, callback) {
        if (!this.webApp?.MainButton) return;

        const mainButton = this.webApp.MainButton;
        mainButton.setText(text);
        mainButton.show();
        
        // Remove previous listeners and add new one
        mainButton.offClick();
        mainButton.onClick(callback);
    }

    /**
     * Hide main button
     */
    hideMainButton() {
        if (!this.webApp?.MainButton) return;
        this.webApp.MainButton.hide();
    }

    /**
     * Show back button
     */
    showBackButton() {
        if (!this.webApp?.BackButton) return;
        this.webApp.BackButton.show();
    }

    /**
     * Hide back button
     */
    hideBackButton() {
        if (!this.webApp?.BackButton) return;
        this.webApp.BackButton.hide();
    }

    /**
     * Close the WebApp
     */
    close() {
        if (this.webApp) {
            this.webApp.close();
        }
    }
}

// Create global instances
window.authManager = new AuthManager();
window.telegramWebApp = new TelegramWebAppHelper();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { AuthManager, TelegramWebAppHelper };
}