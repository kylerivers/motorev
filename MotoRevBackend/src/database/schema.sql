-- SQLite Database Schema for MotoRev
-- Created: 2024-01-20
-- Description: Complete database schema for motorcycle safety and social platform

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Users table - Core user profiles and authentication
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    phone TEXT,
    date_of_birth DATE,
    profile_picture_url TEXT,
    bio TEXT,
    motorcycle_make TEXT,
    motorcycle_model TEXT,
    motorcycle_year INTEGER,
    total_miles INTEGER DEFAULT 0,
    safety_score INTEGER DEFAULT 100,
    status TEXT DEFAULT 'offline' CHECK (status IN ('online', 'riding', 'offline')),
    location_sharing_enabled BOOLEAN DEFAULT false,
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    push_notifications_enabled BOOLEAN DEFAULT true,
    email_notifications_enabled BOOLEAN DEFAULT true,
    privacy_level TEXT DEFAULT 'public' CHECK (privacy_level IN ('public', 'friends', 'private')),
    is_verified BOOLEAN DEFAULT false,
    is_premium BOOLEAN DEFAULT false,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_active_at DATETIME
);

-- User sessions for authentication management
CREATE TABLE IF NOT EXISTS user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    refresh_token TEXT UNIQUE NOT NULL,
    device_id TEXT,
    device_type TEXT,
    ip_address TEXT,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Follower relationships for social features
CREATE TABLE IF NOT EXISTS followers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    follower_id INTEGER NOT NULL,
    following_id INTEGER NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'blocked')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(follower_id, following_id)
);

-- Social posts for community features
CREATE TABLE IF NOT EXISTS posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    video_url TEXT,
    location_lat REAL,
    location_lng REAL,
    location_name TEXT,
    ride_id INTEGER,
    post_type TEXT DEFAULT 'general' CHECK (post_type IN ('general', 'ride', 'safety', 'maintenance', 'route')),
    visibility TEXT DEFAULT 'public' CHECK (visibility IN ('public', 'followers', 'private')),
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT false,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE SET NULL
);

-- Social stories (temporary posts)
CREATE TABLE IF NOT EXISTS stories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    content TEXT,
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
    location_lat REAL,
    location_lng REAL,
    location_name TEXT,
    views_count INTEGER DEFAULT 0,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Story views tracking
CREATE TABLE IF NOT EXISTS story_views (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id INTEGER NOT NULL,
    viewer_id INTEGER NOT NULL,
    viewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
    FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(story_id, viewer_id)
);

-- Post likes
CREATE TABLE IF NOT EXISTS post_likes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(post_id, user_id)
);

-- Post comments
CREATE TABLE IF NOT EXISTS post_comments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    parent_comment_id INTEGER,
    likes_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_comment_id) REFERENCES post_comments(id) ON DELETE CASCADE
);

-- Rides tracking for journey management
CREATE TABLE IF NOT EXISTS rides (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    title TEXT,
    description TEXT,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    start_location_lat REAL,
    start_location_lng REAL,
    start_location_name TEXT,
    end_location_lat REAL,
    end_location_lng REAL,
    end_location_name TEXT,
    total_distance REAL DEFAULT 0,
    max_speed REAL DEFAULT 0,
    avg_speed REAL DEFAULT 0,
    duration_minutes INTEGER DEFAULT 0,
    fuel_consumed REAL,
    route_data TEXT, -- JSON string of GPS coordinates
    safety_events_count INTEGER DEFAULT 0,
    weather_conditions TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('planned', 'active', 'completed', 'cancelled')),
    visibility TEXT DEFAULT 'public' CHECK (visibility IN ('public', 'followers', 'private')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Real-time location updates during rides
CREATE TABLE IF NOT EXISTS location_updates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ride_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    altitude REAL,
    speed REAL,
    heading REAL,
    accuracy REAL,
    timestamp DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Emergency events and safety incidents
CREATE TABLE IF NOT EXISTS emergency_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    ride_id INTEGER,
    event_type TEXT NOT NULL CHECK (event_type IN ('crash', 'breakdown', 'medical', 'weather', 'manual')),
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    location_name TEXT,
    description TEXT,
    auto_detected BOOLEAN DEFAULT false,
    is_resolved BOOLEAN DEFAULT false,
    emergency_contacts_notified BOOLEAN DEFAULT false,
    authorities_contacted BOOLEAN DEFAULT false,
    response_time_seconds INTEGER,
    resolution_notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE SET NULL
);

-- Hazard reports for community safety
CREATE TABLE IF NOT EXISTS hazard_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reporter_id INTEGER NOT NULL,
    hazard_type TEXT NOT NULL CHECK (hazard_type IN ('pothole', 'debris', 'construction', 'weather', 'traffic', 'road_condition', 'other')),
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high')),
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    location_name TEXT,
    description TEXT NOT NULL,
    image_url TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'duplicate', 'false_report')),
    upvotes INTEGER DEFAULT 0,
    downvotes INTEGER DEFAULT 0,
    reports_count INTEGER DEFAULT 1,
    is_verified BOOLEAN DEFAULT false,
    expires_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Hazard confirmations from other users
CREATE TABLE IF NOT EXISTS hazard_confirmations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hazard_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    confirmation_type TEXT NOT NULL CHECK (confirmation_type IN ('upvote', 'downvote', 'still_there', 'resolved')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (hazard_id) REFERENCES hazard_reports(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(hazard_id, user_id)
);

-- Riding packs for group rides
CREATE TABLE IF NOT EXISTS riding_packs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    created_by INTEGER NOT NULL,
    max_members INTEGER DEFAULT 10,
    current_members INTEGER DEFAULT 1,
    pack_type TEXT DEFAULT 'temporary' CHECK (pack_type IN ('temporary', 'permanent')),
    privacy_level TEXT DEFAULT 'public' CHECK (privacy_level IN ('public', 'invite_only', 'private')),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'riding', 'finished', 'cancelled')),
    meeting_point_lat REAL,
    meeting_point_lng REAL,
    meeting_point_name TEXT,
    planned_route TEXT, -- JSON string
    start_time DATETIME,
    estimated_duration INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

-- Pack membership management
CREATE TABLE IF NOT EXISTS pack_members (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pack_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role TEXT DEFAULT 'member' CHECK (role IN ('leader', 'co_leader', 'member')),
    status TEXT DEFAULT 'active' CHECK (status IN ('invited', 'active', 'left', 'removed')),
    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    left_at DATETIME,
    FOREIGN KEY (pack_id) REFERENCES riding_packs(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(pack_id, user_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_refresh_token ON user_sessions(refresh_token);
CREATE INDEX IF NOT EXISTS idx_followers_follower_id ON followers(follower_id);
CREATE INDEX IF NOT EXISTS idx_followers_following_id ON followers(following_id);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at);
CREATE INDEX IF NOT EXISTS idx_posts_visibility ON posts(visibility);
CREATE INDEX IF NOT EXISTS idx_stories_user_id ON stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_expires_at ON stories(expires_at);
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_rides_user_id ON rides(user_id);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_start_time ON rides(start_time);
CREATE INDEX IF NOT EXISTS idx_location_updates_ride_id ON location_updates(ride_id);
CREATE INDEX IF NOT EXISTS idx_location_updates_timestamp ON location_updates(timestamp);
CREATE INDEX IF NOT EXISTS idx_emergency_events_user_id ON emergency_events(user_id);
CREATE INDEX IF NOT EXISTS idx_emergency_events_created_at ON emergency_events(created_at);
CREATE INDEX IF NOT EXISTS idx_hazard_reports_location ON hazard_reports(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_hazard_reports_status ON hazard_reports(status);
CREATE INDEX IF NOT EXISTS idx_riding_packs_created_by ON riding_packs(created_by);
CREATE INDEX IF NOT EXISTS idx_pack_members_pack_id ON pack_members(pack_id);
CREATE INDEX IF NOT EXISTS idx_pack_members_user_id ON pack_members(user_id); 