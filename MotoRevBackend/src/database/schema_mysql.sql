-- MySQL Database Schema for MotoRev
-- Created: 2024-01-20
-- Updated for MySQL: 2025-01-08
-- Description: Complete database schema for motorcycle safety and social platform

-- Set default charset and collation
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- Users table - Core user profiles and authentication
CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    phone VARCHAR(20),
    date_of_birth DATE,
    profile_picture_url TEXT,
    bio TEXT,
    motorcycle_make VARCHAR(50),
    motorcycle_model VARCHAR(50),
    motorcycle_year INT,
    riding_experience ENUM('beginner', 'intermediate', 'advanced', 'expert') DEFAULT 'beginner',
    total_miles INT DEFAULT 0,
    safety_score INT DEFAULT 100,
    posts_count INT DEFAULT 0,
    followers_count INT DEFAULT 0,
    following_count INT DEFAULT 0,
    status ENUM('online', 'riding', 'offline') DEFAULT 'offline',
    location_sharing_enabled BOOLEAN DEFAULT FALSE,
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    push_notifications_enabled BOOLEAN DEFAULT TRUE,
    email_notifications_enabled BOOLEAN DEFAULT TRUE,
    privacy_level ENUM('public', 'friends', 'private') DEFAULT 'public',
    is_verified BOOLEAN DEFAULT FALSE,
    is_premium BOOLEAN DEFAULT FALSE,
    role ENUM('user','admin','super_admin') DEFAULT 'user',
    subscription_tier ENUM('standard','pro') DEFAULT 'standard',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_active_at DATETIME,
    INDEX idx_email (email),
    INDEX idx_username (username),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User sessions for authentication management
CREATE TABLE IF NOT EXISTS user_sessions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    refresh_token VARCHAR(500) UNIQUE NOT NULL,
    device_id VARCHAR(100),
    device_type VARCHAR(50),
    ip_address VARCHAR(45),
    user_agent TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_refresh_token (refresh_token),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Follower relationships for social features
CREATE TABLE IF NOT EXISTS followers (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    follower_id BIGINT NOT NULL,
    following_id BIGINT NOT NULL,
    status ENUM('active', 'blocked') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_follow (follower_id, following_id),
    INDEX idx_follower_id (follower_id),
    INDEX idx_following_id (following_id),
    FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Social posts for community features
CREATE TABLE IF NOT EXISTS posts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    video_url TEXT,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    location_name VARCHAR(200),
    ride_id BIGINT,
    post_type ENUM('general', 'ride', 'safety', 'maintenance', 'route') DEFAULT 'general',
    visibility ENUM('public', 'followers', 'private') DEFAULT 'public',
    likes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    shares_count INT DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_visibility (visibility),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Social stories (temporary posts)
CREATE TABLE IF NOT EXISTS stories (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    content TEXT,
    image_url TEXT,
    video_url TEXT,
    background_color VARCHAR(7),
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    location_name VARCHAR(200),
    views_count INT DEFAULT 0,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Story views tracking
CREATE TABLE IF NOT EXISTS story_views (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    story_id BIGINT NOT NULL,
    viewer_id BIGINT NOT NULL,
    viewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_view (story_id, viewer_id),
    FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
    FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Post likes
CREATE TABLE IF NOT EXISTS post_likes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_like (post_id, user_id),
    INDEX idx_post_id (post_id),
    INDEX idx_user_id (user_id),
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Post comments
CREATE TABLE IF NOT EXISTS post_comments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    content TEXT NOT NULL,
    parent_comment_id BIGINT,
    likes_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_post_id (post_id),
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_comment_id) REFERENCES post_comments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rides tracking for journey management
CREATE TABLE IF NOT EXISTS rides (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    title VARCHAR(200),
    description TEXT,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    start_location_lat DECIMAL(10, 8),
    start_location_lng DECIMAL(11, 8),
    start_location_name VARCHAR(200),
    end_location_lat DECIMAL(10, 8),
    end_location_lng DECIMAL(11, 8),
    end_location_name VARCHAR(200),
    total_distance DECIMAL(8, 2) DEFAULT 0,
    max_speed DECIMAL(5, 2) DEFAULT 0,
    avg_speed DECIMAL(5, 2) DEFAULT 0,
    duration_minutes INT DEFAULT 0,
    fuel_consumed DECIMAL(5, 2),
    route_data LONGTEXT, -- JSON string of GPS coordinates
    safety_events_count INT DEFAULT 0,
    weather_conditions VARCHAR(100),
    status ENUM('planned', 'active', 'completed', 'cancelled') DEFAULT 'active',
    visibility ENUM('public', 'followers', 'private') DEFAULT 'public',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_start_time (start_time),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Real-time location updates during rides
CREATE TABLE IF NOT EXISTS location_updates (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    ride_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    altitude DECIMAL(7, 2),
    speed DECIMAL(5, 2),
    heading DECIMAL(5, 2),
    accuracy DECIMAL(5, 2),
    timestamp DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ride_id (ride_id),
    FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Location sharing for finding nearby riders
CREATE TABLE IF NOT EXISTS location_shares (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    altitude DECIMAL(7, 2),
    speed DECIMAL(5, 2),
    heading DECIMAL(5, 2),
    accuracy DECIMAL(5, 2),
    expires_at DATETIME NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at),
    INDEX idx_location (latitude, longitude),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Emergency events and safety incidents
CREATE TABLE IF NOT EXISTS emergency_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    ride_id BIGINT,
    event_type ENUM('crash', 'breakdown', 'medical', 'weather', 'manual') NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    location_name VARCHAR(200),
    description TEXT,
    auto_detected BOOLEAN DEFAULT FALSE,
    is_resolved BOOLEAN DEFAULT FALSE,
    emergency_contacts_notified BOOLEAN DEFAULT FALSE,
    authorities_contacted BOOLEAN DEFAULT FALSE,
    response_time_seconds INT,
    resolution_notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Hazard reports for community safety
CREATE TABLE IF NOT EXISTS hazard_reports (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    reporter_id BIGINT NOT NULL,
    hazard_type ENUM('pothole', 'debris', 'construction', 'weather', 'traffic', 'road_condition', 'other') NOT NULL,
    severity ENUM('low', 'medium', 'high') NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    location_name VARCHAR(200),
    description TEXT NOT NULL,
    image_url TEXT,
    status ENUM('active', 'resolved', 'duplicate', 'false_report') DEFAULT 'active',
    upvotes INT DEFAULT 0,
    downvotes INT DEFAULT 0,
    reports_count INT DEFAULT 1,
    is_verified BOOLEAN DEFAULT FALSE,
    expires_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Hazard confirmations from other users
CREATE TABLE IF NOT EXISTS hazard_confirmations (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    hazard_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    confirmation_type ENUM('upvote', 'downvote', 'still_there', 'resolved') NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_confirmation (hazard_id, user_id),
    FOREIGN KEY (hazard_id) REFERENCES hazard_reports(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Riding packs for group rides
CREATE TABLE IF NOT EXISTS riding_packs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    created_by BIGINT NOT NULL,
    max_members INT DEFAULT 10,
    current_members INT DEFAULT 1,
    pack_type ENUM('temporary', 'permanent') DEFAULT 'temporary',
    privacy_level ENUM('public', 'invite_only', 'private') DEFAULT 'public',
    status ENUM('active', 'riding', 'finished', 'cancelled') DEFAULT 'active',
    meeting_point_lat DECIMAL(10, 8),
    meeting_point_lng DECIMAL(11, 8),
    meeting_point_name VARCHAR(200),
    planned_route LONGTEXT, -- JSON string
    start_time DATETIME,
    estimated_duration INT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Pack membership management
CREATE TABLE IF NOT EXISTS pack_members (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pack_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role ENUM('leader', 'co_leader', 'member') DEFAULT 'member',
    status ENUM('invited', 'active', 'left', 'removed') DEFAULT 'active',
    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    left_at DATETIME,
    UNIQUE KEY unique_membership (pack_id, user_id),
    FOREIGN KEY (pack_id) REFERENCES riding_packs(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Digital Garage - Bikes Table
CREATE TABLE IF NOT EXISTS bikes (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  name VARCHAR(100) NOT NULL,
  year INT,
  make VARCHAR(50),
  model VARCHAR(100),
  color VARCHAR(50),
  engine_size VARCHAR(20),
  bike_type ENUM('sport', 'touring', 'cruiser', 'adventure', 'naked', 'dirt', 'scooter', 'other') DEFAULT 'other',
  current_mileage INT DEFAULT 0,
  purchase_date DATE,
  notes TEXT,
  is_primary BOOLEAN DEFAULT FALSE,
  photos JSON, -- Array of photo URLs
  modifications JSON, -- Array of modification objects
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_bikes (user_id),
  INDEX idx_primary_bike (user_id, is_primary)
);

-- Maintenance Records Table
CREATE TABLE IF NOT EXISTS maintenance_records (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  bike_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  maintenance_type ENUM('oil_change', 'chain_service', 'tire_check', 'brake_service', 'air_filter', 'spark_plugs', 'coolant', 'battery', 'general_service', 'custom') NOT NULL,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  cost DECIMAL(10,2),
  mileage_at_service INT,
  service_date DATE NOT NULL,
  next_service_mileage INT,
  next_service_date DATE,
  shop_name VARCHAR(100),
  parts_used JSON, -- Array of parts objects
  photos JSON, -- Array of photo URLs
  reminder_enabled BOOLEAN DEFAULT TRUE,
  completed BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (bike_id) REFERENCES bikes(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_bike_maintenance (bike_id),
  INDEX idx_user_maintenance (user_id),
  INDEX idx_maintenance_type (maintenance_type),
  INDEX idx_next_service (next_service_date, reminder_enabled)
);

-- Maintenance Templates Table (for common service intervals)
CREATE TABLE IF NOT EXISTS maintenance_templates (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  bike_id BIGINT NOT NULL,
  maintenance_type ENUM('oil_change', 'chain_service', 'tire_check', 'brake_service', 'air_filter', 'spark_plugs', 'coolant', 'battery', 'general_service', 'custom') NOT NULL,
  title VARCHAR(200) NOT NULL,
  interval_miles INT, -- Miles between services
  interval_months INT, -- Months between services
  reminder_miles_before INT DEFAULT 500, -- Remind X miles before due
  reminder_days_before INT DEFAULT 30, -- Remind X days before due
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (bike_id) REFERENCES bikes(id) ON DELETE CASCADE,
  INDEX idx_bike_templates (bike_id),
  INDEX idx_active_templates (bike_id, is_active)
);

-- Ride Recorder - Crash telemetry recordings
CREATE TABLE IF NOT EXISTS ride_recordings (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  ride_id BIGINT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  duration_seconds INT NOT NULL,
  speed_series JSON NOT NULL,
  lean_angle_series JSON,
  acceleration_series JSON,
  braking_series JSON,
  gps_series JSON NOT NULL,
  audio_sample_url TEXT,
  notes TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE SET NULL,
  INDEX idx_user_recordings (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Fuel Logs - Per-bike fuel fill-ups and MPG tracking
CREATE TABLE IF NOT EXISTS fuel_logs (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  bike_id BIGINT,
  log_date DATETIME NOT NULL,
  station_name VARCHAR(200),
  fuel_type ENUM('regular','midgrade','premium','diesel','ethanol','other') DEFAULT 'regular',
  gallons DECIMAL(6,3) NOT NULL,
  price_per_gallon DECIMAL(6,3) NOT NULL,
  total_cost DECIMAL(8,2) NOT NULL,
  odometer INT,
  notes TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (bike_id) REFERENCES bikes(id) ON DELETE SET NULL,
  INDEX idx_user_bike_date (user_id, bike_id, log_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci; 

-- Push tokens for APNs
CREATE TABLE IF NOT EXISTS push_tokens (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  token VARCHAR(256) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_user_token (user_id, token),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci; 

-- Subscription receipts (App Store)
CREATE TABLE IF NOT EXISTS subscription_receipts (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  product_id VARCHAR(100) NOT NULL,
  transaction_id VARCHAR(200),
  payload LONGTEXT,
  verified BOOLEAN DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_product (user_id, product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ride Events table
CREATE TABLE IF NOT EXISTS ride_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    organizer_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    location VARCHAR(255) NOT NULL,
    max_participants INT,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (organizer_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_events_start_time (start_time),
    INDEX idx_events_organizer (organizer_id),
    INDEX idx_events_public (is_public)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Event Participants table
CREATE TABLE IF NOT EXISTS event_participants (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (event_id) REFERENCES ride_events(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_participant (event_id, user_id),
    INDEX idx_participants_event (event_id),
    INDEX idx_participants_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Shared Music table
CREATE TABLE IF NOT EXISTS shared_music (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pack_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    track_title VARCHAR(255) NOT NULL,
    artist VARCHAR(255) NOT NULL,
    shared_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pack_id) REFERENCES riding_packs(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_shared_music_pack (pack_id),
    INDEX idx_shared_music_user (user_id),
    INDEX idx_shared_music_time (shared_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Voice Sessions table
CREATE TABLE IF NOT EXISTS voice_sessions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    room_id VARCHAR(255) NOT NULL,
    user_id BIGINT NOT NULL,
    is_muted BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_room_user (room_id, user_id),
    INDEX idx_voice_sessions_room (room_id),
    INDEX idx_voice_sessions_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add music and voice features to riding_packs table (only if they don't exist)
ALTER TABLE riding_packs 
ADD COLUMN IF NOT EXISTS current_track VARCHAR(255) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS current_artist VARCHAR(255) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS track_updated_at TIMESTAMP DEFAULT NULL;

-- Add music and voice connection status to pack_members table (only if they don't exist)
ALTER TABLE pack_members 
ADD COLUMN IF NOT EXISTS is_music_connected BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_voice_connected BOOLEAN DEFAULT FALSE;

-- Create completed_rides table
CREATE TABLE IF NOT EXISTS completed_rides (
    id VARCHAR(255) PRIMARY KEY,
    user_id BIGINT NOT NULL,
    ride_type VARCHAR(50) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    duration FLOAT NOT NULL, -- in seconds
    distance FLOAT NOT NULL, -- in meters
    average_speed FLOAT NOT NULL, -- in mph
    max_speed FLOAT NOT NULL, -- in mph
    route_data TEXT, -- JSON array of route points
    safety_score INT DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Add user statistics columns
ALTER TABLE users ADD COLUMN total_rides INT DEFAULT 0;
ALTER TABLE users ADD COLUMN total_miles FLOAT DEFAULT 0.0;
ALTER TABLE users ADD COLUMN total_ride_time FLOAT DEFAULT 0.0; -- in hours 