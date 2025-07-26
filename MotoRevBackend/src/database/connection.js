const mysql = require('mysql2/promise');
require('dotenv').config();

// Debug: Log all environment variables
console.log('🔍 Environment Variables Debug:');
console.log('================================');
console.log('MYSQL_HOST:', process.env.MYSQL_HOST);
console.log('MYSQL_USER:', process.env.MYSQL_USER);
console.log('MYSQL_PASSWORD:', process.env.MYSQL_PASSWORD ? '***SET***' : 'NOT SET');
console.log('MYSQL_DATABASE:', process.env.MYSQL_DATABASE);
console.log('MYSQL_PORT:', process.env.MYSQL_PORT);
console.log('');
console.log('DB_HOST:', process.env.DB_HOST);
console.log('DB_USER:', process.env.DB_USER);
console.log('DB_PASSWORD:', process.env.DB_PASSWORD ? '***SET***' : 'NOT SET');
console.log('DB_NAME:', process.env.DB_NAME);
console.log('DB_PORT:', process.env.DB_PORT);
console.log('');
console.log('NODE_ENV:', process.env.NODE_ENV);
console.log('================================');

// MySQL database configuration - prioritize Railway variables
const dbConfig = {
  host: process.env.MYSQL_HOST || process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.MYSQL_PORT) || parseInt(process.env.DB_PORT) || 3306,
  user: process.env.MYSQL_USER || process.env.DB_USER || 'root',
  password: process.env.MYSQL_PASSWORD || process.env.DB_PASSWORD || '',
  database: process.env.MYSQL_DATABASE || process.env.DB_NAME || 'motorev',
  charset: 'utf8mb4',
  connectionLimit: 10,
  acquireTimeout: 60000,
  timeout: 60000,
  reconnect: true
};

// Debug: Log the database configuration (without password)
console.log('🔧 Database Configuration:');
console.log('Host:', dbConfig.host);
console.log('Port:', dbConfig.port);
console.log('User:', dbConfig.user);
console.log('Database:', dbConfig.database);
console.log('Password set:', dbConfig.password ? 'YES' : 'NO');
console.log('================================');

// Create connection pool for better performance
const pool = mysql.createPool(dbConfig);

// Test connection
async function testConnection() {
  try {
    const connection = await pool.getConnection();
    console.log('✅ Connected to MySQL database successfully');
    connection.release();
  } catch (error) {
    console.error('❌ MySQL connection failed:', error.message);
    throw error;
  }
}

// Helper function to run queries (SELECT statements)
const query = async (sql, params = []) => {
  try {
    const [rows] = await pool.execute(sql, params);
    return rows;
  } catch (error) {
    console.error('Query error:', error);
    throw error;
  }
};

// Helper function to get single row
const get = async (sql, params = []) => {
  try {
    const [rows] = await pool.execute(sql, params);
    return rows[0] || null;
  } catch (error) {
    console.error('Get query error:', error);
    throw error;
  }
};

// Helper function for insert/update/delete
const run = async (sql, params = []) => {
  try {
    const [result] = await pool.execute(sql, params);
    return {
      insertId: result.insertId,
      affectedRows: result.affectedRows,
      changedRows: result.changedRows || 0
    };
  } catch (error) {
    console.error('Run query error:', error);
    throw error;
  }
};

// Helper function to execute multiple statements (for schema setup)
const executeMultiple = async (sql) => {
  const connection = await pool.getConnection();
  try {
    // Split SQL by semicolons and execute each statement
    const statements = sql.split(';').filter(stmt => stmt.trim().length > 0);
    
    for (const statement of statements) {
      if (statement.trim()) {
        await connection.execute(statement);
      }
    }
  } finally {
    connection.release();
  }
};

// Graceful shutdown
const closePool = async () => {
  try {
    await pool.end();
    console.log('✅ MySQL connection pool closed');
  } catch (error) {
    console.error('❌ Error closing MySQL pool:', error);
  }
};

module.exports = {
  pool,
  query,
  get,
  run,
  executeMultiple,
  testConnection,
  closePool
}; 