require('dotenv').config();
const { query, closePool } = require('./src/database/connection');

async function setupTables() {
    try {
        console.log('🚀 Setting up database tables for MotoRev...');
        
        // Create completed_rides table
        console.log('📊 Creating completed_rides table...');
        await query(`
            CREATE TABLE IF NOT EXISTS completed_rides (
                id VARCHAR(255) PRIMARY KEY,
                user_id BIGINT NOT NULL,
                ride_type VARCHAR(50) NOT NULL,
                start_time DATETIME NOT NULL,
                end_time DATETIME NOT NULL,
                duration DECIMAL(10,2) NOT NULL,
                distance DECIMAL(10,2) NOT NULL,
                average_speed DECIMAL(8,2) NOT NULL,
                max_speed DECIMAL(8,2) NOT NULL,
                route_data TEXT,
                safety_score INT DEFAULT 100,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_user_rides (user_id),
                INDEX idx_start_time (start_time),
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        
        // Create ride_events table  
        console.log('📅 Creating ride_events table...');
        await query(`
            CREATE TABLE IF NOT EXISTS ride_events (
                id BIGINT PRIMARY KEY AUTO_INCREMENT,
                organizer_id BIGINT NOT NULL,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                start_time DATETIME NOT NULL,
                end_time DATETIME,
                location TEXT NOT NULL,
                max_participants INT,
                is_public BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_organizer (organizer_id),
                INDEX idx_start_time (start_time),
                INDEX idx_public (is_public),
                FOREIGN KEY (organizer_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        
        // Create event_participants table
        console.log('👥 Creating event_participants table...');
        await query(`
            CREATE TABLE IF NOT EXISTS event_participants (
                id BIGINT PRIMARY KEY AUTO_INCREMENT,
                event_id BIGINT NOT NULL,
                user_id BIGINT NOT NULL,
                joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_participant (event_id, user_id),
                INDEX idx_event (event_id),
                INDEX idx_user (user_id),
                FOREIGN KEY (event_id) REFERENCES ride_events(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        
        // Add user stats columns if they don't exist
        console.log('👤 Adding user stats columns...');
        try {
            await query(`ALTER TABLE users ADD COLUMN total_rides INT DEFAULT 0`);
            console.log('✅ Added total_rides column');
        } catch (e) {
            console.log('ℹ️ total_rides column already exists');
        }
        
        try {
            await query(`ALTER TABLE users ADD COLUMN total_miles DECIMAL(10,2) DEFAULT 0`);
            console.log('✅ Added total_miles column');
        } catch (e) {
            console.log('ℹ️ total_miles column already exists');
        }
        
        try {
            await query(`ALTER TABLE users ADD COLUMN total_ride_time DECIMAL(10,2) DEFAULT 0`);
            console.log('✅ Added total_ride_time column');
        } catch (e) {
            console.log('ℹ️ total_ride_time column already exists');
        }
        
        console.log('🎉 Database setup completed successfully!');
        
    } catch (error) {
        console.error('❌ Database setup failed:', error);
        process.exit(1);
    } finally {
        await closePool();
        process.exit(0);
    }
}

setupTables();

