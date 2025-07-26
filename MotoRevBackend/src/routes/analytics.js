const express = require('express');
const { query } = require('../database/connection');
const cacheService = require('../services/cacheService');
const router = express.Router();

// Dashboard overview analytics
router.get('/dashboard', async (req, res) => {
    try {
        // Check cache first
        const cached = await cacheService.getDashboardStats();
        if (cached) {
            return res.json(cached);
        }

        // User analytics
        const userStats = await query(`
            SELECT 
                COUNT(*) as total_users,
                COUNT(CASE WHEN created_at > DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as new_users_week,
                COUNT(CASE WHEN created_at > DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END) as new_users_month,
                COUNT(CASE WHEN last_active_at > DATE_SUB(NOW(), INTERVAL 24 HOUR) THEN 1 END) as active_users_day,
                COUNT(CASE WHEN status = 'online' THEN 1 END) as online_users,
                COUNT(CASE WHEN is_verified = TRUE THEN 1 END) as verified_users,
                COUNT(CASE WHEN is_premium = TRUE THEN 1 END) as premium_users
            FROM users 
            WHERE deleted_at IS NULL
        `);

        // Content analytics
        const contentStats = await query(`
            SELECT 
                COUNT(*) as total_posts,
                COUNT(CASE WHEN created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR) THEN 1 END) as posts_today,
                COUNT(CASE WHEN created_at > DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as posts_week,
                SUM(likes_count) as total_likes,
                SUM(comments_count) as total_comments,
                SUM(views_count) as total_views,
                AVG(likes_count) as avg_likes_per_post,
                COUNT(CASE WHEN visibility = 'public' THEN 1 END) as public_posts
            FROM posts 
            WHERE is_deleted = FALSE
        `);

        // Engagement analytics
        const engagementStats = await query(`
            SELECT 
                COUNT(DISTINCT pl.user_id) as users_who_liked,
                COUNT(DISTINCT pc.user_id) as users_who_commented,
                COUNT(*) as total_interactions
            FROM post_likes pl
            LEFT JOIN post_comments pc ON pl.created_at = pc.created_at
            WHERE pl.created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
        `);

        // Safety analytics
        const safetyStats = await query(`
            SELECT 
                COUNT(CASE WHEN event_type = 'crash' THEN 1 END) as crash_events,
                COUNT(CASE WHEN event_type = 'breakdown' THEN 1 END) as breakdown_events,
                COUNT(CASE WHEN status = 'active' THEN 1 END) as active_emergencies,
                AVG(CASE WHEN resolved_at IS NOT NULL THEN 
                    TIMESTAMPDIFF(MINUTE, created_at, resolved_at) END) as avg_response_time
            FROM emergency_events
            WHERE created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
        `);

        // Social network metrics
        const socialStats = await query(`
            SELECT 
                COUNT(*) as total_follows,
                COUNT(CASE WHEN created_at > DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as new_follows_week,
                COUNT(DISTINCT follower_id) as users_following_others,
                COUNT(DISTINCT following_id) as users_with_followers
            FROM followers
        `);

        // Riding analytics
        const ridingStats = await query(`
            SELECT 
                COUNT(*) as total_rides,
                COUNT(CASE WHEN started_at > DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as rides_week,
                AVG(distance_miles) as avg_distance,
                AVG(safety_score) as avg_safety_score,
                SUM(distance_miles) as total_miles
            FROM rides
            WHERE completed_at IS NOT NULL
        `);

        const dashboard = {
            users: userStats[0],
            content: contentStats[0],
            engagement: engagementStats[0],
            safety: safetyStats[0],
            social: socialStats[0],
            riding: ridingStats[0],
            timestamp: new Date().toISOString()
        };

        // Cache for 5 minutes
        await cacheService.setDashboardStats(dashboard);

        res.json(dashboard);
    } catch (error) {
        console.error('Dashboard analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch dashboard analytics' });
    }
});

// User growth analytics
router.get('/users/growth', async (req, res) => {
    try {
        const { period = '30', granularity = 'day' } = req.query;
        
        const cacheKey = `user_growth_${period}_${granularity}`;
        const cached = await cacheService.getAnalytics('user_growth', `${period}_${granularity}`);
        if (cached) {
            return res.json(cached);
        }

        let dateFormat, interval;
        switch (granularity) {
            case 'hour':
                dateFormat = '%Y-%m-%d %H:00:00';
                interval = 'HOUR';
                break;
            case 'week':
                dateFormat = '%Y-%u';
                interval = 'WEEK';
                break;
            case 'month':
                dateFormat = '%Y-%m';
                interval = 'MONTH';
                break;
            default:
                dateFormat = '%Y-%m-%d';
                interval = 'DAY';
        }

        const growth = await query(`
            SELECT 
                DATE_FORMAT(created_at, ?) as period,
                COUNT(*) as new_users,
                COUNT(CASE WHEN is_verified = TRUE THEN 1 END) as verified_users,
                COUNT(CASE WHEN is_premium = TRUE THEN 1 END) as premium_users
            FROM users 
            WHERE created_at > DATE_SUB(NOW(), INTERVAL ? ${interval})
                AND deleted_at IS NULL
            GROUP BY DATE_FORMAT(created_at, ?)
            ORDER BY period
        `, [dateFormat, period, dateFormat]);

        await cacheService.setAnalytics('user_growth', `${period}_${granularity}`, growth);
        res.json(growth);
    } catch (error) {
        console.error('User growth analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch user growth analytics' });
    }
});

// Content engagement analytics
router.get('/content/engagement', async (req, res) => {
    try {
        const { period = '7' } = req.query;
        
        const cached = await cacheService.getAnalytics('content_engagement', period);
        if (cached) {
            return res.json(cached);
        }

        const engagement = await query(`
            SELECT 
                DATE(p.created_at) as date,
                COUNT(p.id) as posts_created,
                SUM(p.likes_count) as total_likes,
                SUM(p.comments_count) as total_comments,
                SUM(p.views_count) as total_views,
                AVG(p.likes_count) as avg_likes,
                AVG(p.comments_count) as avg_comments,
                COUNT(DISTINCT p.user_id) as unique_creators
            FROM posts p
            WHERE p.created_at > DATE_SUB(NOW(), INTERVAL ? DAY)
                AND p.is_deleted = FALSE
            GROUP BY DATE(p.created_at)
            ORDER BY date DESC
        `, [period]);

        await cacheService.setAnalytics('content_engagement', period, engagement);
        res.json(engagement);
    } catch (error) {
        console.error('Content engagement analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch content engagement analytics' });
    }
});

// Top content analytics
router.get('/content/top', async (req, res) => {
    try {
        const { metric = 'likes', period = '7', limit = 10 } = req.query;
        
        const cacheKey = `top_content_${metric}_${period}_${limit}`;
        const cached = await cacheService.getAnalytics('top_content', cacheKey);
        if (cached) {
            return res.json(cached);
        }

        let orderBy;
        switch (metric) {
            case 'comments':
                orderBy = 'p.comments_count';
                break;
            case 'views':
                orderBy = 'p.views_count';
                break;
            case 'engagement':
                orderBy = '(p.likes_count * 2 + p.comments_count * 3 + p.views_count * 0.1)';
                break;
            default:
                orderBy = 'p.likes_count';
        }

        const topContent = await query(`
            SELECT 
                p.id,
                p.content,
                p.likes_count,
                p.comments_count,
                p.views_count,
                p.created_at,
                u.username,
                u.profile_picture_url,
                u.is_verified,
                (p.likes_count * 2 + p.comments_count * 3 + p.views_count * 0.1) as engagement_score
            FROM posts p
            JOIN users u ON p.user_id = u.id
            WHERE p.created_at > DATE_SUB(NOW(), INTERVAL ? DAY)
                AND p.is_deleted = FALSE
                AND p.visibility = 'public'
            ORDER BY ${orderBy} DESC
            LIMIT ?
        `, [period, parseInt(limit)]);

        await cacheService.setAnalytics('top_content', cacheKey, topContent);
        res.json(topContent);
    } catch (error) {
        console.error('Top content analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch top content analytics' });
    }
});

// User activity analytics
router.get('/users/activity', async (req, res) => {
    try {
        const { period = '24' } = req.query;
        
        const cached = await cacheService.getAnalytics('user_activity', period);
        if (cached) {
            return res.json(cached);
        }

        const activity = await query(`
            SELECT 
                HOUR(timestamp) as hour,
                event_category,
                COUNT(*) as event_count,
                COUNT(DISTINCT user_id) as unique_users
            FROM analytics_events 
            WHERE timestamp > DATE_SUB(NOW(), INTERVAL ? HOUR)
            GROUP BY HOUR(timestamp), event_category
            ORDER BY hour, event_category
        `, [period]);

        await cacheService.setAnalytics('user_activity', period, activity);
        res.json(activity);
    } catch (error) {
        console.error('User activity analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch user activity analytics' });
    }
});

// Safety analytics
router.get('/safety/overview', async (req, res) => {
    try {
        const { period = '30' } = req.query;
        
        const cached = await cacheService.getAnalytics('safety_overview', period);
        if (cached) {
            return res.json(cached);
        }

        const safetyData = await query(`
            SELECT 
                DATE(created_at) as date,
                event_type,
                severity,
                COUNT(*) as incident_count,
                AVG(CASE WHEN resolved_at IS NOT NULL THEN 
                    TIMESTAMPDIFF(MINUTE, created_at, resolved_at) END) as avg_response_time
            FROM emergency_events
            WHERE created_at > DATE_SUB(NOW(), INTERVAL ? DAY)
            GROUP BY DATE(created_at), event_type, severity
            ORDER BY date DESC
        `, [period]);

        const hazardData = await query(`
            SELECT 
                DATE(created_at) as date,
                hazard_type,
                severity,
                COUNT(*) as report_count,
                SUM(confirmations_count) as total_confirmations
            FROM hazard_reports
            WHERE created_at > DATE_SUB(NOW(), INTERVAL ? DAY)
            GROUP BY DATE(created_at), hazard_type, severity
            ORDER BY date DESC
        `, [period]);

        const safetyOverview = {
            emergency_events: safetyData,
            hazard_reports: hazardData
        };

        await cacheService.setAnalytics('safety_overview', period, safetyOverview);
        res.json(safetyOverview);
    } catch (error) {
        console.error('Safety analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch safety analytics' });
    }
});

// Social network analytics
router.get('/social/network', async (req, res) => {
    try {
        const cached = await cacheService.getAnalytics('social_network', 'overview');
        if (cached) {
            return res.json(cached);
        }

        // Network growth
        const networkGrowth = await query(`
            SELECT 
                DATE(created_at) as date,
                COUNT(*) as new_connections
            FROM followers
            WHERE created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
            GROUP BY DATE(created_at)
            ORDER BY date
        `);

        // Top influencers
        const topInfluencers = await query(`
            SELECT 
                u.id,
                u.username,
                u.profile_picture_url,
                u.is_verified,
                u.followers_count,
                u.following_count,
                u.posts_count,
                ROUND(u.followers_count / NULLIF(u.following_count, 0), 2) as influence_ratio
            FROM users u
            WHERE u.deleted_at IS NULL
                AND u.followers_count > 0
            ORDER BY u.followers_count DESC
            LIMIT 20
        `);

        // Network density metrics
        const networkMetrics = await query(`
            SELECT 
                COUNT(DISTINCT follower_id) as total_following_users,
                COUNT(DISTINCT following_id) as total_followed_users,
                COUNT(*) as total_connections,
                AVG(follower_counts.follower_count) as avg_followers_per_user,
                AVG(following_counts.following_count) as avg_following_per_user
            FROM followers f
            JOIN (
                SELECT following_id, COUNT(*) as follower_count 
                FROM followers 
                GROUP BY following_id
            ) follower_counts ON f.following_id = follower_counts.following_id
            JOIN (
                SELECT follower_id, COUNT(*) as following_count 
                FROM followers 
                GROUP BY follower_id
            ) following_counts ON f.follower_id = following_counts.follower_id
        `);

        const socialNetwork = {
            growth: networkGrowth,
            top_influencers: topInfluencers,
            metrics: networkMetrics[0]
        };

        await cacheService.setAnalytics('social_network', 'overview', socialNetwork);
        res.json(socialNetwork);
    } catch (error) {
        console.error('Social network analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch social network analytics' });
    }
});

// Device and platform analytics
router.get('/platform/devices', async (req, res) => {
    try {
        const { period = '30' } = req.query;
        
        const cached = await cacheService.getAnalytics('platform_devices', period);
        if (cached) {
            return res.json(cached);
        }

        const deviceStats = await query(`
            SELECT 
                device_type,
                app_version,
                COUNT(DISTINCT user_id) as unique_users,
                COUNT(*) as total_events
            FROM analytics_events
            WHERE timestamp > DATE_SUB(NOW(), INTERVAL ? DAY)
                AND device_type IS NOT NULL
            GROUP BY device_type, app_version
            ORDER BY unique_users DESC
        `, [period]);

        await cacheService.setAnalytics('platform_devices', period, deviceStats);
        res.json(deviceStats);
    } catch (error) {
        console.error('Platform analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch platform analytics' });
    }
});

// Real-time analytics
router.get('/realtime/feed', async (req, res) => {
    try {
        // Recent events (last 5 minutes)
        const recentEvents = await query(`
            SELECT 
                ae.event_type,
                ae.event_category,
                ae.timestamp,
                u.username,
                ae.device_type
            FROM analytics_events ae
            LEFT JOIN users u ON ae.user_id = u.id
            WHERE ae.timestamp > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
            ORDER BY ae.timestamp DESC
            LIMIT 50
        `);

        // Current online users
        const onlineUsers = await query(`
            SELECT COUNT(*) as count
            FROM users 
            WHERE status = 'online' 
                AND last_active_at > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
        `);

        // Recent posts
        const recentPosts = await query(`
            SELECT 
                p.id,
                p.content,
                p.created_at,
                u.username,
                p.likes_count,
                p.comments_count
            FROM posts p
            JOIN users u ON p.user_id = u.id
            WHERE p.created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)
                AND p.is_deleted = FALSE
            ORDER BY p.created_at DESC
            LIMIT 10
        `);

        res.json({
            recent_events: recentEvents,
            online_users: onlineUsers[0].count,
            recent_posts: recentPosts,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('Real-time analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch real-time analytics' });
    }
});

module.exports = router; 