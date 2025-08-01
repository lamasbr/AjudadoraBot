import { ApiClient, ApiError } from '../js/api.js';

describe('ApiClient', () => {
  let apiClient;

  beforeEach(() => {
    apiClient = new ApiClient();
    fetchMock.resetMocks();
    localStorage.clear();
  });

  describe('constructor', () => {
    test('should initialize with correct base URL', () => {
      expect(apiClient.baseURL).toBe('http://localhost/api');
    });

    test('should initialize with null tokens', () => {
      expect(apiClient.token).toBeNull();
      expect(apiClient.refreshToken).toBeNull();
    });
  });

  describe('setTokens', () => {
    test('should set tokens and store in localStorage', () => {
      const token = 'test-token';
      const refreshToken = 'test-refresh-token';

      apiClient.setTokens(token, refreshToken);

      expect(apiClient.token).toBe(token);
      expect(apiClient.refreshToken).toBe(refreshToken);
      expect(localStorage.getItem('auth_token')).toBe(token);
      expect(localStorage.getItem('refresh_token')).toBe(refreshToken);
    });

    test('should clear tokens when null is passed', () => {
      // First set tokens
      apiClient.setTokens('token', 'refresh');
      
      // Then clear them
      apiClient.setTokens(null);

      expect(apiClient.token).toBeNull();
      expect(apiClient.refreshToken).toBeNull();
      expect(localStorage.getItem('auth_token')).toBeNull();
      expect(localStorage.getItem('refresh_token')).toBeNull();
    });
  });

  describe('getToken', () => {
    test('should return token from memory', () => {
      apiClient.token = 'memory-token';
      expect(apiClient.getToken()).toBe('memory-token');
    });

    test('should return token from localStorage when not in memory', () => {
      localStorage.setItem('auth_token', 'storage-token');
      expect(apiClient.getToken()).toBe('storage-token');
      expect(apiClient.token).toBe('storage-token');
    });

    test('should return null when no token exists', () => {
      expect(apiClient.getToken()).toBeNull();
    });
  });

  describe('clearTokens', () => {
    test('should clear all tokens and localStorage', () => {
      apiClient.setTokens('token', 'refresh');
      apiClient.clearTokens();

      expect(apiClient.token).toBeNull();
      expect(apiClient.refreshToken).toBeNull();
      expect(localStorage.getItem('auth_token')).toBeNull();
      expect(localStorage.getItem('refresh_token')).toBeNull();
    });
  });

  describe('request', () => {
    test('should make successful GET request', async () => {
      const mockData = { message: 'success' };
      fetchMock.mockResponseOnce(JSON.stringify(mockData));

      const result = await apiClient.request('/test');

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/test',
        expect.objectContaining({
          headers: expect.objectContaining({
            'Content-Type': 'application/json'
          })
        })
      );
      expect(result).toEqual(mockData);
    });

    test('should include authorization header when token exists', async () => {
      apiClient.setTokens('test-token');
      fetchMock.mockResponseOnce(JSON.stringify({}));

      await apiClient.request('/test');

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/test',
        expect.objectContaining({
          headers: expect.objectContaining({
            'Authorization': 'Bearer test-token'
          })
        })
      );
    });

    test('should make POST request with body', async () => {
      const postData = { key: 'value' };
      fetchMock.mockResponseOnce(JSON.stringify({ success: true }));

      await apiClient.request('/test', {
        method: 'POST',
        body: JSON.stringify(postData)
      });

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/test',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(postData)
        })
      );
    });

    test('should throw ApiError on HTTP error', async () => {
      fetchMock.mockResponseOnce(
        JSON.stringify({ message: 'Bad Request' }),
        { status: 400 }
      );

      await expect(apiClient.request('/test')).rejects.toThrow(ApiError);
      await expect(apiClient.request('/test')).rejects.toThrow('Bad Request');
    });

    test('should handle 401 error and attempt token refresh', async () => {
      apiClient.setTokens('expired-token', 'valid-refresh');
      
      // First call returns 401
      fetchMock.mockResponseOnce('', { status: 401 });
      
      // Token refresh call
      fetchMock.mockResponseOnce(JSON.stringify({
        token: 'new-token',
        refreshToken: 'new-refresh'
      }));
      
      // Retry call succeeds
      fetchMock.mockResponseOnce(JSON.stringify({ success: true }));

      const result = await apiClient.request('/test');

      expect(fetchMock).toHaveBeenCalledTimes(3);
      expect(result).toEqual({ success: true });
      expect(apiClient.token).toBe('new-token');
    });

    test('should handle failed token refresh', async () => {
      apiClient.setTokens('expired-token', 'invalid-refresh');
      
      // First call returns 401
      fetchMock.mockResponseOnce('', { status: 401 });
      
      // Token refresh fails
      fetchMock.mockResponseOnce('', { status: 401 });

      await expect(apiClient.request('/test')).rejects.toThrow('Authentication failed');
      expect(apiClient.token).toBeNull();
    });

    test('should handle network errors', async () => {
      fetchMock.mockReject(new Error('Network error'));

      await expect(apiClient.request('/test')).rejects.toThrow(ApiError);
      await expect(apiClient.request('/test')).rejects.toThrow('Network error');
    });

    test('should handle non-JSON responses', async () => {
      fetchMock.mockResponseOnce('plain text response', {
        headers: { 'Content-Type': 'text/plain' }
      });

      const result = await apiClient.request('/test');
      expect(result).toBe('plain text response');
    });
  });

  describe('refreshAuthToken', () => {
    test('should refresh token successfully', async () => {
      apiClient.refreshToken = 'valid-refresh';
      fetchMock.mockResponseOnce(JSON.stringify({
        token: 'new-token',
        refreshToken: 'new-refresh'
      }));

      await apiClient.refreshAuthToken();

      expect(apiClient.token).toBe('new-token');
      expect(apiClient.refreshToken).toBe('new-refresh');
    });

    test('should throw error when no refresh token available', async () => {
      await expect(apiClient.refreshAuthToken()).rejects.toThrow('No refresh token available');
    });

    test('should clear tokens on refresh failure', async () => {
      apiClient.setTokens('token', 'invalid-refresh');
      fetchMock.mockResponseOnce('', { status: 401 });

      await expect(apiClient.refreshAuthToken()).rejects.toThrow('Token refresh failed');
      expect(apiClient.token).toBeNull();
      expect(apiClient.refreshToken).toBeNull();
    });

    test('should prevent concurrent refresh requests', async () => {
      apiClient.refreshToken = 'valid-refresh';
      fetchMock.mockResponseOnce(JSON.stringify({
        token: 'new-token',
        refreshToken: 'new-refresh'
      }));

      // Start two refresh operations simultaneously
      const promise1 = apiClient.refreshAuthToken();
      const promise2 = apiClient.refreshAuthToken();

      await Promise.all([promise1, promise2]);

      // Should only make one API call
      expect(fetchMock).toHaveBeenCalledTimes(1);
    });
  });

  describe('API endpoint methods', () => {
    beforeEach(() => {
      fetchMock.mockResponse(JSON.stringify({ success: true }));
    });

    test('login should call correct endpoint', async () => {
      const telegramData = { user: { id: 123 } };
      await apiClient.login(telegramData);

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/auth/telegram-login',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(telegramData)
        })
      );
    });

    test('getBotStatus should call correct endpoint', async () => {
      await apiClient.getBotStatus();

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/bot',
        expect.objectContaining({
          headers: expect.objectContaining({
            'Content-Type': 'application/json'
          })
        })
      );
    });

    test('startBot should call correct endpoint', async () => {
      await apiClient.startBot();

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/bot/start',
        expect.objectContaining({ method: 'POST' })
      );
    });

    test('stopBot should call correct endpoint', async () => {
      await apiClient.stopBot();

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/bot/stop',
        expect.objectContaining({ method: 'POST' })
      );
    });

    test('sendMessage should call correct endpoint', async () => {
      const messageData = { chatId: 123, text: 'Hello' };
      await apiClient.sendMessage(messageData);

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/bot/send-message',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(messageData)
        })
      );
    });

    test('getUsers should call correct endpoint with query parameters', async () => {
      await apiClient.getUsers(2, 30, 'search term');

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/users?page=2&pageSize=30&search=search+term',
        expect.any(Object)
      );
    });

    test('getUserById should call correct endpoint', async () => {
      await apiClient.getUserById(123);

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/users/123',
        expect.any(Object)
      );
    });

    test('getAnalyticsStats should call correct endpoint', async () => {
      await apiClient.getAnalyticsStats('7d');

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/analytics/stats?period=7d',
        expect.any(Object)
      );
    });

    test('getInteractionAnalytics should call correct endpoint with date parameters', async () => {
      await apiClient.getInteractionAnalytics('2023-01-01', '2023-01-31');

      expect(fetchMock).toHaveBeenCalledWith(
        'http://localhost/api/analytics/interactions?startDate=2023-01-01&endDate=2023-01-31',
        expect.any(Object)
      );
    });
  });

  describe('handleAuthError', () => {
    test('should clear tokens and dispatch auth-required event', () => {
      apiClient.setTokens('token', 'refresh');
      const dispatchEventSpy = jest.spyOn(window, 'dispatchEvent');

      apiClient.handleAuthError();

      expect(apiClient.token).toBeNull();
      expect(apiClient.refreshToken).toBeNull();
      expect(dispatchEventSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'auth-required'
        })
      );
    });
  });
});

describe('ApiError', () => {
  test('should create error with correct properties', () => {
    const error = new ApiError(404, 'Not Found', { extra: 'data' });

    expect(error.name).toBe('ApiError');
    expect(error.status).toBe(404);
    expect(error.message).toBe('Not Found');
    expect(error.data).toEqual({ extra: 'data' });
  });

  test('should correctly identify error types', () => {
    expect(new ApiError(0, 'Network').isNetworkError).toBe(true);
    expect(new ApiError(401, 'Unauthorized').isAuthError).toBe(true);
    expect(new ApiError(403, 'Forbidden').isAuthError).toBe(true);
    expect(new ApiError(404, 'Not Found').isClientError).toBe(true);
    expect(new ApiError(500, 'Server Error').isServerError).toBe(true);
  });

  test('should correctly categorize status codes', () => {
    const networkError = new ApiError(0, 'Network');
    const authError = new ApiError(401, 'Unauthorized');
    const clientError = new ApiError(404, 'Not Found');
    const serverError = new ApiError(500, 'Internal Server Error');

    expect(networkError.isNetworkError).toBe(true);
    expect(networkError.isAuthError).toBe(false);
    expect(networkError.isClientError).toBe(false);
    expect(networkError.isServerError).toBe(false);

    expect(authError.isNetworkError).toBe(false);
    expect(authError.isAuthError).toBe(true);
    expect(authError.isClientError).toBe(true);
    expect(authError.isServerError).toBe(false);

    expect(clientError.isNetworkError).toBe(false);
    expect(clientError.isAuthError).toBe(false);
    expect(clientError.isClientError).toBe(true);
    expect(clientError.isServerError).toBe(false);

    expect(serverError.isNetworkError).toBe(false);
    expect(serverError.isAuthError).toBe(false);
    expect(serverError.isClientError).toBe(false);
    expect(serverError.isServerError).toBe(true);
  });
});