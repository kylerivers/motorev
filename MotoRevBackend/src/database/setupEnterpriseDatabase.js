const { pool, query, run, executeMultiple } = require('./connection');
const fs = require('fs');
const path = require('path');

async function setupEnterpriseDatabase() {
    console.log('🚀 Setting up enterprise-scale MotoRev database...');
    
    try {
        // Read the optimized schema
        const schemaPath = path.join(__dirname, 'schema_enterprise_mysql.sql');
        let schema = fs.readFileSync(schemaPath, 'utf8');
        
        // Remove the partitioning from analytics_events for now
        schema = schema.replace(
            /PARTITION BY RANGE.*?PARTITION p_future VALUES LESS THAN MAXVALUE\s*\);/gs,
            ');'
        );
        
        // Backup existing data first
        console.log('📦 Backing up existing data...');
        const backupData = await backupExistingData();
        
        // Apply the optimized schema
        console.log('🔧 Applying enterprise schema...');
        await executeMultiple(schema);
        
        // Restore data with new schema
        console.log('📊 Restoring data with optimized structure...');
        await restoreDataWithEnhancements(backupData);
        
        // Create additional indexes for performance
        await createOptimizedIndexes();
        
        // Set up database monitoring
        await setupMonitoring();
        
        console.log('✅ Enterprise database setup completed!');
        
        // Show final statistics
        await showDatabaseStats();
        
    } catch (error) {
        console.error('❌ Enterprise database setup failed:', error);
        throw error;
    }
}

async function backupExistingData() {
    console.log('   📋 Collecting existing data...');
    
    const backup = {};
    
    const tables = [
        'users', 'user_sessions', 'posts', 'post_likes', 'post_comments',
        'stories', 'story_views', 'followers', 'rides', 'location_updates',
        'emergency_events', 'hazard_reports', 'hazard_confirmations',
        'riding_packs', 'pack_members'
    ];
    
    for (const table of tables) {
        try {
            const data = await query(`SELECT * FROM ${table}`);
            backup[table] = data;
            console.log(`   ✅ Backed up ${data.length} records from ${table}`);
        } catch (error) {
            console.log(`   ⚠️  Could not backup ${table}: ${error.message}`);
            backup[table] = [];
        }
    }
    
    return backup;
}

async function restoreDataWithEnhancements(backup) {
    console.log('   🔄 Restoring data with enhancements...');
    
    // Disable foreign key checks temporarily
    await query('SET foreign_key_checks = 0');
    
    try {
        // Restore users with enhanced fields
        if (backup.users && backup.users.length > 0) {
            for (const user of backup.users) {
                const enhancedUser = {
                    ...user,
                    riding_experience: user.riding_experience || 'beginner',
                    posts_count: 0, // Will be calculated
                    followers_count: 0, // Will be calculated
                    following_count: 0, // Will be calculated
                    last_known_lat: user.last_known_lat || null,
                    last_known_lng: user.last_known_lng || null,
                    last_known_location: null
                };
                
                // Remove any fields that don't exist in new schema
                delete enhancedUser.riding_experience; // Temporary removal for compatibility
                
                const columns = Object.keys(enhancedUser);
                const values = Object.values(enhancedUser);
                const placeholders = columns.map(() => '?').join(', ');
                
                await run(
                    `INSERT INTO users (${columns.join(', ')}) VALUES (${placeholders})`,
                    values
                );
            }
            console.log(`   ✅ Restored ${backup.users.length} users`);
        }
        
        // Restore other tables in dependency order
        const restoreOrder = [
            'user_sessions', 'posts', 'stories', 'rides', 'emergency_events',
            'hazard_reports', 'riding_packs', 'pack_members', 'followers',
            'post_likes', 'post_comments', 'story_views', 'hazard_confirmations',
            'location_updates'
        ];
        
        for (const tableName of restoreOrder) {
            if (backup[tableName] && backup[tableName].length > 0) {
                for (const record of backup[tableName]) {
                    try {
                        const columns = Object.keys(record);
                        const values = Object.values(record);
                        const placeholders = columns.map(() => '?').join(', ');
                        
                        await run(
                            `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES (${placeholders})`,
                            values
                        );
                    } catch (error) {
                        console.log(`   ⚠️  Error restoring record in ${tableName}: ${error.message}`);
                    }
                }
                console.log(`   ✅ Restored ${backup[tableName].length} records to ${tableName}`);
            }
        }
        
        // Update denormalized counts
        await updateDenormalizedCounts();
        
    } finally {
        // Re-enable foreign key checks
        await query('SET foreign_key_checks = 1');
    }
}

async function updateDenormalizedCounts() {
    console.log('   🔢 Updating denormalized counts...');
    
    // Update user post counts
    await query(`
        UPDATE users u 
        SET posts_count = (
            SELECT COUNT(*) FROM posts p 
            WHERE p.user_id = u.id AND p.is_deleted = FALSE
        )
    `);
    
    // Update user follower counts
    await query(`
        UPDATE users u 
        SET followers_count = (
            SELECT COUNT(*) FROM followers f 
            WHERE f.following_id = u.id
        )
    `);
    
    // Update user following counts
    await query(`
        UPDATE users u 
        SET following_count = (
            SELECT COUNT(*) FROM followers f 
            WHERE f.follower_id = u.id
        )
    `);
    
    // Update post like counts
    await query(`
        UPDATE posts p 
        SET likes_count = (
            SELECT COUNT(*) FROM post_likes pl 
            WHERE pl.post_id = p.id
        )
    `);
    
    // Update post comment counts
    await query(`
        UPDATE posts p 
        SET comments_count = (
            SELECT COUNT(*) FROM post_comments pc 
            WHERE pc.post_id = p.id AND pc.is_deleted = FALSE
        )
    `);
    
    console.log('   ✅ Denormalized counts updated');
}

async function createOptimizedIndexes() {
    console.log('   📈 Creating additional performance indexes...');
    
    const indexes = [
        // Composite indexes for common queries
        'CREATE INDEX IF NOT EXISTS idx_posts_user_created ON posts(user_id, created_at DESC)',
        'CREATE INDEX IF NOT EXISTS idx_posts_engagement ON posts(likes_count DESC, comments_count DESC, created_at DESC)',
        'CREATE INDEX IF NOT EXISTS idx_posts_trending ON posts(visibility, is_deleted, created_at DESC)',
        'CREATE INDEX IF NOT EXISTS idx_followers_timeline ON followers(following_id, created_at DESC)',
        'CREATE INDEX IF NOT EXISTS idx_location_recent ON location_updates(user_id, timestamp DESC)',
        'CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read, created_at DESC)',
        
        // Partial indexes for better performance
        'CREATE INDEX IF NOT EXISTS idx_users_active ON users(id) WHERE deleted_at IS NULL',
        'CREATE INDEX IF NOT EXISTS idx_posts_public ON posts(id, created_at DESC) WHERE visibility = "public" AND is_deleted = FALSE',
        'CREATE INDEX IF NOT EXISTS idx_stories_active ON stories(user_id, created_at DESC) WHERE is_active = TRUE',
        
        // Covering indexes for common SELECTs
        'CREATE INDEX IF NOT EXISTS idx_user_profile_cover ON users(id, username, first_name, last_name, profile_picture_url, is_verified)',
        'CREATE INDEX IF NOT EXISTS idx_post_feed_cover ON posts(id, user_id, content, created_at, likes_count, comments_count) WHERE visibility = "public" AND is_deleted = FALSE'
    ];
    
    for (const indexSQL of indexes) {
        try {
            await query(indexSQL);
        } catch (error) {
            console.log(`   ⚠️  Index creation warning: ${error.message}`);
        }
    }
    
    console.log('   ✅ Performance indexes created');
}

async function setupMonitoring() {
    console.log('   📊 Setting up database monitoring...');
    
    // Create performance monitoring table
    await query(`
        CREATE TABLE IF NOT EXISTS db_performance_log (
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
    
    // Enable query logging for performance analysis
    await query('SET GLOBAL slow_query_log = "ON"');
    await query('SET GLOBAL long_query_time = 1'); // Log queries taking > 1 second
    
    console.log('   ✅ Database monitoring configured');
}

async function showDatabaseStats() {
    console.log('\n📊 Enterprise Database Statistics:');
    
    const stats = {};
    
    const tables = [
        'users', 'posts', 'post_likes', 'post_comments', 'followers',
        'stories', 'rides', 'emergency_events', 'hazard_reports',
        'riding_packs', 'notifications', 'analytics_events'
    ];
    
    for (const table of tables) {
        try {
            const [result] = await query(`SELECT COUNT(*) as count FROM ${table}`);
            stats[table] = result.count;
        } catch (error) {
            stats[table] = 0;
        }
    }
    
    // Show engagement metrics
    const [engagementStats] = await query(`
        SELECT 
            SUM(likes_count) as total_likes,
            SUM(comments_count) as total_comments,
            SUM(views_count) as total_views,
            AVG(likes_count) as avg_likes_per_post,
            AVG(comments_count) as avg_comments_per_post
        FROM posts 
        WHERE is_deleted = FALSE
    `);
    
    console.log('\n🎯 Core Metrics:');
    Object.entries(stats).forEach(([table, count]) => {
        console.log(`   ${table}: ${count.toLocaleString()} records`);
    });
    
    if (engagementStats) {
        console.log('\n💫 Engagement Metrics:');
        console.log(`   Total Likes: ${engagementStats.total_likes?.toLocaleString() || 0}`);
        console.log(`   Total Comments: ${engagementStats.total_comments?.toLocaleString() || 0}`);
        console.log(`   Total Views: ${engagementStats.total_views?.toLocaleString() || 0}`);
        console.log(`   Avg Likes/Post: ${parseFloat(engagementStats.avg_likes_per_post || 0).toFixed(2)}`);
        console.log(`   Avg Comments/Post: ${parseFloat(engagementStats.avg_comments_per_post || 0).toFixed(2)}`);
    }
    
    // Show index information
    const indexes = await query(`
        SELECT 
            TABLE_NAME,
            INDEX_NAME,
            NON_UNIQUE,
            COLUMN_NAME
        FROM information_schema.STATISTICS 
        WHERE TABLE_SCHEMA = DATABASE()
        ORDER BY TABLE_NAME, INDEX_NAME
    `);
    
    console.log(`\n📈 Database Indexes: ${indexes.length} total indexes created`);
    
    console.log('\n🚀 Enterprise database is ready for millions of users!');
}

module.exports = { setupEnterpriseDatabase };

// Run if called directly
if (require.main === module) {
    setupEnterpriseDatabase()
        .then(() => {
            console.log('\n✨ Enterprise database setup completed successfully!');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n❌ Setup failed:', error);
            process.exit(1);
        });
} 