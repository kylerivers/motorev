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
