const fs = require('fs').promises;
const path = require('path');
const { pool, query, run, executeMultiple, testConnection } = require('./connection');

async function dropAllTablesForReset() {
  console.log('⚠️ SCHEMA_RESET=true detected. Dropping existing tables (safe order)...');
  const tables = [
    'hazard_confirmations',
    'hazard_reports',
    'emergency_events',
    'location_updates',
    'location_shares',
    'maintenance_templates',
    'maintenance_records',
    'bikes',
    'pack_members',
    'riding_packs',
    'post_comments',
    'post_likes',
    'story_views',
    'stories',
    'posts',
    'followers',
    'user_sessions',
    'notifications',
    'analytics_events',
    'content_moderation',
    'db_performance_log',
    'rides',
    'users'
  ];
  await pool.execute('SET FOREIGN_KEY_CHECKS=0');
  for (const t of tables) {
    try { await pool.execute(`DROP TABLE IF EXISTS \`${t}\``); console.log(`   - dropped ${t}`);} catch (e) { console.log(`   - skip ${t}: ${e.message}`);} }
  await pool.execute('SET FOREIGN_KEY_CHECKS=1');
  console.log('✅ Drop complete');
}

async function ensureCoreIdsAreBigInt() {
  console.log('🔎 Ensuring core id columns use BIGINT UNSIGNED...');
  const core = [
    { table: 'users', column: 'id' },
    { table: 'posts', column: 'id' },
    { table: 'stories', column: 'id' },
    { table: 'rides', column: 'id' },
  ];
  for (const { table, column } of core) {
    try {
      const [rows] = await pool.execute(
        `SELECT DATA_TYPE, COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
        [table, column]
      );
      const type = rows[0]?.DATA_TYPE;
      const columnType = rows[0]?.COLUMN_TYPE?.toLowerCase() || '';
      const isUnsigned = columnType.includes('unsigned');
      if (!rows[0] || type.toLowerCase() !== 'bigint' || !isUnsigned) {
        console.log(`   - Upgrading ${table}.${column} (${columnType || 'missing'}) -> BIGINT UNSIGNED`);
        await pool.execute('SET FOREIGN_KEY_CHECKS=0');
        await pool.execute(`ALTER TABLE \`${table}\` MODIFY \`${column}\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT`);
        await pool.execute('SET FOREIGN_KEY_CHECKS=1');
      }
    } catch (e) {
      // Table might not exist yet; skip
    }
  }
  const fkCols = [
    { table: 'location_shares', column: 'user_id' },
    { table: 'location_updates', column: 'user_id' },
    { table: 'post_likes', column: 'user_id' },
    { table: 'post_comments', column: 'user_id' },
    { table: 'posts', column: 'user_id' },
    { table: 'rides', column: 'user_id' },
    { table: 'followers', column: 'follower_id' },
    { table: 'followers', column: 'following_id' },
    { table: 'riding_packs', column: 'created_by' },
    { table: 'pack_members', column: 'user_id' },
    { table: 'pack_members', column: 'pack_id' },
    { table: 'maintenance_records', column: 'user_id' },
    { table: 'maintenance_records', column: 'bike_id' },
    { table: 'bikes', column: 'user_id' },
  ];
  for (const { table, column } of fkCols) {
    try {
      const [rows] = await pool.execute(
        `SELECT DATA_TYPE, COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
        [table, column]
      );
      const type = rows[0]?.DATA_TYPE;
      const columnType = rows[0]?.COLUMN_TYPE?.toLowerCase() || '';
      const isUnsigned = columnType.includes('unsigned');
      if (!rows[0] || type.toLowerCase() !== 'bigint' || !isUnsigned) {
        console.log(`   - Upgrading ${table}.${column} (${columnType || 'missing'}) -> BIGINT UNSIGNED`);
        await pool.execute('SET FOREIGN_KEY_CHECKS=0');
        await pool.execute(`ALTER TABLE \`${table}\` MODIFY \`${column}\` BIGINT UNSIGNED NOT NULL`);
        await pool.execute('SET FOREIGN_KEY_CHECKS=1');
      }
    } catch { /* ignore if table not present yet */ }
  }
  console.log('✅ Core id columns verified/updated');
}

async function ensureAdminColumns() {
  console.log('🔎 Ensuring admin-related columns exist...');
  const checks = [
    { column: 'role', ddl: "ALTER TABLE `users` ADD COLUMN `role` ENUM('user','admin','super_admin') DEFAULT 'user' AFTER is_premium" },
    { column: 'subscription_tier', ddl: "ALTER TABLE `users` ADD COLUMN `subscription_tier` ENUM('standard','pro') DEFAULT 'standard' AFTER role" }
  ];
  for (const { column, ddl } of checks) {
    try {
      const [rows] = await pool.execute(
        `SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = ?`,
        [column]
      );
      if (rows.length === 0) {
        console.log(`   - Adding users.${column}`);
        await pool.execute(ddl);
      }
    } catch (e) {
      console.log(`   - Could not verify/add users.${column}: ${e.message}`);
    }
  }
  console.log('✅ Admin columns verified');
}

async function ensureAdditionalColumns() {
  console.log('🔧 Ensuring additional table columns...');
  
  // Check and add columns to riding_packs table
  const ridingPacksColumns = [
    { name: 'current_track', ddl: 'ALTER TABLE riding_packs ADD COLUMN current_track VARCHAR(255) DEFAULT NULL' },
    { name: 'current_artist', ddl: 'ALTER TABLE riding_packs ADD COLUMN current_artist VARCHAR(255) DEFAULT NULL' },
    { name: 'track_updated_at', ddl: 'ALTER TABLE riding_packs ADD COLUMN track_updated_at TIMESTAMP DEFAULT NULL' }
  ];
  
  for (const column of ridingPacksColumns) {
    try {
      const [rows] = await pool.execute(
        `SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'riding_packs' AND COLUMN_NAME = ?`,
        [column.name]
      );
      if (rows.length === 0) {
        console.log(`   - Adding riding_packs.${column.name}`);
        await pool.execute(column.ddl);
      } else {
        console.log(`   - riding_packs.${column.name} already exists`);
      }
    } catch (e) {
      console.log(`   - Could not verify/add riding_packs.${column.name}: ${e.message}`);
    }
  }
  
  // Check and add columns to pack_members table
  const packMembersColumns = [
    { name: 'is_music_connected', ddl: 'ALTER TABLE pack_members ADD COLUMN is_music_connected BOOLEAN DEFAULT FALSE' },
    { name: 'is_voice_connected', ddl: 'ALTER TABLE pack_members ADD COLUMN is_voice_connected BOOLEAN DEFAULT FALSE' }
  ];
  
  for (const column of packMembersColumns) {
    try {
      const [rows] = await pool.execute(
        `SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pack_members' AND COLUMN_NAME = ?`,
        [column.name]
      );
      if (rows.length === 0) {
        console.log(`   - Adding pack_members.${column.name}`);
        await pool.execute(column.ddl);
      } else {
        console.log(`   - pack_members.${column.name} already exists`);
      }
    } catch (e) {
      console.log(`   - Could not verify/add pack_members.${column.name}: ${e.message}`);
    }
  }
  
  console.log('✅ Additional columns verified');
}

async function setupDatabase(attempt = 0) {
  try {
    console.log('🔧 Setting up MySQL database...');
    await testConnection();

    const doReset = String(process.env.SCHEMA_RESET || 'false').toLowerCase() === 'true';
    if (doReset) { await dropAllTablesForReset(); }

    await ensureCoreIdsAreBigInt();

    const schemaPath = path.join(__dirname, 'schema_mysql.sql');
    const schema = await fs.readFile(schemaPath, 'utf8');

    // Force all BIGINT columns in schema to UNSIGNED for compatibility
    const adjustedSchema = schema.replace(/\bBIGINT\b/gi, 'BIGINT UNSIGNED');

    await pool.execute('SET FOREIGN_KEY_CHECKS=0');
    await executeMultiple(adjustedSchema);
    await pool.execute('SET FOREIGN_KEY_CHECKS=1');

    // Ensure columns in case table already existed
    await ensureAdminColumns();
    await ensureAdditionalColumns();

    console.log('✅ Database schema created successfully');

    const isProduction = (process.env.NODE_ENV || 'development') === 'production';
    if (!isProduction && !doReset) {
      const users = await query('SELECT COUNT(*) as count FROM users');
      if (users[0].count === 0) { console.log('🌱 Seeding initial data (non-production)...'); await seedInitialData(); }
      else { console.log('📊 Database already contains data, skipping seed'); }
    } else if (isProduction) { console.log('🚫 Production environment detected: skipping seed'); }

    console.log('🎉 Database setup complete!');
  } catch (error) {
    if (error && error.code === 'ER_FK_INCOMPATIBLE_COLUMNS' && attempt === 0) {
      console.warn('🛠️ Detected FK type mismatch. Performing one-time auto-repair (drop & recreate)...');
      await dropAllTablesForReset();
      return setupDatabase(1);
    }
    console.error('❌ Database setup failed:', error);
    throw error;
  }
}

async function seedInitialData() {
  try {
    const testUsers = [
      { username: 'rider_alex', email: 'alex@motorev.com', password_hash: '$2a$10$rOQqm5Z8hJ5A5Q5Z5Z5Z5uO5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5', first_name: 'Alex', last_name: 'Rivera', motorcycle_make: 'Yamaha', motorcycle_model: 'R1', motorcycle_year: 2023, total_miles: 15420, safety_score: 95, status: 'online' },
      { username: 'biker_sam', email: 'sam@motorev.com', password_hash: '$2a$10$rOQqm5Z8hJ5A5Q5Z5Z5Z5uO5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5', first_name: 'Sam', last_name: 'Chen', motorcycle_make: 'Honda', motorcycle_model: 'CBR1000RR', motorcycle_year: 2022, total_miles: 8750, safety_score: 88, status: 'riding' },
      { username: 'road_warrior', email: 'warrior@motorev.com', password_hash: '$2a$10$rOQqm5Z8hJ5A5Q5Z5Z5Z5uO5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5', first_name: 'Jordan', last_name: 'Taylor', motorcycle_make: 'Ducati', motorcycle_model: 'Panigale V4', motorcycle_year: 2024, total_miles: 3200, safety_score: 92, status: 'offline' }
    ];
    for (const user of testUsers) {
      await run(`INSERT INTO users (username, email, password_hash, first_name, last_name, motorcycle_make, motorcycle_model, motorcycle_year, total_miles, safety_score, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, [user.username, user.email, user.password_hash, user.first_name, user.last_name, user.motorcycle_make, user.motorcycle_model, user.motorcycle_year, user.total_miles, user.safety_score, user.status]);
    }
    await run(`INSERT INTO posts (user_id, content, post_type, likes_count, comments_count) VALUES (1, 'Just completed an amazing 200-mile ride through the mountains! 🏔️ The new R1 handled every curve perfectly.', 'ride', 12, 3), (2, 'PSA: Watch out for construction on Highway 101 near mile marker 45. Lane closures causing delays.', 'safety', 8, 1), (3, 'First ride on the new Panigale! This machine is absolutely incredible. The power delivery is smooth as silk.', 'general', 15, 5)`);
    await run(`INSERT INTO riding_packs (name, description, created_by, meeting_point_lat, meeting_point_lng, meeting_point_name, start_time) VALUES ('Weekend Mountain Cruise', 'Scenic ride through the coastal mountains', 1, 37.7749, -122.4194, 'Golden Gate Park', DATE_ADD(NOW(), INTERVAL 2 DAY))`);
    await run(`INSERT INTO pack_members (pack_id, user_id, role, status) VALUES (1, 1, 'leader', 'active'), (1, 2, 'member', 'active')`);
    await run(`INSERT INTO hazard_reports (reporter_id, hazard_type, severity, latitude, longitude, location_name, description, upvotes) VALUES (1, 'pothole', 'medium', 37.7849, -122.4094, 'Highway 1', 'Large pothole in right lane', 3), (2, 'debris', 'high', 37.7949, -122.3994, 'Pacific Coast Highway', 'Tree branch blocking lane', 7)`);
    console.log('✅ Test data seeded successfully');
  } catch (error) {
    console.error('❌ Seeding failed:', error);
    throw error;
  }
}

if (require.main === module) {
  setupDatabase()
    .then(() => { console.log('Database setup completed successfully'); process.exit(0); })
    .catch((error) => { console.error('Database setup failed:', error); process.exit(1); });
}

module.exports = { setupDatabase, seedInitialData }; 