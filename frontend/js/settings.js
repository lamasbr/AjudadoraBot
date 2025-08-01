/**
 * Settings Component
 * Handles bot configuration, webhook/polling mode switching, and settings management
 */

class SettingsManager {
    constructor() {
        this.currentConfig = null;
        this.isLoading = false;
        this.isSaving = false;
        this.isVisible = false;
        
        // Bind methods
        this.loadSettings = this.loadSettings.bind(this);
        this.saveSettings = this.saveSettings.bind(this);
        this.handleModeChange = this.handleModeChange.bind(this);
        this.handleBotToggle = this.handleBotToggle.bind(this);
        this.validateSettings = this.validateSettings.bind(this);
    }

    /**
     * Initialize settings manager
     */
    async init() {
        try {
            // Set up event listeners
            this.setupEventListeners();
            
            // Load current settings
            await this.loadSettings();
            
            console.log('Settings manager initialized successfully');
        } catch (error) {
            console.error('Failed to initialize settings manager:', error);
            window.showToast('Failed to load settings', 'error');
        }
    }

    /**
     * Set up event listeners
     */
    setupEventListeners() {
        // Bot active toggle
        const botActiveToggle = document.getElementById('bot-active');
        if (botActiveToggle) {
            botActiveToggle.addEventListener('change', this.handleBotToggle);
        }

        // Bot mode selector
        const botModeSelect = document.getElementById('bot-mode');
        if (botModeSelect) {
            botModeSelect.addEventListener('change', this.handleModeChange);
        }

        // Save settings button
        const saveButton = document.getElementById('save-settings');
        if (saveButton) {
            saveButton.addEventListener('click', this.saveSettings);
        }

        // Webhook URL input validation
        const webhookUrlInput = document.getElementById('webhook-url');
        if (webhookUrlInput) {
            webhookUrlInput.addEventListener('input', this.validateWebhookUrl.bind(this));
            webhookUrlInput.addEventListener('blur', this.validateWebhookUrl.bind(this));
        }

        // Bot token input validation
        const botTokenInput = document.getElementById('bot-token');
        if (botTokenInput) {
            botTokenInput.addEventListener('input', this.validateBotToken.bind(this));
            botTokenInput.addEventListener('blur', this.validateBotToken.bind(this));
        }
    }

    /**
     * Set visibility and load data when needed
     */
    setVisible(visible) {
        this.isVisible = visible;
        
        if (visible && !this.currentConfig) {
            this.loadSettings();
        }
    }

    /**
     * Load current bot settings
     */
    async loadSettings() {
        if (this.isLoading) return;

        this.isLoading = true;
        
        try {
            // Show loading state
            this.showLoadingState();
            
            // Fetch current bot configuration
            const config = await window.apiClient.getBotStatus();
            
            this.currentConfig = config;
            
            // Update form with current settings
            this.updateForm(config);
            
            // Hide loading state
            this.hideLoadingState();
            
        } catch (error) {
            console.error('Failed to load settings:', error);
            this.showErrorState();
            
            if (error.status === 401) {
                // Authentication error will be handled by API client
                return;
            }
            
            window.showToast('Failed to load settings', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Update form fields with current configuration
     */
    updateForm(config) {
        // Bot active toggle
        const botActiveToggle = document.getElementById('bot-active');
        if (botActiveToggle) {
            botActiveToggle.checked = config.isActive || false;
        }

        // Bot mode selector
        const botModeSelect = document.getElementById('bot-mode');
        if (botModeSelect) {
            botModeSelect.value = config.mode || 'polling';
            this.handleModeChange({ target: { value: config.mode || 'polling' } });
        }

        // Webhook URL
        const webhookUrlInput = document.getElementById('webhook-url');
        if (webhookUrlInput) {
            webhookUrlInput.value = config.webhookUrl || '';
        }

        // Bot token (don't show the actual token for security)
        const botTokenInput = document.getElementById('bot-token');
        if (botTokenInput) {
            botTokenInput.value = config.hasToken ? '••••••••••••••••••••••••••••••••••••••••' : '';
            botTokenInput.placeholder = config.hasToken ? 'Token is set (hidden for security)' : 'Enter your bot token';
        }
    }

    /**
     * Handle bot mode change (polling/webhook)
     */
    handleModeChange(event) {
        const mode = event.target.value;
        const webhookConfig = document.getElementById('webhook-config');
        
        if (webhookConfig) {
            if (mode === 'webhook') {
                webhookConfig.style.display = 'block';
                // Focus on webhook URL input
                setTimeout(() => {
                    const webhookUrlInput = document.getElementById('webhook-url');
                    if (webhookUrlInput && !webhookUrlInput.value) {
                        webhookUrlInput.focus();
                    }
                }, 100);
            } else {
                webhookConfig.style.display = 'none';
            }
        }

        // Trigger haptic feedback
        if (window.hapticSelection) {
            window.hapticSelection();
        }
    }

    /**
     * Handle bot active/inactive toggle
     */
    async handleBotToggle(event) {
        const isActive = event.target.checked;
        
        // Trigger haptic feedback
        if (window.hapticImpact) {
            window.hapticImpact('medium');
        }

        try {
            if (isActive) {
                // Validate settings before starting
                const validation = this.validateSettings();
                if (!validation.isValid) {
                    // Revert toggle
                    event.target.checked = false;
                    window.showToast(validation.message, 'error');
                    return;
                }

                // Show confirmation dialog
                const confirmed = await window.showDialog(
                    'Start Bot',
                    'Are you sure you want to start the bot with current settings?',
                    'Start Bot',
                    'Cancel'
                );

                if (!confirmed) {
                    event.target.checked = false;
                    return;
                }

                // Start bot
                await window.apiClient.startBot();
                window.showToast('Bot started successfully', 'success');
                
                // Update bot status in header
                this.updateBotStatusDisplay(true);
                
            } else {
                // Show confirmation dialog
                const confirmed = await window.showDialog(
                    'Stop Bot', 
                    'Are you sure you want to stop the bot? Users will not be able to interact with it.',
                    'Stop Bot',
                    'Cancel'
                );

                if (!confirmed) {
                    event.target.checked = true;
                    return;
                }

                // Stop bot
                await window.apiClient.stopBot();
                window.showToast('Bot stopped successfully', 'success');
                
                // Update bot status in header
                this.updateBotStatusDisplay(false);
            }

        } catch (error) {
            console.error('Failed to toggle bot status:', error);
            
            // Revert toggle
            event.target.checked = !isActive;
            
            const action = isActive ? 'start' : 'stop';
            window.showToast(`Failed to ${action} bot`, 'error');
        }
    }

    /**
     * Save settings
     */
    async saveSettings() {
        if (this.isSaving) return;

        // Validate settings
        const validation = this.validateSettings();
        if (!validation.isValid) {
            window.showToast(validation.message, 'error');
            return;
        }

        this.isSaving = true;
        
        try {
            // Show saving state
            const saveButton = document.getElementById('save-settings');
            const originalText = saveButton.textContent;
            saveButton.textContent = 'Saving...';
            saveButton.disabled = true;

            // Trigger haptic feedback
            if (window.hapticImpact) {
                window.hapticImpact('light');
            }

            // Collect form data
            const formData = this.collectFormData();
            
            // Save configuration
            await window.apiClient.updateBotConfiguration(formData);
            
            // Update current config
            this.currentConfig = { ...this.currentConfig, ...formData };
            
            // Show success message
            window.showToast('Settings saved successfully', 'success');
            
            // Update bot status display
            this.updateBotStatusDisplay(formData.isActive);

        } catch (error) {
            console.error('Failed to save settings:', error);
            
            if (error.status === 401) {
                // Authentication error will be handled by API client
                return;
            }
            
            window.showToast('Failed to save settings', 'error');
        } finally {
            this.isSaving = false;
            
            // Restore save button
            const saveButton = document.getElementById('save-settings');
            saveButton.textContent = 'Save Settings';
            saveButton.disabled = false;
        }
    }

    /**
     * Collect form data
     */
    collectFormData() {
        const botActiveToggle = document.getElementById('bot-active');
        const botModeSelect = document.getElementById('bot-mode');
        const webhookUrlInput = document.getElementById('webhook-url');
        const botTokenInput = document.getElementById('bot-token');

        const formData = {
            isActive: botActiveToggle ? botActiveToggle.checked : false,
            mode: botModeSelect ? botModeSelect.value : 'polling',
            webhookUrl: webhookUrlInput ? webhookUrlInput.value.trim() : '',
        };

        // Only include token if it's not the masked value
        if (botTokenInput && botTokenInput.value && !botTokenInput.value.includes('•')) {
            formData.token = botTokenInput.value.trim();
        }

        return formData;
    }

    /**
     * Validate current settings
     */
    validateSettings() {
        const formData = this.collectFormData();

        // Check if bot token is provided
        if (!this.currentConfig?.hasToken && !formData.token) {
            return {
                isValid: false,
                message: 'Bot token is required'
            };
        }

        // Validate bot token format if provided
        if (formData.token && !window.validationUtils.isValidBotToken(formData.token)) {
            return {
                isValid: false,
                message: 'Invalid bot token format'
            };
        }

        // Validate webhook URL if webhook mode is selected
        if (formData.mode === 'webhook') {
            if (!formData.webhookUrl) {
                return {
                    isValid: false,
                    message: 'Webhook URL is required for webhook mode'
                };
            }

            if (!window.validationUtils.isValidUrl(formData.webhookUrl)) {
                return {
                    isValid: false,
                    message: 'Invalid webhook URL format'
                };
            }

            // Check if webhook URL is HTTPS
            if (!formData.webhookUrl.startsWith('https://')) {
                return {
                    isValid: false,
                    message: 'Webhook URL must use HTTPS'
                };
            }
        }

        return { isValid: true };
    }

    /**
     * Validate webhook URL input
     */
    validateWebhookUrl(event) {
        const input = event.target;
        const value = input.value.trim();
        
        this.clearFieldError(input);

        if (value && !window.validationUtils.isValidUrl(value)) {
            this.showFieldError(input, 'Invalid URL format');
            return;
        }

        if (value && !value.startsWith('https://')) {
            this.showFieldError(input, 'Webhook URL must use HTTPS');
            return;
        }
    }

    /**
     * Validate bot token input
     */
    validateBotToken(event) {
        const input = event.target;
        const value = input.value.trim();
        
        this.clearFieldError(input);

        // Skip validation for masked tokens
        if (value.includes('•')) {
            return;
        }

        if (value && !window.validationUtils.isValidBotToken(value)) {
            this.showFieldError(input, 'Invalid bot token format (should be: 123456789:ABC-DEF...)');
            return;
        }
    }

    /**
     * Show field validation error
     */
    showFieldError(input, message) {
        // Remove existing error
        this.clearFieldError(input);

        // Add error class
        input.classList.add('error');

        // Create error message element
        const errorElement = document.createElement('div');
        errorElement.className = 'field-error';
        errorElement.textContent = message;
        errorElement.dataset.fieldError = input.id;

        // Insert after input
        input.parentNode.insertBefore(errorElement, input.nextSibling);
    }

    /**
     * Clear field validation error
     */
    clearFieldError(input) {
        input.classList.remove('error');
        
        const existingError = document.querySelector(`[data-field-error="${input.id}"]`);
        if (existingError) {
            existingError.remove();
        }
    }

    /**
     * Update bot status display in header
     */
    updateBotStatusDisplay(isActive) {
        const statusElement = document.getElementById('bot-status');
        const statusText = statusElement?.querySelector('.status-text');
        
        if (statusElement && statusText) {
            if (isActive) {
                statusElement.classList.add('online');
                const mode = this.currentConfig?.mode || 'polling';
                statusText.textContent = `Online (${mode})`;
            } else {
                statusElement.classList.remove('online');
                statusText.textContent = 'Offline';
            }
        }
    }

    /**
     * Show loading state
     */
    showLoadingState() {
        const formElements = document.querySelectorAll('#settings-page input, #settings-page select, #settings-page button');
        formElements.forEach(element => {
            element.disabled = true;
        });

        const saveButton = document.getElementById('save-settings');
        if (saveButton) {
            saveButton.textContent = 'Loading...';
        }
    }

    /**
     * Hide loading state
     */
    hideLoadingState() {
        const formElements = document.querySelectorAll('#settings-page input, #settings-page select, #settings-page button');
        formElements.forEach(element => {
            element.disabled = false;
        });

        const saveButton = document.getElementById('save-settings');
        if (saveButton) {
            saveButton.textContent = 'Save Settings';
        }
    }

    /**
     * Show error state
     */
    showErrorState() {
        this.hideLoadingState();
        
        // You could add specific error UI here
        const settingsSection = document.querySelector('.settings-section');
        if (settingsSection) {
            // Add error styling or message
            settingsSection.classList.add('error-state');
        }
    }

    /**
     * Test webhook URL
     */
    async testWebhook() {
        const webhookUrlInput = document.getElementById('webhook-url');
        const webhookUrl = webhookUrlInput?.value.trim();

        if (!webhookUrl) {
            window.showToast('Enter webhook URL first', 'warning');
            return;
        }

        if (!window.validationUtils.isValidUrl(webhookUrl)) {
            window.showToast('Invalid webhook URL', 'error');
            return;
        }

        try {
            window.showToast('Testing webhook...', 'info', 3000);
            
            // You could implement a webhook test endpoint here
            // For now, just do a basic fetch to check if the URL is reachable
            const response = await fetch(webhookUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ test: true })
            });

            if (response.ok) {
                window.showToast('Webhook test successful', 'success');
            } else {
                window.showToast(`Webhook test failed: ${response.status}`, 'warning');
            }
            
        } catch (error) {
            console.error('Webhook test failed:', error);
            window.showToast('Webhook test failed - check URL and network', 'error');
        }
    }

    /**
     * Reset settings to defaults
     */
    async resetSettings() {
        const confirmed = await window.showDialog(
            'Reset Settings',
            'Are you sure you want to reset all settings to defaults? This will stop the bot if it\'s running.',
            'Reset',
            'Cancel'
        );

        if (!confirmed) return;

        try {
            // Stop bot first if active
            if (this.currentConfig?.isActive) {
                await window.apiClient.stopBot();
            }

            // Reset form to defaults
            const botActiveToggle = document.getElementById('bot-active');
            const botModeSelect = document.getElementById('bot-mode');
            const webhookUrlInput = document.getElementById('webhook-url');
            const botTokenInput = document.getElementById('bot-token');

            if (botActiveToggle) botActiveToggle.checked = false;
            if (botModeSelect) botModeSelect.value = 'polling';
            if (webhookUrlInput) webhookUrlInput.value = '';
            if (botTokenInput) botTokenInput.value = '';

            // Trigger mode change to hide webhook config
            this.handleModeChange({ target: { value: 'polling' } });

            // Clear any field errors
            document.querySelectorAll('.field-error').forEach(error => error.remove());
            document.querySelectorAll('.error').forEach(element => element.classList.remove('error'));

            window.showToast('Settings reset to defaults', 'success');

            // Update bot status display
            this.updateBotStatusDisplay(false);

        } catch (error) {
            console.error('Failed to reset settings:', error);
            window.showToast('Failed to reset settings', 'error');
        }
    }
}

// Create global settings manager instance
window.settingsManager = new SettingsManager();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { SettingsManager };
}