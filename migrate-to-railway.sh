#!/bin/bash

echo "🚀 MotoRev Database Migration to Railway"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "MotoRevBackend/package.json" ]; then
    print_error "Please run this script from the MotoRev root directory"
    exit 1
fi

print_status "Starting database migration process..."

# Step 1: Create backup of current database
print_status "Step 1: Creating backup of current local database..."

# Create backup directory
mkdir -p database_backup
BACKUP_FILE="database_backup/motorev_backup_$(date +%Y%m%d_%H%M%S).sql"

# Try to backup using mysqldump
if command -v mysqldump &> /dev/null; then
    print_status "Using mysqldump to create backup..."
    mysqldump -u root -p motorev > "$BACKUP_FILE" 2>/dev/null
    if [ $? -eq 0 ]; then
        print_success "Database backup created: $BACKUP_FILE"
    else
        print_warning "mysqldump failed, trying alternative method..."
        # Alternative: Use Node.js to export data
        cd MotoRevBackend
        node -e "
        const mysql = require('mysql2/promise');
        const fs = require('fs');
        
        async function backupDatabase() {
            try {
                const connection = await mysql.createConnection({
                    host: 'localhost',
                    user: 'root',
                    password: '',
                    database: 'motorev'
                });
                
                const tables = await connection.execute('SHOW TABLES');
                let backup = '';
                
                for (const table of tables[0]) {
                    const tableName = Object.values(table)[0];
                    const data = await connection.execute(\`SELECT * FROM \${tableName}\`);
                    backup += \`-- Table: \${tableName}\n\`;
                    backup += \`-- Data: \${JSON.stringify(data[0], null, 2)}\n\n\`;
                }
                
                fs.writeFileSync('../$BACKUP_FILE', backup);
                console.log('Backup created successfully');
                await connection.end();
            } catch (error) {
                console.error('Backup failed:', error.message);
            }
        }
        
        backupDatabase();
        "
        cd ..
    fi
else
    print_warning "mysqldump not found, using Node.js backup method..."
    cd MotoRevBackend
    node -e "
    const mysql = require('mysql2/promise');
    const fs = require('fs');
    
    async function backupDatabase() {
        try {
            const connection = await mysql.createConnection({
                host: 'localhost',
                user: 'root',
                password: '',
                database: 'motorev'
            });
            
            const tables = await connection.execute('SHOW TABLES');
            let backup = '';
            
            for (const table of tables[0]) {
                const tableName = Object.values(table)[0];
                const data = await connection.execute(\`SELECT * FROM \${tableName}\`);
                backup += \`-- Table: \${tableName}\n\`;
                backup += \`-- Data: \${JSON.stringify(data[0], null, 2)}\n\n\`;
            }
            
            fs.writeFileSync('../$BACKUP_FILE', backup);
            console.log('Backup created successfully');
            await connection.end();
        } catch (error) {
            console.error('Backup failed:', error.message);
        }
    }
    
    backupDatabase();
    "
    cd ..
fi

# Step 2: Get Railway MySQL connection details
print_status "Step 2: Setting up Railway MySQL connection..."

# Check if Railway CLI is available
if ! command -v railway &> /dev/null; then
    print_error "Railway CLI not found. Please install it first:"
    echo "npm install -g @railway/cli"
    exit 1
fi

# Get Railway project info
RAILWAY_PROJECT=$(railway status | grep "Project:" | awk '{print $2}')
if [ -z "$RAILWAY_PROJECT" ]; then
    print_error "No Railway project found. Please run 'railway login' and 'railway init' first."
    exit 1
fi

print_status "Railway project: $RAILWAY_PROJECT"

# Step 3: Create migration script
print_status "Step 3: Creating migration script..."

cat > migrate_data.js << 'EOF'
const mysql = require('mysql2/promise');
const fs = require('fs');

// Local database config
const localConfig = {
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'motorev'
};

// Railway database config (will be set via environment variables)
const railwayConfig = {
    host: process.env.MYSQL_HOST,
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    port: process.env.MYSQL_PORT || 3306
};

async function migrateData() {
    let localConnection, railwayConnection;
    
    try {
        console.log('🔗 Connecting to local database...');
        localConnection = await mysql.createConnection(localConfig);
        console.log('✅ Connected to local database');
        
        console.log('🔗 Connecting to Railway database...');
        railwayConnection = await mysql.createConnection(railwayConfig);
        console.log('✅ Connected to Railway database');
        
        // Get all tables from local database
        const [tables] = await localConnection.execute('SHOW TABLES');
        console.log(`📋 Found ${tables.length} tables to migrate`);
        
        for (const tableRow of tables) {
            const tableName = Object.values(tableRow)[0];
            console.log(`🔄 Migrating table: ${tableName}`);
            
            // Get table structure
            const [structure] = await localConnection.execute(`SHOW CREATE TABLE ${tableName}`);
            const createTableSQL = structure[0]['Create Table'];
            
            // Create table in Railway
            try {
                await railwayConnection.execute(`DROP TABLE IF EXISTS ${tableName}`);
                await railwayConnection.execute(createTableSQL);
                console.log(`✅ Created table: ${tableName}`);
            } catch (error) {
                console.log(`⚠️  Table creation failed for ${tableName}:`, error.message);
                continue;
            }
            
            // Get data from local table
            const [data] = await localConnection.execute(`SELECT * FROM ${tableName}`);
            console.log(`📊 Found ${data.length} rows in ${tableName}`);
            
            if (data.length > 0) {
                // Insert data into Railway table
                for (const row of data) {
                    const columns = Object.keys(row).join(', ');
                    const values = Object.values(row).map(val => 
                        val === null ? 'NULL' : `'${String(val).replace(/'/g, "''")}'`
                    ).join(', ');
                    
                    const insertSQL = `INSERT INTO ${tableName} (${columns}) VALUES (${values})`;
                    await railwayConnection.execute(insertSQL);
                }
                console.log(`✅ Migrated ${data.length} rows to ${tableName}`);
            }
        }
        
        console.log('🎉 Database migration completed successfully!');
        
    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    } finally {
        if (localConnection) await localConnection.end();
        if (railwayConnection) await railwayConnection.end();
    }
}

migrateData().catch(console.error);
EOF

print_success "Migration script created: migrate_data.js"

# Step 4: Set up Railway environment variables
print_status "Step 4: Setting up Railway environment variables..."

# Get Railway MySQL service variables
print_status "Please copy the MySQL connection details from your Railway dashboard:"
echo ""
echo "1. Go to your Railway dashboard"
echo "2. Click on your MySQL database service"
echo "3. Go to 'Variables' tab"
echo "4. Copy these values:"
echo "   - MYSQL_HOST"
echo "   - MYSQL_USER"
echo "   - MYSQL_PASSWORD"
echo "   - MYSQL_DATABASE"
echo "   - MYSQL_PORT"
echo ""
echo "5. Then run this command with your values:"
echo "railway variables --set \"MYSQL_HOST=your_host\" --set \"MYSQL_USER=your_user\" --set \"MYSQL_PASSWORD=your_password\" --set \"MYSQL_DATABASE=your_database\" --set \"MYSQL_PORT=your_port\""
echo ""

# Step 5: Deploy to Railway
print_status "Step 5: Deploying to Railway..."

cd MotoRevBackend
railway up

print_success "Migration setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Copy MySQL variables from Railway dashboard to your app service"
echo "2. Run the migration script: node ../migrate_data.js"
echo "3. Your app will be live at: https://motorevv-production.up.railway.app"
echo ""
echo "💾 Your local database backup is saved at: $BACKUP_FILE" 