/**
 * Dashboard Component
 * Handles real-time statistics, charts, and activity feeds
 */

class Dashboard {
    constructor() {
        this.refreshInterval = null;
        this.chart = null;
        this.chartData = {
            labels: [],
            datasets: [{
                label: 'Interactions',
                data: [],
                borderColor: 'var(--primary-color)',
                backgroundColor: 'rgba(36, 129, 204, 0.1)',
                borderWidth: 2,
                fill: true,
                tension: 0.4
            }]
        };
        
        this.isVisible = false;
        this.lastUpdate = null;
        
        // Bind methods
        this.refresh = this.refresh.bind(this);
        this.updateStats = this.updateStats.bind(this);
        this.updateChart = this.updateChart.bind(this);
        this.updateActivity = this.updateActivity.bind(this);
    }

    /**
     * Initialize dashboard
     */
    async init() {
        try {
            // Initialize chart
            await this.initChart();
            
            // Load initial data
            await this.refresh();
            
            // Set up auto-refresh
            this.startAutoRefresh();
            
            console.log('Dashboard initialized successfully');
        } catch (error) {
            console.error('Failed to initialize dashboard:', error);
            window.showToast('Failed to load dashboard data', 'error');
        }
    }

    /**
     * Initialize the interactions chart
     */
    async initChart() {
        const canvas = document.getElementById('interactions-chart');
        if (!canvas) {
            console.warn('Chart canvas not found');
            return;
        }

        const ctx = canvas.getContext('2d');
        
        // Simple chart implementation without external libraries
        this.chart = new SimpleChart(ctx, {
            type: 'line',
            data: this.chartData,
            options: {
                responsive: true,
                maintainAspectRatio: false,
                animation: {
                    duration: 1000,
                    easing: 'easeInOutQuart'
                },
                scales: {
                    x: {
                        display: true,
                        title: {
                            display: true,
                            text: 'Time'
                        }
                    },
                    y: {
                        display: true,
                        title: {
                            display: true,
                            text: 'Interactions'
                        },
                        beginAtZero: true
                    }
                }
            }
        });
    }

    /**
     * Start auto-refresh interval
     */
    startAutoRefresh() {
        // Refresh every 30 seconds
        this.refreshInterval = setInterval(this.refresh, 30000);
    }

    /**
     * Stop auto-refresh interval
     */
    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
    }

    /**
     * Set dashboard visibility
     */
    setVisible(visible) {
        this.isVisible = visible;
        
        if (visible) {
            this.startAutoRefresh();
            // Refresh immediately when becoming visible
            this.refresh();
        } else {
            this.stopAutoRefresh();
        }
    }

    /**
     * Refresh all dashboard data
     */
    async refresh() {
        if (!this.isVisible) return;

        try {
            // Show loading state for stats
            this.showStatsLoading();
            
            // Fetch all data in parallel
            const [statsData, analyticsData, botStatus] = await Promise.all([
                window.apiClient.getAnalyticsStats('24h'),
                window.apiClient.getInteractionAnalytics(
                    this.getDateRange().startDate,
                    this.getDateRange().endDate
                ),
                window.apiClient.getBotStatus()
            ]);

            // Update components
            this.updateStats(statsData);
            this.updateChart(analyticsData);
            this.updateBotStatus(botStatus);
            await this.updateActivity();

            this.lastUpdate = new Date();
            
        } catch (error) {
            console.error('Failed to refresh dashboard:', error);
            this.showStatsError();
            
            if (error.status === 401) {
                // Authentication error will be handled by API client
                return;
            }
            
            window.showToast('Failed to refresh dashboard data', 'error');
        }
    }

    /**
     * Get date range for analytics (last 24 hours)
     */
    getDateRange() {
        const endDate = new Date();
        const startDate = new Date(endDate.getTime() - 24 * 60 * 60 * 1000);
        
        return {
            startDate: startDate.toISOString(),
            endDate: endDate.toISOString()
        };
    }

    /**
     * Update statistics cards
     */
    updateStats(data) {
        const elements = {
            totalUsers: document.getElementById('total-users'),
            totalInteractions: document.getElementById('total-interactions'),
            avgResponseTime: document.getElementById('avg-response-time'),
            uptime: document.getElementById('uptime')
        };

        // Animate number changes
        if (elements.totalUsers) {
            this.animateNumber(elements.totalUsers, data.totalUsers || 0);
        }
        
        if (elements.totalInteractions) {
            this.animateNumber(elements.totalInteractions, data.interactionsToday || 0);
        }
        
        if (elements.avgResponseTime) {
            const responseTime = data.averageResponseTime || 0;
            this.animateNumber(elements.avgResponseTime, responseTime, (value) => 
                window.formatUtils.formatDuration(value)
            );
        }
        
        if (elements.uptime) {
            const uptime = data.uptime || 0;
            this.animateNumber(elements.uptime, uptime, (value) => 
                Math.round(value) + '%'
            );
        }

        // Trigger haptic feedback for significant changes
        if (window.hapticSelection && this.lastUpdate) {
            window.hapticSelection();
        }
    }

    /**
     * Animate number changes in stat cards
     */
    animateNumber(element, targetValue, formatter = null) {
        const currentValue = parseInt(element.textContent) || 0;
        const difference = targetValue - currentValue;
        const duration = 1000;
        const steps = 30;
        const stepValue = difference / steps;
        const stepDuration = duration / steps;

        let currentStep = 0;
        
        const animate = () => {
            if (currentStep >= steps) {
                element.textContent = formatter ? formatter(targetValue) : window.formatUtils.formatNumber(targetValue);
                return;
            }

            const value = currentValue + (stepValue * currentStep);
            element.textContent = formatter ? formatter(value) : window.formatUtils.formatNumber(Math.round(value));
            
            currentStep++;
            setTimeout(animate, stepDuration);
        };

        animate();
    }

    /**
     * Update interactions chart
     */
    updateChart(data) {
        if (!this.chart || !data.interactions) return;

        try {
            // Process data for chart
            const processedData = this.processChartData(data.interactions);
            
            // Update chart data
            this.chartData.labels = processedData.labels;
            this.chartData.datasets[0].data = processedData.values;
            
            // Redraw chart
            this.chart.update();
            
        } catch (error) {
            console.error('Failed to update chart:', error);
        }
    }

    /**
     * Process raw interaction data for chart display
     */
    processChartData(interactions) {
        // Group interactions by hour
        const hourlyData = {};
        const now = new Date();
        
        // Initialize last 24 hours
        for (let i = 23; i >= 0; i--) {
            const hour = new Date(now.getTime() - i * 60 * 60 * 1000);
            const hourKey = hour.toISOString().substring(0, 13);
            hourlyData[hourKey] = 0;
        }

        // Count interactions per hour
        interactions.forEach(interaction => {
            const hourKey = new Date(interaction.timestamp).toISOString().substring(0, 13);
            if (hourlyData.hasOwnProperty(hourKey)) {
                hourlyData[hourKey]++;
            }
        });

        // Convert to chart format
        const labels = Object.keys(hourlyData).map(key => {
            const date = new Date(key + ':00:00Z');
            return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        });
        
        const values = Object.values(hourlyData);

        return { labels, values };
    }

    /**
     * Update bot status indicator
     */
    updateBotStatus(status) {
        const statusElement = document.getElementById('bot-status');
        const statusText = statusElement.querySelector('.status-text');
        
        if (status.isActive) {
            statusElement.classList.add('online');
            statusText.textContent = `Online (${status.mode})`;
        } else {
            statusElement.classList.remove('online');
            statusText.textContent = 'Offline';
        }
    }

    /**
     * Update recent activity feed
     */
    async updateActivity() {
        const activityList = document.getElementById('activity-list');
        if (!activityList) return;

        try {
            // Get recent bot updates/interactions
            const updates = await window.apiClient.getBotUpdates(0, 10);
            
            // Clear existing items
            activityList.innerHTML = '';
            
            if (!updates.length) {
                activityList.innerHTML = `
                    <div class="activity-item">
                        <div class="activity-icon info">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                                <path d="M12 16V12" stroke="currentColor" stroke-width="2"/>
                                <path d="M12 8H12.01" stroke="currentColor" stroke-width="2"/>
                            </svg>
                        </div>
                        <div class="activity-content">
                            <div class="activity-text">No recent activity</div>
                            <div class="activity-time">Start your bot to see interactions here</div>
                        </div>
                    </div>
                `;
                return;
            }

            // Render activity items
            updates.forEach(update => {
                const activityItem = this.createActivityItem(update);
                activityList.appendChild(activityItem);
            });
            
        } catch (error) {
            console.error('Failed to load activity:', error);
            activityList.innerHTML = `
                <div class="activity-item">
                    <div class="activity-icon error">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                            <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                            <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
                            <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
                        </svg>
                    </div>
                    <div class="activity-content">
                        <div class="activity-text">Failed to load activity</div>
                        <div class="activity-time">Please try refreshing</div>
                    </div>
                </div>
            `;
        }
    }

    /**
     * Create activity item element
     */
    createActivityItem(update) {
        const item = document.createElement('div');
        item.className = 'activity-item';
        
        const iconType = this.getActivityIconType(update.type);
        const icon = this.getActivityIcon(iconType);
        
        item.innerHTML = `
            <div class="activity-icon ${iconType}">
                ${icon}
            </div>
            <div class="activity-content">
                <div class="activity-text">${this.formatActivityText(update)}</div>
                <div class="activity-time">${window.formatUtils.formatRelativeTime(update.timestamp)}</div>
            </div>
        `;
        
        return item;
    }

    /**
     * Get activity icon type based on update type
     */
    getActivityIconType(type) {
        const typeMap = {
            'message': 'info',
            'command': 'info',
            'error': 'error',
            'start': 'success',
            'stop': 'error',
            'user_joined': 'success'
        };
        
        return typeMap[type] || 'info';
    }

    /**
     * Get SVG icon for activity type
     */
    getActivityIcon(type) {
        const icons = {
            success: `
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <polyline points="20,6 9,17 4,12" stroke="currentColor" stroke-width="2"/>
                </svg>
            `,
            error: `
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                    <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
                    <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
                </svg>
            `,
            info: `
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                    <path d="M21 15C21 15.5304 20.7893 16.0391 20.4142 16.4142C20.0391 16.7893 19.5304 17 19 17H7L3 21V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H19C19.5304 3 20.0391 3.21071 20.4142 3.58579C20.7893 3.96086 21 4.46957 21 5V15Z" stroke="currentColor" stroke-width="2"/>
                </svg>
            `
        };
        
        return icons[type] || icons.info;
    }

    /**
     * Format activity text for display
     */
    formatActivityText(update) {
        switch (update.type) {
            case 'message':
                return `Message from ${update.user?.firstName || 'User'}: ${this.truncateText(update.text, 50)}`;
            case 'command':
                return `Command executed: ${update.command}`;
            case 'error':
                return `Error: ${this.truncateText(update.message, 50)}`;
            case 'start':
                return 'Bot started';
            case 'stop':
                return 'Bot stopped';
            case 'user_joined':
                return `New user joined: ${update.user?.firstName || 'Unknown'}`;
            default:
                return update.message || 'Unknown activity';
        }
    }

    /**
     * Truncate text to specified length
     */
    truncateText(text, maxLength) {
        if (!text || text.length <= maxLength) return text;
        return text.substring(0, maxLength) + '...';
    }

    /**
     * Show loading state for stats
     */
    showStatsLoading() {
        const elements = [
            'total-users',
            'total-interactions', 
            'avg-response-time',
            'uptime'
        ];

        elements.forEach(id => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = '...';
            }
        });
    }

    /**
     * Show error state for stats
     */
    showStatsError() {
        const elements = [
            'total-users',
            'total-interactions',
            'avg-response-time', 
            'uptime'
        ];

        elements.forEach(id => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = 'Error';
            }
        });
    }

    /**
     * Cleanup dashboard resources
     */
    destroy() {
        this.stopAutoRefresh();
        
        if (this.chart) {
            this.chart.destroy();
            this.chart = null;
        }
    }
}

/**
 * Simple Chart Implementation
 * Basic line chart without external dependencies
 */
class SimpleChart {
    constructor(ctx, config) {
        this.ctx = ctx;
        this.config = config;
        this.data = config.data;
        this.options = config.options || {};
        
        this.width = ctx.canvas.width;
        this.height = ctx.canvas.height;
        
        // Set canvas size
        this.resize();
        
        // Initial draw
        this.draw();
    }

    resize() {
        const rect = this.ctx.canvas.getBoundingClientRect();
        this.ctx.canvas.width = rect.width * window.devicePixelRatio;
        this.ctx.canvas.height = rect.height * window.devicePixelRatio;
        this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
        
        this.width = rect.width;
        this.height = rect.height;
    }

    update() {
        this.draw();
    }

    draw() {
        const ctx = this.ctx;
        const data = this.data;
        
        // Clear canvas
        ctx.clearRect(0, 0, this.width, this.height);
        
        if (!data.labels.length || !data.datasets[0].data.length) {
            this.drawNoData();
            return;
        }
        
        // Calculate dimensions
        const padding = 40;
        const chartWidth = this.width - padding * 2;
        const chartHeight = this.height - padding * 2;
        
        // Get data range
        const values = data.datasets[0].data;
        const maxValue = Math.max(...values, 1);
        const minValue = Math.min(...values, 0);
        const range = maxValue - minValue || 1;
        
        // Draw grid lines
        this.drawGrid(ctx, padding, chartWidth, chartHeight, maxValue, minValue);
        
        // Draw data line
        this.drawLine(ctx, padding, chartWidth, chartHeight, values, range, minValue);
        
        // Draw data points
        this.drawPoints(ctx, padding, chartWidth, chartHeight, values, range, minValue);
    }

    drawGrid(ctx, padding, width, height, maxValue, minValue) {
        ctx.strokeStyle = getComputedStyle(document.documentElement)
            .getPropertyValue('--border-color') || '#e1e1e1';
        ctx.lineWidth = 1;
        
        // Horizontal grid lines
        const gridLines = 5;
        for (let i = 0; i <= gridLines; i++) {
            const y = padding + (height / gridLines) * i;
            ctx.beginPath();
            ctx.moveTo(padding, y);
            ctx.lineTo(padding + width, y);
            ctx.stroke();
        }
        
        // Vertical grid lines
        const dataPoints = this.data.labels.length;
        if (dataPoints > 1) {
            const stepX = width / (dataPoints - 1);
            for (let i = 0; i < dataPoints; i++) {
                const x = padding + stepX * i;
                ctx.beginPath();
                ctx.moveTo(x, padding);
                ctx.lineTo(x, padding + height);
                ctx.stroke();
            }
        }
    }

    drawLine(ctx, padding, width, height, values, range, minValue) {
        const dataset = this.data.datasets[0];
        
        ctx.strokeStyle = getComputedStyle(document.documentElement)
            .getPropertyValue('--primary-color') || '#2481cc';
        ctx.lineWidth = 2;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        
        if (values.length < 2) return;
        
        const stepX = width / (values.length - 1);
        
        ctx.beginPath();
        
        for (let i = 0; i < values.length; i++) {
            const x = padding + stepX * i;
            const y = padding + height - ((values[i] - minValue) / range) * height;
            
            if (i === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        }
        
        ctx.stroke();
        
        // Fill area under line
        if (dataset.fill) {
            ctx.fillStyle = dataset.backgroundColor || 'rgba(36, 129, 204, 0.1)';
            ctx.lineTo(padding + width, padding + height);
            ctx.lineTo(padding, padding + height);
            ctx.closePath();
            ctx.fill();
        }
    }

    drawPoints(ctx, padding, width, height, values, range, minValue) {
        ctx.fillStyle = getComputedStyle(document.documentElement)
            .getPropertyValue('--primary-color') || '#2481cc';
        
        const stepX = width / (values.length - 1);
        const pointRadius = 3;
        
        for (let i = 0; i < values.length; i++) {
            const x = padding + stepX * i;
            const y = padding + height - ((values[i] - minValue) / range) * height;
            
            ctx.beginPath();
            ctx.arc(x, y, pointRadius, 0, 2 * Math.PI);
            ctx.fill();
        }
    }

    drawNoData() {
        const ctx = this.ctx;
        ctx.fillStyle = getComputedStyle(document.documentElement)
            .getPropertyValue('--text-secondary') || '#999999';
        ctx.font = '14px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('No data available', this.width / 2, this.height / 2);
    }

    destroy() {
        // Cleanup if needed
    }
}

// Create global dashboard instance
window.dashboard = new Dashboard();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { Dashboard, SimpleChart };
}