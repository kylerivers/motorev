-- MotoRev Enterprise Optimization Schema
-- Adds analytics, performance indexes, and scalability improvements
-- Without breaking existing data structure

-- Add missing columns to existing tables for enhanced functionality
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS posts_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS followers_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS following_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS status ENUM('online', 'offline', 'riding') DEFAULT 'offline',
ADD COLUMN IF NOT EXISTS location_sharing_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_known_lat DECIMAL(10,8),
ADD COLUMN IF NOT EXISTS last_known_lng DECIMAL(11,8),
ADD COLUMN IF NOT EXISTS last_known_location VARCHAR(255),
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS premium_expires_at DATETIME NULL,
ADD COLUMN IF NOT EXISTS privacy_level ENUM('public', 'followers', 'private') DEFAULT 'public',
ADD COLUMN IF NOT EXISTS push_notifications_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS email_notifications_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS last_active_at DATETIME,
ADD COLUMN IF NOT EXISTS deleted_at DATETIME NULL;

-- Add missing columns to posts table
ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS likes_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS comments_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS shares_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS views_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS visibility ENUM('public', 'followers', 'private') DEFAULT 'public',
ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_flagged BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS hashtags JSON,
ADD COLUMN IF NOT EXISTS mentioned_users JSON,
ADD COLUMN IF NOT EXISTS deleted_at DATETIME NULL;

-- Add missing columns to hazard_reports table
ALTER TABLE hazard_reports 
ADD COLUMN IF NOT EXISTS location_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS confirmations_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS visibility_radius_miles DECIMAL(5,2) DEFAULT 5.0;

-- Add missing columns to user_sessions table
ALTER TABLE user_sessions 
ADD COLUMN IF NOT EXISTS device_info JSON,
ADD COLUMN IF NOT EXISTS ip_address VARCHAR(45),
ADD COLUMN IF NOT EXISTS user_agent TEXT,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS last_used_at DATETIME DEFAULT CURRENT_TIMESTAMP;

-- Add missing columns to riding_packs table
ALTER TABLE riding_packs 
ADD COLUMN IF NOT EXISTS current_members_count INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS invite_code VARCHAR(10) UNIQUE,
ADD COLUMN IF NOT EXISTS meeting_point VARCHAR(255),
ADD COLUMN IF NOT EXISTS meeting_lat DECIMAL(10,8),
ADD COLUMN IF NOT EXISTS meeting_lng DECIMAL(11,8),
ADD COLUMN IF NOT EXISTS scheduled_start DATETIME,
ADD COLUMN IF NOT EXISTS estimated_duration_minutes INT,
ADD COLUMN IF NOT EXISTS difficulty_level ENUM('easy', 'moderate', 'hard', 'expert') DEFAULT 'moderate',
ADD COLUMN IF NOT EXISTS status ENUM('planned', 'active', 'completed', 'cancelled') DEFAULT 'planned';

-- Add missing columns to pack_members table
ALTER TABLE pack_members 
ADD COLUMN IF NOT EXISTS role ENUM('leader', 'co-leader', 'member') DEFAULT 'member',
ADD COLUMN IF NOT EXISTS left_at DATETIME NULL,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- Create analytics events table for business intelligence
CREATE TABLE IF NOT EXISTS analytics_events (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create content moderation table
CREATE TABLE IF NOT EXISTS content_moderation (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create database performance monitoring table
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create optimized indexes for performance with millions of records

-- User table indexes
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_location_sharing ON users(location_sharing_enabled);
CREATE INDEX IF NOT EXISTS idx_users_last_active ON users(last_active_at);
CREATE INDEX IF NOT EXISTS idx_users_safety_score ON users(safety_score);
CREATE INDEX IF NOT EXISTS idx_users_followers_count ON users(followers_count);
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users(deleted_at);
CREATE INDEX IF NOT EXISTS idx_users_location ON users(last_known_lat, last_known_lng);
CREATE INDEX IF NOT EXISTS idx_users_privacy_level ON users(privacy_level);
-- Fulltext search for users
ALTER TABLE users ADD FULLTEXT(username, first_name, last_name, bio);

-- Posts table indexes for social media scale
CREATE INDEX IF NOT EXISTS idx_posts_visibility ON posts(visibility);
CREATE INDEX IF NOT EXISTS idx_posts_deleted ON posts(is_deleted);
CREATE INDEX IF NOT EXISTS idx_posts_featured ON posts(is_featured);
CREATE INDEX IF NOT EXISTS idx_posts_engagement ON posts(likes_count, comments_count, views_count);
CREATE INDEX IF NOT EXISTS idx_posts_user_created ON posts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_trending ON posts(visibility, is_deleted, created_at DESC);
-- Fulltext search for posts
ALTER TABLE posts ADD FULLTEXT(content);

-- Post likes table optimization
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_created_at ON post_likes(created_at);

-- Post comments table optimization
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_user_id ON post_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_parent ON post_comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_created_at ON post_comments(created_at);
-- Fulltext search for comments
ALTER TABLE post_comments ADD FULLTEXT(content);

-- Followers table optimization for social network scale
CREATE INDEX IF NOT EXISTS idx_followers_follower ON followers(follower_id);
CREATE INDEX IF NOT EXISTS idx_followers_following ON followers(following_id);
CREATE INDEX IF NOT EXISTS idx_followers_created_at ON followers(created_at);
CREATE INDEX IF NOT EXISTS idx_followers_timeline ON followers(following_id, created_at DESC);

-- User sessions optimization
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires ON user_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_user_sessions_device ON user_sessions(device_type);

-- Stories optimization
CREATE INDEX IF NOT EXISTS idx_stories_active ON stories(is_active);
CREATE INDEX IF NOT EXISTS idx_stories_expires ON stories(expires_at);

-- Story views optimization
CREATE INDEX IF NOT EXISTS idx_story_views_story_id ON story_views(story_id);
CREATE INDEX IF NOT EXISTS idx_story_views_viewer_id ON story_views(viewer_id);
CREATE INDEX IF NOT EXISTS idx_story_views_viewed_at ON story_views(viewed_at);

-- Rides optimization
CREATE INDEX IF NOT EXISTS idx_rides_distance ON rides(distance_miles);
CREATE INDEX IF NOT EXISTS idx_rides_safety_score ON rides(safety_score);
CREATE INDEX IF NOT EXISTS idx_rides_started_at ON rides(started_at);
CREATE INDEX IF NOT EXISTS idx_rides_public ON rides(is_public);
CREATE INDEX IF NOT EXISTS idx_rides_location_start ON rides(start_lat, start_lng);
CREATE INDEX IF NOT EXISTS idx_rides_location_end ON rides(end_lat, end_lng);

-- Location updates optimization
CREATE INDEX IF NOT EXISTS idx_location_updates_timestamp ON location_updates(timestamp);
CREATE INDEX IF NOT EXISTS idx_location_updates_location ON location_updates(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_location_recent ON location_updates(user_id, timestamp DESC);

-- Emergency events optimization
CREATE INDEX IF NOT EXISTS idx_emergency_events_status ON emergency_events(status);
CREATE INDEX IF NOT EXISTS idx_emergency_events_severity ON emergency_events(severity);
CREATE INDEX IF NOT EXISTS idx_emergency_events_location ON emergency_events(latitude, longitude);

-- Hazard reports optimization
CREATE INDEX IF NOT EXISTS idx_hazard_reports_hazard_type ON hazard_reports(hazard_type);
CREATE INDEX IF NOT EXISTS idx_hazard_reports_severity ON hazard_reports(severity);
CREATE INDEX IF NOT EXISTS idx_hazard_reports_location ON hazard_reports(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_hazard_reports_resolved ON hazard_reports(is_resolved);

-- Hazard confirmations optimization
CREATE INDEX IF NOT EXISTS idx_hazard_confirmations_hazard_id ON hazard_confirmations(hazard_id);
CREATE INDEX IF NOT EXISTS idx_hazard_confirmations_user_id ON hazard_confirmations(user_id);

-- Riding packs optimization
CREATE INDEX IF NOT EXISTS idx_riding_packs_public ON riding_packs(is_public);
CREATE INDEX IF NOT EXISTS idx_riding_packs_status ON riding_packs(status);
CREATE INDEX IF NOT EXISTS idx_riding_packs_scheduled ON riding_packs(scheduled_start);
CREATE INDEX IF NOT EXISTS idx_riding_packs_location ON riding_packs(meeting_lat, meeting_lng);
CREATE INDEX IF NOT EXISTS idx_riding_packs_invite_code ON riding_packs(invite_code);

-- Pack members optimization
CREATE INDEX IF NOT EXISTS idx_pack_members_pack_id ON pack_members(pack_id);
CREATE INDEX IF NOT EXISTS idx_pack_members_user_id ON pack_members(user_id);
CREATE INDEX IF NOT EXISTS idx_pack_members_active ON pack_members(is_active);
CREATE INDEX IF NOT EXISTS idx_pack_members_joined_at ON pack_members(joined_at);

-- Create optimized views for common analytics queries
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    u.id,
    u.username,
    u.first_name,
    u.last_name,
    u.profile_picture_url,
    u.is_verified,
    u.followers_count,
    u.following_count,
    u.posts_count,
    u.safety_score,
    u.total_miles,
    u.total_rides,
    u.created_at,
    u.last_active_at,
    u.status,
    COUNT(DISTINCT p.id) as actual_posts_count,
    COUNT(DISTINCT f1.id) as actual_followers_count,
    COUNT(DISTINCT f2.id) as actual_following_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id AND p.is_deleted = FALSE
LEFT JOIN followers f1 ON u.id = f1.following_id
LEFT JOIN followers f2 ON u.id = f2.follower_id
WHERE u.deleted_at IS NULL
GROUP BY u.id;

-- Create trending posts view
CREATE OR REPLACE VIEW trending_posts AS
SELECT 
    p.*,
    u.username,
    u.profile_picture_url,
    u.is_verified,
    (p.likes_count * 2 + p.comments_count * 3 + p.shares_count * 5 + p.views_count * 0.1) as engagement_score,
    TIMESTAMPDIFF(HOUR, p.created_at, NOW()) as hours_old
FROM posts p
JOIN users u ON p.user_id = u.id
WHERE p.is_deleted = FALSE 
    AND p.visibility = 'public'
    AND p.created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY engagement_score DESC, p.created_at DESC;

-- Create engagement analytics view
CREATE OR REPLACE VIEW engagement_analytics AS
SELECT 
    DATE(p.created_at) as date,
    COUNT(p.id) as posts_count,
    SUM(p.likes_count) as total_likes,
    SUM(p.comments_count) as total_comments,
    SUM(p.views_count) as total_views,
    AVG(p.likes_count) as avg_likes_per_post,
    AVG(p.comments_count) as avg_comments_per_post,
    COUNT(DISTINCT p.user_id) as active_users
FROM posts p
WHERE p.is_deleted = FALSE
    AND p.created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(p.created_at)
ORDER BY date DESC;

-- Insert sample analytics events
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
(3, 'safety_check', 'safety', '{"location_shared": true, "emergency_contacts": 2}', 'ios', '1.0.0');

-- Create database triggers for maintaining denormalized counts
DELIMITER //

DROP TRIGGER IF EXISTS update_user_posts_count_insert//
CREATE TRIGGER update_user_posts_count_insert 
AFTER INSERT ON posts
FOR EACH ROW
BEGIN
    IF NEW.is_deleted = FALSE THEN
        UPDATE users SET posts_count = posts_count + 1 WHERE id = NEW.user_id;
    END IF;
END//

DROP TRIGGER IF EXISTS update_user_posts_count_update//
CREATE TRIGGER update_user_posts_count_update 
AFTER UPDATE ON posts
FOR EACH ROW
BEGIN
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        UPDATE users SET posts_count = posts_count - 1 WHERE id = NEW.user_id;
    ELSEIF NEW.is_deleted = FALSE AND OLD.is_deleted = TRUE THEN
        UPDATE users SET posts_count = posts_count + 1 WHERE id = NEW.user_id;
    END IF;
END//

DROP TRIGGER IF EXISTS update_followers_count_insert//
CREATE TRIGGER update_followers_count_insert 
AFTER INSERT ON followers
FOR EACH ROW
BEGIN
    UPDATE users SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
    UPDATE users SET following_count = following_count + 1 WHERE id = NEW.follower_id;
END//

DROP TRIGGER IF EXISTS update_followers_count_delete//
CREATE TRIGGER update_followers_count_delete 
AFTER DELETE ON followers
FOR EACH ROW
BEGIN
    UPDATE users SET followers_count = followers_count - 1 WHERE id = OLD.following_id;
    UPDATE users SET following_count = following_count - 1 WHERE id = OLD.follower_id;
END//

DROP TRIGGER IF EXISTS update_post_likes_count_insert//
CREATE TRIGGER update_post_likes_count_insert 
AFTER INSERT ON post_likes
FOR EACH ROW
BEGIN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
END//

DROP TRIGGER IF EXISTS update_post_likes_count_delete//
CREATE TRIGGER update_post_likes_count_delete 
AFTER DELETE ON post_likes
FOR EACH ROW
BEGIN
    UPDATE posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
END//

DROP TRIGGER IF EXISTS update_post_comments_count_insert//
CREATE TRIGGER update_post_comments_count_insert 
AFTER INSERT ON post_comments
FOR EACH ROW
BEGIN
    IF NEW.is_deleted = FALSE THEN
        UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    END IF;
END//

DROP TRIGGER IF EXISTS update_post_comments_count_update//
CREATE TRIGGER update_post_comments_count_update 
AFTER UPDATE ON post_comments
FOR EACH ROW
BEGIN
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        UPDATE posts SET comments_count = comments_count - 1 WHERE id = NEW.post_id;
    ELSEIF NEW.is_deleted = FALSE AND OLD.is_deleted = TRUE THEN
        UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    END IF;
END//

DROP TRIGGER IF EXISTS update_hazard_confirmations_count_insert//
CREATE TRIGGER update_hazard_confirmations_count_insert 
AFTER INSERT ON hazard_confirmations
FOR EACH ROW
BEGIN
    UPDATE hazard_reports SET confirmations_count = confirmations_count + 1 WHERE id = NEW.hazard_id;
END//

DROP TRIGGER IF EXISTS update_hazard_confirmations_count_delete//
CREATE TRIGGER update_hazard_confirmations_count_delete 
AFTER DELETE ON hazard_confirmations
FOR EACH ROW
BEGIN
    UPDATE hazard_reports SET confirmations_count = confirmations_count - 1 WHERE id = OLD.hazard_id;
END//

DELIMITER ;

-- Update existing denormalized counts
UPDATE users u 
SET posts_count = (
    SELECT COUNT(*) FROM posts p 
    WHERE p.user_id = u.id AND p.is_deleted = FALSE
);

UPDATE users u 
SET followers_count = (
    SELECT COUNT(*) FROM followers f 
    WHERE f.following_id = u.id
);

UPDATE users u 
SET following_count = (
    SELECT COUNT(*) FROM followers f 
    WHERE f.follower_id = u.id
);

UPDATE posts p 
SET likes_count = (
    SELECT COUNT(*) FROM post_likes pl 
    WHERE pl.post_id = p.id
);

UPDATE posts p 
SET comments_count = (
    SELECT COUNT(*) FROM post_comments pc 
    WHERE pc.post_id = p.id AND pc.is_deleted = FALSE
);

UPDATE hazard_reports h 
SET confirmations_count = (
    SELECT COUNT(*) FROM hazard_confirmations hc 
    WHERE hc.hazard_id = h.id
);

-- Optimize tables for better performance
OPTIMIZE TABLE users, posts, post_likes, post_comments, followers, user_sessions;

SELECT 'Enterprise database optimization completed successfully!' as status; 