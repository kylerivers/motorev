const mysql = require('mysql2/promise');
const readline = require('readline');
const fs = require('fs');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

async function setupMySQLDatabase() {
  try {
    console.log('🔧 Setting up MySQL database for MotoRev...');
    
    // Get password from user
    const password = await new Promise((resolve) => {
      rl.question('Enter MySQL root password: ', (answer) => {
        resolve(answer);
      });
    });
    
    // Create connection
    const connection = await mysql.createConnection({
      host: 'localhost',
      port: 3306,
      user: 'root',
      password: password
    });
    
    console.log('✅ Connected to MySQL successfully');
    
    // Create database
    await connection.execute('CREATE DATABASE IF NOT EXISTS motorev');
    console.log('✅ Database "motorev" created/verified');
    
    // Use the database
    await connection.execute('USE motorev');
    
    // Read and execute schema
    const schemaPath = './src/database/schema_mysql.sql';
    if (fs.existsSync(schemaPath)) {
      const schema = fs.readFileSync(schemaPath, 'utf8');
      const statements = schema.split(';').filter(stmt => stmt.trim().length > 0);
      
      for (const statement of statements) {
        if (statement.trim()) {
          await connection.execute(statement);
        }
      }
      console.log('✅ Database schema created successfully');
    } else {
      console.log('⚠️  Schema file not found, skipping schema creation');
    }
    
    // Read and execute seed data
    const seedPath = './src/database/seed_mysql.sql';
    if (fs.existsSync(seedPath)) {
      const seed = fs.readFileSync(seedPath, 'utf8');
      const statements = seed.split(';').filter(stmt => stmt.trim().length > 0);
      
      for (const statement of statements) {
        if (statement.trim()) {
          try {
            await connection.execute(statement);
          } catch (error) {
            // Ignore duplicate entry errors
            if (!error.message.includes('Duplicate entry')) {
              throw error;
            }
          }
        }
      }
      console.log('✅ Seed data loaded successfully');
    } else {
      console.log('⚠️  Seed file not found, skipping seed data');
    }
    
    // Update .env file
    const envContent = `# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=${password}
DB_NAME=motorev

# Server Configuration
PORT=3000
NODE_ENV=development
CORS_ORIGIN=*

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-here-change-in-production
JWT_EXPIRES_IN=7d

# File Upload Configuration
MAX_FILE_SIZE=10485760
UPLOAD_PATH=./uploads

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=1000
`;
    
    fs.writeFileSync('.env', envContent);
    console.log('✅ .env file updated with database configuration');
    
    await connection.end();
    console.log('🎉 MySQL database setup complete!');
    console.log('💡 You can now run "npm start" to start the server');
    
  } catch (error) {
    console.error('❌ Setup failed:', error.message);
    process.exit(1);
  } finally {
    rl.close();
  }
}

setupMySQLDatabase(); 