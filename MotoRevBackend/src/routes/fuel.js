const express = require('express');
const { query, get, run } = require('../database/connection');
const authRouter = require('./auth');
const { authenticateToken } = authRouter;
const router = express.Router();

// Create fuel log
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { bikeId, date, stationName, fuelType, gallons, pricePerGallon, totalCost, odometer, notes } = req.body;

    if (!date || !gallons || !pricePerGallon || !totalCost) {
      return res.status(400).json({ error: 'date, gallons, pricePerGallon, and totalCost are required' });
    }

    if (bikeId) {
      const bike = await get('SELECT id FROM bikes WHERE id = ? AND user_id = ?', [bikeId, req.user.userId]);
      if (!bike) return res.status(404).json({ error: 'Bike not found' });
    }

    const result = await run(`
      INSERT INTO fuel_logs (
        user_id, bike_id, log_date, station_name, fuel_type, gallons, price_per_gallon, total_cost, odometer, notes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      req.user.userId,
      bikeId || null,
      date,
      stationName || null,
      fuelType || 'regular',
      gallons,
      pricePerGallon,
      totalCost,
      odometer || null,
      notes || null
    ]);

    const created = await get('SELECT * FROM fuel_logs WHERE id = ?', [result.insertId]);
    res.status(201).json({ fuelLog: created });
  } catch (e) {
    console.error('Create fuel log error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// List fuel logs
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { bikeId, limit = 50, offset = 0 } = req.query;

    let where = 'WHERE user_id = ?';
    const params = [req.user.userId];
    if (bikeId) {
      where += ' AND bike_id = ?';
      params.push(bikeId);
    }

    const logs = await query(`
      SELECT * FROM fuel_logs
      ${where}
      ORDER BY log_date DESC
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), parseInt(offset)]);

    res.json({ fuelLogs: logs });
  } catch (e) {
    console.error('List fuel logs error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update fuel log
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { date, stationName, fuelType, gallons, pricePerGallon, totalCost, odometer, notes } = req.body;

    const existing = await get('SELECT id FROM fuel_logs WHERE id = ? AND user_id = ?', [id, req.user.userId]);
    if (!existing) return res.status(404).json({ error: 'Fuel log not found' });

    await run(`
      UPDATE fuel_logs SET
        log_date = COALESCE(?, log_date),
        station_name = COALESCE(?, station_name),
        fuel_type = COALESCE(?, fuel_type),
        gallons = COALESCE(?, gallons),
        price_per_gallon = COALESCE(?, price_per_gallon),
        total_cost = COALESCE(?, total_cost),
        odometer = COALESCE(?, odometer),
        notes = COALESCE(?, notes),
        updated_at = NOW()
      WHERE id = ? AND user_id = ?
    `, [date, stationName, fuelType, gallons, pricePerGallon, totalCost, odometer, notes, id, req.user.userId]);

    const updated = await get('SELECT * FROM fuel_logs WHERE id = ?', [id]);
    res.json({ fuelLog: updated });
  } catch (e) {
    console.error('Update fuel log error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete fuel log
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await run('DELETE FROM fuel_logs WHERE id = ? AND user_id = ?', [id, req.user.userId]);
    if (result.changes === 0) return res.status(404).json({ error: 'Fuel log not found' });
    res.json({ message: 'Fuel log deleted' });
  } catch (e) {
    console.error('Delete fuel log error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router; 