-- MotoRev Development Seed Data
-- Sample data for testing and development

-- Insert sample users
INSERT INTO users (id, email, username, password_hash, first_name, last_name, phone, bio, profile_image_url, is_verified, emergency_contacts, preferences) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'kyle.rivers@example.com', 'kylerivers', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewwL5nOX.gEzLR3i', 'Kyle', 'Rivers', '+1-555-0100', 'Motorcycle enthusiast and safety advocate. Building the future of rider safety with AI.', 'https://example.com/avatars/kyle.jpg', true, '[{"name": "Emergency Contact", "phone": "+1-555-0199", "relationship": "family"}]', '{"crashDetection": true, "locationSharing": true, "notifications": true}'),
('550e8400-e29b-41d4-a716-446655440001', 'alex.morgan@example.com', 'alexrider', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewwL5nOX.gEzLR3i', 'Alex', 'Morgan', '+1-555-0101', 'Weekend warrior, mountain rides and adventure seeker. Always ready for the next journey!', 'https://example.com/avatars/alex.jpg', true, '[{"name": "Sarah Morgan", "phone": "+1-555-0102", "relationship": "spouse"}]', '{"crashDetection": true, "locationSharing": false, "notifications": true}'),
('550e8400-e29b-41d4-a716-446655440002', 'sarah.johnson@example.com', 'sarahj', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewwL5nOX.gEzLR3i', 'Sarah', 'Johnson', '+1-555-0102', 'Track day enthusiast and speed demon. Love pushing limits safely with MotoRev.', 'https://example.com/avatars/sarah.jpg', false, '[{"name": "Mike Johnson", "phone": "+1-555-0103", "relationship": "family"}]', '{"crashDetection": true, "locationSharing": true, "notifications": false}'),
('550e8400-e29b-41d4-a716-446655440003', 'mike.chen@example.com', 'bikermikechen', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewwL5nOX.gEzLR3i', 'Mike', 'Chen', '+1-555-0103', 'Touring rider and photographer. Capturing beautiful rides one mile at a time.', 'https://example.com/avatars/mike.jpg', true, '[{"name": "Lisa Chen", "phone": "+1-555-0104", "relationship": "spouse"}]', '{"crashDetection": true, "locationSharing": true, "notifications": true}'),
('550e8400-e29b-41d4-a716-446655440004', 'emma.davis@example.com', 'emmadavis', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewwL5nOX.gEzLR3i', 'Emma', 'Davis', '+1-555-0104', 'New rider learning the ropes. Grateful for MotoRev keeping me safe!', 'https://example.com/avatars/emma.jpg', false, '[{"name": "Dad", "phone": "+1-555-0105", "relationship": "family"}]', '{"crashDetection": true, "locationSharing": true, "notifications": true}');

-- Insert user stats
INSERT INTO user_stats (user_id, total_rides, total_miles, total_time, crashes_detected, stories_created, posts_created, followers_count, following_count, rank_points, achievements) VALUES
('550e8400-e29b-41d4-a716-446655440000', 45, 1250.5, 82800, 0, 23, 18, 145, 89, 1580, '["Safety Expert", "Social Butterfly", "Long Distance Rider"]'),
('550e8400-e29b-41d4-a716-446655440001', 78, 2100.2, 145600, 1, 15, 42, 203, 156, 2340, '["Mountain Master", "Adventure Seeker", "Crash Survivor"]'),
('550e8400-e29b-41d4-a716-446655440002', 23, 450.8, 28900, 0, 8, 12, 89, 67, 890, '["Speed Demon", "Track Day Pro"]'),
('550e8400-e29b-41d4-a716-446655440003', 67, 3450.1, 201200, 0, 31, 38, 178, 134, 2100, '["Photo Master", "Touring Legend", "Community Leader"]'),
('550e8400-e29b-41d4-a716-446655440004', 12, 180.3, 14400, 0, 5, 8, 34, 45, 320, '["New Rider", "Safety First"]');

-- Insert sample rides
INSERT INTO rides (id, user_id, title, description, start_location, end_location, route_data, distance, duration, max_speed, avg_speed, start_time, end_time, status, weather_data) VALUES
('650e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', 'Weekend Mountain Ride', 'Beautiful ride through the mountains with perfect weather', '{"latitude": 37.7749, "longitude": -122.4194, "address": "San Francisco, CA"}', '{"latitude": 37.8719, "longitude": -122.2585, "address": "Berkeley, CA"}', '{"coordinates": [[37.7749, -122.4194], [37.8044, -122.2711], [37.8719, -122.2585]]}', 28.5, 3600, 65.2, 45.8, '2024-01-15 09:00:00+00', '2024-01-15 10:00:00+00', 'completed', '{"temperature": 72, "condition": "sunny", "windSpeed": 8}'),
('650e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', 'Coast Highway Adventure', 'Epic coastal ride with ocean views', '{"latitude": 36.5527, "longitude": -121.9233, "address": "Monterey, CA"}', '{"latitude": 35.6870, "longitude": -121.2831, "address": "San Luis Obispo, CA"}', '{"coordinates": [[36.5527, -121.9233], [36.2004, -121.5969], [35.6870, -121.2831]]}', 125.8, 10800, 78.3, 52.4, '2024-01-14 08:30:00+00', '2024-01-14 11:30:00+00', 'completed', '{"temperature": 68, "condition": "partly_cloudy", "windSpeed": 12}'),
('650e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440002', 'Quick City Loop', 'Short ride around the city for coffee', '{"latitude": 34.0522, "longitude": -118.2437, "address": "Los Angeles, CA"}', '{"latitude": 34.0522, "longitude": -118.2437, "address": "Los Angeles, CA"}', '{"coordinates": [[34.0522, -118.2437], [34.0736, -118.2400], [34.0522, -118.2437]]}', 15.2, 2100, 55.1, 35.6, '2024-01-13 16:00:00+00', '2024-01-13 16:35:00+00', 'completed', '{"temperature": 75, "condition": "sunny", "windSpeed": 5}');

-- Insert location updates for active ride tracking
INSERT INTO location_updates (ride_id, user_id, latitude, longitude, altitude, speed, heading, accuracy, timestamp) VALUES
('650e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', 37.7749, -122.4194, 52.1, 0.0, 0.0, 5.0, '2024-01-15 09:00:00+00'),
('650e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', 37.7820, -122.4150, 58.3, 25.5, 45.2, 4.8, '2024-01-15 09:15:00+00'),
('650e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', 37.8044, -122.2711, 125.7, 48.3, 78.9, 5.2, '2024-01-15 09:45:00+00'),
('650e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', 37.8719, -122.2585, 68.2, 0.0, 0.0, 4.5, '2024-01-15 10:00:00+00');

-- Insert social connections
INSERT INTO social_connections (follower_id, following_id, status) VALUES
('550e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440001', 'active'),
('550e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440002', 'active'),
('550e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440003', 'active'),
('550e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440000', 'active'),
('550e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440003', 'active'),
('550e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440000', 'active'),
('550e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', 'active'),
('550e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440000', 'active'),
('550e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440001', 'active'),
('550e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440000', 'active');

-- Insert posts
INSERT INTO posts (id, user_id, ride_id, content, images, location, likes_count, comments_count) VALUES
('750e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', '650e8400-e29b-41d4-a716-446655440000', 'Amazing mountain ride this morning! Perfect weather and beautiful views. MotoRev kept me safe the whole way 🏍️ #MotoRev #SafetyFirst', '["https://example.com/images/mountain-ride-1.jpg", "https://example.com/images/mountain-ride-2.jpg"]', '{"latitude": 37.8044, "longitude": -122.2711, "address": "Berkeley Hills, CA"}', 23, 7),
('750e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '650e8400-e29b-41d4-a716-446655440001', 'Coast highway was incredible today! 125 miles of pure freedom. Thanks to MotoRev for the peace of mind during this epic adventure 🌊', '["https://example.com/images/coast-highway-1.jpg"]', '{"latitude": 36.2004, "longitude": -121.5969, "address": "Big Sur, CA"}', 45, 12),
('750e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440002', null, 'Track day preparation in full swing! Testing all safety systems before tomorrow''s session. Always better to be safe than sorry! 🏁', '["https://example.com/images/track-prep.jpg"]', '{"latitude": 34.0522, "longitude": -118.2437, "address": "Los Angeles, CA"}', 18, 5),
('750e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440003', null, 'New MotoRev features are amazing! The AI crash detection gives me so much confidence on long tours. Technology saving lives! 🤖', '[]', null, 31, 9),
('750e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440004', null, 'Still learning but loving every mile! MotoRev helps me feel confident as a new rider. The community support is incredible! 🙏', '["https://example.com/images/new-rider.jpg"]', null, 28, 15);

-- Insert stories
INSERT INTO stories (id, user_id, ride_id, content, background_color, location, is_live, views_count, expires_at) VALUES
('850e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', null, 'Getting ready for an epic mountain ride! Weather looks perfect ☀️', '#FF6B6B', '{"latitude": 37.7749, "longitude": -122.4194, "address": "San Francisco, CA"}', false, 15, NOW() + INTERVAL '18 hours'),
('850e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '650e8400-e29b-41d4-a716-446655440001', 'LIVE: Coast highway ride in progress! Amazing views! 🌊', '#4ECDC4', '{"latitude": 36.2004, "longitude": -121.5969, "address": "Big Sur, CA"}', true, 32, NOW() + INTERVAL '22 hours'),
('850e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440002', null, 'Track day tomorrow! Who else is going? 🏁', '#45B7D1', null, false, 8, NOW() + INTERVAL '12 hours'),
('850e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440003', null, 'Planning next week''s photo tour. Any scenic route suggestions? 📸', '#96CEB4', null, false, 21, NOW() + INTERVAL '16 hours');

-- Insert story views
INSERT INTO story_views (story_id, viewer_id) VALUES
('850e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440001'),
('850e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440002'),
('850e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440003'),
('850e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440000'),
('850e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440002'),
('850e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440003'),
('850e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001'),
('850e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440000');

-- Insert post likes
INSERT INTO post_likes (post_id, user_id) VALUES
('750e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440001'),
('750e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440002'),
('750e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440003'),
('750e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440000'),
('750e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440002'),
('750e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440003'),
('750e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001'),
('750e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440003'),
('750e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440000'),
('750e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440001'),
('750e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440000'),
('750e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440001'),
('750e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440003');

-- Insert post comments
INSERT INTO post_comments (id, post_id, user_id, content) VALUES
('950e8400-e29b-41d4-a716-446655440000', '750e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440001', 'Awesome ride! Those mountain views are incredible 🏔️'),
('950e8400-e29b-41d4-a716-446655440001', '750e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440002', 'Need to hit those roads soon! Thanks for sharing'),
('950e8400-e29b-41d4-a716-446655440002', '750e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440000', 'Coast highway is the best! Jealous of that perfect weather'),
('950e8400-e29b-41d4-a716-446655440003', '750e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440003', 'Great photos! The ocean views look amazing 📸'),
('950e8400-e29b-41d4-a716-446655440004', '750e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440000', 'Keep up the great riding! Safety first always 🙌'),
('950e8400-e29b-41d4-a716-446655440005', '750e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440001', 'Welcome to the community! We''re here to help');

-- Insert a sample pack
INSERT INTO packs (id, name, description, image_url, owner_id, member_count, location) VALUES
('450e8400-e29b-41d4-a716-446655440000', 'Bay Area Riders', 'Weekly group rides around the San Francisco Bay Area. All skill levels welcome!', 'https://example.com/images/bay-area-pack.jpg', '550e8400-e29b-41d4-a716-446655440000', 4, '{"latitude": 37.7749, "longitude": -122.4194, "address": "San Francisco Bay Area, CA"}');

-- Insert pack members
INSERT INTO pack_members (pack_id, user_id, role, status) VALUES
('450e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', 'owner', 'active'),
('450e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440001', 'admin', 'active'),
('450e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440002', 'member', 'active'),
('450e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440003', 'member', 'active');

-- Insert sample emergency event
INSERT INTO emergency_events (id, user_id, ride_id, event_type, severity, location, auto_detected, resolved, response_time) VALUES
('a50e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440001', '650e8400-e29b-41d4-a716-446655440001', 'crash_detected', 'medium', '{"latitude": 36.3456, "longitude": -121.7890, "address": "Highway 1, CA"}', true, true, 180);

-- Insert sample notifications
INSERT INTO notifications (id, user_id, type, title, message, data, read) VALUES
('b50e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', 'social', 'New Follower', 'Emma Davis started following you', '{"userId": "550e8400-e29b-41d4-a716-446655440004"}', false),
('b50e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440000', 'social', 'Post Liked', 'Alex Morgan liked your mountain ride post', '{"postId": "750e8400-e29b-41d4-a716-446655440000", "userId": "550e8400-e29b-41d4-a716-446655440001"}', false),
('b50e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', 'safety', 'Emergency Resolved', 'Your recent emergency event has been marked as resolved', '{"eventId": "a50e8400-e29b-41d4-a716-446655440000"}', true),
('b50e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440002', 'ride', 'Ride Completed', 'Great job on your 15.2 mile city ride!', '{"rideId": "650e8400-e29b-41d4-a716-446655440002", "distance": 15.2}', true); 