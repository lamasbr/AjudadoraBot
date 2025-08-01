import { AuthManager, TelegramWebAppHelper } from '../js/auth.js';

// Mock the API client
const mockApiClient = {
  getToken: jest.fn(),
  clearTokens: jest.fn(),
  login: jest.fn(),
  getBotStatus: jest.fn(),
  refreshAuthToken: jest.fn(),
  setTokens: jest.fn()
};

// Mock global functions
global.showToast = jest.fn();

describe('AuthManager', () => {
  let authManager;

  beforeEach(() => {
    authManager = new AuthManager();
    window.apiClient = mockApiClient;
    
    // Reset all mocks
    Object.values(mockApiClient).forEach(mock => mock.mockReset());
    showToast.mockClear();
    
    // Reset timers
    jest.clearAllTimers();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  describe('constructor', () => {
    test('should initialize with correct default values', () => {
      expect(authManager.isAuthenticated).toBe(false);
      expect(authManager.user).toBeNull();
      expect(authManager.initPromise).toBeNull();
    });

    test('should bind event handlers', () => {
      const spy = jest.spyOn(window, 'addEventListener');
      new AuthManager();
      
      expect(spy).toHaveBeenCalledWith('auth-required', expect.any(Function));
    });
  });

  describe('init', () => {
    test('should return same promise on multiple calls', async () => {
      mockApiClient.getToken.mockReturnValue('existing-token');
      mockApiClient.getBotStatus.mockResolvedValue({ status: 'active' });

      const promise1 = authManager.init();
      const promise2 = authManager.init();

      expect(promise1).toBe(promise2);
      
      await promise1;
      expect(authManager.isAuthenticated).toBe(true);
    });

    test('should throw error when not in Telegram WebApp environment', async () => {
      const originalTelegram = window.Telegram;
      delete window.Telegram;

      await expect(authManager.init()).rejects.toThrow('Not running in Telegram WebApp environment');
      
      window.Telegram = originalTelegram;
    });

    test('should use existing valid token', async () => {
      mockApiClient.getToken.mockReturnValue('valid-token');
      mockApiClient.getBotStatus.mockResolvedValue({ status: 'active' });

      const result = await authManager.init();

      expect(result.success).toBe(true);
      expect(authManager.isAuthenticated).toBe(true);
      expect(mockApiClient.getBotStatus).toHaveBeenCalled();
    });

    test('should clear invalid token and authenticate with Telegram', async () => {
      mockApiClient.getToken.mockReturnValue('invalid-token');
      mockApiClient.getBotStatus.mockRejectedValue(new Error('Unauthorized'));
      mockApiClient.login.mockResolvedValue({
        success: true,
        user: { id: 123, firstName: 'Test' }
      });

      const result = await authManager.init();

      expect(mockApiClient.clearTokens).toHaveBeenCalled();
      expect(mockApiClient.login).toHaveBeenCalled();
      expect(result.success).toBe(true);
    });
  });

  describe('authenticateWithTelegram', () => {
    test('should authenticate successfully with valid Telegram data', async () => {
      mockApiClient.login.mockResolvedValue({
        success: true,
        user: { id: 123456789, firstName: 'Test', lastName: 'User' }
      });

      const result = await authManager.authenticateWithTelegram();

      expect(result.success).toBe(true);
      expect(authManager.isAuthenticated).toBe(true);
      expect(authManager.user).toEqual({
        id: 123456789,
        firstName: 'Test',
        lastName: 'User'
      });
    });

    test('should throw error when no user data available', async () => {
      const originalTelegram = window.Telegram;
      window.Telegram = {
        WebApp: {
          initData: '',
          initDataUnsafe: {}
        }
      };

      await expect(authManager.authenticateWithTelegram()).rejects.toThrow('No user data available from Telegram');
      
      window.Telegram = originalTelegram;
    });

    test('should throw error when authentication fails', async () => {
      mockApiClient.login.mockResolvedValue({
        success: false,
        message: 'Invalid credentials'
      });

      await expect(authManager.authenticateWithTelegram()).rejects.toThrow('Invalid credentials');
    });

    test('should handle network errors during authentication', async () => {
      mockApiClient.login.mockRejectedValue(new Error('Network error'));

      await expect(authManager.authenticateWithTelegram()).rejects.toThrow('Network error');
    });
  });

  describe('extractUserFromWebApp', () => {
    test('should extract user data correctly', () => {
      const mockWebApp = {
        initDataUnsafe: {
          user: {
            id: 123456789,
            first_name: 'John',
            last_name: 'Doe',
            username: 'johndoe',
            language_code: 'en',
            is_premium: true,
            photo_url: 'https://example.com/photo.jpg'
          }
        }
      };

      const user = authManager.extractUserFromWebApp(mockWebApp);

      expect(user).toEqual({
        id: 123456789,
        firstName: 'John',
        lastName: 'Doe',
        username: 'johndoe',
        languageCode: 'en',
        isPremium: true,
        photoUrl: 'https://example.com/photo.jpg'
      });
    });

    test('should return null when no user data', () => {
      const mockWebApp = { initDataUnsafe: {} };
      const user = authManager.extractUserFromWebApp(mockWebApp);
      expect(user).toBeNull();
    });
  });

  describe('scheduleTokenRefresh', () => {
    test('should set up token refresh interval', () => {
      const setIntervalSpy = jest.spyOn(global, 'setInterval');
      
      authManager.scheduleTokenRefresh();

      expect(setIntervalSpy).toHaveBeenCalledWith(
        expect.any(Function),
        50 * 60 * 1000 // 50 minutes
      );
    });

    test('should handle token refresh failure', async () => {
      mockApiClient.refreshAuthToken.mockRejectedValue(new Error('Refresh failed'));
      const handleAuthRequiredSpy = jest.spyOn(authManager, 'handleAuthRequired');

      authManager.scheduleTokenRefresh();

      // Fast-forward time to trigger the interval
      jest.advanceTimersByTime(50 * 60 * 1000);

      // Wait for promises to resolve
      await new Promise(resolve => setTimeout(resolve, 0));
      expect(handleAuthRequiredSpy).toHaveBeenCalled();
    });
  });

  describe('handleAuthRequired', () => {
    test('should reset authentication state and show error', () => {
      authManager.isAuthenticated = true;
      authManager.user = { id: 123 };

      authManager.handleAuthRequired();

      expect(authManager.isAuthenticated).toBe(false);
      expect(authManager.user).toBeNull();
      expect(showToast).toHaveBeenCalledWith('Authentication required. Please restart the app.', 'error');
    });

    test('should close WebApp after delay', () => {
      const closeSpy = jest.spyOn(Telegram.WebApp, 'close');

      authManager.handleAuthRequired();

      // Fast-forward time
      jest.advanceTimersByTime(3000);

      expect(closeSpy).toHaveBeenCalled();
    });
  });

  describe('logout', () => {
    test('should clear authentication state and close WebApp', () => {
      authManager.isAuthenticated = true;
      authManager.user = { id: 123 };
      const closeSpy = jest.spyOn(Telegram.WebApp, 'close');

      authManager.logout();

      expect(authManager.isAuthenticated).toBe(false);
      expect(authManager.user).toBeNull();
      expect(mockApiClient.clearTokens).toHaveBeenCalled();
      expect(closeSpy).toHaveBeenCalled();
    });
  });

  describe('utility methods', () => {
    test('isUserAuthenticated should return correct status', () => {
      expect(authManager.isUserAuthenticated()).toBe(false);

      authManager.isAuthenticated = true;
      authManager.user = { id: 123 };
      expect(authManager.isUserAuthenticated()).toBe(true);

      authManager.user = null;
      expect(authManager.isUserAuthenticated()).toBe(false);
    });

    test('getCurrentUser should return current user', () => {
      const user = { id: 123, firstName: 'Test' };
      authManager.user = user;

      expect(authManager.getCurrentUser()).toBe(user);
    });

    test('verifyPermissions should check authentication', async () => {
      await expect(authManager.verifyPermissions()).rejects.toThrow('User not authenticated');

      authManager.isAuthenticated = true;
      const result = await authManager.verifyPermissions();
      expect(result).toBe(true);
    });
  });
});

describe('TelegramWebAppHelper', () => {
  let helper;

  beforeEach(() => {
    helper = new TelegramWebAppHelper();
  });

  describe('constructor', () => {
    test('should initialize with WebApp reference', () => {
      expect(helper.webApp).toBe(Telegram.WebApp);
      expect(helper.isReady).toBe(false);
    });
  });

  describe('init', () => {
    test('should initialize WebApp features', () => {
      const readySpy = jest.spyOn(Telegram.WebApp, 'ready');

      helper.init();

      expect(readySpy).toHaveBeenCalled();
      expect(helper.isReady).toBe(true);
    });

    test('should handle missing WebApp gracefully', () => {
      const originalTelegram = window.Telegram;
      delete window.Telegram;
      
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
      helper = new TelegramWebAppHelper();
      helper.init();

      expect(consoleSpy).toHaveBeenCalledWith('Telegram WebApp not available');
      
      window.Telegram = originalTelegram;
      consoleSpy.mockRestore();
    });
  });

  describe('applyTheme', () => {
    test('should apply theme colors to CSS variables', () => {
      const setPropertySpy = jest.spyOn(document.documentElement.style, 'setProperty');

      helper.applyTheme();

      expect(setPropertySpy).toHaveBeenCalledWith('--tg-bg-color', '#ffffff');
      expect(setPropertySpy).toHaveBeenCalledWith('--tg-text-color', '#000000');
      expect(setPropertySpy).toHaveBeenCalledWith('--tg-button-color', '#0088cc');
    });

    test('should apply dark theme class when appropriate', () => {
      const originalColorScheme = Telegram.WebApp.colorScheme;
      Telegram.WebApp.colorScheme = 'dark';

      helper.applyTheme();

      expect(document.documentElement.classList.contains('dark-theme')).toBe(true);

      Telegram.WebApp.colorScheme = originalColorScheme;
    });
  });

  describe('main button methods', () => {
    test('showMainButton should configure and show button', () => {
      const callback = jest.fn();
      const setText = jest.spyOn(Telegram.WebApp.MainButton, 'setText');
      const show = jest.spyOn(Telegram.WebApp.MainButton, 'show');
      const onClick = jest.spyOn(Telegram.WebApp.MainButton, 'onClick');
      const offClick = jest.spyOn(Telegram.WebApp.MainButton, 'offClick');

      helper.showMainButton('Test Button', callback);

      expect(setText).toHaveBeenCalledWith('Test Button');
      expect(show).toHaveBeenCalled();
      expect(offClick).toHaveBeenCalled();
      expect(onClick).toHaveBeenCalledWith(callback);
    });

    test('hideMainButton should hide button', () => {
      const hide = jest.spyOn(Telegram.WebApp.MainButton, 'hide');

      helper.hideMainButton();

      expect(hide).toHaveBeenCalled();
    });
  });

  describe('back button methods', () => {
    test('showBackButton should show back button', () => {
      const show = jest.spyOn(Telegram.WebApp.BackButton, 'show');

      helper.showBackButton();

      expect(show).toHaveBeenCalled();
    });

    test('hideBackButton should hide back button', () => {
      const hide = jest.spyOn(Telegram.WebApp.BackButton, 'hide');

      helper.hideBackButton();

      expect(hide).toHaveBeenCalled();
    });
  });

  describe('haptic feedback', () => {
    test('enableHapticFeedback should create global functions', () => {
      helper.enableHapticFeedback();

      expect(typeof window.hapticImpact).toBe('function');
      expect(typeof window.hapticNotification).toBe('function');
      expect(typeof window.hapticSelection).toBe('function');

      // Test the functions
      window.hapticImpact('medium');
      expect(Telegram.WebApp.HapticFeedback.impactOccurred).toHaveBeenCalledWith('medium');

      window.hapticNotification('warning');
      expect(Telegram.WebApp.HapticFeedback.notificationOccurred).toHaveBeenCalledWith('warning');

      window.hapticSelection();
      expect(Telegram.WebApp.HapticFeedback.selectionChanged).toHaveBeenCalled();
    });
  });

  describe('close', () => {
    test('should close WebApp', () => {
      const closeSpy = jest.spyOn(Telegram.WebApp, 'close');

      helper.close();

      expect(closeSpy).toHaveBeenCalled();
    });

    test('should handle missing WebApp gracefully', () => {
      helper.webApp = null;
      
      expect(() => helper.close()).not.toThrow();
    });
  });

  describe('button event handling', () => {
    test('should set up main button click handler', () => {
      const onClick = jest.spyOn(Telegram.WebApp.MainButton, 'onClick');
      const dispatchEventSpy = jest.spyOn(window, 'dispatchEvent');

      helper.setupMainButton();

      // Simulate button click
      const clickHandler = onClick.mock.calls[0][0];
      clickHandler();

      expect(dispatchEventSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'main-button-click'
        })
      );
    });

    test('should set up back button click handler', () => {
      const onClick = jest.spyOn(Telegram.WebApp.BackButton, 'onClick');
      const dispatchEventSpy = jest.spyOn(window, 'dispatchEvent');

      helper.setupBackButton();

      // Simulate button click
      const clickHandler = onClick.mock.calls[0][0];
      clickHandler();

      expect(dispatchEventSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'back-button-click'
        })
      );
    });
  });
});