const { pool, query, run } = require('./connection');

async function columnExists(tableName, columnName) {
    try {
        const result = await query(`
            SELECT COUNT(*) as count 
            FROM information_schema.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = ? 
            AND COLUMN_NAME = ?
        `, [tableName, columnName]);
        
        return result[0].count > 0;
    } catch (error) {
        console.log(`Error checking column ${tableName}.${columnName}:`, error.message);
        return false;
    }
}

async function tableExists(tableName) {
    try {
        const result = await query(`
            SELECT COUNT(*) as count 
            FROM information_schema.TABLES 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = ?
        `, [tableName]);
        
        return result[0].count > 0;
    } catch (error) {
        console.log(`Error checking table ${tableName}:`, error.message);
        return false;
    }
}

async function indexExists(tableName, indexName) {
    try {
        const result = await query(`
            SELECT COUNT(*) as count 
            FROM information_schema.STATISTICS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = ? 
            AND INDEX_NAME = ?
        `, [tableName, indexName]);
        
        return result[0].count > 0;
    } catch (error) {
        console.log(`Error checking index ${tableName}.${indexName}:`, error.message);
        return false;
    }
}

async function applyEnterpriseOptimizations() {
    console.log('🚀 Applying enterprise database optimizations...');
    
    try {
        // Add columns to users table
        console.log('📊 Optimizing users table...');
        const userColumns = [
            { name: 'posts_count', definition: 'INT DEFAULT 0' },
            { name: 'followers_count', definition: 'INT DEFAULT 0' },
            { name: 'following_count', definition: 'INT DEFAULT 0' },
            { name: 'status', definition: "ENUM('online', 'offline', 'riding') DEFAULT 'offline'" },
            { name: 'location_sharing_enabled', definition: 'BOOLEAN DEFAULT FALSE' },
            { name: 'last_known_lat', definition: 'DECIMAL(10,8)' },
            { name: 'last_known_lng', definition: 'DECIMAL(11,8)' },
            { name: 'last_known_location', definition: 'VARCHAR(255)' },
            { name: 'is_verified', definition: 'BOOLEAN DEFAULT FALSE' },
            { name: 'is_premium', definition: 'BOOLEAN DEFAULT FALSE' },
            { name: 'premium_expires_at', definition: 'DATETIME NULL' },
            { name: 'privacy_level', definition: "ENUM('public', 'followers', 'private') DEFAULT 'public'" },
            { name: 'push_notifications_enabled', definition: 'BOOLEAN DEFAULT TRUE' },
            { name: 'email_notifications_enabled', definition: 'BOOLEAN DEFAULT TRUE' },
            { name: 'last_active_at', definition: 'DATETIME' },
            { name: 'deleted_at', definition: 'DATETIME NULL' }
        ];

        for (const col of userColumns) {
            if (!(await columnExists('users', col.name))) {
                try {
                    await query(`ALTER TABLE users ADD COLUMN ${col.name} ${col.definition}`);
                    console.log(`   ✅ Added users.${col.name}`);
                } catch (error) {
                    console.log(`   ⚠️  Could not add users.${col.name}: ${error.message}`);
                }
            } else {
                console.log(`   ⏭️  users.${col.name} already exists`);
            }
        }

        // Add columns to posts table
        console.log('📝 Optimizing posts table...');
        const postColumns = [
            { name: 'likes_count', definition: 'INT DEFAULT 0' },
            { name: 'comments_count', definition: 'INT DEFAULT 0' },
            { name: 'shares_count', definition: 'INT DEFAULT 0' },
            { name: 'views_count', definition: 'INT DEFAULT 0' },
            { name: 'visibility', definition: "ENUM('public', 'followers', 'private') DEFAULT 'public'" },
            { name: 'is_pinned', definition: 'BOOLEAN DEFAULT FALSE' },
            { name: 'is_featured', definition: 'BOOLEAN DEFAULT FALSE' },
            { name: 'is_flagged', definition: 'BOOLEAN DEFAULT FALSE' },
            { name: 'is_deleted', definition: 'BOOLEAN DEFAULT FALSE' },
            { name: 'hashtags', definition: 'JSON' },
            { name: 'mentioned_users', definition: 'JSON' },
            { name: 'deleted_at', definition: 'DATETIME NULL' }
        ];

        for (const col of postColumns) {
            if (!(await columnExists('posts', col.name))) {
                try {
                    await query(`ALTER TABLE posts ADD COLUMN ${col.name} ${col.definition}`);
                    console.log(`   ✅ Added posts.${col.name}`);
                } catch (error) {
                    console.log(`   ⚠️  Could not add posts.${col.name}: ${error.message}`);
                }
            } else {
                console.log(`   ⏭️  posts.${col.name} already exists`);
            }
        }

        // Add columns to hazard_reports table
        console.log('🚨 Optimizing hazard_reports table...');
        const hazardColumns = [
            { name: 'location_name', definition: 'VARCHAR(255)' },
            { name: 'confirmations_count', definition: 'INT DEFAULT 0' },
            { name: 'visibility_radius_miles', definition: 'DECIMAL(5,2) DEFAULT 5.0' }
        ];

        for (const col of hazardColumns) {
            if (!(await columnExists('hazard_reports', col.name))) {
                try {
                    await query(`ALTER TABLE hazard_reports ADD COLUMN ${col.name} ${col.definition}`);
                    console.log(`   ✅ Added hazard_reports.${col.name}`);
                } catch (error) {
                    console.log(`   ⚠️  Could not add hazard_reports.${col.name}: ${error.message}`);
                }
            } else {
                console.log(`   ⏭️  hazard_reports.${col.name} already exists`);
            }
        }

        // Create new tables
        console.log('🗂️  Creating analytics and monitoring tables...');

        // Analytics events table
        if (!(await tableExists('analytics_events'))) {
            await query(`
                CREATE TABLE analytics_events (
                    id BIGINT PRIMARY KEY AUTO_INCREMENT,
                    user_id BIGINT,
                    event_type VARCHAR(50) NOT NULL,
                    event_category VARCHAR(50) NOT NULL,
                    event_data JSON,
                    session_id VARCHAR(255),
                    device_type ENUM('ios', 'android', 'web'),
                    app_version VARCHAR(20),
                    os_version VARCHAR(20),
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
                    INDEX idx_user_id (user_id),
                    INDEX idx_event_type (event_type),
                    INDEX idx_event_category (event_category),
                    INDEX idx_timestamp (timestamp),
                    INDEX idx_session (session_id),
                    INDEX idx_device (device_type)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            `);
            console.log('   ✅ Created analytics_events table');
        }

        // Notifications table
        if (!(await tableExists('notifications'))) {
            await query(`
                CREATE TABLE notifications (
                    id BIGINT PRIMARY KEY AUTO_INCREMENT,
                    user_id BIGINT NOT NULL,
                    type VARCHAR(50) NOT NULL,
                    title VARCHAR(255) NOT NULL,
                    message TEXT NOT NULL,
                    data JSON,
                    is_read BOOLEAN DEFAULT FALSE,
                    is_sent BOOLEAN DEFAULT FALSE,
                    sent_at DATETIME NULL,
                    expires_at DATETIME,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                    INDEX idx_user_id (user_id),
                    INDEX idx_type (type),
                    INDEX idx_read (is_read),
                    INDEX idx_sent (is_sent),
                    INDEX idx_created_at (created_at),
                    INDEX idx_expires (expires_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            `);
            console.log('   ✅ Created notifications table');
        }

        // Content moderation table
        if (!(await tableExists('content_moderation'))) {
            await query(`
                CREATE TABLE content_moderation (
                    id BIGINT PRIMARY KEY AUTO_INCREMENT,
                    content_type ENUM('post', 'comment', 'story', 'user_profile') NOT NULL,
                    content_id BIGINT NOT NULL,
                    reporter_id BIGINT,
                    reason ENUM('spam', 'harassment', 'inappropriate', 'violence', 'copyright', 'other') NOT NULL,
                    description TEXT,
                    status ENUM('pending', 'approved', 'rejected', 'escalated') DEFAULT 'pending',
                    moderator_id BIGINT,
                    moderator_notes TEXT,
                    action_taken ENUM('none', 'warning', 'content_removed', 'user_suspended', 'user_banned'),
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    resolved_at DATETIME,
                    
                    FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE SET NULL,
                    FOREIGN KEY (moderator_id) REFERENCES users(id) ON DELETE SET NULL,
                    INDEX idx_content (content_type, content_id),
                    INDEX idx_status (status),
                    INDEX idx_created_at (created_at),
                    INDEX idx_moderator (moderator_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            `);
            console.log('   ✅ Created content_moderation table');
        }

        // Performance monitoring table
        if (!(await tableExists('db_performance_log'))) {
            await query(`
                CREATE TABLE db_performance_log (
                    id BIGINT PRIMARY KEY AUTO_INCREMENT,
                    query_type VARCHAR(50),
                    execution_time_ms DECIMAL(10,3),
                    rows_examined INT,
                    rows_sent INT,
                    table_name VARCHAR(100),
                    index_used VARCHAR(100),
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    
                    INDEX idx_timestamp (timestamp),
                    INDEX idx_query_type (query_type),
                    INDEX idx_execution_time (execution_time_ms)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            `);
            console.log('   ✅ Created db_performance_log table');
        }

        // Create optimized indexes
        console.log('📈 Creating performance indexes...');
        const indexes = [
            // User indexes
            { table: 'users', name: 'idx_users_status', definition: 'status' },
            { table: 'users', name: 'idx_users_location_sharing', definition: 'location_sharing_enabled' },
            { table: 'users', name: 'idx_users_last_active', definition: 'last_active_at' },
            { table: 'users', name: 'idx_users_safety_score', definition: 'safety_score' },
            { table: 'users', name: 'idx_users_followers_count', definition: 'followers_count' },
            { table: 'users', name: 'idx_users_deleted_at', definition: 'deleted_at' },
            { table: 'users', name: 'idx_users_location', definition: '(last_known_lat, last_known_lng)' },
            { table: 'users', name: 'idx_users_privacy_level', definition: 'privacy_level' },
            
            // Post indexes
            { table: 'posts', name: 'idx_posts_visibility', definition: 'visibility' },
            { table: 'posts', name: 'idx_posts_deleted', definition: 'is_deleted' },
            { table: 'posts', name: 'idx_posts_featured', definition: 'is_featured' },
            { table: 'posts', name: 'idx_posts_engagement', definition: '(likes_count, comments_count, views_count)' },
            { table: 'posts', name: 'idx_posts_user_created', definition: '(user_id, created_at DESC)' },
            { table: 'posts', name: 'idx_posts_trending', definition: '(visibility, is_deleted, created_at DESC)' },
            
            // Social indexes
            { table: 'followers', name: 'idx_followers_timeline', definition: '(following_id, created_at DESC)' },
            { table: 'post_likes', name: 'idx_post_likes_created_at', definition: 'created_at' },
            { table: 'post_comments', name: 'idx_post_comments_created_at', definition: 'created_at' },
            
            // Location and safety indexes
            { table: 'location_updates', name: 'idx_location_recent', definition: '(user_id, timestamp DESC)' },
            { table: 'emergency_events', name: 'idx_emergency_events_status', definition: 'status' },
            { table: 'hazard_reports', name: 'idx_hazard_reports_location', definition: '(latitude, longitude)' }
        ];

        for (const idx of indexes) {
            if (!(await indexExists(idx.table, idx.name))) {
                try {
                    await query(`CREATE INDEX ${idx.name} ON ${idx.table} ${idx.definition}`);
                    console.log(`   ✅ Created index ${idx.table}.${idx.name}`);
                } catch (error) {
                    console.log(`   ⚠️  Could not create index ${idx.table}.${idx.name}: ${error.message}`);
                }
            } else {
                console.log(`   ⏭️  Index ${idx.table}.${idx.name} already exists`);
            }
        }

        // Update denormalized counts
        console.log('🔢 Updating denormalized counts...');
        
        await query(`
            UPDATE users u 
            SET posts_count = (
                SELECT COUNT(*) FROM posts p 
                WHERE p.user_id = u.id AND COALESCE(p.is_deleted, FALSE) = FALSE
            )
        `);
        console.log('   ✅ Updated user post counts');

        await query(`
            UPDATE users u 
            SET followers_count = (
                SELECT COUNT(*) FROM followers f 
                WHERE f.following_id = u.id
            )
        `);
        console.log('   ✅ Updated user follower counts');

        await query(`
            UPDATE users u 
            SET following_count = (
                SELECT COUNT(*) FROM followers f 
                WHERE f.follower_id = u.id
            )
        `);
        console.log('   ✅ Updated user following counts');

        await query(`
            UPDATE posts p 
            SET likes_count = (
                SELECT COUNT(*) FROM post_likes pl 
                WHERE pl.post_id = p.id
            )
        `);
        console.log('   ✅ Updated post like counts');

        await query(`
            UPDATE posts p 
            SET comments_count = (
                SELECT COUNT(*) FROM post_comments pc 
                WHERE pc.post_id = p.id AND COALESCE(pc.is_deleted, FALSE) = FALSE
            )
        `);
        console.log('   ✅ Updated post comment counts');

        // Insert sample analytics data
        console.log('📊 Inserting sample analytics data...');
        await query(`
            INSERT IGNORE INTO analytics_events (user_id, event_type, event_category, event_data, device_type, app_version) VALUES
            (1, 'app_open', 'engagement', '{"source": "push_notification"}', 'ios', '1.0.0'),
            (1, 'post_view', 'content', '{"post_id": 1, "duration_seconds": 15}', 'ios', '1.0.0'),
            (2, 'post_like', 'engagement', '{"post_id": 1}', 'ios', '1.0.0'),
            (3, 'app_open', 'engagement', '{"source": "direct"}', 'ios', '1.0.0'),
            (1, 'ride_start', 'activity', '{"planned_distance": 50}', 'ios', '1.0.0'),
            (2, 'profile_view', 'social', '{"viewed_user_id": 1}', 'ios', '1.0.0'),
            (3, 'feed_scroll', 'engagement', '{"posts_viewed": 10, "time_spent": 120}', 'ios', '1.0.0'),
            (1, 'post_create', 'content', '{"content_length": 150, "has_image": true}', 'ios', '1.0.0'),
            (2, 'hazard_report', 'safety', '{"hazard_type": "pothole", "severity": "medium"}', 'ios', '1.0.0'),
            (3, 'safety_check', 'safety', '{"location_shared": true, "emergency_contacts": 2}', 'ios', '1.0.0'),
            (1, 'social_follow', 'social', '{"followed_user_id": 2}', 'ios', '1.0.0'),
            (2, 'comment_create', 'engagement', '{"post_id": 1, "comment_length": 50}', 'ios', '1.0.0'),
            (3, 'route_share', 'social', '{"route_distance": 25, "difficulty": "medium"}', 'ios', '1.0.0'),
            (1, 'emergency_activation', 'safety', '{"event_type": "crash", "location_shared": true}', 'ios', '1.0.0'),
            (2, 'pack_join', 'social', '{"pack_id": 1, "pack_size": 5}', 'ios', '1.0.0')
        `);
        console.log('   ✅ Sample analytics data inserted');

        // Optimize tables
        console.log('⚡ Optimizing tables for performance...');
        await query('OPTIMIZE TABLE users, posts, post_likes, post_comments, followers, user_sessions');
        console.log('   ✅ Tables optimized');

        console.log('\n✅ Enterprise optimization completed successfully!');
        
        // Show final statistics
        await showEnterpriseStats();

    } catch (error) {
        console.error('❌ Enterprise optimization failed:', error);
        throw error;
    }
}

async function showEnterpriseStats() {
    console.log('\n📊 Enterprise Database Statistics:');
    
    const tables = [
        'users', 'posts', 'post_likes', 'post_comments', 'followers',
        'stories', 'rides', 'emergency_events', 'hazard_reports',
        'riding_packs', 'notifications', 'analytics_events', 'content_moderation'
    ];
    
    console.log('\n🎯 Core Metrics:');
    for (const table of tables) {
        try {
            const [result] = await query(`SELECT COUNT(*) as count FROM ${table}`);
            console.log(`   ${table}: ${result.count.toLocaleString()} records`);
        } catch (error) {
            console.log(`   ${table}: Table not found`);
        }
    }

    // Show engagement metrics
    try {
        const [engagementStats] = await query(`
            SELECT 
                COALESCE(SUM(likes_count), 0) as total_likes,
                COALESCE(SUM(comments_count), 0) as total_comments,
                COALESCE(SUM(views_count), 0) as total_views,
                COALESCE(AVG(likes_count), 0) as avg_likes_per_post,
                COALESCE(AVG(comments_count), 0) as avg_comments_per_post
            FROM posts 
            WHERE COALESCE(is_deleted, FALSE) = FALSE
        `);
        
        if (engagementStats) {
            console.log('\n💫 Engagement Metrics:');
            console.log(`   Total Likes: ${engagementStats.total_likes?.toLocaleString() || 0}`);
            console.log(`   Total Comments: ${engagementStats.total_comments?.toLocaleString() || 0}`);
            console.log(`   Total Views: ${engagementStats.total_views?.toLocaleString() || 0}`);
            console.log(`   Avg Likes/Post: ${parseFloat(engagementStats.avg_likes_per_post || 0).toFixed(2)}`);
            console.log(`   Avg Comments/Post: ${parseFloat(engagementStats.avg_comments_per_post || 0).toFixed(2)}`);
        }
    } catch (error) {
        console.log('   ⚠️  Could not calculate engagement metrics');
    }

    // Show index information
    try {
        const indexes = await query(`
            SELECT 
                TABLE_NAME,
                COUNT(*) as index_count
            FROM information_schema.STATISTICS 
            WHERE TABLE_SCHEMA = DATABASE()
            GROUP BY TABLE_NAME
            ORDER BY index_count DESC
        `);
        
        console.log('\n📈 Database Indexes:');
        indexes.forEach(idx => {
            console.log(`   ${idx.TABLE_NAME}: ${idx.index_count} indexes`);
        });
    } catch (error) {
        console.log('   ⚠️  Could not retrieve index information');
    }

    console.log('\n🚀 Enterprise database is ready for millions of users!');
}

module.exports = { applyEnterpriseOptimizations };

// Run if called directly
if (require.main === module) {
    applyEnterpriseOptimizations()
        .then(() => {
            console.log('\n✨ Enterprise optimization completed successfully!');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n❌ Optimization failed:', error);
            process.exit(1);
        });
} 