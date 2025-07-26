const Redis = require('ioredis');

class CacheService {
    constructor() {
        this.redis = new Redis({
            host: process.env.REDIS_HOST || 'localhost',
            port: process.env.REDIS_PORT || 6379,
            password: process.env.REDIS_PASSWORD,
            retryDelayOnFailover: 100,
            maxRetriesPerRequest: 3,
            lazyConnect: true,
            enableAutoPipelining: true,
            keepAlive: 30000,
            family: 4,
            keyPrefix: 'motorev:',
        });

        // Error handling
        this.redis.on('error', (error) => {
            console.error('Redis connection error:', error);
        });

        this.redis.on('ready', () => {
            console.log('✅ Redis connected successfully');
        });

        this.redis.on('reconnecting', () => {
            console.log('🔄 Redis reconnecting...');
        });

        // Cache TTL constants (in seconds)
        this.TTL = {
            USER_PROFILE: 300,      // 5 minutes
            USER_FEED: 120,         // 2 minutes  
            POST_DETAILS: 600,      // 10 minutes
            TRENDING_POSTS: 180,    // 3 minutes
            USER_FOLLOWERS: 300,    // 5 minutes
            LEADERBOARD: 600,       // 10 minutes
            ANALYTICS: 300,         // 5 minutes
            HAZARD_REPORTS: 60,     // 1 minute (safety critical)
            RIDING_PACKS: 180,      // 3 minutes
            NOTIFICATIONS: 60,      // 1 minute
            SEARCH_RESULTS: 300,    // 5 minutes
            USER_STATS: 600,        // 10 minutes
            ENGAGEMENT_DATA: 120,   // 2 minutes
        };
    }

    // Generic cache operations
    async get(key) {
        try {
            const data = await this.redis.get(key);
            if (data) {
                return JSON.parse(data);
            }
            return null;
        } catch (error) {
            console.error(`Cache get error for key ${key}:`, error);
            return null;
        }
    }

    async set(key, data, ttl = 300) {
        try {
            await this.redis.setex(key, ttl, JSON.stringify(data));
            return true;
        } catch (error) {
            console.error(`Cache set error for key ${key}:`, error);
            return false;
        }
    }

    async del(key) {
        try {
            await this.redis.del(key);
            return true;
        } catch (error) {
            console.error(`Cache delete error for key ${key}:`, error);
            return false;
        }
    }

    async exists(key) {
        try {
            return await this.redis.exists(key);
        } catch (error) {
            console.error(`Cache exists error for key ${key}:`, error);
            return false;
        }
    }

    // User-specific cache operations
    async getUserProfile(userId) {
        return this.get(`user:profile:${userId}`);
    }

    async setUserProfile(userId, profile) {
        return this.set(`user:profile:${userId}`, profile, this.TTL.USER_PROFILE);
    }

    async getUserFeed(userId, page = 1) {
        return this.get(`user:feed:${userId}:page:${page}`);
    }

    async setUserFeed(userId, feed, page = 1) {
        return this.set(`user:feed:${userId}:page:${page}`, feed, this.TTL.USER_FEED);
    }

    async getUserFollowers(userId) {
        return this.get(`user:followers:${userId}`);
    }

    async setUserFollowers(userId, followers) {
        return this.set(`user:followers:${userId}`, followers, this.TTL.USER_FOLLOWERS);
    }

    async getUserStats(userId) {
        return this.get(`user:stats:${userId}`);
    }

    async setUserStats(userId, stats) {
        return this.set(`user:stats:${userId}`, stats, this.TTL.USER_STATS);
    }

    // Post-specific cache operations
    async getPost(postId) {
        return this.get(`post:${postId}`);
    }

    async setPost(postId, post) {
        return this.set(`post:${postId}`, post, this.TTL.POST_DETAILS);
    }

    async getTrendingPosts() {
        return this.get('posts:trending');
    }

    async setTrendingPosts(posts) {
        return this.set('posts:trending', posts, this.TTL.TRENDING_POSTS);
    }

    async getPostEngagement(postId) {
        return this.get(`post:engagement:${postId}`);
    }

    async setPostEngagement(postId, engagement) {
        return this.set(`post:engagement:${postId}`, engagement, this.TTL.ENGAGEMENT_DATA);
    }

    // Social features cache
    async getLeaderboard(type = 'safety') {
        return this.get(`leaderboard:${type}`);
    }

    async setLeaderboard(type, data) {
        return this.set(`leaderboard:${type}`, data, this.TTL.LEADERBOARD);
    }

    async getNotifications(userId) {
        return this.get(`notifications:${userId}`);
    }

    async setNotifications(userId, notifications) {
        return this.set(`notifications:${userId}`, notifications, this.TTL.NOTIFICATIONS);
    }

    // Safety features cache
    async getHazardReports(lat, lng, radius = 5) {
        const key = `hazards:${lat}:${lng}:${radius}`;
        return this.get(key);
    }

    async setHazardReports(lat, lng, radius, reports) {
        const key = `hazards:${lat}:${lng}:${radius}`;
        return this.set(key, reports, this.TTL.HAZARD_REPORTS);
    }

    async getRidingPacks(userId) {
        return this.get(`packs:${userId}`);
    }

    async setRidingPacks(userId, packs) {
        return this.set(`packs:${userId}`, packs, this.TTL.RIDING_PACKS);
    }

    // Analytics cache
    async getAnalytics(type, period = 'day') {
        return this.get(`analytics:${type}:${period}`);
    }

    async setAnalytics(type, period, data) {
        return this.set(`analytics:${type}:${period}`, data, this.TTL.ANALYTICS);
    }

    async getDashboardStats() {
        return this.get('dashboard:stats');
    }

    async setDashboardStats(stats) {
        return this.set('dashboard:stats', stats, this.TTL.ANALYTICS);
    }

    // Search cache
    async getSearchResults(query, type = 'all') {
        const key = `search:${type}:${Buffer.from(query).toString('base64')}`;
        return this.get(key);
    }

    async setSearchResults(query, type, results) {
        const key = `search:${type}:${Buffer.from(query).toString('base64')}`;
        return this.set(key, results, this.TTL.SEARCH_RESULTS);
    }

    // Session management
    async setUserSession(sessionToken, userData) {
        return this.set(`session:${sessionToken}`, userData, 86400); // 24 hours
    }

    async getUserSession(sessionToken) {
        return this.get(`session:${sessionToken}`);
    }

    async deleteUserSession(sessionToken) {
        return this.del(`session:${sessionToken}`);
    }

    // Rate limiting
    async checkRateLimit(key, limit = 100, window = 3600) {
        try {
            const current = await this.redis.incr(`rate:${key}`);
            if (current === 1) {
                await this.redis.expire(`rate:${key}`, window);
            }
            return {
                count: current,
                remaining: Math.max(0, limit - current),
                limit,
                reset: await this.redis.ttl(`rate:${key}`)
            };
        } catch (error) {
            console.error(`Rate limit error for key ${key}:`, error);
            return { count: 0, remaining: limit, limit, reset: window };
        }
    }

    // Cache invalidation helpers
    async invalidateUserCache(userId) {
        const patterns = [
            `user:profile:${userId}`,
            `user:feed:${userId}:*`,
            `user:followers:${userId}`,
            `user:stats:${userId}`,
            `notifications:${userId}`,
            `packs:${userId}`
        ];

        for (const pattern of patterns) {
            if (pattern.includes('*')) {
                const keys = await this.redis.keys(pattern);
                if (keys.length > 0) {
                    await this.redis.del(...keys);
                }
            } else {
                await this.del(pattern);
            }
        }
    }

    async invalidatePostCache(postId, userId) {
        const patterns = [
            `post:${postId}`,
            `post:engagement:${postId}`,
            'posts:trending',
            `user:feed:*:*` // Invalidate all user feeds
        ];

        for (const pattern of patterns) {
            if (pattern.includes('*')) {
                const keys = await this.redis.keys(pattern);
                if (keys.length > 0) {
                    await this.redis.del(...keys);
                }
            } else {
                await this.del(pattern);
            }
        }
    }

    async invalidateFollowCache(followerId, followingId) {
        await this.del(`user:followers:${followingId}`);
        await this.del(`user:followers:${followerId}`);
        
        // Invalidate feeds
        const feedKeys = await this.redis.keys(`user:feed:${followerId}:*`);
        if (feedKeys.length > 0) {
            await this.redis.del(...feedKeys);
        }
    }

    // Batch operations for performance
    async mget(keys) {
        try {
            const results = await this.redis.mget(keys);
            return results.map(result => result ? JSON.parse(result) : null);
        } catch (error) {
            console.error('Batch get error:', error);
            return new Array(keys.length).fill(null);
        }
    }

    async mset(keyValuePairs, ttl = 300) {
        try {
            const pipeline = this.redis.pipeline();
            
            for (const [key, value] of keyValuePairs) {
                pipeline.setex(key, ttl, JSON.stringify(value));
            }
            
            await pipeline.exec();
            return true;
        } catch (error) {
            console.error('Batch set error:', error);
            return false;
        }
    }

    // Health check
    async healthCheck() {
        try {
            await this.redis.ping();
            return { status: 'healthy', connected: true };
        } catch (error) {
            return { status: 'unhealthy', connected: false, error: error.message };
        }
    }

    // Performance monitoring
    async getCacheStats() {
        try {
            const info = await this.redis.info('memory');
            const stats = await this.redis.info('stats');
            
            return {
                memory: this.parseRedisInfo(info),
                stats: this.parseRedisInfo(stats),
                connected_clients: await this.redis.info('clients')
            };
        } catch (error) {
            console.error('Cache stats error:', error);
            return null;
        }
    }

    parseRedisInfo(info) {
        const lines = info.split('\r\n');
        const result = {};
        
        for (const line of lines) {
            if (line.includes(':')) {
                const [key, value] = line.split(':');
                result[key] = isNaN(value) ? value : Number(value);
            }
        }
        
        return result;
    }

    // Cleanup and shutdown
    async disconnect() {
        try {
            await this.redis.disconnect();
            console.log('✅ Redis disconnected successfully');
        } catch (error) {
            console.error('Redis disconnect error:', error);
        }
    }
}

// Create singleton instance
const cacheService = new CacheService();

module.exports = cacheService; 