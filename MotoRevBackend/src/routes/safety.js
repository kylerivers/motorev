const express = require('express');
const { query, get, run } = require('../database/connection');
const authRouter = require('./auth');
const { authenticateToken } = authRouter;
const router = express.Router();
const bodyParser = require('body-parser');
router.use(bodyParser.json({ limit: '2mb' }));

// Report emergency event
router.post('/emergency', authenticateToken, async (req, res) => {
  try {
    const { 
      type, 
      severity, 
      location, 
      description, 
      automaticDetection = false,
      sensorData 
    } = req.body;

    if (!type || !severity || !location) {
      return res.status(400).json({ error: 'Type, severity, and location are required' });
    }

    // Persist emergency event
    const result = await run(`
      INSERT INTO emergency_events (
        user_id, ride_id, event_type, severity, latitude, longitude, description, 
        auto_detected, is_resolved, created_at
      ) VALUES (?, NULL, ?, ?, ?, ?, ?, ?, 0, NOW())
    `, [
      req.user.userId,
      type,
      severity,
      parseFloat(location.latitude),
      parseFloat(location.longitude),
      description || null,
      automaticDetection ? 1 : 0
    ]);

    const emergencyId = result.insertId;

    const emergency = await get(`
      SELECT * FROM emergency_events WHERE id = ?
    `, [emergencyId]);

    // Store/share ICE snapshot for responders
    const ice = req.body.ice || null;
    if (ice) {
      await run(`
        INSERT INTO emergency_ice (emergency_id, blood_type, allergies, medications, medical_id, conditions, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `, [
        emergencyId,
        ice.bloodType || null,
        ice.allergies ? JSON.stringify(ice.allergies) : null,
        ice.medications ? JSON.stringify(ice.medications) : null,
        ice.medicalID || null,
        ice.conditions ? JSON.stringify(ice.conditions) : null,
        ice.emergencyNotes || null
      ]);
    }

    res.status(201).json({ 
      message: 'Emergency event reported successfully',
      emergency,
      iceShared: !!ice
    });
  } catch (error) {
    console.error('Report emergency error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update emergency status
router.put('/emergency/:emergencyId', authenticateToken, async (req, res) => {
  try {
    const { emergencyId } = req.params;
    const { status, notes } = req.body;

    if (!status) {
      return res.status(400).json({ error: 'Status is required' });
    }

    const validStatuses = ['active', 'resolved', 'false_alarm'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const result = await run(`
      UPDATE emergency_events 
      SET status = ?, response_notes = ?, updated_at = NOW()
      WHERE id = ? AND user_id = ?
    `, [status, notes || null, emergencyId, req.user.userId]);

    if (result.changes === 0) {
      return res.status(404).json({ error: 'Emergency event not found' });
    }

    res.json({ message: 'Emergency status updated successfully' });
  } catch (error) {
    console.error('Update emergency error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user's emergency events
router.get('/emergency/history', authenticateToken, async (req, res) => {
  try {
    const { limit = 20, offset = 0, status } = req.query;
    
    let whereClause = 'WHERE user_id = ?';
    let params = [req.user.userId];
    
    if (status) {
      whereClause += ' AND status = ?';
      params.push(status);
    }

    const emergencies = await query(`
      SELECT * FROM emergency_events 
      ${whereClause}
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), parseInt(offset)]);

    res.json({ emergencies });
  } catch (error) {
    console.error('Get emergency history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Report hazard
router.post('/hazards', authenticateToken, async (req, res) => {
  try {
    const { type, location, description, severity, images } = req.body;

    if (!type || !location) {
      return res.status(400).json({ error: 'Type and location are required' });
    }

    const result = await run(`
      INSERT INTO hazard_reports (
        user_id, type, location, description, severity, images, 
        status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, 'active', NOW())
    `, [
      req.user.userId,
      type,
      JSON.stringify(location),
      description || null,
      severity || 'medium',
      images ? JSON.stringify(images) : null
    ]);

    const hazardId = result.insertId;

    const hazard = await get(`
      SELECT hr.*, u.username, u.first_name, u.last_name, u.profile_picture
      FROM hazard_reports hr
      JOIN users u ON hr.user_id = u.id
      WHERE hr.id = ?
    `, [hazardId]);

    res.status(201).json({ 
      message: 'Hazard reported successfully',
      hazard: hazard 
    });
  } catch (error) {
    console.error('Report hazard error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Confirm hazard
router.post('/hazards/:hazardId/confirm', authenticateToken, async (req, res) => {
  try {
    const { hazardId } = req.params;
    const { stillPresent, notes } = req.body;

    // Check if user already confirmed this hazard
    const existingConfirmation = await get(
      'SELECT id FROM hazard_confirmations WHERE hazard_id = ? AND user_id = ?',
      [hazardId, req.user.userId]
    );

    if (existingConfirmation) {
      return res.status(409).json({ error: 'You have already confirmed this hazard' });
    }

    await run(`
      INSERT INTO hazard_confirmations (
        hazard_id, user_id, still_present, notes, created_at
      ) VALUES (?, ?, ?, ?, NOW())
    `, [hazardId, req.user.userId, stillPresent, notes || null]);

    res.json({ message: 'Hazard confirmation recorded successfully' });
  } catch (error) {
    console.error('Confirm hazard error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get nearby hazards
router.get('/hazards/nearby', authenticateToken, async (req, res) => {
  try {
    const { latitude, longitude, radius = 10 } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({ error: 'Latitude and longitude are required' });
    }

    // Simple distance calculation for SQLite (for production, consider using PostGIS)
    const hazards = await query(`
      SELECT hr.*, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             COUNT(hc.id) as confirmation_count
      FROM hazard_reports hr
      JOIN users u ON hr.user_id = u.id
      LEFT JOIN hazard_confirmations hc ON hr.id = hc.hazard_id
      WHERE hr.status = 'active'
      GROUP BY hr.id
      ORDER BY hr.created_at DESC
      LIMIT 50
    `, []);

    // Filter by distance (simple calculation)
    const filteredHazards = hazards.filter(hazard => {
      const hazardLocation = JSON.parse(hazard.location);
      const distance = calculateDistance(
        parseFloat(latitude), 
        parseFloat(longitude),
        hazardLocation.latitude, 
        hazardLocation.longitude
      );
      return distance <= parseFloat(radius);
    });

    res.json({ hazards: filteredHazards });
  } catch (error) {
    console.error('Get nearby hazards error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get safety statistics
router.get('/stats', authenticateToken, async (req, res) => {
  try {
    // Get user's safety stats
    const userStats = await get(`
      SELECT safety_score, total_rides, total_miles FROM users WHERE id = ?
    `, [req.user.userId]);

    // Get emergency events count
    const emergencyStats = await get(`
      SELECT 
        COUNT(*) as total_emergencies,
        COUNT(CASE WHEN status = 'active' THEN 1 END) as active_emergencies,
        COUNT(CASE WHEN automatic_detection = 1 THEN 1 END) as auto_detected
      FROM emergency_events WHERE user_id = ?
    `, [req.user.userId]);

    // Get hazard reports count
    const hazardStats = await get(`
      SELECT COUNT(*) as hazards_reported FROM hazard_reports WHERE user_id = ?
    `, [req.user.userId]);

    // Get recent safety events
    const recentEvents = await query(`
      SELECT 'emergency' as event_type, type, severity, created_at 
      FROM emergency_events 
      WHERE user_id = ?
      UNION ALL
      SELECT 'hazard' as event_type, type, severity, created_at 
      FROM hazard_reports 
      WHERE user_id = ?
      ORDER BY created_at DESC
      LIMIT 10
    `, [req.user.userId, req.user.userId]);

    res.json({
      stats: {
        safetyScore: userStats?.safety_score || 100,
        totalRides: userStats?.total_rides || 0,
        totalMiles: userStats?.total_miles || 0,
        totalEmergencies: emergencyStats?.total_emergencies || 0,
        activeEmergencies: emergencyStats?.active_emergencies || 0,
        autoDetectedEmergencies: emergencyStats?.auto_detected || 0,
        hazardsReported: hazardStats?.hazards_reported || 0
      },
      recentEvents: recentEvents || []
    });
  } catch (error) {
    console.error('Get safety stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Crash detection endpoint (for automatic detection)
router.post('/crash-detection', authenticateToken, async (req, res) => {
  try {
    const { 
      sensorData, 
      location, 
      confidence, 
      rideId 
    } = req.body;

    if (!sensorData || !location || !confidence) {
      return res.status(400).json({ error: 'Sensor data, location, and confidence are required' });
    }

    // Only trigger if confidence is high enough
    if (confidence < 0.7) {
      return res.json({ message: 'Confidence too low, no action taken' });
    }

    // Create emergency event
    const result = await run(`
      INSERT INTO emergency_events (
        user_id, type, severity, location, description, 
        automatic_detection, sensor_data, status, ride_id, created_at
      ) VALUES (?, 'crash', 'high', ?, 'Automatic crash detection', 1, ?, 'active', ?, NOW())
    `, [
      req.user.userId,
      JSON.stringify(location),
      JSON.stringify(sensorData),
      rideId || null
    ]);

    const emergencyId = result.insertId;

    res.status(201).json({ 
      message: 'Crash detected and emergency event created',
      emergencyId: emergencyId,
      confidence: confidence
    });
  } catch (error) {
    console.error('Crash detection error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Helper function to calculate distance between two points
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 3959; // Earth's radius in miles
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

module.exports = router; 