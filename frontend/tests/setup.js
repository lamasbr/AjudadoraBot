// Test setup for Jest
import fetchMock from 'jest-fetch-mock';

// Enable fetch mocking
fetchMock.enableMocks();

// Global test utilities
global.localStorage = {
  data: {},
  getItem(key) {
    return this.data[key] || null;
  },
  setItem(key, value) {
    this.data[key] = value;
  },
  removeItem(key) {
    delete this.data[key];
  },
  clear() {
    this.data = {};
  }
};

// Mock Telegram WebApp
global.Telegram = {
  WebApp: {
    initData: 'query_id=test&user=%7B%22id%22%3A123456789%2C%22first_name%22%3A%22Test%22%2C%22last_name%22%3A%22User%22%2C%22username%22%3A%22testuser%22%2C%22language_code%22%3A%22en%22%7D&auth_date=1234567890&hash=test_hash',
    initDataUnsafe: {
      query_id: 'test',
      user: {
        id: 123456789,
        first_name: 'Test',
        last_name: 'User',
        username: 'testuser',
        language_code: 'en',
        is_premium: false
      },
      auth_date: 1234567890,
      hash: 'test_hash'
    },
    version: '6.0',
    colorScheme: 'light',
    themeParams: {
      bg_color: '#ffffff',
      text_color: '#000000',
      hint_color: '#999999',
      link_color: '#0088cc',
      button_color: '#0088cc',
      button_text_color: '#ffffff'
    },
    isExpanded: false,
    viewportHeight: 600,
    viewportStableHeight: 600,
    headerColor: '#ffffff',
    backgroundColor: '#ffffff',
    ready: jest.fn(),
    expand: jest.fn(),
    close: jest.fn(),
    enableClosingConfirmation: jest.fn(),
    disableClosingConfirmation: jest.fn(),
    MainButton: {
      text: '',
      color: '#0088cc',
      textColor: '#ffffff',
      isVisible: false,
      isActive: true,
      isProgressVisible: false,
      setText: jest.fn(),
      onClick: jest.fn(),
      offClick: jest.fn(),
      show: jest.fn(),
      hide: jest.fn(),
      enable: jest.fn(),
      disable: jest.fn(),
      showProgress: jest.fn(),
      hideProgress: jest.fn()
    },
    BackButton: {
      isVisible: false,
      onClick: jest.fn(),
      offClick: jest.fn(),
      show: jest.fn(),
      hide: jest.fn()
    },
    HapticFeedback: {
      impactOccurred: jest.fn(),
      notificationOccurred: jest.fn(),
      selectionChanged: jest.fn()
    }
  }
};

// Mock console methods to reduce noise in tests
global.console = {
  ...console,
  // Uncomment the lines below to silence console output during tests
  // log: jest.fn(),
  // error: jest.fn(),
  // warn: jest.fn(),
  // info: jest.fn(),
  // debug: jest.fn()
};

// Custom matchers
expect.extend({
  toBeWithinRange(received, floor, ceiling) {
    const pass = received >= floor && received <= ceiling;
    if (pass) {
      return {
        message: () => `expected ${received} not to be within range ${floor} - ${ceiling}`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be within range ${floor} - ${ceiling}`,
        pass: false,
      };
    }
  },
});

// Reset mocks before each test
beforeEach(() => {
  fetchMock.resetMocks();
  localStorage.clear();
  
  // Reset Telegram WebApp mocks
  Object.values(Telegram.WebApp.MainButton).forEach(fn => {
    if (typeof fn === 'function') fn.mockClear();
  });
  Object.values(Telegram.WebApp.BackButton).forEach(fn => {
    if (typeof fn === 'function') fn.mockClear();
  });
  Object.values(Telegram.WebApp.HapticFeedback).forEach(fn => {
    if (typeof fn === 'function') fn.mockClear();
  });
  
  // Clear all timers
  jest.clearAllTimers();
});

// Helper functions for tests
global.createMockResponse = (data, status = 200) => {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
};

global.createMockErrorResponse = (message, status = 400) => {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
};

// Mock DOM elements and methods that might be used
global.document.dispatchEvent = jest.fn();
global.window.dispatchEvent = jest.fn();

// Mock showToast function that might be used in components
global.showToast = jest.fn();