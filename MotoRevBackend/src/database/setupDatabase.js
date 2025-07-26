const fs = require('fs').promises;
const path = require('path');
const { pool, query, run, executeMultiple, testConnection } = require('./connection');

async function setupDatabase() {
  try {
    console.log('🔧 Setting up MySQL database...');

    // Test connection first
    await testConnection();

    // Read and execute MySQL schema
    const schemaPath = path.join(__dirname, 'schema_mysql.sql');
    const schema = await fs.readFile(schemaPath, 'utf8');
    
    // Execute schema using executeMultiple for MySQL
    await executeMultiple(schema);

    console.log('✅ Database schema created successfully');

    // Check if we should seed data
    const users = await query('SELECT COUNT(*) as count FROM users');
    if (users[0].count === 0) {
      console.log('🌱 Seeding initial data...');
      await seedInitialData();
    } else {
      console.log('📊 Database already contains data, skipping seed');
    }

    console.log('🎉 Database setup complete!');
    
  } catch (error) {
    console.error('❌ Database setup failed:', error);
    throw error;
  }
}

async function seedInitialData() {
  try {
    // Create test users
    const testUsers = [
      {
        username: 'rider_alex',
        email: 'alex@motorev.com',
        password_hash: '$2a$10$rOQqm5Z8hJ5A5Q5Z5Z5Z5uO5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5',
        first_name: 'Alex',
        last_name: 'Rivera',
        motorcycle_make: 'Yamaha',
        motorcycle_model: 'R1',
        motorcycle_year: 2023,
        total_miles: 15420,
        safety_score: 95,
        status: 'online'
      },
      {
        username: 'biker_sam',
        email: 'sam@motorev.com', 
        password_hash: '$2a$10$rOQqm5Z8hJ5A5Q5Z5Z5Z5uO5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5',
        first_name: 'Sam',
        last_name: 'Chen',
        motorcycle_make: 'Honda',
        motorcycle_model: 'CBR1000RR',
        motorcycle_year: 2022,
        total_miles: 8750,
        safety_score: 88,
        status: 'riding'
      },
      {
        username: 'road_warrior',
        email: 'warrior@motorev.com',
        password_hash: '$2a$10$rOQqm5Z8hJ5A5Q5Z5Z5Z5uO5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5',
        first_name: 'Jordan',
        last_name: 'Taylor',
        motorcycle_make: 'Ducati',
        motorcycle_model: 'Panigale V4',
        motorcycle_year: 2024,
        total_miles: 3200,
        safety_score: 92,
        status: 'offline'
      }
    ];

    for (const user of testUsers) {
      await run(`
        INSERT INTO users (username, email, password_hash, first_name, last_name, 
                          motorcycle_make, motorcycle_model, motorcycle_year, 
                          total_miles, safety_score, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        user.username, user.email, user.password_hash, user.first_name, user.last_name,
        user.motorcycle_make, user.motorcycle_model, user.motorcycle_year,
        user.total_miles, user.safety_score, user.status
      ]);
    }

    // Create some test posts
    await run(`
      INSERT INTO posts (user_id, content, post_type, likes_count, comments_count)
      VALUES 
        (1, 'Just completed an amazing 200-mile ride through the mountains! 🏔️ The new R1 handled every curve perfectly.', 'ride', 12, 3),
        (2, 'PSA: Watch out for construction on Highway 101 near mile marker 45. Lane closures causing delays.', 'safety', 8, 1),
        (3, 'First ride on the new Panigale! This machine is absolutely incredible. The power delivery is smooth as silk.', 'general', 15, 5)
    `);

    // Create a test riding pack
    await run(`
      INSERT INTO riding_packs (name, description, created_by, meeting_point_lat, 
                               meeting_point_lng, meeting_point_name, start_time)
      VALUES ('Weekend Mountain Cruise', 'Scenic ride through the coastal mountains', 1, 
              37.7749, -122.4194, 'Golden Gate Park', DATE_ADD(NOW(), INTERVAL 2 DAY))
    `);

    // Add members to the pack
    await run(`
      INSERT INTO pack_members (pack_id, user_id, role, status)
      VALUES 
        (1, 1, 'leader', 'active'),
        (1, 2, 'member', 'active')
    `);

    // Create some hazard reports
    await run(`
      INSERT INTO hazard_reports (reporter_id, hazard_type, severity, latitude, longitude, 
                                 location_name, description, upvotes)
      VALUES 
        (1, 'pothole', 'medium', 37.7849, -122.4094, 'Highway 1', 'Large pothole in right lane', 3),
        (2, 'debris', 'high', 37.7949, -122.3994, 'Pacific Coast Highway', 'Tree branch blocking lane', 7)
    `);

    console.log('✅ Test data seeded successfully');
    
  } catch (error) {
    console.error('❌ Seeding failed:', error);
    throw error;
  }
}

// Run setup if called directly
if (require.main === module) {
  setupDatabase()
    .then(() => {
      console.log('Database setup completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Database setup failed:', error);
      process.exit(1);
    });
}

module.exports = { setupDatabase, seedInitialData }; 