const express = require('express');
const { query, get, run } = require('../database/connection');
const authRouter = require('./auth');
const { authenticateToken } = authRouter;
const router = express.Router();

// Create/upload a new ride recording
router.post('/', authenticateToken, async (req, res) => {
  try {
    const {
      rideId,
      durationSeconds,
      speedSeries,
      leanAngleSeries,
      accelerationSeries,
      brakingSeries,
      gpsSeries,
      audioSampleUrl,
      notes
    } = req.body;

    if (!durationSeconds || !gpsSeries || !speedSeries) {
      return res.status(400).json({ error: 'durationSeconds, gpsSeries and speedSeries are required' });
    }

    const result = await run(`
      INSERT INTO ride_recordings (
        user_id, ride_id, duration_seconds, speed_series, lean_angle_series, acceleration_series, braking_series, gps_series, audio_sample_url, notes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      req.user.userId,
      rideId || null,
      durationSeconds,
      JSON.stringify(speedSeries),
      leanAngleSeries ? JSON.stringify(leanAngleSeries) : null,
      accelerationSeries ? JSON.stringify(accelerationSeries) : null,
      brakingSeries ? JSON.stringify(brakingSeries) : null,
      JSON.stringify(gpsSeries),
      audioSampleUrl || null,
      notes || null
    ]);

    const created = await get('SELECT * FROM ride_recordings WHERE id = ?', [result.insertId]);
    res.status(201).json({ recording: created });
  } catch (e) {
    console.error('Create recording error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// List recordings for current user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { rideId, limit = 20, offset = 0 } = req.query;

    let where = 'WHERE user_id = ?';
    const params = [req.user.userId];
    if (rideId) {
      where += ' AND ride_id = ?';
      params.push(rideId);
    }

    const rows = await query(`
      SELECT * FROM ride_recordings
      ${where}
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), parseInt(offset)]);

    res.json({ recordings: rows });
  } catch (e) {
    console.error('List recordings error:', e);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router; 