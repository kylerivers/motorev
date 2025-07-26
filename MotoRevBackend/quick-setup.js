#!/usr/bin/env node

const mysql = require('mysql2/promise');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

async function quickSetup() {
  console.log('🏍️  MotoRev MySQL Quick Setup');
  console.log('================================');
  console.log('');

  try {
    // Get MySQL password from user
    const password = await new Promise((resolve) => {
      rl.question('Enter your MySQL root password: ', (answer) => {
        resolve(answer);
      });
    });

    console.log('🔌 Connecting to MySQL...');
    
    // Connect to MySQL
    const connection = await mysql.createConnection({
      host: 'localhost',
      port: 3306,
      user: 'root',
      password: password,
      charset: 'utf8mb4'
    });

    console.log('✅ Connected to MySQL successfully!');

    // Create database
    await connection.execute('CREATE DATABASE IF NOT EXISTS motorev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
    console.log('✅ Database "motorev" created successfully!');

    // Update .env file
    const fs = require('fs');
    let envContent = fs.readFileSync('.env', 'utf8');
    envContent = envContent.replace('DB_PASSWORD=yourpassword', `DB_PASSWORD=${password}`);
    fs.writeFileSync('.env', envContent);
    console.log('✅ Updated .env file with your password');

    await connection.end();

    console.log('');
    console.log('🎉 Setup complete! Now run:');
    console.log('   npm start');
    console.log('');
    console.log('Then visit: http://localhost:3000');

  } catch (error) {
    console.error('❌ Setup failed:', error.message);
    
    if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      console.log('');
      console.log('💡 Try these solutions:');
      console.log('1. Make sure you entered the correct password');
      console.log('2. If you forgot the password, reset it with:');
      console.log('   brew services stop mysql');
      console.log('   mysqld_safe --skip-grant-tables &');
      console.log('   mysql -u root');
      console.log('   Then: ALTER USER "root"@"localhost" IDENTIFIED BY "newpassword";');
    }
  } finally {
    rl.close();
  }
}

quickSetup(); 