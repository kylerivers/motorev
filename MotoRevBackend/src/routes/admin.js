const express = require('express');
const { query, get, run } = require('../database/connection');
const { authenticateToken, requireAdmin, requireSuperAdmin } = require('../middleware/auth');
const router = express.Router();

// Debug endpoint without auth (temporary)
router.get('/debug/users-schema', async (req, res) => {
  try {
    const columns = await query('DESCRIBE users');
    const sampleData = await query('SELECT * FROM users LIMIT 1');
    res.json({ 
      columns, 
      sampleData,
      columnNames: columns.map(col => col.Field)
    });
  } catch (e) {
    console.error('Schema debug error:', e);
    res.status(500).json({ error: e.message });
  }
});

// TEMP: Debug users endpoint without auth
router.get('/debug/users', async (req, res) => {
  try {
    const { search = '', page = 1, limit = 50 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const like = `%${search}%`;
    
    console.log('🚨🚨🚨 [Admin] DEBUG /admin/debug/users called', { search, page, limit });
    
    const rows = await query(`
      SELECT 
        id, username, email, first_name, last_name, role, subscription_tier, is_premium,
        created_at, updated_at
      FROM users
      ORDER BY created_at DESC
      LIMIT 5
    `);
    
    const users = rows.map(row => ({
      id: row.id,
      username: row.username,
      email: row.email,
      firstName: row.first_name,
      lastName: row.last_name,
      role: row.role || 'user',
      subscriptionTier: row.subscription_tier || 'standard',
      isPremium: Boolean(row.is_premium),
      totalRides: 0,
      totalMiles: 0,
      totalRideTime: 0.0,
      safetyScore: 100,
      status: 'offline',
      locationSharingEnabled: false,
      isVerified: Boolean(row.is_verified),
      phone: null,
      bio: null,
      motorcycleMake: null,
      motorcycleModel: null,
      motorcycleYear: null,
      profilePictureUrl: null,
      ridingExperience: 'beginner',
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      postsCount: 0,
      followersCount: 0,
      followingCount: 0
    }));
    
    console.log('🚨🚨🚨 [Admin] DEBUG returning:', { userCount: users.length, firstUser: users[0] ? users[0].username : 'none' });
    res.json({ users });
    
  } catch (e) {
    console.error('❌ [Admin] DEBUG users error:', e);
    res.status(500).json({ error: e.message, stack: e.stack });
  }
});

// Require auth/admin for all admin routes
router.use(authenticateToken, requireAdmin);

// Whitelist allowed tables for security
const allowedTables = [
  'posts', 'stories', 'rides', 'emergency_events', 
  'hazard_reports', 'followers', 'post_likes', 'post_comments',
  'location_updates', 'riding_packs', 'pack_members', 'user_sessions',
  'story_views', 'hazard_confirmations'
];

// Users management
router.get('/users', async (req, res) => {
  try {
    const { search = '', page = 1, limit = 50 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const like = `%${search}%`;
    
    console.log('🚨🚨🚨 [Admin] GET /admin/users called', { search, page, limit, url: req.originalUrl });
    console.log('🚨🚨🚨 [Admin] Request headers:', req.headers.authorization ? 'HAS AUTH' : 'NO AUTH');
    
        // Use simple query without prepared statement parameters for now
    const rows = await query(`
      SELECT
        id, username, email, first_name, last_name, role, subscription_tier, is_premium,
        created_at, updated_at
      FROM users
      ORDER BY created_at DESC
      LIMIT ${parseInt(limit)} OFFSET ${offset}
    `);
    
    // Transform the data to match the client's expected structure
    const users = rows.map(row => ({
      id: row.id,
      username: row.username,
      email: row.email,
      firstName: row.first_name,
      lastName: row.last_name,
      role: row.role || 'user',
      subscriptionTier: row.subscription_tier || 'standard',
      isPremium: Boolean(row.is_premium),
      totalRides: row.total_rides || 0,
      totalMiles: row.total_miles || 0,
      totalRideTime: row.total_ride_time || 0.0,
      safetyScore: row.safety_score || 100,
      status: row.status || 'offline',
      locationSharingEnabled: Boolean(row.location_sharing_enabled),
      isVerified: Boolean(row.is_verified),
      phone: row.phone,
      bio: row.bio,
      motorcycleMake: row.motorcycle_make,
      motorcycleModel: row.motorcycle_model,
      motorcycleYear: row.motorcycle_year,
      profilePictureUrl: row.profile_picture_url,
      ridingExperience: row.riding_experience || 'beginner',
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      postsCount: row.posts_count || 0,
      followersCount: row.followers_count || 0,
      followingCount: row.following_count || 0
    }));
    
    console.log('🚨🚨🚨 [Admin] About to return:', { userCount: users.length, firstUser: users[0] ? users[0].username : 'none' });
    console.log('🚨🚨🚨 [Admin] Response structure: { users: [...] }');
    res.json({ users });
    
  } catch (e) {
    console.error('❌ [Admin] List users error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/users/:id/role', requireSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;
    if (!['user','admin','super_admin'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role' });
    }
    await run('UPDATE users SET role = ?, updated_at = NOW() WHERE id = ?', [role, id]);
    res.json({ message: 'Role updated' });
  } catch (e) {
    console.error('Update role error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/users/:id/subscription', async (req, res) => {
  try {
    const { id } = req.params;
    const { tier } = req.body; // 'standard' | 'pro'
    if (!['standard','pro'].includes(tier)) {
      return res.status(400).json({ error: 'Invalid tier' });
    }
    await run('UPDATE users SET subscription_tier = ?, is_premium = ?, updated_at = NOW() WHERE id = ?', [tier, tier === 'pro', id]);
    res.json({ message: 'Subscription updated' });
  } catch (e) {
    console.error('Update subscription error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update hazard status
router.put('/hazards/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // 'active','resolved','duplicate','false_report'
    if (!['active','resolved','duplicate','false_report'].includes(status)) {
      return res.status(400).json({ error: 'Invalid hazard status' });
    }
    const result = await run('UPDATE hazard_reports SET status = ?, updated_at = NOW() WHERE id = ?', [status, id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Hazard not found' });
    res.json({ message: 'Hazard status updated' });
  } catch (e) {
    console.error('Update hazard status error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Resolve/Unresolve emergency event
router.put('/emergencies/:id/resolve', async (req, res) => {
  try {
    const { id } = req.params;
    const { resolved } = req.body; // boolean
    const isResolved = resolved ? 1 : 0;
    const result = await run('UPDATE emergency_events SET is_resolved = ?, resolved_at = CASE WHEN ? = 1 THEN NOW() ELSE NULL END WHERE id = ?', [isResolved, isResolved, id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Emergency event not found' });
    res.json({ message: 'Emergency resolution updated' });
  } catch (e) {
    console.error('Resolve emergency error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get table data with pagination
router.get('/table/:tableName', async (req, res) => {
  try {
    const { tableName } = req.params;
    const { limit = 100, offset = 0 } = req.query;
    
    console.log('🔥🔥🔥 [Admin] GET /admin/table/' + tableName + ' called', { limit, offset, url: req.originalUrl });
    
    if (!allowedTables.includes(tableName)) {
      return res.status(400).json({ error: 'Invalid table name' });
    }
    
    const sanitizedLimit = Math.max(1, Math.min(1000, parseInt(limit) || 100));
    const sanitizedOffset = Math.max(0, parseInt(offset) || 0);
    
    const rows = await query(`SELECT * FROM ${tableName} ORDER BY id DESC LIMIT ${sanitizedLimit} OFFSET ${sanitizedOffset}`);
    const totalResult = await get(`SELECT COUNT(*) as total FROM ${tableName}`);
    
    console.log('🔥🔥🔥 [Admin] Returning table data with ROWS structure for', tableName, { rowCount: rows.length });
    res.json({ 
      rows, 
      total: totalResult?.total || 0,
      limit: sanitizedLimit,
      offset: sanitizedOffset
    });
  } catch (error) {
    console.error('Get table data error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get single record by ID
router.get('/table/:tableName/:id', async (req, res) => {
  try {
    const { tableName, id } = req.params;
    
    if (!allowedTables.includes(tableName)) {
      return res.status(400).json({ error: 'Invalid table name' });
    }
    
    const record = await get(`SELECT * FROM ${tableName} WHERE id = ?`, [id]);
    
    if (!record) {
      return res.status(404).json({ error: 'Record not found' });
    }
    
    res.json(record);
  } catch (error) {
    console.error('Get record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new record
router.post('/table/:tableName', async (req, res) => {
  try {
    const { tableName } = req.params;
    const data = req.body;
    
    if (!allowedTables.includes(tableName)) {
      return res.status(400).json({ error: 'Invalid table name' });
    }
    
    // Remove id from data if present (auto-increment)
    delete data.id;
    
    // Add timestamps if table supports them
    if (data.hasOwnProperty('created_at') || tableName === 'posts') {
      data.created_at = new Date().toISOString();
      data.updated_at = new Date().toISOString();
    }
    
    const columns = Object.keys(data);
    const values = Object.values(data);
    const placeholders = columns.map(() => '?').join(', ');
    
    const sql = `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES (${placeholders})`;
    const result = await run(sql, values);
    
    res.json({ 
      message: 'Record created successfully',
      id: result.insertId,
      affectedRows: result.affectedRows
    });
  } catch (error) {
    console.error('Create record error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Update existing record
router.put('/table/:tableName/:id', async (req, res) => {
  try {
    const { tableName, id } = req.params;
    const data = req.body;
    
    if (!allowedTables.includes(tableName)) {
      return res.status(400).json({ error: 'Invalid table name' });
    }
    
    // Remove id from data
    delete data.id;
    
    // Add updated timestamp if table supports it
    if (data.hasOwnProperty('updated_at') || tableName === 'posts') {
      data.updated_at = new Date().toISOString();
    }
    
    const columns = Object.keys(data);
    const values = Object.values(data);
    const setClause = columns.map(col => `${col} = ?`).join(', ');
    
    const sql = `UPDATE ${tableName} SET ${setClause} WHERE id = ?`;
    const result = await run(sql, [...values, id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Record not found' });
    }
    
    res.json({ 
      message: 'Record updated successfully',
      affectedRows: result.affectedRows
    });
  } catch (error) {
    console.error('Update record error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Delete record
router.delete('/table/:tableName/:id', async (req, res) => {
  try {
    const { tableName, id } = req.params;
    
    if (!allowedTables.includes(tableName)) {
      return res.status(400).json({ error: 'Invalid table name' });
    }
    
    // Don't allow deleting from certain critical tables
    if (false) { // Removed users table protection
      return res.status(400).json({ error: 'Cannot delete seed users' });
    }
    
    const result = await run(`DELETE FROM ${tableName} WHERE id = ?`, [id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Record not found' });
    }
    
    res.json({ 
      message: 'Record deleted successfully',
      affectedRows: result.affectedRows
    });
  } catch (error) {
    console.error('Delete record error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Get table schema/structure
router.get('/schema/:tableName', async (req, res) => {
  try {
    const { tableName } = req.params;
    
    if (!allowedTables.includes(tableName)) {
      return res.status(400).json({ error: 'Invalid table name' });
    }
    
    const columns = await query(`DESCRIBE ${tableName}`);
    
    res.json({ columns });
  } catch (error) {
    console.error('Get schema error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get database statistics
router.get('/stats', async (req, res) => {
  try {
    const stats = {};
    
    // Always include users count
    try {
      const usersResult = await get(`SELECT COUNT(*) as count FROM users`);
      stats.users = usersResult?.count || 0;
    } catch (error) {
      stats.users = 0;
    }
    
    for (const table of allowedTables) {
      try {
        const result = await get(`SELECT COUNT(*) as count FROM ${table}`);
        stats[table] = result?.count || 0;
      } catch (error) {
        stats[table] = 0;
      }
    }
    
    console.log('🚨 [Admin] Stats response:', stats);
    res.json(stats);
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Upgrade Kyle Rivers to Pro account (one-time setup)
router.post('/setup-kyle-pro', async (req, res) => {
  try {
    const result = await run(`
      UPDATE users 
      SET subscription_tier = 'pro', is_premium = 1, role = 'super_admin', updated_at = NOW() 
      WHERE username = 'kylerivers'
    `);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'User kylerivers not found' });
    }
    
    res.json({ 
      message: 'Kyle Rivers upgraded to Pro with Super Admin privileges',
      affectedRows: result.affectedRows
    });
  } catch (error) {
    console.error('Setup Kyle Pro error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Clear table data (for testing) - excluding users table
router.delete('/table/:tableName', async (req, res) => {
  try {
    const { tableName } = req.params;
    
    const clearableeTables = [
      'posts', 'stories', 'rides', 'emergency_events', 
      'hazard_reports', 'followers', 'post_likes', 'post_comments',
      'location_updates', 'pack_members', 'story_views', 'hazard_confirmations'
    ];
    
    if (!clearableeTables.includes(tableName)) {
      return res.status(400).json({ error: 'Cannot clear this table' });
    }
    
    await run(`DELETE FROM ${tableName}`);
    
    res.json({ message: `${tableName} table cleared successfully` });
  } catch (error) {
    console.error('Clear table error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Reset password for Kyle Rivers (emergency access) - DEBUG endpoint, no auth required
router.post('/debug/reset-kyle-password', async (req, res) => {
  try {
    const bcrypt = require('bcrypt');
    const newPassword = '47industries';
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);
    
    console.log('🔄 Admin: Resetting password for kylerivers...');
    
    // First, check if user exists
    const existingUser = await query('SELECT id, username, email FROM users WHERE username = ? OR email = ?', ['kylerivers', 'kylerivers']);
    
    if (existingUser.length === 0) {
      // Create the user if doesn't exist
      const createResult = await run(`
        INSERT INTO users (username, email, password, first_name, last_name, role, subscription_tier, is_premium, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
      `, ['kylerivers', 'kyle@motorev.com', hashedPassword, 'Kyle', 'Rivers', 'super_admin', 'pro', 1]);
      
      res.json({ 
        message: 'Kyle Rivers account created successfully',
        username: 'kylerivers',
        password: '47industries',
        userId: createResult.insertId
      });
    } else {
      // Update existing user's password
      const updateResult = await run('UPDATE users SET password = ?, updated_at = NOW() WHERE username = ? OR email = ?', 
        [hashedPassword, 'kylerivers', 'kylerivers']);
      
      res.json({ 
        message: 'Kyle Rivers password reset successfully',
        username: 'kylerivers',
        password: '47industries',
        affectedRows: updateResult.affectedRows
      });
    }
    
  } catch (error) {
    console.error('❌ Reset Kyle password error:', error);
    res.status(500).json({ error: 'Internal server error', details: error.message });
  }
});

module.exports = router; 