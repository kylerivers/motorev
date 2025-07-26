require('dotenv').config();

console.log('🔍 Testing Environment Variables:');
console.log('================================');
console.log('All environment variables:');
Object.keys(process.env).forEach(key => {
  if (key.includes('MYSQL') || key.includes('DB') || key.includes('NODE_ENV')) {
    const value = key.includes('PASSWORD') ? '***HIDDEN***' : process.env[key];
    console.log(`${key}=${value}`);
  }
});
console.log('================================'); 