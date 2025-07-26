const express = require('express');
const { query, get, run } = require('../database/connection');
const router = express.Router();

// Whitelist allowed tables for security
const allowedTables = [
  'users', 'posts', 'stories', 'rides', 'emergency_events', 
  'hazard_reports', 'followers', 'post_likes', 'post_comments',
  'location_updates', 'riding_packs', 'pack_members', 'user_sessions',
  'story_views', 'hazard_confirmations'
];

// Get table data with pagination
router.get('/table/:tableName', async (req, res) => {
  try {
    const { tableName } = req.params;
    const { limit = 100, offset = 0 } = req.query;
    
    if (!allowedTables.includes(tableName)) {
      return res.status(400).json({ error: 'Invalid table name' });
    }
    
    // Sanitize parameters
    const sanitizedLimit = Math.max(1, Math.min(1000, parseInt(limit) || 100));
    const sanitizedOffset = Math.max(0, parseInt(offset) || 0);
    
    const rows = await query(`SELECT * FROM ${tableName} ORDER BY id DESC LIMIT ${sanitizedLimit} OFFSET ${sanitizedOffset}`);
    const totalResult = await get(`SELECT COUNT(*) as total FROM ${tableName}`);
    
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
    if (data.hasOwnProperty('created_at') || tableName === 'users' || tableName === 'posts') {
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
    if (data.hasOwnProperty('updated_at') || tableName === 'users' || tableName === 'posts') {
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
    if (tableName === 'users' && id <= 3) {
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
    
    for (const table of allowedTables) {
      try {
        const result = await get(`SELECT COUNT(*) as count FROM ${table}`);
        stats[table] = result?.count || 0;
      } catch (error) {
        stats[table] = 0;
      }
    }
    
    res.json(stats);
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Clear table data (for testing) - excluding users table
router.delete('/table/:tableName', async (req, res) => {
  try {
    const { tableName } = req.params;
    
    // More restrictive whitelist for clearing tables
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

module.exports = router; 