/**
 * API Client for AjudadoraBot Management
 * Handles all HTTP requests to the backend API with JWT authentication
 */

class ApiClient {
    constructor() {
        this.baseURL = window.location.origin + '/api';
        this.token = null;
        this.refreshToken = null;
        this.refreshPromise = null;
    }

    /**
     * Set authentication tokens
     */
    setTokens(token, refreshToken = null) {
        this.token = token;
        this.refreshToken = refreshToken;
        
        // Store in localStorage for persistence
        if (token) {
            localStorage.setItem('auth_token', token);
            if (refreshToken) {
                localStorage.setItem('refresh_token', refreshToken);
            }
        } else {
            localStorage.removeItem('auth_token');
            localStorage.removeItem('refresh_token');
        }
    }

    /**
     * Get stored token
     */
    getToken() {
        if (!this.token) {
            this.token = localStorage.getItem('auth_token');
        }
        return this.token;
    }

    /**
     * Clear authentication tokens
     */
    clearTokens() {
        this.token = null;
        this.refreshToken = null;
        localStorage.removeItem('auth_token');
        localStorage.removeItem('refresh_token');
    }

    /**
     * Refresh the authentication token
     */
    async refreshAuthToken() {
        if (this.refreshPromise) {
            return this.refreshPromise;
        }

        this.refreshPromise = this._performTokenRefresh();
        
        try {
            await this.refreshPromise;
        } finally {
            this.refreshPromise = null;
        }
    }

    async _performTokenRefresh() {
        const refreshToken = this.refreshToken || localStorage.getItem('refresh_token');
        
        if (!refreshToken) {
            throw new Error('No refresh token available');
        }

        try {
            const response = await fetch(`${this.baseURL}/auth/refresh`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ refreshToken })
            });

            if (!response.ok) {
                throw new Error('Token refresh failed');
            }

            const data = await response.json();
            this.setTokens(data.token, data.refreshToken);
            
            return data.token;
        } catch (error) {
            this.clearTokens();
            throw error;
        }
    }

    /**
     * Make authenticated HTTP request
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        const token = this.getToken();

        const config = {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        };

        // Add authorization header if token exists
        if (token) {
            config.headers.Authorization = `Bearer ${token}`;
        }

        try {
            let response = await fetch(url, config);

            // Handle token expiration
            if (response.status === 401 && token) {
                try {
                    await this.refreshAuthToken();
                    
                    // Retry request with new token
                    config.headers.Authorization = `Bearer ${this.getToken()}`;
                    response = await fetch(url, config);
                } catch (refreshError) {
                    // Redirect to login or show auth error
                    this.handleAuthError();
                    throw new Error('Authentication failed');
                }
            }

            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                throw new ApiError(response.status, errorData.message || response.statusText, errorData);
            }

            // Handle empty responses
            const contentType = response.headers.get('content-type');
            if (contentType && contentType.includes('application/json')) {
                return await response.json();
            }
            
            return await response.text();
        } catch (error) {
            if (error instanceof ApiError) {
                throw error;
            }
            throw new ApiError(0, error.message, { originalError: error });
        }
    }

    /**
     * Handle authentication errors
     */
    handleAuthError() {
        this.clearTokens();
        // Show authentication required message
        window.dispatchEvent(new CustomEvent('auth-required'));
    }

    // Authentication endpoints
    async login(telegramData) {
        const response = await this.request('/auth/telegram-login', {
            method: 'POST',
            body: JSON.stringify(telegramData)
        });
        
        if (response.token) {
            this.setTokens(response.token, response.refreshToken);
        }
        
        return response;
    }

    // Bot management endpoints
    async getBotStatus() {
        return await this.request('/bot');
    }

    async startBot() {
        return await this.request('/bot/start', { method: 'POST' });
    }

    async stopBot() {
        return await this.request('/bot/stop', { method: 'POST' });
    }

    async updateBotConfiguration(config) {
        return await this.request('/bot', {
            method: 'PUT',
            body: JSON.stringify(config)
        });
    }

    async sendMessage(messageData) {
        return await this.request('/bot/send-message', {
            method: 'POST',
            body: JSON.stringify(messageData)
        });
    }

    async getBotUpdates(offset = 0, limit = 100) {
        return await this.request(`/bot/updates?offset=${offset}&limit=${limit}`);
    }

    // User management endpoints
    async getUsers(page = 1, pageSize = 20, search = '') {
        const params = new URLSearchParams({
            page: page.toString(),
            pageSize: pageSize.toString(),
            search
        });
        
        return await this.request(`/users?${params}`);
    }

    async getUserById(userId) {
        return await this.request(`/users/${userId}`);
    }

    // Analytics endpoints
    async getAnalyticsStats(period = '24h') {
        return await this.request(`/analytics/stats?period=${period}`);
    }

    async getInteractionAnalytics(startDate, endDate) {
        const params = new URLSearchParams();
        if (startDate) params.append('startDate', startDate);
        if (endDate) params.append('endDate', endDate);
        
        return await this.request(`/analytics/interactions?${params}`);
    }
}

/**
 * Custom API Error class
 */
class ApiError extends Error {
    constructor(status, message, data = {}) {
        super(message);
        this.name = 'ApiError';
        this.status = status;
        this.data = data;
    }

    get isNetworkError() {
        return this.status === 0;
    }

    get isServerError() {
        return this.status >= 500;
    }

    get isClientError() {
        return this.status >= 400 && this.status < 500;
    }

    get isAuthError() {
        return this.status === 401 || this.status === 403;
    }
}

// Create global API client instance
window.apiClient = new ApiClient();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { ApiClient, ApiError };
}