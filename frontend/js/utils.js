/**
 * Utility Functions for AjudadoraBot Manager
 * Common helper functions and utilities
 */

/**
 * Toast notification system
 */
class ToastManager {
    constructor() {
        this.container = document.getElementById('toast-container');
        this.toasts = new Map();
    }

    show(message, type = 'info', duration = 4000) {
        const toast = this.createToast(message, type);
        this.container.appendChild(toast);
        
        // Trigger haptic feedback
        if (window.hapticNotification) {
            const hapticType = type === 'error' ? 'error' : type === 'success' ? 'success' : 'warning';
            window.hapticNotification(hapticType);
        }

        // Animate in
        requestAnimationFrame(() => {
            toast.classList.add('show');
        });

        // Auto remove
        if (duration > 0) {
            setTimeout(() => {
                this.remove(toast);
            }, duration);
        }

        return toast;
    }

    createToast(message, type) {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        
        const icon = this.getIconForType(type);
        
        toast.innerHTML = `
            <div class="toast-icon">${icon}</div>
            <div class="toast-message">${this.escapeHtml(message)}</div>
            <button class="toast-close" onclick="toastManager.remove(this.parentElement)">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <line x1="18" y1="6" x2="6" y2="18" stroke="currentColor" stroke-width="2"/>
                    <line x1="6" y1="6" x2="18" y2="18" stroke="currentColor" stroke-width="2"/>
                </svg>
            </button>
        `;

        return toast;
    }

    getIconForType(type) {
        const icons = {
            success: `<svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <polyline points="20,6 9,17 4,12" stroke="currentColor" stroke-width="2"/>
            </svg>`,
            error: `<svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
                <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
            </svg>`,
            warning: `<svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M10.29 3.86L1.82 18A2 2 0 0 0 3.54 21H20.46A2 2 0 0 0 22.18 18L13.71 3.86A2 2 0 0 0 10.29 3.86Z" stroke="currentColor" stroke-width="2"/>
                <line x1="12" y1="9" x2="12" y2="13" stroke="currentColor" stroke-width="2"/>
                <line x1="12" y1="17" x2="12.01" y2="17" stroke="currentColor" stroke-width="2"/>
            </svg>`,
            info: `<svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                <path d="M12 16V12" stroke="currentColor" stroke-width="2"/>
                <path d="M12 8H12.01" stroke="currentColor" stroke-width="2"/>
            </svg>`
        };
        
        return icons[type] || icons.info;
    }

    remove(toast) {
        if (toast && toast.parentElement) {
            toast.classList.add('hide');
            setTimeout(() => {
                if (toast.parentElement) {
                    toast.parentElement.removeChild(toast);
                }
            }, 300);
        }
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

/**
 * Dialog/Modal system
 */
class DialogManager {
    constructor() {
        this.overlay = document.getElementById('confirmation-dialog');
        this.titleElement = document.getElementById('dialog-title');
        this.messageElement = document.getElementById('dialog-message');
        this.cancelButton = document.getElementById('dialog-cancel');
        this.confirmButton = document.getElementById('dialog-confirm');
        
        this.currentResolve = null;
        
        // Bind event handlers
        this.cancelButton.addEventListener('click', () => this.close(false));
        this.confirmButton.addEventListener('click', () => this.close(true));
        this.overlay.addEventListener('click', (e) => {
            if (e.target === this.overlay) {
                this.close(false);
            }
        });
    }

    show(title, message, confirmText = 'Confirm', cancelText = 'Cancel') {
        return new Promise((resolve) => {
            this.currentResolve = resolve;
            
            this.titleElement.textContent = title;
            this.messageElement.textContent = message;
            this.confirmButton.textContent = confirmText;
            this.cancelButton.textContent = cancelText;
            
            this.overlay.style.display = 'flex';
            
            // Trigger haptic feedback
            if (window.hapticImpact) {
                window.hapticImpact('medium');
            }
            
            // Focus on confirm button
            setTimeout(() => {
                this.confirmButton.focus();
            }, 100);
        });
    }

    close(result) {
        this.overlay.style.display = 'none';
        
        if (this.currentResolve) {
            this.currentResolve(result);
            this.currentResolve = null;
        }
    }
}

/**
 * Loading state manager
 */
class LoadingManager {
    constructor() {
        this.loadingScreen = document.getElementById('loading-screen');
        this.app = document.getElementById('app');
        this.activeLoaders = new Set();
    }

    show(id = 'default') {
        this.activeLoaders.add(id);
        this.updateVisibility();
    }

    hide(id = 'default') {
        this.activeLoaders.delete(id);
        this.updateVisibility();
    }

    updateVisibility() {
        const isLoading = this.activeLoaders.size > 0;
        
        if (isLoading) {
            this.loadingScreen.style.display = 'flex';
            this.app.style.display = 'none';
        } else {
            this.loadingScreen.style.display = 'none';
            this.app.style.display = 'block';
        }
    }
}

/**
 * Format utilities
 */
const formatUtils = {
    /**
     * Format date relative to now
     */
    formatRelativeTime(date) {
        const now = new Date();
        const diffMs = now - new Date(date);
        const diffSeconds = Math.floor(diffMs / 1000);
        const diffMinutes = Math.floor(diffSeconds / 60);
        const diffHours = Math.floor(diffMinutes / 60);
        const diffDays = Math.floor(diffHours / 24);

        if (diffSeconds < 60) {
            return 'just now';
        } else if (diffMinutes < 60) {
            return `${diffMinutes}m ago`;
        } else if (diffHours < 24) {
            return `${diffHours}h ago`;
        } else if (diffDays < 7) {
            return `${diffDays}d ago`;
        } else {
            return new Date(date).toLocaleDateString();
        }
    },

    /**
     * Format number with appropriate suffix
     */
    formatNumber(num) {
        if (num >= 1000000) {
            return (num / 1000000).toFixed(1) + 'M';
        } else if (num >= 1000) {
            return (num / 1000).toFixed(1) + 'K';
        }
        return num.toString();
    },

    /**
     * Format duration in milliseconds
     */
    formatDuration(ms) {
        if (ms < 1000) {
            return `${ms}ms`;
        } else if (ms < 60000) {
            return `${(ms / 1000).toFixed(1)}s`;
        } else {
            return `${(ms / 60000).toFixed(1)}m`;
        }
    },

    /**
     * Format file size
     */
    formatFileSize(bytes) {
        const sizes = ['B', 'KB', 'MB', 'GB'];
        if (bytes === 0) return '0 B';
        
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
    }
};

/**
 * Validation utilities
 */
const validationUtils = {
    /**
     * Validate email address
     */
    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    },

    /**
     * Validate URL
     */
    isValidUrl(url) {
        try {
            new URL(url);
            return true;
        } catch {
            return false;
        }
    },

    /**
     * Validate Telegram bot token
     */
    isValidBotToken(token) {
        const tokenRegex = /^\d+:[A-Za-z0-9_-]{35}$/;
        return tokenRegex.test(token);
    },

    /**
     * Sanitize HTML input
     */
    sanitizeHtml(html) {
        const div = document.createElement('div');
        div.textContent = html;
        return div.innerHTML;
    }
};

/**
 * Storage utilities
 */
const storageUtils = {
    /**
     * Set item in localStorage with JSON serialization
     */
    setItem(key, value) {
        try {
            localStorage.setItem(key, JSON.stringify(value));
            return true;
        } catch (error) {
            console.error('Failed to save to localStorage:', error);
            return false;
        }
    },

    /**
     * Get item from localStorage with JSON parsing
     */
    getItem(key, defaultValue = null) {
        try {
            const item = localStorage.getItem(key);
            return item ? JSON.parse(item) : defaultValue;
        } catch (error) {
            console.error('Failed to read from localStorage:', error);
            return defaultValue;
        }
    },

    /**
     * Remove item from localStorage
     */
    removeItem(key) {
        try {
            localStorage.removeItem(key);
            return true;
        } catch (error) {
            console.error('Failed to remove from localStorage:', error);
            return false;
        }
    },

    /**
     * Clear all localStorage
     */
    clear() {
        try {
            localStorage.clear();
            return true;
        } catch (error) {
            console.error('Failed to clear localStorage:', error);
            return false;
        }
    }
};

/**
 * Debounce function
 */
function debounce(func, wait, immediate = false) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            timeout = null;
            if (!immediate) func(...args);
        };
        const callNow = immediate && !timeout;
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
        if (callNow) func(...args);
    };
}

/**
 * Throttle function
 */
function throttle(func, limit) {
    let inThrottle;
    return function(...args) {
        if (!inThrottle) {
            func.apply(this, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

/**
 * Simple event emitter
 */
class EventEmitter {
    constructor() {
        this.events = {};
    }

    on(event, callback) {
        if (!this.events[event]) {
            this.events[event] = [];
        }
        this.events[event].push(callback);
    }

    off(event, callback) {
        if (!this.events[event]) return;
        
        this.events[event] = this.events[event].filter(cb => cb !== callback);
    }

    emit(event, ...args) {
        if (!this.events[event]) return;
        
        this.events[event].forEach(callback => {
            try {
                callback(...args);
            } catch (error) {
                console.error('Event callback error:', error);
            }
        });
    }
}

// Create global instances
window.toastManager = new ToastManager();
window.dialogManager = new DialogManager();
window.loadingManager = new LoadingManager();
window.eventBus = new EventEmitter();

// Add global utility functions
window.showToast = (message, type, duration) => window.toastManager.show(message, type, duration);
window.showDialog = (title, message, confirmText, cancelText) => window.dialogManager.show(title, message, confirmText, cancelText);
window.showLoading = (id) => window.loadingManager.show(id);
window.hideLoading = (id) => window.loadingManager.hide(id);

// Export utilities
window.formatUtils = formatUtils;
window.validationUtils = validationUtils;
window.storageUtils = storageUtils;
window.debounce = debounce;
window.throttle = throttle;

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        ToastManager,
        DialogManager,
        LoadingManager,
        EventEmitter,
        formatUtils,
        validationUtils,
        storageUtils,
        debounce,
        throttle
    };
}