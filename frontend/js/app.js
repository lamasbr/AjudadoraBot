/**
 * Main Application Controller
 * Coordinates all components and manages navigation
 */

class App {
    constructor() {
        this.currentPage = 'dashboard';
        this.isInitialized = false;
        this.isAuthenticated = false;
        
        // Component instances
        this.components = {
            dashboard: window.dashboard,
            users: window.usersManager,
            messages: window.messagesManager,
            settings: window.settingsManager
        };
        
        // Bind methods
        this.init = this.init.bind(this);
        this.handleNavigation = this.handleNavigation.bind(this);
        this.handleBackButton = this.handleBackButton.bind(this);
        this.handleMainButton = this.handleMainButton.bind(this);
        this.navigateToPage = this.navigateToPage.bind(this);
    }

    /**
     * Initialize the application
     */
    async init() {
        if (this.isInitialized) return;

        try {
            console.log('Initializing AjudadoraBot Manager...');
            
            // Show loading screen
            window.showLoading('app-init');
            
            // Initialize Telegram WebApp
            window.telegramWebApp.init();
            
            // Initialize authentication
            const authResult = await window.authManager.init();
            
            if (!authResult.success) {
                throw new Error('Authentication failed');
            }
            
            this.isAuthenticated = true;
            
            // Set up navigation
            this.setupNavigation();
            
            // Set up global event listeners
            this.setupGlobalEventListeners();
            
            // Initialize all components
            await this.initializeComponents();
            
            // Set initial page
            this.navigateToPage('dashboard', false);
            
            // Hide loading screen
            window.hideLoading('app-init');
            
            this.isInitialized = true;
            
            console.log('AjudadoraBot Manager initialized successfully');
            
            // Show welcome message
            const user = window.authManager.getCurrentUser();
            if (user) {
                window.showToast(`Welcome, ${user.firstName || user.username || 'User'}!`, 'success');
            }
            
        } catch (error) {
            console.error('Failed to initialize app:', error);
            
            // Hide loading screen
            window.hideLoading('app-init');
            
            // Show error message
            this.showInitializationError(error);
        }
    }

    /**
     * Set up navigation event listeners
     */
    setupNavigation() {
        // Navigation tabs
        const navTabs = document.querySelectorAll('.nav-tab');
        navTabs.forEach(tab => {
            tab.addEventListener('click', (e) => {
                e.preventDefault();
                const page = tab.dataset.page;
                if (page && page !== this.currentPage) {
                    this.navigateToPage(page);
                }
            });
        });

        // Back button (in header)
        const backButton = document.getElementById('back-btn');
        if (backButton) {
            backButton.addEventListener('click', this.handleBackButton);
        }
    }

    /**
     * Set up global event listeners
     */
    setupGlobalEventListeners() {
        // Telegram WebApp events
        window.addEventListener('back-button-click', this.handleBackButton);
        window.addEventListener('main-button-click', this.handleMainButton);
        
        // Custom navigation events
        window.eventBus.on('navigate-to-page', this.navigateToPage);
        
        // Auth events
        window.addEventListener('auth-required', () => {
            this.handleAuthenticationRequired();
        });
        
        // Handle browser back/forward
        window.addEventListener('popstate', (e) => {
            if (e.state && e.state.page) {
                this.navigateToPage(e.state.page, false, false);
            }
        });
        
        // Handle visibility change for performance optimization
        document.addEventListener('visibilitychange', () => {
            this.handleVisibilityChange();
        });
        
        // Handle page resize
        window.addEventListener('resize', window.debounce(() => {
            this.handleResize();
        }, 250));
    }

    /**
     * Initialize all components
     */
    async initializeComponents() {
        const componentPromises = Object.values(this.components).map(async (component) => {
            if (component && typeof component.init === 'function') {
                try {
                    await component.init();
                } catch (error) {
                    console.error(`Failed to initialize component:`, error);
                }
            }
        });

        await Promise.allSettled(componentPromises);
    }

    /**
     * Navigate to a specific page
     */
    navigateToPage(page, addToHistory = true, updateNav = true) {
        if (!this.isValidPage(page) || page === this.currentPage) {
            return;
        }

        // Trigger haptic feedback
        if (window.hapticSelection) {
            window.hapticSelection();
        }

        // Hide current page
        this.hidePage(this.currentPage);
        
        // Update current page
        const previousPage = this.currentPage;
        this.currentPage = page;
        
        // Show new page
        this.showPage(page);
        
        // Update navigation
        if (updateNav) {
            this.updateNavigation(page);
        }
        
        // Update page title
        this.updatePageTitle(page);
        
        // Update browser history
        if (addToHistory) {
            this.updateBrowserHistory(page);
        }
        
        // Update back button visibility
        this.updateBackButtonVisibility(page);
        
        // Notify component about visibility change
        this.notifyComponentVisibility(previousPage, false);
        this.notifyComponentVisibility(page, true);
        
        console.log(`Navigated to page: ${page}`);
    }

    /**
     * Check if page is valid
     */
    isValidPage(page) {
        const validPages = ['dashboard', 'users', 'messages', 'settings'];
        return validPages.includes(page);
    }

    /**
     * Hide a page
     */
    hidePage(page) {
        const pageElement = document.getElementById(`${page}-page`);
        if (pageElement) {
            pageElement.classList.remove('active');
        }
    }

    /**
     * Show a page
     */
    showPage(page) {
        const pageElement = document.getElementById(`${page}-page`);
        if (pageElement) {
            pageElement.classList.add('active');
        }
    }

    /**
     * Update navigation tab states
     */
    updateNavigation(activePage) {
        const navTabs = document.querySelectorAll('.nav-tab');
        navTabs.forEach(tab => {
            if (tab.dataset.page === activePage) {
                tab.classList.add('active');
            } else {
                tab.classList.remove('active');
            }
        });
    }

    /**
     * Update page title in header
     */
    updatePageTitle(page) {
        const pageTitle = document.getElementById('page-title');
        if (pageTitle) {
            const titles = {
                dashboard: 'Dashboard',
                users: 'Users',
                messages: 'Messages',
                settings: 'Settings'
            };
            pageTitle.textContent = titles[page] || 'AjudadoraBot';
        }
    }

    /**
     * Update browser history
     */
    updateBrowserHistory(page) {
        const url = new URL(window.location);
        url.searchParams.set('page', page);
        window.history.pushState({ page }, '', url);
    }

    /**
     * Update back button visibility
     */
    updateBackButtonVisibility(page) {
        const backButton = document.getElementById('back-btn');
        if (backButton) {
            // Show back button for non-dashboard pages
            if (page !== 'dashboard') {
                backButton.style.display = 'block';
                window.telegramWebApp.showBackButton();
            } else {
                backButton.style.display = 'none';
                window.telegramWebApp.hideBackButton();
            }
        }
    }

    /**
     * Notify component about visibility change
     */
    notifyComponentVisibility(page, visible) {
        const component = this.components[page];
        if (component && typeof component.setVisible === 'function') {
            component.setVisible(visible);
        }
    }

    /**
     * Handle back button click
     */
    handleBackButton() {
        if (this.currentPage !== 'dashboard') {
            this.navigateToPage('dashboard');
        } else {
            // On dashboard, close the app
            if (window.telegramWebApp) {
                window.telegramWebApp.close();
            }
        }
    }

    /**
     * Handle main button click
     */
    handleMainButton() {
        // Main button behavior depends on current page
        switch (this.currentPage) {
            case 'messages':
                // Send message
                if (window.messagesManager && typeof window.messagesManager.sendMessage === 'function') {
                    window.messagesManager.sendMessage();
                }
                break;
            case 'settings':
                // Save settings
                if (window.settingsManager && typeof window.settingsManager.saveSettings === 'function') {
                    window.settingsManager.saveSettings();
                }
                break;
            default:
                // Default action or hide main button
                window.telegramWebApp.hideMainButton();
                break;
        }
    }

    /**
     * Handle authentication required
     */
    handleAuthenticationRequired() {
        this.isAuthenticated = false;
        
        // Show authentication error
        window.showToast('Authentication expired. Please restart the app.', 'error', 5000);
        
        // Close app after a delay
        setTimeout(() => {
            if (window.telegramWebApp) {
                window.telegramWebApp.close();
            }
        }, 5000);
    }

    /**
     * Handle visibility change
     */
    handleVisibilityChange() {
        if (document.hidden) {
            // App is hidden - pause updates
            this.pauseUpdates();
        } else {
            // App is visible - resume updates
            this.resumeUpdates();
        }
    }

    /**
     * Handle window resize
     */
    handleResize() {
        // Update chart dimensions if needed
        if (this.currentPage === 'dashboard' && this.components.dashboard) {
            // Dashboard component should handle its own resize logic
        }
        
        // Update any other responsive elements
    }

    /**
     * Pause updates when app is hidden
     */
    pauseUpdates() {
        // Pause dashboard auto-refresh
        if (this.components.dashboard && typeof this.components.dashboard.stopAutoRefresh === 'function') {
            this.components.dashboard.stopAutoRefresh();
        }
    }

    /**
     * Resume updates when app becomes visible
     */
    resumeUpdates() {
        // Resume dashboard auto-refresh if on dashboard page
        if (this.currentPage === 'dashboard' && this.components.dashboard) {
            if (typeof this.components.dashboard.startAutoRefresh === 'function') {
                this.components.dashboard.startAutoRefresh();
            }
        }
    }

    /**
     * Show initialization error
     */
    showInitializationError(error) {
        const errorContainer = document.createElement('div');
        errorContainer.className = 'init-error';
        errorContainer.innerHTML = `
            <div class="error-content">
                <div class="error-icon">
                    <svg width="64" height="64" viewBox="0 0 24 24" fill="none">
                        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                        <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
                        <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
                    </svg>
                </div>
                <h2>Initialization Failed</h2>
                <p>${error.message || 'Failed to start the application'}</p>
                <button onclick="location.reload()" class="primary-button">
                    Retry
                </button>
            </div>
        `;
        
        // Replace app content with error
        const app = document.getElementById('app');
        if (app) {
            app.innerHTML = '';
            app.appendChild(errorContainer);
            app.style.display = 'flex';
            app.style.alignItems = 'center';
            app.style.justifyContent = 'center';
            app.style.height = '100vh';
        }
    }

    /**
     * Get current page
     */
    getCurrentPage() {
        return this.currentPage;
    }

    /**
     * Check if app is initialized
     */
    isAppInitialized() {
        return this.isInitialized;
    }

    /**
     * Check if user is authenticated
     */
    isUserAuthenticated() {
        return this.isAuthenticated;
    }

    /**
     * Cleanup resources
     */
    destroy() {
        // Stop auto-refresh timers
        this.pauseUpdates();
        
        // Cleanup components
        Object.values(this.components).forEach(component => {
            if (component && typeof component.destroy === 'function') {
                component.destroy();
            }
        });
        
        // Remove event listeners
        window.removeEventListener('back-button-click', this.handleBackButton);
        window.removeEventListener('main-button-click', this.handleMainButton);
        window.removeEventListener('auth-required', this.handleAuthenticationRequired);
        window.removeEventListener('popstate', this.handlePopState);
        
        this.isInitialized = false;
        this.isAuthenticated = false;
    }
}

/**
 * Initialize app when DOM is ready
 */
document.addEventListener('DOMContentLoaded', async () => {
    // Create global app instance
    window.app = new App();
    
    // Initialize the app
    await window.app.init();
});

/**
 * Handle page load from URL parameters
 */
window.addEventListener('load', () => {
    const urlParams = new URLSearchParams(window.location.search);
    const page = urlParams.get('page');
    
    if (page && window.app && window.app.isAppInitialized()) {
        window.app.navigateToPage(page, false);
    }
});

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { App };
}