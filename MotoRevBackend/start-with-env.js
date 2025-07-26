#!/usr/bin/env node

// Debug: Log ALL environment variables to see what Railway is passing
console.log('🔍 ALL Environment Variables:');
console.log('================================');
Object.keys(process.env).sort().forEach(key => {
  const value = key.includes('PASSWORD') || key.includes('SECRET') ? '***HIDDEN***' : process.env[key];
  console.log(`${key}=${value}`);
});
console.log('================================');

// Force set Railway environment variables if they exist
if (process.env.MYSQL_HOST) {
  console.log('✅ Railway MySQL variables detected');
  console.log('MYSQL_HOST:', process.env.MYSQL_HOST);
  console.log('MYSQL_USER:', process.env.MYSQL_USER);
  console.log('MYSQL_DATABASE:', process.env.MYSQL_DATABASE);
  console.log('MYSQL_PORT:', process.env.MYSQL_PORT);
  console.log('MYSQL_PASSWORD:', process.env.MYSQL_PASSWORD ? '***SET***' : 'NOT SET');
} else {
  console.log('❌ Railway MySQL variables NOT detected');
  console.log('Available env vars:', Object.keys(process.env).filter(k => k.includes('MYSQL')));
}

// Start the server
require('./server.js'); 