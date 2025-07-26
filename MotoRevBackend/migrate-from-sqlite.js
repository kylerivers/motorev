const sqlite3 = require('sqlite3').verbose();
const mysql = require('mysql2/promise');
require('dotenv').config();

// MySQL connection config
const mysqlConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'motorev',
  charset: 'utf8mb4'
};

// SQLite database path
const sqlitePath = './motorev.db';

async function migrateData() {
  console.log('🔄 Starting comprehensive data migration from SQLite to MySQL...');
  
  let mysqlConnection;
  let sqliteDb;
  
  try {
    // Connect to MySQL
    console.log('📡 Connecting to MySQL...');
    mysqlConnection = await mysql.createConnection(mysqlConfig);
    console.log('✅ MySQL connected successfully');
    
    // Connect to SQLite
    console.log('📡 Connecting to SQLite...');
    sqliteDb = new sqlite3.Database(sqlitePath);
    console.log('✅ SQLite connected successfully');
    
    // Define tables to migrate in order (to handle foreign keys)
    const tables = [
      'users',
      'user_sessions', 
      'posts',
      'stories',
      'rides',
      'emergency_events',
      'hazard_reports',
      'hazard_confirmations',
      'followers',
      'post_likes',
      'post_comments',
      'story_views',
      'location_updates',
      'riding_packs',
      'pack_members'
    ];
    
    // Clear existing MySQL data first
    console.log('🗑️  Clearing existing MySQL data...');
    for (const table of tables.reverse()) { // Reverse order for foreign keys
      try {
        await mysqlConnection.execute(`DELETE FROM ${table}`);
        await mysqlConnection.execute(`ALTER TABLE ${table} AUTO_INCREMENT = 1`);
        console.log(`   ✅ Cleared ${table}`);
      } catch (error) {
        console.log(`   ⚠️  Could not clear ${table}: ${error.message}`);
      }
    }
    
    // Migrate each table
    tables.reverse(); // Back to normal order
    for (const tableName of tables) {
      await migrateTable(sqliteDb, mysqlConnection, tableName);
    }
    
    console.log('🎉 Migration completed successfully!');
    
    // Show final stats
    console.log('\n📊 Final Database Statistics:');
    for (const table of tables) {
      try {
        const [rows] = await mysqlConnection.execute(`SELECT COUNT(*) as count FROM ${table}`);
        console.log(`   ${table}: ${rows[0].count} records`);
      } catch (error) {
        console.log(`   ${table}: Error counting records`);
      }
    }
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    // Close connections
    if (mysqlConnection) {
      await mysqlConnection.end();
      console.log('🔌 MySQL connection closed');
    }
    if (sqliteDb) {
      sqliteDb.close();
      console.log('🔌 SQLite connection closed');
    }
  }
}

async function migrateTable(sqliteDb, mysqlConnection, tableName) {
  return new Promise(async (resolve, reject) => {
    try {
      console.log(`\n🔄 Migrating ${tableName}...`);
      
      // Get all data from SQLite
      sqliteDb.all(`SELECT * FROM ${tableName}`, async (err, rows) => {
        if (err) {
          console.log(`   ⚠️  Table ${tableName} doesn't exist in SQLite or error: ${err.message}`);
          resolve();
          return;
        }
        
        if (rows.length === 0) {
          console.log(`   📝 ${tableName}: No data to migrate`);
          resolve();
          return;
        }
        
        console.log(`   📝 Found ${rows.length} records in ${tableName}`);
        
        // Get column names
        const columns = Object.keys(rows[0]);
        
        // Prepare MySQL insert statement
        const placeholders = columns.map(() => '?').join(', ');
        const sql = `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES (${placeholders})`;
        
        // Insert each row
        let successCount = 0;
        let errorCount = 0;
        
        for (const row of rows) {
          try {
            const values = columns.map(col => {
              let value = row[col];
              
              // Handle date/time conversions
              if (col.includes('_at') || col.includes('date') || col.includes('time')) {
                if (value && typeof value === 'string') {
                  // Convert SQLite datetime to MySQL format
                  value = new Date(value).toISOString().slice(0, 19).replace('T', ' ');
                }
              }
              
              // Handle boolean conversions
              if (typeof value === 'number' && (value === 0 || value === 1)) {
                // Keep as is for MySQL
              }
              
              return value;
            });
            
            await mysqlConnection.execute(sql, values);
            successCount++;
          } catch (insertError) {
            console.log(`   ❌ Error inserting record ${row.id || 'unknown'}: ${insertError.message}`);
            errorCount++;
          }
        }
        
        console.log(`   ✅ ${tableName}: ${successCount} records migrated successfully`);
        if (errorCount > 0) {
          console.log(`   ⚠️  ${tableName}: ${errorCount} records failed`);
        }
        
        resolve();
      });
    } catch (error) {
      console.log(`   ❌ Error migrating ${tableName}: ${error.message}`);
      resolve(); // Continue with other tables
    }
  });
}

// Add some sample data if needed
async function addSampleData(mysqlConnection) {
  console.log('\n🎨 Adding sample data...');
  
  try {
    // Add some sample posts if none exist
    const [postRows] = await mysqlConnection.execute('SELECT COUNT(*) as count FROM posts');
    if (postRows[0].count === 0) {
      const samplePosts = [
        {
          user_id: 1,
          content: 'Just finished an amazing ride through the mountains! 🏔️🏍️',
          image_url: null,
          location: 'Mountain Pass, CA',
          is_public: 1,
          created_at: '2025-07-09 12:00:00',
          updated_at: '2025-07-09 12:00:00'
        },
        {
          user_id: 2,
          content: 'Safety first! Always wear your gear. Spotted a hazard on Highway 1.',
          image_url: null,
          location: 'Highway 1, CA',
          is_public: 1,
          created_at: '2025-07-09 11:30:00',
          updated_at: '2025-07-09 11:30:00'
        },
        {
          user_id: 3,
          content: 'New Ducati is running perfectly! Ready for the weekend ride.',
          image_url: null,
          location: 'Los Angeles, CA',
          is_public: 1,
          created_at: '2025-07-09 10:15:00',
          updated_at: '2025-07-09 10:15:00'
        }
      ];
      
      for (const post of samplePosts) {
        const columns = Object.keys(post);
        const values = Object.values(post);
        const placeholders = columns.map(() => '?').join(', ');
        const sql = `INSERT INTO posts (${columns.join(', ')}) VALUES (${placeholders})`;
        
        await mysqlConnection.execute(sql, values);
      }
      
      console.log('   ✅ Added 3 sample posts');
    }
    
    // Add some follower relationships
    const [followerRows] = await mysqlConnection.execute('SELECT COUNT(*) as count FROM followers');
    if (followerRows[0].count === 0) {
      const relationships = [
        { follower_id: 1, following_id: 2, created_at: '2025-07-09 09:00:00' },
        { follower_id: 1, following_id: 3, created_at: '2025-07-09 09:00:00' },
        { follower_id: 2, following_id: 1, created_at: '2025-07-09 09:00:00' },
        { follower_id: 2, following_id: 3, created_at: '2025-07-09 09:00:00' },
        { follower_id: 3, following_id: 1, created_at: '2025-07-09 09:00:00' }
      ];
      
      for (const rel of relationships) {
        await mysqlConnection.execute(
          'INSERT INTO followers (follower_id, following_id, created_at) VALUES (?, ?, ?)',
          [rel.follower_id, rel.following_id, rel.created_at]
        );
      }
      
      console.log('   ✅ Added 5 follower relationships');
    }
    
  } catch (error) {
    console.log(`   ⚠️  Error adding sample data: ${error.message}`);
  }
}

// Run the migration
if (require.main === module) {
  migrateData().then(async () => {
    console.log('\n🌟 Migration process completed!');
    console.log('🚀 You can now use your admin interface at http://localhost:3000');
    process.exit(0);
  });
}

module.exports = { migrateData }; 