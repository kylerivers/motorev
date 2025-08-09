#!/usr/bin/env node

// Debug: Log ALL environment variables to see what Railway is passing
console.log('🔍 ALL Environment Variables:');
console.log('================================');
Object.keys(process.env).sort().forEach(key => {
  const value = key.includes('PASSWORD') || key.includes('SECRET') ? '***HIDDEN***' : process.env[key];
  console.log(`${key}=${value}`);
});
console.log('================================');

// Map Railway MySQL env (MYSQLHOST-style) to our expected underscore vars
if (process.env.MYSQLHOST) {
  console.log('✅ Mapping Railway MySQL variables');
  process.env.MYSQL_HOST = process.env.MYSQL_HOST || process.env.MYSQLHOST;
  process.env.MYSQL_PORT = process.env.MYSQL_PORT || process.env.MYSQLPORT;
  process.env.MYSQL_USER = process.env.MYSQL_USER || process.env.MYSQLUSER;
  process.env.MYSQL_PASSWORD = process.env.MYSQL_PASSWORD || process.env.MYSQLPASSWORD;
  process.env.MYSQL_DATABASE = process.env.MYSQL_DATABASE || process.env.MYSQLDATABASE;
}

// Start the server
require('./server.js'); 