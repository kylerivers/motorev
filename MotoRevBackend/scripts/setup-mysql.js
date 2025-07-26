#!/usr/bin/env node

const mysql = require('mysql2/promise');
require('dotenv').config();

async function setupMySQL() {
  let connection;
  
  try {
    console.log('🔧 Setting up MySQL database for MotoRev...');
    
    // Connect to MySQL without specifying database
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 3306,
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      charset: 'utf8mb4'
    });
    
    console.log('✅ Connected to MySQL server');
    
    // Create database if it doesn't exist
    const dbName = process.env.DB_NAME || 'motorev';
    await connection.execute(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
    console.log(`✅ Database '${dbName}' created/verified`);
    
    console.log('🎉 MySQL setup completed successfully!');
    console.log('');
    console.log('Next steps:');
    console.log('1. Run: npm start');
    console.log('2. The server will automatically create tables and seed data');
    console.log('3. Visit: http://localhost:3000 to see the database admin interface');
    
  } catch (error) {
    console.error('❌ MySQL setup failed:', error.message);
    console.log('');
    console.log('Troubleshooting:');
    console.log('1. Make sure MySQL is installed and running');
    console.log('2. Check your .env file for correct database credentials');
    console.log('3. Ensure the MySQL user has CREATE DATABASE privileges');
    
    if (error.code === 'ECONNREFUSED') {
      console.log('4. MySQL server appears to be offline. Start it with:');
      console.log('   macOS: brew services start mysql');
      console.log('   Linux: sudo systemctl start mysql');
      console.log('   Windows: net start mysql');
    }
    
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run if called directly
if (require.main === module) {
  setupMySQL();
}

module.exports = setupMySQL; 