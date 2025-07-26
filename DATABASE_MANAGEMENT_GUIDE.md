# MotoRev Database Management Guide

## 🎯 Is the App Fully Database-Driven?

**YES!** The MotoRev app is 100% database-driven with the following architecture:

### 📱 **iOS App (Frontend)**
- Pure UI layer - no local data storage
- All data fetched from API endpoints
- Real-time updates via WebSocket connections
- Authentication tokens for secure access

### 🔗 **API Layer (Backend)**
- RESTful API endpoints for all operations
- JWT-based authentication
- Real-time WebSocket for live features
- All business logic in backend

### 🗄️ **MySQL Database (Data Layer)**
- **Users** - Profiles, authentication, preferences
- **Posts** - Social media content and interactions
- **Rides** - Journey tracking and statistics
- **Safety** - Emergency events and hazard reports
- **Social** - Followers, likes, comments
- **Real-time** - Location updates, pack coordination

## 🔍 Database Viewing & Management Options

### 1. **Built-in Web Admin** (Recommended)

Start the server and visit the admin interface:

```bash
cd MotoRevBackend
npm start
```

Then open: **http://localhost:3000**

**Features:**
- ✅ View all tables and data
- ✅ Browse user profiles and posts
- ✅ Monitor ride tracking data
- ✅ Check safety events
- ✅ Real-time server status
- ✅ No additional software needed

### 2. **MySQL Command Line**

After installing MySQL:

```bash
# Connect to database
mysql -u root -p motorev

# Common commands
SHOW TABLES;                    # List all tables
SELECT * FROM users LIMIT 10;  # View users
SELECT * FROM posts ORDER BY created_at DESC LIMIT 5;
SELECT * FROM rides WHERE status = 'active';

# User management
SELECT username, email, safety_score FROM users;
UPDATE users SET safety_score = 95 WHERE username = 'rider_alex';

# Ride statistics
SELECT COUNT(*) as total_rides, AVG(total_distance) as avg_distance 
FROM rides WHERE status = 'completed';
```

### 3. **MySQL Workbench** (GUI Tool)

Professional database management:

```bash
# Install MySQL Workbench
brew install --cask mysql-workbench

# Connection details:
Host: localhost
Port: 3306
Username: root
Password: (your MySQL password)
Database: motorev
```

### 4. **TablePlus** (Premium GUI)

Modern database client:

```bash
# Install TablePlus
brew install --cask tableplus

# Create new connection:
# Type: MySQL
# Host: 127.0.0.1
# Port: 3306
# User: root
# Database: motorev
```

### 5. **Sequel Pro** (Free GUI)

Free MySQL client for macOS:

```bash
# Install Sequel Pro
brew install --cask sequel-pro
```

## 📊 Database Structure Overview

### **Core Tables**

| Table | Purpose | Key Data |
|-------|---------|----------|
| `users` | User profiles & auth | username, email, motorcycle info, safety_score |
| `posts` | Social media content | content, images, likes, comments |
| `rides` | Journey tracking | start/end times, distance, speed, routes |
| `emergency_events` | Safety incidents | location, type, severity, response |
| `hazard_reports` | Road hazards | location, type, status, confirmations |
| `followers` | Social connections | follower/following relationships |
| `riding_packs` | Group rides | pack info, members, routes |

### **Real-time Tables**

| Table | Purpose | Updates |
|-------|---------|---------|
| `location_updates` | Live GPS tracking | Every few seconds during rides |
| `user_sessions` | Active sessions | Login/logout events |
| `story_views` | Story engagement | Real-time story views |

## 🛠️ Common Database Operations

### **User Management**

```sql
-- View all users
SELECT id, username, email, first_name, last_name, safety_score, total_miles 
FROM users ORDER BY created_at DESC;

-- Update user safety score
UPDATE users SET safety_score = 98 WHERE username = 'rider_alex';

-- View user statistics
SELECT username, total_miles, safety_score, 
       (SELECT COUNT(*) FROM rides WHERE user_id = users.id) as total_rides
FROM users ORDER BY safety_score DESC;
```

### **Content Management**

```sql
-- View recent posts
SELECT p.content, u.username, p.likes_count, p.created_at
FROM posts p JOIN users u ON p.user_id = u.id
ORDER BY p.created_at DESC LIMIT 10;

-- Moderate content
UPDATE posts SET visibility = 'private' WHERE id = 123;
DELETE FROM posts WHERE id = 456;
```

### **Safety Monitoring**

```sql
-- Active emergency events
SELECT u.username, e.event_type, e.severity, e.location_name, e.created_at
FROM emergency_events e JOIN users u ON e.user_id = u.id
WHERE e.is_resolved = FALSE;

-- Hazard reports by location
SELECT location_name, hazard_type, COUNT(*) as reports
FROM hazard_reports 
WHERE status = 'active'
GROUP BY location_name, hazard_type
ORDER BY reports DESC;
```

### **Analytics Queries**

```sql
-- User engagement stats
SELECT 
  COUNT(*) as total_users,
  COUNT(CASE WHEN last_active_at > DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as active_users,
  AVG(safety_score) as avg_safety_score
FROM users;

-- Ride statistics
SELECT 
  COUNT(*) as total_rides,
  SUM(total_distance) as total_distance,
  AVG(total_distance) as avg_ride_distance,
  MAX(max_speed) as highest_speed
FROM rides WHERE status = 'completed';
```

## 🔧 Database Maintenance

### **Backup Database**

```bash
# Create backup
mysqldump -u root -p motorev > motorev_backup_$(date +%Y%m%d).sql

# Restore backup
mysql -u root -p motorev < motorev_backup_20250108.sql
```

### **Performance Monitoring**

```sql
-- Check table sizes
SELECT 
  TABLE_NAME,
  ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'motorev'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;

-- Active connections
SHOW PROCESSLIST;

-- Query performance
SHOW STATUS LIKE 'Slow_queries';
```

### **Data Cleanup**

```sql
-- Clean old sessions
DELETE FROM user_sessions WHERE expires_at < NOW();

-- Archive old location updates (keep last 30 days)
DELETE FROM location_updates 
WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Clean expired stories
DELETE FROM stories WHERE expires_at < NOW();
```

## 🚀 Production Database Management

### **Environment Variables**

For production, use these environment variables:

```env
# Production Database
DB_HOST=your-production-host
DB_USER=motorev_user
DB_PASSWORD=secure_password
DB_NAME=motorev_production

# Connection Pool Settings
DB_CONNECTION_LIMIT=20
DB_ACQUIRE_TIMEOUT=60000
DB_TIMEOUT=60000
```

### **Monitoring Tools**

1. **MySQL Performance Schema** - Built-in monitoring
2. **Prometheus + Grafana** - Metrics and dashboards
3. **New Relic** - Application performance monitoring
4. **DataDog** - Database monitoring

### **Scaling Strategies**

1. **Read Replicas** - Separate read/write operations
2. **Connection Pooling** - Already implemented
3. **Query Optimization** - Index tuning
4. **Caching Layer** - Redis for frequently accessed data

## 📱 Real-time Data Flow

```
iOS App → API Endpoints → MySQL Database
    ↑                         ↓
WebSocket ← Real-time Updates ←
```

**Examples:**
- User posts → Immediately stored in `posts` table
- GPS location → Real-time updates to `location_updates`
- Emergency alert → Instant insert to `emergency_events`
- Social interactions → Live updates to `post_likes`, `followers`

Your MotoRev app is fully database-driven and ready for production scaling! 🎉 