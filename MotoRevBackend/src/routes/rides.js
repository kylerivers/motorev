const express = require('express');
const { query, get, run } = require('../database/connection');
const authRouter = require('./auth');
const { authenticateToken } = authRouter;
const router = express.Router();

// Start a new ride
router.post('/start', authenticateToken, async (req, res) => {
  try {
    const { title, startLocation, plannedRoute } = req.body;

    const result = await run(`
      INSERT INTO rides (
        user_id, title, start_location_name, route_data, status, 
        start_time
      ) VALUES (?, ?, ?, ?, 'active', NOW())
    `, [
      req.user.userId,
      title || 'Ride',
      startLocation || null,
      plannedRoute ? JSON.stringify(plannedRoute) : null
    ]);

    const rideId = result.insertId;

    const ride = await get(`
      SELECT * FROM rides WHERE id = ?
    `, [rideId]);

    res.status(201).json({ 
      message: 'Ride started successfully',
      ride: ride 
    });
  } catch (error) {
    console.error('Start ride error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// End a ride
router.put('/:rideId/end', authenticateToken, async (req, res) => {
  try {
    const { rideId } = req.params;
    const { endLocation, totalDistance, maxSpeed, avgSpeed, durationMinutes } = req.body;

    // Verify ride belongs to user
    const ride = await get(`
      SELECT id, user_id FROM rides WHERE id = ? AND user_id = ?
    `, [rideId, req.user.userId]);

    if (!ride) {
      return res.status(404).json({ error: 'Ride not found' });
    }

    // Update ride
    await run(`
      UPDATE rides 
      SET status = 'completed', 
          end_time = NOW(),
          end_location_name = ?,
          total_distance = ?,
          max_speed = ?,
          avg_speed = ?,
          duration_minutes = ?
      WHERE id = ?
    `, [endLocation, totalDistance, maxSpeed, avgSpeed, durationMinutes, rideId]);

    const updatedRide = await get(`
      SELECT * FROM rides WHERE id = ?
    `, [rideId]);

    res.json({ 
      message: 'Ride ended successfully',
      ride: updatedRide 
    });
  } catch (error) {
    console.error('End ride error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user's rides
router.get('/my-rides', authenticateToken, async (req, res) => {
  try {
    const { limit = 20, offset = 0 } = req.query;

    const rides = await query(`
      SELECT * FROM rides 
      WHERE user_id = ? 
      ORDER BY start_time DESC 
      LIMIT ? OFFSET ?
    `, [req.user.userId, parseInt(limit), parseInt(offset)]);

    res.json({ rides });
  } catch (error) {
    console.error('Get rides error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get public rides feed
router.get('/public', async (req, res) => {
  try {
    const { limit = 20, offset = 0 } = req.query;

    const rides = await query(`
      SELECT r.*, u.username, u.first_name, u.last_name, u.profile_picture_url
      FROM rides r
      JOIN users u ON r.user_id = u.id
      WHERE r.visibility = 'public' AND r.status = 'completed'
      ORDER BY r.start_time DESC
      LIMIT ? OFFSET ?
    `, [parseInt(limit), parseInt(offset)]);

    res.json({ rides });
  } catch (error) {
    console.error('Get public rides error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get specific ride details
router.get('/:rideId', authenticateToken, async (req, res) => {
  try {
    const { rideId } = req.params;

    const ride = await get(`
      SELECT r.*, u.username, u.first_name, u.last_name, u.profile_picture_url
      FROM rides r
      JOIN users u ON r.user_id = u.id
      WHERE r.id = ?
    `, [rideId]);

    if (!ride) {
      return res.status(404).json({ error: 'Ride not found' });
    }

    // Check if user can view this ride
    if (ride.visibility === 'private' && ride.user_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    res.json({ ride });
  } catch (error) {
    console.error('Get ride error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Add location update to active ride
router.post('/:rideId/location', authenticateToken, async (req, res) => {
  try {
    const { rideId } = req.params;
    const { latitude, longitude, altitude, speed, heading, accuracy } = req.body;

    // Verify ride exists and belongs to user
    const ride = await get(`
      SELECT id FROM rides WHERE id = ? AND user_id = ? AND status = 'active'
    `, [rideId, req.user.userId]);

    if (!ride) {
      return res.status(404).json({ error: 'Active ride not found' });
    }

    // Add location update
    await run(`
      INSERT INTO location_updates (
        ride_id, user_id, latitude, longitude, altitude, speed, heading, accuracy, timestamp
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
    `, [rideId, req.user.userId, latitude, longitude, altitude, speed, heading, accuracy]);

    res.json({ message: 'Location updated successfully' });
  } catch (error) {
    console.error('Add location error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get ride statistics
router.get('/stats/summary', authenticateToken, async (req, res) => {
  try {
    const stats = await get(`
      SELECT 
        COUNT(*) as total_rides,
        SUM(total_distance) as total_distance,
        SUM(duration_minutes) as total_minutes,
        AVG(avg_speed) as avg_speed,
        MAX(max_speed) as max_speed
      FROM rides 
      WHERE user_id = ? AND status = 'completed'
    `, [req.user.userId]);

    res.json({ stats });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

// Search rides
router.get('/search', authenticateToken, async (req, res) => {
  try {
    const { query: searchQuery, limit = 20, offset = 0 } = req.query;
    
    if (!searchQuery || searchQuery.trim().length < 2) {
      return res.status(400).json({ error: 'Search query must be at least 2 characters' });
    }

    const rides = await query(`
      SELECT r.*, u.username, u.first_name, u.last_name, u.profile_picture_url
      FROM rides r
      JOIN users u ON r.user_id = u.id
      WHERE (r.title LIKE ? OR r.start_location_name LIKE ? OR r.end_location_name LIKE ?)
      AND r.visibility = 'public' 
      AND r.status IN ('completed', 'active')
      ORDER BY r.start_time DESC
      LIMIT ? OFFSET ?
    `, [
      `%${searchQuery}%`,
      `%${searchQuery}%`, 
      `%${searchQuery}%`,
      parseInt(limit), 
      parseInt(offset)
    ]);

    res.json({ 
      success: true,
      rides: rides,
      query: searchQuery,
      total: rides.length
    });
  } catch (error) {
    console.error('Search rides error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}); 