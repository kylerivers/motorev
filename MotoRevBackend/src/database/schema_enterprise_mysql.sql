-- MotoRev Enterprise Scale Database Schema
-- Optimized for millions of users, posts, and social interactions
-- Compatible with major social platform architectures

SET foreign_key_checks = 0;

-- Drop existing tables in correct order
DROP TABLE IF EXISTS story_views;
DROP TABLE IF EXISTS hazard_confirmations;
DROP TABLE IF EXISTS pack_members;
DROP TABLE IF EXISTS riding_packs;
DROP TABLE IF EXISTS location_updates;
DROP TABLE IF EXISTS post_comments;
DROP TABLE IF EXISTS post_likes;
DROP TABLE IF EXISTS followers;
DROP TABLE IF EXISTS hazard_reports;
DROP TABLE IF EXISTS emergency_events;
DROP TABLE IF EXISTS rides;
DROP TABLE IF EXISTS stories;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS user_sessions;
DROP TABLE IF EXISTS users;

-- Users table with advanced indexing and analytics support
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    
    -- Profile information
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    date_of_birth DATE,
    profile_picture_url TEXT,
    bio TEXT,
    
    -- Motorcycle information
    motorcycle_make VARCHAR(100),
    motorcycle_model VARCHAR(100),
    motorcycle_year INT,
    riding_experience ENUM('beginner', 'intermediate', 'advanced', 'expert') DEFAULT 'beginner',
    
    -- Statistics (for analytics and leaderboards)
    total_miles DECIMAL(10,2) DEFAULT 0,
    total_rides INT DEFAULT 0,
    safety_score INT DEFAULT 0,
    posts_count INT DEFAULT 0,
    followers_count INT DEFAULT 0,
    following_count INT DEFAULT 0,
    
    -- Status and preferences
    status ENUM('online', 'offline', 'riding') DEFAULT 'offline',
    location_sharing_enabled BOOLEAN DEFAULT FALSE,
    emergency_contact_name VARCHAR(200),
    emergency_contact_phone VARCHAR(20),
    push_notifications_enabled BOOLEAN DEFAULT TRUE,
    email_notifications_enabled BOOLEAN DEFAULT TRUE,
    privacy_level ENUM('public', 'followers', 'private') DEFAULT 'public',
    
    -- Verification and premium status
    is_verified BOOLEAN DEFAULT FALSE,
    is_premium BOOLEAN DEFAULT FALSE,
    premium_expires_at DATETIME NULL,
    
    -- Location information
    last_known_lat DECIMAL(10,8),
    last_known_lng DECIMAL(11,8),
    last_known_location VARCHAR(255),
    
    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_active_at DATETIME,
    deleted_at DATETIME NULL,
    
    -- Indexes for performance
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_status (status),
    INDEX idx_location_sharing (location_sharing_enabled),
    INDEX idx_created_at (created_at),
    INDEX idx_last_active (last_active_at),
    INDEX idx_safety_score (safety_score),
    INDEX idx_followers_count (followers_count),
    INDEX idx_deleted_at (deleted_at),
    INDEX idx_location (last_known_lat, last_known_lng),
    INDEX idx_privacy_level (privacy_level),
    FULLTEXT idx_search (username, first_name, last_name, bio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User sessions for authentication tracking
CREATE TABLE user_sessions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    device_type ENUM('ios', 'android', 'web') NOT NULL,
    device_info JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_used_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_token (session_token),
    INDEX idx_expires (expires_at),
    INDEX idx_active (is_active),
    INDEX idx_device (device_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Posts table optimized for millions of records
CREATE TABLE posts (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    video_url TEXT,
    
    -- Location data
    location_lat DECIMAL(10,8),
    location_lng DECIMAL(11,8),
    location_name VARCHAR(200),
    
    -- Post metadata
    ride_id BIGINT NULL,
    post_type ENUM('general', 'ride', 'safety', 'maintenance', 'route', 'emergency') DEFAULT 'general',
    visibility ENUM('public', 'followers', 'private') DEFAULT 'public',
    
    -- Engagement metrics (denormalized for performance)
    likes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    shares_count INT DEFAULT 0,
    views_count INT DEFAULT 0,
    
    -- Moderation
    is_pinned BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,
    is_flagged BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- Hashtags and mentions (JSON for flexibility)
    hashtags JSON,
    mentioned_users JSON,
    
    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_post_type (post_type),
    INDEX idx_visibility (visibility),
    INDEX idx_created_at (created_at),
    INDEX idx_likes_count (likes_count),
    INDEX idx_location (location_lat, location_lng),
    INDEX idx_deleted (is_deleted),
    INDEX idx_featured (is_featured),
    INDEX idx_engagement (likes_count, comments_count, views_count),
    FULLTEXT idx_content_search (content)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Post likes table (millions of records expected)
CREATE TABLE post_likes (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_like (post_id, user_id),
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_post_id (post_id),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Post comments with threading support
CREATE TABLE post_comments (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    parent_comment_id BIGINT NULL,
    content TEXT NOT NULL,
    likes_count INT DEFAULT 0,
    replies_count INT DEFAULT 0,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_comment_id) REFERENCES post_comments(id) ON DELETE CASCADE,
    INDEX idx_post_id (post_id),
    INDEX idx_user_id (user_id),
    INDEX idx_parent (parent_comment_id),
    INDEX idx_created_at (created_at),
    INDEX idx_deleted (is_deleted),
    FULLTEXT idx_content_search (content)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Stories (temporary content)
CREATE TABLE stories (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    content TEXT,
    image_url TEXT,
    video_url TEXT,
    background_color VARCHAR(7),
    location_lat DECIMAL(10,8),
    location_lng DECIMAL(11,8),
    location_name VARCHAR(200),
    views_count INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_active (is_active),
    INDEX idx_expires (expires_at),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Story views tracking
CREATE TABLE story_views (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    story_id BIGINT NOT NULL,
    viewer_id BIGINT NOT NULL,
    viewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_view (story_id, viewer_id),
    FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
    FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_story_id (story_id),
    INDEX idx_viewer_id (viewer_id),
    INDEX idx_viewed_at (viewed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Followers relationship (millions expected)
CREATE TABLE followers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    follower_id BIGINT NOT NULL,
    following_id BIGINT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_follow (follower_id, following_id),
    FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_follower (follower_id),
    INDEX idx_following (following_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rides tracking
CREATE TABLE rides (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    title VARCHAR(200),
    description TEXT,
    start_location VARCHAR(255),
    end_location VARCHAR(255),
    start_lat DECIMAL(10,8),
    start_lng DECIMAL(11,8),
    end_lat DECIMAL(10,8),
    end_lng DECIMAL(11,8),
    distance_miles DECIMAL(10,2),
    duration_minutes INT,
    max_speed_mph DECIMAL(5,2),
    avg_speed_mph DECIMAL(5,2),
    safety_score INT,
    route_data JSON,
    is_public BOOLEAN DEFAULT TRUE,
    started_at DATETIME,
    completed_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_distance (distance_miles),
    INDEX idx_safety_score (safety_score),
    INDEX idx_started_at (started_at),
    INDEX idx_public (is_public),
    INDEX idx_location_start (start_lat, start_lng),
    INDEX idx_location_end (end_lat, end_lng)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Location updates for real-time tracking
CREATE TABLE location_updates (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    ride_id BIGINT,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    altitude DECIMAL(8,2),
    speed_mph DECIMAL(5,2),
    heading DECIMAL(5,2),
    accuracy DECIMAL(5,2),
    timestamp DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_ride_id (ride_id),
    INDEX idx_location (latitude, longitude),
    INDEX idx_timestamp (timestamp),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Emergency events
CREATE TABLE emergency_events (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    event_type ENUM('crash', 'breakdown', 'medical', 'other') NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    location_description TEXT,
    description TEXT,
    contact_attempts JSON,
    resolved_at DATETIME,
    responder_id BIGINT,
    status ENUM('active', 'responding', 'resolved', 'cancelled') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (responder_id) REFERENCES users(id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_severity (severity),
    INDEX idx_location (latitude, longitude),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Hazard reports
CREATE TABLE hazard_reports (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    reporter_id BIGINT NOT NULL,
    hazard_type ENUM('pothole', 'debris', 'construction', 'weather', 'animal', 'accident', 'other') NOT NULL,
    severity ENUM('low', 'medium', 'high') NOT NULL,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    location_description TEXT,
    description TEXT NOT NULL,
    image_url TEXT,
    confirmations_count INT DEFAULT 0,
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at DATETIME,
    visibility_radius_miles DECIMAL(5,2) DEFAULT 5.0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_reporter (reporter_id),
    INDEX idx_hazard_type (hazard_type),
    INDEX idx_severity (severity),
    INDEX idx_location (latitude, longitude),
    INDEX idx_resolved (is_resolved),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Hazard confirmations
CREATE TABLE hazard_confirmations (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    hazard_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_confirmation (hazard_id, user_id),
    FOREIGN KEY (hazard_id) REFERENCES hazard_reports(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_hazard_id (hazard_id),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Riding packs (group rides)
CREATE TABLE riding_packs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    leader_id BIGINT NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    max_members INT DEFAULT 50,
    current_members_count INT DEFAULT 1,
    is_public BOOLEAN DEFAULT TRUE,
    invite_code VARCHAR(10) UNIQUE,
    meeting_point VARCHAR(255),
    meeting_lat DECIMAL(10,8),
    meeting_lng DECIMAL(11,8),
    scheduled_start DATETIME,
    estimated_duration_minutes INT,
    difficulty_level ENUM('easy', 'moderate', 'hard', 'expert') DEFAULT 'moderate',
    status ENUM('planned', 'active', 'completed', 'cancelled') DEFAULT 'planned',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (leader_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_leader (leader_id),
    INDEX idx_public (is_public),
    INDEX idx_status (status),
    INDEX idx_scheduled (scheduled_start),
    INDEX idx_location (meeting_lat, meeting_lng),
    INDEX idx_invite_code (invite_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Pack members
CREATE TABLE pack_members (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    pack_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role ENUM('leader', 'co-leader', 'member') DEFAULT 'member',
    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    left_at DATETIME NULL,
    is_active BOOLEAN DEFAULT TRUE,
    
    UNIQUE KEY unique_active_membership (pack_id, user_id, is_active),
    FOREIGN KEY (pack_id) REFERENCES riding_packs(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_pack_id (pack_id),
    INDEX idx_user_id (user_id),
    INDEX idx_active (is_active),
    INDEX idx_joined_at (joined_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Analytics tracking table for business intelligence
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
PARTITION BY RANGE (YEAR(timestamp)) (
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION p2027 VALUES LESS THAN (2028),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Notification queue for push notifications
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Content moderation queue
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET foreign_key_checks = 1;

-- Create optimized views for common queries
CREATE VIEW user_stats AS
SELECT 
    u.id,
    u.username,
    u.followers_count,
    u.following_count,
    u.posts_count,
    u.safety_score,
    u.total_miles,
    u.total_rides,
    u.created_at,
    u.last_active_at,
    COUNT(DISTINCT p.id) as actual_posts_count,
    COUNT(DISTINCT f1.id) as actual_followers_count,
    COUNT(DISTINCT f2.id) as actual_following_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id AND p.is_deleted = FALSE
LEFT JOIN followers f1 ON u.id = f1.following_id
LEFT JOIN followers f2 ON u.id = f2.follower_id
WHERE u.deleted_at IS NULL
GROUP BY u.id;

-- Create view for trending posts
CREATE VIEW trending_posts AS
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

-- Triggers to maintain denormalized counts
DELIMITER //

CREATE TRIGGER update_user_posts_count_insert 
AFTER INSERT ON posts
FOR EACH ROW
BEGIN
    UPDATE users SET posts_count = posts_count + 1 WHERE id = NEW.user_id;
END//

CREATE TRIGGER update_user_posts_count_delete 
AFTER UPDATE ON posts
FOR EACH ROW
BEGIN
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        UPDATE users SET posts_count = posts_count - 1 WHERE id = NEW.user_id;
    ELSEIF NEW.is_deleted = FALSE AND OLD.is_deleted = TRUE THEN
        UPDATE users SET posts_count = posts_count + 1 WHERE id = NEW.user_id;
    END IF;
END//

CREATE TRIGGER update_followers_count_insert 
AFTER INSERT ON followers
FOR EACH ROW
BEGIN
    UPDATE users SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
    UPDATE users SET following_count = following_count + 1 WHERE id = NEW.follower_id;
END//

CREATE TRIGGER update_followers_count_delete 
AFTER DELETE ON followers
FOR EACH ROW
BEGIN
    UPDATE users SET followers_count = followers_count - 1 WHERE id = OLD.following_id;
    UPDATE users SET following_count = following_count - 1 WHERE id = OLD.follower_id;
END//

CREATE TRIGGER update_post_likes_count_insert 
AFTER INSERT ON post_likes
FOR EACH ROW
BEGIN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
END//

CREATE TRIGGER update_post_likes_count_delete 
AFTER DELETE ON post_likes
FOR EACH ROW
BEGIN
    UPDATE posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
END//

CREATE TRIGGER update_post_comments_count_insert 
AFTER INSERT ON post_comments
FOR EACH ROW
BEGIN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
END//

CREATE TRIGGER update_post_comments_count_delete 
AFTER UPDATE ON post_comments
FOR EACH ROW
BEGIN
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        UPDATE posts SET comments_count = comments_count - 1 WHERE id = NEW.post_id;
    ELSEIF NEW.is_deleted = FALSE AND OLD.is_deleted = TRUE THEN
        UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    END IF;
END//

DELIMITER ;

-- Insert sample analytics events for testing
INSERT INTO analytics_events (user_id, event_type, event_category, event_data, device_type, app_version) VALUES
(1, 'app_open', 'engagement', '{"source": "push_notification"}', 'ios', '1.0.0'),
(1, 'post_view', 'content', '{"post_id": 1, "duration_seconds": 15}', 'ios', '1.0.0'),
(2, 'post_like', 'engagement', '{"post_id": 1}', 'ios', '1.0.0'),
(3, 'app_open', 'engagement', '{"source": "direct"}', 'ios', '1.0.0'),
(1, 'ride_start', 'activity', '{"planned_distance": 50}', 'ios', '1.0.0'),
(2, 'profile_view', 'social', '{"viewed_user_id": 1}', 'ios', '1.0.0');

-- Optimize tables for better performance
OPTIMIZE TABLE users, posts, post_likes, post_comments, followers;

-- Show table creation success
SELECT 'Enterprise database schema created successfully!' as status; 