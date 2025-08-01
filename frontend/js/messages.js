/**
 * Messages Component
 * Handles message sending, message history, and recipient management
 */

class MessagesManager {
    constructor() {
        this.recentMessages = [];
        this.isLoading = false;
        this.isSending = false;
        this.isVisible = false;
        
        // Bind methods
        this.sendMessage = this.sendMessage.bind(this);
        this.loadRecentMessages = this.loadRecentMessages.bind(this);
        this.handleRecipientTypeChange = this.handleRecipientTypeChange.bind(this);
        this.validateMessage = this.validateMessage.bind(this);
    }

    /**
     * Initialize messages manager
     */
    async init() {
        try {
            // Set up event listeners
            this.setupEventListeners();
            
            // Load recent messages
            await this.loadRecentMessages();
            
            console.log('Messages manager initialized successfully');
        } catch (error) {
            console.error('Failed to initialize messages manager:', error);
            window.showToast('Failed to load messages', 'error');
        }
    }

    /**
     * Set up event listeners
     */
    setupEventListeners() {
        // Send message button
        const sendButton = document.getElementById('send-message');
        if (sendButton) {
            sendButton.addEventListener('click', this.sendMessage);
        }

        // Recipient type change
        const recipientTypeSelect = document.getElementById('recipient-type');
        if (recipientTypeSelect) {
            recipientTypeSelect.addEventListener('change', this.handleRecipientTypeChange);
        }

        // Message text area - handle Enter key
        const messageTextArea = document.getElementById('message-text');
        if (messageTextArea) {
            messageTextArea.addEventListener('keypress', (e) => {
                if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
                    e.preventDefault();
                    this.sendMessage();
                }
            });

            // Auto-resize textarea
            messageTextArea.addEventListener('input', this.autoResizeTextarea);
        }

        // Specific user input - validation and suggestions
        const specificUserInput = document.getElementById('specific-user');
        if (specificUserInput) {
            specificUserInput.addEventListener('input', this.handleSpecificUserInput.bind(this));
            specificUserInput.addEventListener('blur', this.validateSpecificUser.bind(this));
        }
    }

    /**
     * Set visibility and load data when needed
     */
    setVisible(visible) {
        this.isVisible = visible;
        
        if (visible) {
            this.loadRecentMessages();
            
            // Focus on message text area
            setTimeout(() => {
                const messageTextArea = document.getElementById('message-text');
                if (messageTextArea) {
                    messageTextArea.focus();
                }
            }, 100);
        }
    }

    /**
     * Handle recipient type change
     */
    handleRecipientTypeChange(event) {
        const recipientType = event.target.value;
        const specificUserGroup = document.getElementById('specific-user-group');
        
        if (specificUserGroup) {
            if (recipientType === 'specific') {
                specificUserGroup.style.display = 'block';
                
                // Focus on specific user input
                setTimeout(() => {
                    const specificUserInput = document.getElementById('specific-user');
                    if (specificUserInput) {
                        specificUserInput.focus();
                    }
                }, 100);
            } else {
                specificUserGroup.style.display = 'none';
            }
        }

        // Trigger haptic feedback
        if (window.hapticSelection) {
            window.hapticSelection();
        }
    }

    /**
     * Send message
     */
    async sendMessage() {
        if (this.isSending) return;

        // Validate message
        const validation = this.validateMessage();
        if (!validation.isValid) {
            window.showToast(validation.message, 'error');
            return;
        }

        this.isSending = true;

        try {
            // Show sending state
            const sendButton = document.getElementById('send-message');
            const originalText = sendButton.textContent;
            sendButton.textContent = 'Sending...';
            sendButton.disabled = true;

            // Trigger haptic feedback
            if (window.hapticImpact) {
                window.hapticImpact('medium');
            }

            // Collect message data
            const messageData = this.collectMessageData();
            
            // Send message
            const result = await window.apiClient.sendMessage(messageData);
            
            // Show success message
            const recipientCount = result.recipientCount || 1;
            const successMessage = recipientCount === 1 
                ? 'Message sent successfully'
                : `Message sent to ${recipientCount} users`;
            
            window.showToast(successMessage, 'success');
            
            // Clear form
            this.clearMessageForm();
            
            // Reload recent messages
            await this.loadRecentMessages();
            
            // Trigger success haptic feedback
            if (window.hapticNotification) {
                window.hapticNotification('success');
            }

        } catch (error) {
            console.error('Failed to send message:', error);
            
            if (error.status === 401) {
                // Authentication error will be handled by API client
                return;
            }
            
            let errorMessage = 'Failed to send message';
            if (error.status === 400) {
                errorMessage = error.data?.message || 'Invalid message data';
            } else if (error.status === 404) {
                errorMessage = 'User not found';
            } else if (error.status === 503) {
                errorMessage = 'Bot is not active';
            }
            
            window.showToast(errorMessage, 'error');
            
            // Trigger error haptic feedback
            if (window.hapticNotification) {
                window.hapticNotification('error');
            }
            
        } finally {
            this.isSending = false;
            
            // Restore send button
            const sendButton = document.getElementById('send-message');
            sendButton.textContent = 'Send Message';
            sendButton.disabled = false;
        }
    }

    /**
     * Collect message data from form
     */
    collectMessageData() {
        const recipientTypeSelect = document.getElementById('recipient-type');
        const specificUserInput = document.getElementById('specific-user');
        const messageTextArea = document.getElementById('message-text');

        const messageData = {
            text: messageTextArea ? messageTextArea.value.trim() : '',
            recipientType: recipientTypeSelect ? recipientTypeSelect.value : 'all'
        };

        // Add specific user if selected
        if (messageData.recipientType === 'specific' && specificUserInput) {
            const userIdentifier = specificUserInput.value.trim();
            
            // Check if it's a user ID (numeric) or username
            if (/^\d+$/.test(userIdentifier)) {
                messageData.recipientId = parseInt(userIdentifier);
            } else {
                messageData.recipientUsername = userIdentifier.replace('@', '');
            }
        }

        return messageData;
    }

    /**
     * Validate message before sending
     */
    validateMessage() {
        const messageData = this.collectMessageData();

        // Check message text
        if (!messageData.text) {
            return {
                isValid: false,
                message: 'Message text is required'
            };
        }

        if (messageData.text.length > 4096) {
            return {
                isValid: false,
                message: 'Message is too long (max 4096 characters)'
            };
        }

        // Check specific user if selected
        if (messageData.recipientType === 'specific') {
            if (!messageData.recipientId && !messageData.recipientUsername) {
                return {
                    isValid: false,
                    message: 'User ID or username is required'
                };
            }
        }

        return { isValid: true };
    }

    /**
     * Clear message form
     */
    clearMessageForm() {
        const messageTextArea = document.getElementById('message-text');
        const specificUserInput = document.getElementById('specific-user');
        const recipientTypeSelect = document.getElementById('recipient-type');

        if (messageTextArea) {
            messageTextArea.value = '';
            this.autoResizeTextarea({ target: messageTextArea });
        }

        if (specificUserInput) {
            specificUserInput.value = '';
        }

        if (recipientTypeSelect) {
            recipientTypeSelect.value = 'all';
            this.handleRecipientTypeChange({ target: recipientTypeSelect });
        }

        // Clear any validation errors
        this.clearAllFieldErrors();
    }

    /**
     * Load recent messages
     */
    async loadRecentMessages() {
        if (this.isLoading) return;

        this.isLoading = true;

        try {
            // Show loading state
            this.showMessagesLoadingState();

            // Fetch recent bot updates/sent messages
            const updates = await window.apiClient.getBotUpdates(0, 20);
            
            // Filter for sent messages
            this.recentMessages = updates.filter(update => 
                update.type === 'sent_message' || update.type === 'message_sent'
            );
            
            // Render messages
            this.renderRecentMessages();

        } catch (error) {
            console.error('Failed to load recent messages:', error);
            this.showMessagesErrorState();
            
            if (error.status !== 401) {
                // Don't show error toast for auth errors
                window.showToast('Failed to load recent messages', 'error');
            }
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Render recent messages list
     */
    renderRecentMessages() {
        const messagesList = document.getElementById('recent-messages');
        if (!messagesList) return;

        if (this.recentMessages.length === 0) {
            this.showMessagesEmptyState();
            return;
        }

        // Clear existing content
        messagesList.innerHTML = '';

        // Render each message
        this.recentMessages.forEach(message => {
            const messageElement = this.createMessageElement(message);
            messagesList.appendChild(messageElement);
        });
    }

    /**
     * Create message list item element
     */
    createMessageElement(message) {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'message-item';
        
        const recipientText = this.getRecipientText(message);
        const messageText = this.truncateText(message.text || message.content || '', 100);
        const timeText = window.formatUtils.formatRelativeTime(message.timestamp || message.createdAt);

        messageDiv.innerHTML = `
            <div class="message-header">
                <div class="message-recipient">${this.escapeHtml(recipientText)}</div>
                <div class="message-time">${timeText}</div>
            </div>
            <div class="message-text">${this.escapeHtml(messageText)}</div>
            ${message.status ? `<div class="message-status ${message.status}">${this.getStatusText(message.status)}</div>` : ''}
        `;

        // Add click handler to view full message
        messageDiv.addEventListener('click', () => {
            this.showMessageDetails(message);
        });

        return messageDiv;
    }

    /**
     * Get recipient text for display
     */
    getRecipientText(message) {
        if (message.recipientType === 'all') {
            return 'All Users';
        } else if (message.recipientType === 'active') {
            return 'Active Users';
        } else if (message.recipientType === 'specific') {
            return message.recipientUsername 
                ? `@${message.recipientUsername}`
                : `User ID: ${message.recipientId}`;
        }
        return 'Unknown';
    }

    /**
     * Get status text for display
     */
    getStatusText(status) {
        const statusMap = {
            'sent': 'Sent',
            'delivered': 'Delivered', 
            'failed': 'Failed',
            'pending': 'Pending'
        };
        return statusMap[status] || status;
    }

    /**
     * Show message details in dialog
     */
    async showMessageDetails(message) {
        if (window.hapticImpact) {
            window.hapticImpact('light');
        }

        const content = `
            <div class="message-details-content">
                <div class="message-details-header">
                    <h4>Message Details</h4>
                    <div class="message-meta">
                        <span><strong>To:</strong> ${this.escapeHtml(this.getRecipientText(message))}</span>
                        <span><strong>Sent:</strong> ${new Date(message.timestamp || message.createdAt).toLocaleString()}</span>
                        ${message.status ? `<span><strong>Status:</strong> ${this.getStatusText(message.status)}</span>` : ''}
                    </div>
                </div>
                <div class="message-details-body">
                    <h5>Message Text:</h5>
                    <div class="message-full-text">${this.escapeHtml(message.text || message.content || '')}</div>
                </div>
                ${message.error ? `
                <div class="message-details-error">
                    <h5>Error:</h5>
                    <div class="error-text">${this.escapeHtml(message.error)}</div>
                </div>
                ` : ''}
            </div>
        `;

        // Create custom dialog
        const dialog = document.createElement('div');
        dialog.className = 'dialog-overlay';
        dialog.innerHTML = `
            <div class="dialog message-details-dialog">
                <div class="dialog-content">
                    ${content}
                </div>
                <div class="dialog-actions">
                    <button class="secondary-button" data-action="close">Close</button>
                    <button class="primary-button" data-action="resend">Send Similar</button>
                </div>
            </div>
        `;

        // Add to DOM
        document.body.appendChild(dialog);

        // Set up event handlers
        dialog.addEventListener('click', (e) => {
            if (e.target === dialog || e.target.dataset.action === 'close') {
                this.closeMessageDetailsDialog(dialog);
            } else if (e.target.dataset.action === 'resend') {
                this.closeMessageDetailsDialog(dialog);
                this.prefillMessageForm(message);
            }
        });

        // Show with animation
        requestAnimationFrame(() => {
            dialog.style.display = 'flex';
        });
    }

    /**
     * Close message details dialog
     */
    closeMessageDetailsDialog(dialog) {
        dialog.style.display = 'none';
        setTimeout(() => {
            if (dialog.parentElement) {
                dialog.parentElement.removeChild(dialog);
            }
        }, 300);
    }

    /**
     * Prefill message form with existing message data
     */
    prefillMessageForm(message) {
        const recipientTypeSelect = document.getElementById('recipient-type');
        const specificUserInput = document.getElementById('specific-user');
        const messageTextArea = document.getElementById('message-text');

        // Set recipient type
        if (recipientTypeSelect && message.recipientType) {
            recipientTypeSelect.value = message.recipientType;
            this.handleRecipientTypeChange({ target: recipientTypeSelect });
        }

        // Set specific user if applicable
        if (specificUserInput && message.recipientType === 'specific') {
            const userIdentifier = message.recipientUsername 
                ? `@${message.recipientUsername}`
                : message.recipientId?.toString() || '';
            specificUserInput.value = userIdentifier;
        }

        // Set message text
        if (messageTextArea && message.text) {
            messageTextArea.value = message.text;
            this.autoResizeTextarea({ target: messageTextArea });
            messageTextArea.focus();
            messageTextArea.setSelectionRange(0, 0); // Place cursor at start
        }
    }

    /**
     * Handle specific user input with suggestions
     */
    async handleSpecificUserInput(event) {
        const input = event.target;
        const value = input.value.trim();
        
        // Clear previous validation errors
        this.clearFieldError(input);

        // TODO: Implement user suggestions dropdown
        // This would fetch users matching the input and show suggestions
    }

    /**
     * Validate specific user input
     */
    validateSpecificUser(event) {
        const input = event.target;
        const value = input.value.trim();
        
        this.clearFieldError(input);

        if (!value) {
            this.showFieldError(input, 'User ID or username is required');
            return;
        }

        // Validate format (either numeric ID or username)
        const isNumeric = /^\d+$/.test(value);
        const isUsername = /^@?[a-zA-Z0-9_]{5,32}$/.test(value);

        if (!isNumeric && !isUsername) {
            this.showFieldError(input, 'Enter valid user ID (numbers) or username (@username)');
            return;
        }
    }

    /**
     * Auto-resize textarea based on content
     */
    autoResizeTextarea(event) {
        const textarea = event.target;
        textarea.style.height = 'auto';
        textarea.style.height = Math.min(textarea.scrollHeight, 200) + 'px';

        // Update character count if exists
        const messageText = textarea.value;
        const charCount = messageText.length;
        const maxChars = 4096;
        
        // You could add a character counter here
        const counterElement = document.getElementById('char-counter');
        if (counterElement) {
            counterElement.textContent = `${charCount}/${maxChars}`;
            counterElement.classList.toggle('limit-exceeded', charCount > maxChars);
        }
    }

    /**
     * Show field validation error
     */
    showFieldError(input, message) {
        this.clearFieldError(input);

        input.classList.add('error');

        const errorElement = document.createElement('div');
        errorElement.className = 'field-error';
        errorElement.textContent = message;
        errorElement.dataset.fieldError = input.id;

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
     * Clear all field errors
     */
    clearAllFieldErrors() {
        document.querySelectorAll('.field-error').forEach(error => error.remove());
        document.querySelectorAll('.error').forEach(element => element.classList.remove('error'));
    }

    /**
     * Show messages loading state
     */
    showMessagesLoadingState() {
        const messagesList = document.getElementById('recent-messages');
        if (!messagesList) return;

        messagesList.innerHTML = `
            <div class="loading-state">
                <div class="loading-spinner"></div>
                <p>Loading recent messages...</p>
            </div>
        `;
    }

    /**
     * Show messages error state
     */
    showMessagesErrorState() {
        const messagesList = document.getElementById('recent-messages');
        if (!messagesList) return;

        messagesList.innerHTML = `
            <div class="error-state">
                <div class="error-icon">
                    <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
                        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                        <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
                        <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
                    </svg>
                </div>
                <h3>Failed to load messages</h3>
                <p>Please check your connection and try again.</p>
                <button class="primary-button" onclick="window.messagesManager.loadRecentMessages()">
                    Try Again
                </button>
            </div>
        `;
    }

    /**
     * Show messages empty state
     */
    showMessagesEmptyState() {
        const messagesList = document.getElementById('recent-messages');
        if (!messagesList) return;

        messagesList.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">
                    <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
                        <path d="M21 15C21 15.5304 20.7893 16.0391 20.4142 16.4142C20.0391 16.7893 19.5304 17 19 17H7L3 21V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H19C19.5304 3 20.0391 3.21071 20.4142 3.58579C20.7893 3.96086 21 4.46957 21 5V15Z" stroke="currentColor" stroke-width="2"/>
                    </svg>
                </div>
                <h3>No Recent Messages</h3>
                <p>Messages you send will appear here.</p>
            </div>
        `;
    }

    /**
     * Truncate text to specified length
     */
    truncateText(text, maxLength) {
        if (!text || text.length <= maxLength) return text;
        return text.substring(0, maxLength) + '...';
    }

    /**
     * Escape HTML to prevent XSS
     */
    escapeHtml(text) {
        if (!text) return '';
        return text.toString()
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }
}

// Create global messages manager instance
window.messagesManager = new MessagesManager();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { MessagesManager };
}