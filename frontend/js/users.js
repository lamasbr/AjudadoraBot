/**
 * Users Management Component
 * Handles user listing, search, pagination, and user details
 */

class UsersManager {
    constructor() {
        this.currentPage = 1;
        this.pageSize = 20;
        this.totalPages = 1;
        this.totalUsers = 0;
        this.currentSearch = '';
        this.users = [];
        this.isLoading = false;
        this.isVisible = false;
        
        // Debounced search function
        this.debouncedSearch = window.debounce(this.performSearch.bind(this), 500);
        
        // Bind methods
        this.loadUsers = this.loadUsers.bind(this);
        this.handleSearch = this.handleSearch.bind(this);
        this.handlePageChange = this.handlePageChange.bind(this);
        this.refresh = this.refresh.bind(this);
    }

    /**
     * Initialize users manager
     */
    async init() {
        try {
            // Set up event listeners
            this.setupEventListeners();
            
            // Load initial data
            await this.loadUsers();
            
            console.log('Users manager initialized successfully');
        } catch (error) {
            console.error('Failed to initialize users manager:', error);
            window.showToast('Failed to load users', 'error');
        }
    }

    /**
     * Set up event listeners
     */
    setupEventListeners() {
        // Search input
        const searchInput = document.getElementById('user-search');
        if (searchInput) {
            searchInput.addEventListener('input', this.handleSearch);
            searchInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    this.performSearch();
                }
            });
        }

        // Refresh button
        const refreshButton = document.getElementById('refresh-users');
        if (refreshButton) {
            refreshButton.addEventListener('click', this.refresh);
        }
    }

    /**
     * Set visibility and load data when needed
     */
    setVisible(visible) {
        this.isVisible = visible;
        
        if (visible && this.users.length === 0) {
            this.loadUsers();
        }
    }

    /**
     * Load users with current filters and pagination
     */
    async loadUsers(showLoadingToast = false) {
        if (this.isLoading) return;

        this.isLoading = true;
        
        try {
            if (showLoadingToast) {
                window.showToast('Loading users...', 'info', 2000);
            }
            
            // Show loading state
            this.showLoadingState();
            
            // Trigger haptic feedback
            if (window.hapticSelection) {
                window.hapticSelection();
            }

            // Fetch users data
            const response = await window.apiClient.getUsers(
                this.currentPage,
                this.pageSize,
                this.currentSearch
            );

            // Update state
            this.users = response.users || [];
            this.totalUsers = response.totalCount || 0;
            this.totalPages = Math.ceil(this.totalUsers / this.pageSize);

            // Update UI
            this.renderUsers();
            this.renderPagination();
            this.updateUserCount();

        } catch (error) {
            console.error('Failed to load users:', error);
            this.showErrorState();
            
            if (error.status === 401) {
                // Authentication error will be handled by API client
                return;
            }
            
            window.showToast('Failed to load users', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Handle search input
     */
    handleSearch(event) {
        const searchTerm = event.target.value.trim();
        
        if (searchTerm !== this.currentSearch) {
            this.currentSearch = searchTerm;
            this.currentPage = 1; // Reset to first page
            this.debouncedSearch();
        }
    }

    /**
     * Perform search (debounced)
     */
    async performSearch() {
        await this.loadUsers();
    }

    /**
     * Handle page navigation
     */
    async handlePageChange(newPage) {
        if (newPage === this.currentPage || newPage < 1 || newPage > this.totalPages || this.isLoading) {
            return;
        }

        this.currentPage = newPage;
        await this.loadUsers();
        
        // Scroll to top of users list
        const usersList = document.getElementById('users-list');
        if (usersList) {
            usersList.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    /**
     * Refresh users list
     */
    async refresh() {
        if (window.hapticImpact) {
            window.hapticImpact('light');
        }
        
        await this.loadUsers(true);
    }

    /**
     * Render users list
     */
    renderUsers() {
        const usersList = document.getElementById('users-list');
        if (!usersList) return;

        if (this.users.length === 0) {
            this.showEmptyState();
            return;
        }

        // Clear existing content
        usersList.innerHTML = '';

        // Render each user
        this.users.forEach(user => {
            const userElement = this.createUserElement(user);
            usersList.appendChild(userElement);
        });
    }

    /**
     * Create user list item element
     */
    createUserElement(user) {
        const userDiv = document.createElement('div');
        userDiv.className = 'user-item';
        userDiv.dataset.userId = user.id;

        // Generate user avatar (initials or photo)
        const avatarContent = user.photoUrl 
            ? `<img src="${user.photoUrl}" alt="${user.firstName}" style="width: 100%; height: 100%; border-radius: 50%; object-fit: cover;">`
            : this.getUserInitials(user);

        const lastSeen = user.lastInteraction 
            ? window.formatUtils.formatRelativeTime(user.lastInteraction)
            : 'Never';

        userDiv.innerHTML = `
            <div class="user-avatar">
                ${avatarContent}
            </div>
            <div class="user-info">
                <div class="user-name">
                    ${this.escapeHtml(this.getDisplayName(user))}
                    ${user.isPremium ? '<span class="premium-badge">★</span>' : ''}
                </div>
                <div class="user-details">
                    <span class="user-id">ID: ${user.telegramId}</span>
                    ${user.username ? `<span class="user-username">@${this.escapeHtml(user.username)}</span>` : ''}
                    <span class="user-status ${user.isActive ? 'active' : 'inactive'}">
                        <span class="status-dot"></span>
                        ${user.isActive ? 'Active' : 'Inactive'}
                    </span>
                    <span class="user-last-seen">Last seen: ${lastSeen}</span>
                </div>
            </div>
        `;

        // Add click handler for user details
        userDiv.addEventListener('click', () => {
            this.showUserDetails(user);
        });

        return userDiv;
    }

    /**
     * Get user initials for avatar
     */
    getUserInitials(user) {
        const firstName = user.firstName || '';
        const lastName = user.lastName || '';
        const initials = (firstName.charAt(0) + lastName.charAt(0)).toUpperCase() || user.username?.charAt(0).toUpperCase() || '?';
        return initials;
    }

    /**
     * Get display name for user
     */
    getDisplayName(user) {
        if (user.firstName || user.lastName) {
            return `${user.firstName || ''} ${user.lastName || ''}`.trim();
        }
        return user.username || `User ${user.telegramId}`;
    }

    /**
     * Show user details modal/page
     */
    async showUserDetails(user) {
        if (window.hapticImpact) {
            window.hapticImpact('medium');
        }

        try {
            // Fetch detailed user information
            const detailedUser = await window.apiClient.getUserById(user.id);
            
            // Create user details content
            const content = this.createUserDetailsContent(detailedUser);
            
            // Show in a dialog or navigate to details page
            await this.showUserDetailsDialog(detailedUser, content);
            
        } catch (error) {
            console.error('Failed to load user details:', error);
            window.showToast('Failed to load user details', 'error');
        }
    }

    /**
     * Create user details content
     */
    createUserDetailsContent(user) {
        const joinDate = new Date(user.createdAt).toLocaleDateString();
        const lastSeen = user.lastInteraction 
            ? window.formatUtils.formatRelativeTime(user.lastInteraction)
            : 'Never';

        return `
            <div class="user-details-content">
                <div class="user-details-header">
                    <div class="user-avatar large">
                        ${user.photoUrl 
                            ? `<img src="${user.photoUrl}" alt="${user.firstName}" style="width: 100%; height: 100%; border-radius: 50%; object-fit: cover;">`
                            : this.getUserInitials(user)
                        }
                    </div>
                    <div class="user-details-info">
                        <h3>${this.escapeHtml(this.getDisplayName(user))}</h3>
                        ${user.username ? `<p class="user-username">@${this.escapeHtml(user.username)}</p>` : ''}
                        <p class="user-status ${user.isActive ? 'active' : 'inactive'}">
                            <span class="status-dot"></span>
                            ${user.isActive ? 'Active' : 'Inactive'}
                        </p>
                    </div>
                </div>
                <div class="user-details-stats">
                    <div class="stat-item">
                        <label>Telegram ID</label>
                        <span>${user.telegramId}</span>
                    </div>
                    <div class="stat-item">
                        <label>Joined</label>
                        <span>${joinDate}</span>
                    </div>
                    <div class="stat-item">
                        <label>Last Seen</label>
                        <span>${lastSeen}</span>
                    </div>
                    <div class="stat-item">
                        <label>Total Interactions</label>
                        <span>${user.totalInteractions || 0}</span>
                    </div>
                    ${user.languageCode ? `
                    <div class="stat-item">
                        <label>Language</label>
                        <span>${user.languageCode.toUpperCase()}</span>
                    </div>
                    ` : ''}
                    ${user.isPremium ? `
                    <div class="stat-item">
                        <label>Telegram Premium</label>
                        <span>Yes ★</span>
                    </div>
                    ` : ''}
                </div>
            </div>
        `;
    }

    /**
     * Show user details in dialog
     */
    async showUserDetailsDialog(user, content) {
        // Create custom dialog for user details
        const dialog = document.createElement('div');
        dialog.className = 'dialog-overlay';
        dialog.innerHTML = `
            <div class="dialog user-details-dialog">
                <div class="dialog-header">
                    <h3>User Details</h3>
                    <button class="dialog-close">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                            <line x1="18" y1="6" x2="6" y2="18" stroke="currentColor" stroke-width="2"/>
                            <line x1="6" y1="6" x2="18" y2="18" stroke="currentColor" stroke-width="2"/>
                        </svg>
                    </button>
                </div>
                <div class="dialog-content">
                    ${content}
                </div>
                <div class="dialog-actions">
                    <button class="secondary-button" data-action="close">Close</button>
                    <button class="primary-button" data-action="message">Send Message</button>
                </div>
            </div>
        `;

        // Add to DOM
        document.body.appendChild(dialog);

        // Set up event handlers
        dialog.addEventListener('click', (e) => {
            if (e.target === dialog || e.target.closest('.dialog-close') || e.target.dataset.action === 'close') {
                this.closeUserDetailsDialog(dialog);
            } else if (e.target.dataset.action === 'message') {
                this.closeUserDetailsDialog(dialog);
                this.showSendMessageToUser(user);
            }
        });

        // Show with animation
        requestAnimationFrame(() => {
            dialog.style.display = 'flex';
        });
    }

    /**
     * Close user details dialog
     */
    closeUserDetailsDialog(dialog) {
        dialog.style.display = 'none';
        setTimeout(() => {
            if (dialog.parentElement) {
                dialog.parentElement.removeChild(dialog);
            }
        }, 300);
    }

    /**
     * Show send message interface for specific user
     */
    showSendMessageToUser(user) {
        // Switch to messages page and prefill user
        window.eventBus.emit('navigate-to-page', 'messages');
        
        // Prefill message form with user
        setTimeout(() => {
            const recipientType = document.getElementById('recipient-type');
            const specificUser = document.getElementById('specific-user');
            
            if (recipientType) {
                recipientType.value = 'specific';
                recipientType.dispatchEvent(new Event('change'));
            }
            
            if (specificUser) {
                specificUser.value = user.telegramId;
                specificUser.focus();
            }
        }, 100);
    }

    /**
     * Render pagination controls
     */
    renderPagination() {
        const paginationContainer = document.getElementById('users-pagination');
        if (!paginationContainer) return;

        if (this.totalPages <= 1) {
            paginationContainer.innerHTML = '';
            return;
        }

        let paginationHTML = '';

        // Previous button
        paginationHTML += `
            <button class="pagination-button ${this.currentPage === 1 ? 'disabled' : ''}" 
                    data-page="${this.currentPage - 1}" ${this.currentPage === 1 ? 'disabled' : ''}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <polyline points="15,18 9,12 15,6" stroke="currentColor" stroke-width="2"/>
                </svg>
            </button>
        `;

        // Page numbers
        const startPage = Math.max(1, this.currentPage - 2);
        const endPage = Math.min(this.totalPages, this.currentPage + 2);

        if (startPage > 1) {
            paginationHTML += `<button class="pagination-button" data-page="1">1</button>`;
            if (startPage > 2) {
                paginationHTML += `<span class="pagination-ellipsis">...</span>`;
            }
        }

        for (let i = startPage; i <= endPage; i++) {
            paginationHTML += `
                <button class="pagination-button ${i === this.currentPage ? 'active' : ''}" 
                        data-page="${i}">${i}</button>
            `;
        }

        if (endPage < this.totalPages) {
            if (endPage < this.totalPages - 1) {
                paginationHTML += `<span class="pagination-ellipsis">...</span>`;
            }
            paginationHTML += `<button class="pagination-button" data-page="${this.totalPages}">${this.totalPages}</button>`;
        }

        // Next button
        paginationHTML += `
            <button class="pagination-button ${this.currentPage === this.totalPages ? 'disabled' : ''}" 
                    data-page="${this.currentPage + 1}" ${this.currentPage === this.totalPages ? 'disabled' : ''}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <polyline points="9,18 15,12 9,6" stroke="currentColor" stroke-width="2"/>
                </svg>
            </button>
        `;

        // Page info
        const startItem = (this.currentPage - 1) * this.pageSize + 1;
        const endItem = Math.min(this.currentPage * this.pageSize, this.totalUsers);
        
        paginationHTML += `
            <span class="pagination-info">
                ${startItem}-${endItem} of ${this.totalUsers}
            </span>
        `;

        paginationContainer.innerHTML = paginationHTML;

        // Add click handlers
        paginationContainer.addEventListener('click', (e) => {
            const button = e.target.closest('.pagination-button');
            if (button && !button.disabled) {
                const page = parseInt(button.dataset.page);
                if (page && page !== this.currentPage) {
                    this.handlePageChange(page);
                }
            }
        });
    }

    /**
     * Update user count display
     */
    updateUserCount() {
        // Update any user count displays in the UI
        const userCountElements = document.querySelectorAll('[data-user-count]');
        userCountElements.forEach(element => {
            element.textContent = window.formatUtils.formatNumber(this.totalUsers);
        });
    }

    /**
     * Show loading state
     */
    showLoadingState() {
        const usersList = document.getElementById('users-list');
        if (!usersList) return;

        usersList.innerHTML = `
            <div class="loading-state">
                <div class="loading-spinner"></div>
                <p>Loading users...</p>
            </div>
        `;
    }

    /**
     * Show error state
     */
    showErrorState() {
        const usersList = document.getElementById('users-list');
        if (!usersList) return;

        usersList.innerHTML = `
            <div class="error-state">
                <div class="error-icon">
                    <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
                        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                        <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
                        <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
                    </svg>
                </div>
                <h3>Failed to load users</h3>
                <p>Please check your connection and try again.</p>
                <button class="primary-button" onclick="window.usersManager.refresh()">
                    Try Again
                </button>
            </div>
        `;
    }

    /**
     * Show empty state
     */
    showEmptyState() {
        const usersList = document.getElementById('users-list');
        if (!usersList) return;

        const message = this.currentSearch 
            ? `No users found matching "${this.currentSearch}"`
            : 'No users found. Start your bot to see users here.';

        usersList.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">
                    <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
                        <path d="M17 21V19C17 16.7909 15.2091 15 13 15H5C2.79086 15 1 16.7909 1 19V21" stroke="currentColor" stroke-width="2"/>
                        <circle cx="9" cy="7" r="4" stroke="currentColor" stroke-width="2"/>
                        <path d="M23 21V19C23 17.1362 21.7252 15.5701 20 15.126" stroke="currentColor" stroke-width="2"/>
                        <path d="M16 3.12598C17.7252 3.56989 19 5.13616 19 7C19 8.86384 17.7252 10.4301 16 10.874" stroke="currentColor" stroke-width="2"/>
                    </svg>
                </div>
                <h3>No Users</h3>
                <p>${message}</p>
                ${this.currentSearch ? `
                    <button class="secondary-button" onclick="document.getElementById('user-search').value = ''; window.usersManager.handleSearch({target: {value: ''}})">
                        Clear Search
                    </button>
                ` : ''}
            </div>
        `;
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

// Create global users manager instance
window.usersManager = new UsersManager();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { UsersManager };
}