/**
 * Service Worker for AjudadoraBot Manager
 * Provides offline functionality and caching
 */

const CACHE_NAME = 'ajudadorabot-v1.0.0';
const STATIC_CACHE_NAME = 'ajudadorabot-static-v1.0.0';
const DYNAMIC_CACHE_NAME = 'ajudadorabot-dynamic-v1.0.0';

// Static assets to cache
const STATIC_ASSETS = [
    '/',
    '/index.html',
    '/css/styles.css',
    '/js/api.js',
    '/js/auth.js',
    '/js/utils.js',
    '/js/dashboard.js',
    '/js/users.js',
    '/js/messages.js',
    '/js/settings.js',
    '/js/app.js',
    'https://telegram.org/js/telegram-web-app.js'
];

// API endpoints that can work offline (read-only cached data)
const CACHEABLE_API_ENDPOINTS = [
    '/api/analytics/stats',
    '/api/users',
    '/api/bot'
];

// Maximum cache size for dynamic content
const MAX_DYNAMIC_CACHE_SIZE = 50;

/**
 * Install event - cache static assets
 */
self.addEventListener('install', (event) => {
    console.log('Service Worker: Installing...');
    
    event.waitUntil(
        caches.open(STATIC_CACHE_NAME)
            .then((cache) => {
                console.log('Service Worker: Caching static assets');
                return cache.addAll(STATIC_ASSETS);
            })
            .then(() => {
                console.log('Service Worker: Static assets cached');
                return self.skipWaiting();
            })
            .catch((error) => {
                console.error('Service Worker: Failed to cache static assets', error);
            })
    );
});

/**
 * Activate event - clean up old caches
 */
self.addEventListener('activate', (event) => {
    console.log('Service Worker: Activating...');
    
    event.waitUntil(
        caches.keys()
            .then((cacheNames) => {
                return Promise.all(
                    cacheNames.map((cacheName) => {
                        if (cacheName !== STATIC_CACHE_NAME && 
                            cacheName !== DYNAMIC_CACHE_NAME &&
                            cacheName.startsWith('ajudadorabot-')) {
                            console.log('Service Worker: Deleting old cache', cacheName);
                            return caches.delete(cacheName);
                        }
                    })
                );
            })
            .then(() => {
                console.log('Service Worker: Activated');
                return self.clients.claim();
            })
    );
});

/**
 * Fetch event - serve from cache or network
 */
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = new URL(request.url);
    
    // Skip non-GET requests
    if (request.method !== 'GET') {
        return;
    }
    
    // Handle different types of requests
    if (isStaticAsset(request)) {
        event.respondWith(handleStaticAsset(request));
    } else if (isApiRequest(request)) {
        event.respondWith(handleApiRequest(request));
    } else {
        event.respondWith(handleOtherRequest(request));
    }
});

/**
 * Check if request is for a static asset
 */
function isStaticAsset(request) {
    const url = new URL(request.url);
    
    // Check if it's one of our static assets
    return STATIC_ASSETS.some(asset => {
        if (asset.startsWith('http')) {
            return url.href === asset;
        }
        return url.pathname === asset || url.pathname.endsWith(asset);
    });
}

/**
 * Check if request is for API
 */
function isApiRequest(request) {
    const url = new URL(request.url);
    return url.pathname.startsWith('/api/');
}

/**
 * Handle static asset requests - cache first strategy
 */
async function handleStaticAsset(request) {
    try {
        // Try cache first
        const cachedResponse = await caches.match(request);
        if (cachedResponse) {
            return cachedResponse;
        }
        
        // If not in cache, fetch from network and cache
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            const cache = await caches.open(STATIC_CACHE_NAME);
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
        
    } catch (error) {
        console.error('Service Worker: Failed to serve static asset', error);
        
        // Return offline page or fallback
        return new Response('Offline - Asset not available', {
            status: 503,
            statusText: 'Service Unavailable'
        });
    }
}

/**
 * Handle API requests - network first with cache fallback
 */
async function handleApiRequest(request) {
    const url = new URL(request.url);
    
    try {
        // Try network first
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            // Cache GET responses for read-only endpoints
            if (isCacheableApiEndpoint(url.pathname)) {
                const cache = await caches.open(DYNAMIC_CACHE_NAME);
                cache.put(request, networkResponse.clone());
                
                // Limit cache size
                await limitCacheSize(DYNAMIC_CACHE_NAME, MAX_DYNAMIC_CACHE_SIZE);
            }
        }
        
        return networkResponse;
        
    } catch (error) {
        console.log('Service Worker: Network failed, trying cache for API request');
        
        // Try cache fallback for read-only endpoints
        if (isCacheableApiEndpoint(url.pathname)) {
            const cachedResponse = await caches.match(request);
            if (cachedResponse) {
                // Add offline indicator header
                const response = cachedResponse.clone();
                response.headers.set('X-Served-By', 'service-worker-cache');
                return response;
            }
        }
        
        // Return offline response
        return new Response(JSON.stringify({
            error: 'Offline',
            message: 'This feature is not available offline'
        }), {
            status: 503,
            statusText: 'Service Unavailable',
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }
}

/**
 * Handle other requests - network with cache fallback
 */
async function handleOtherRequest(request) {
    try {
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            const cache = await caches.open(DYNAMIC_CACHE_NAME);
            cache.put(request, networkResponse.clone());
            await limitCacheSize(DYNAMIC_CACHE_NAME, MAX_DYNAMIC_CACHE_SIZE);
        }
        
        return networkResponse;
        
    } catch (error) {
        // Try cache fallback
        const cachedResponse = await caches.match(request);
        if (cachedResponse) {
            return cachedResponse;
        }
        
        // Return offline response
        return new Response('Offline - Content not available', {
            status: 503,
            statusText: 'Service Unavailable'
        });
    }
}

/**
 * Check if API endpoint can be cached
 */
function isCacheableApiEndpoint(pathname) {
    return CACHEABLE_API_ENDPOINTS.some(endpoint => 
        pathname.startsWith(endpoint)
    );
}

/**
 * Limit cache size by removing oldest entries
 */
async function limitCacheSize(cacheName, maxSize) {
    const cache = await caches.open(cacheName);
    const keys = await cache.keys();
    
    if (keys.length > maxSize) {
        const keysToDelete = keys.slice(0, keys.length - maxSize);
        await Promise.all(keysToDelete.map(key => cache.delete(key)));
    }
}

/**
 * Handle background sync for failed requests
 */
self.addEventListener('sync', (event) => {
    if (event.tag === 'background-sync-messages') {
        event.waitUntil(syncFailedMessages());
    } else if (event.tag === 'background-sync-settings') {
        event.waitUntil(syncFailedSettings());
    }
});

/**
 * Sync failed message sends
 */
async function syncFailedMessages() {
    try {
        // Get failed messages from IndexedDB or localStorage
        const failedMessages = await getFailedMessages();
        
        for (const message of failedMessages) {
            try {
                const response = await fetch('/api/bot/send-message', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${message.token}`
                    },
                    body: JSON.stringify(message.data)
                });
                
                if (response.ok) {
                    await removeFailedMessage(message.id);
                    
                    // Notify the app about successful sync
                    const clients = await self.clients.matchAll();
                    clients.forEach(client => {
                        client.postMessage({
                            type: 'message-synced',
                            messageId: message.id
                        });
                    });
                }
                
            } catch (error) {
                console.error('Service Worker: Failed to sync message', error);
            }
        }
        
    } catch (error) {
        console.error('Service Worker: Background sync failed', error);
    }
}

/**
 * Sync failed settings updates
 */
async function syncFailedSettings() {
    try {
        // Similar to syncFailedMessages but for settings
        const failedSettings = await getFailedSettings();
        
        for (const setting of failedSettings) {
            try {
                const response = await fetch('/api/bot', {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${setting.token}`
                    },
                    body: JSON.stringify(setting.data)
                });
                
                if (response.ok) {
                    await removeFailedSetting(setting.id);
                    
                    // Notify the app about successful sync
                    const clients = await self.clients.matchAll();
                    clients.forEach(client => {
                        client.postMessage({
                            type: 'settings-synced',
                            settingId: setting.id
                        });
                    });
                }
                
            } catch (error) {
                console.error('Service Worker: Failed to sync setting', error);
            }
        }
        
    } catch (error) {
        console.error('Service Worker: Settings sync failed', error);
    }
}

/**
 * Handle push notifications (for future use)
 */
self.addEventListener('push', (event) => {
    if (!event.data) return;
    
    const data = event.data.json();
    
    const options = {
        body: data.body,
        icon: '/icon-192.png',
        badge: '/badge-72.png',
        data: data.data || {},
        actions: data.actions || []
    };
    
    event.waitUntil(
        self.registration.showNotification(data.title, options)
    );
});

/**
 * Handle notification clicks
 */
self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    
    const data = event.notification.data;
    
    event.waitUntil(
        clients.matchAll().then((clientList) => {
            // Try to focus existing window
            for (const client of clientList) {
                if (client.url === '/' && 'focus' in client) {
                    return client.focus();
                }
            }
            
            // Open new window if none exists
            if (clients.openWindow) {
                return clients.openWindow('/');
            }
        })
    );
});

/**
 * Helper functions for IndexedDB operations (simplified)
 */
async function getFailedMessages() {
    // This would normally use IndexedDB
    // For now, return empty array
    return [];
}

async function removeFailedMessage(id) {
    // This would normally remove from IndexedDB
    console.log('Removing failed message:', id);
}

async function getFailedSettings() {
    // This would normally use IndexedDB
    return [];
}

async function removeFailedSetting(id) {
    // This would normally remove from IndexedDB
    console.log('Removing failed setting:', id);
}

/**
 * Handle service worker messages from the app
 */
self.addEventListener('message', (event) => {
    const { type, data } = event.data;
    
    switch (type) {
        case 'SKIP_WAITING':
            self.skipWaiting();
            break;
            
        case 'CACHE_API_RESPONSE':
            // Cache specific API response
            cacheApiResponse(data.request, data.response);
            break;
            
        case 'CLEAR_CACHE':
            // Clear specific cache
            clearCache(data.cacheName);
            break;
            
        default:
            console.log('Service Worker: Unknown message type', type);
    }
});

/**
 * Cache specific API response
 */
async function cacheApiResponse(request, response) {
    try {
        const cache = await caches.open(DYNAMIC_CACHE_NAME);
        await cache.put(request, response);
        await limitCacheSize(DYNAMIC_CACHE_NAME, MAX_DYNAMIC_CACHE_SIZE);
    } catch (error) {
        console.error('Service Worker: Failed to cache API response', error);
    }
}

/**
 * Clear specific cache
 */
async function clearCache(cacheName) {
    try {
        await caches.delete(cacheName);
        console.log('Service Worker: Cache cleared', cacheName);
    } catch (error) {
        console.error('Service Worker: Failed to clear cache', error);
    }
}