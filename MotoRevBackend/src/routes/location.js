const express = require('express');
const { query, get, run } = require('../database/connection');
const authRouter = require('./auth');
const { authenticateToken } = authRouter;
const router = express.Router();

// Share location with pack
router.post('/share', authenticateToken, async (req, res) => {
  try {
    const { latitude, longitude, packId, heading, speed } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({ error: 'Latitude and longitude are required' });
    }

    // Update or insert location sharing
    const existingShare = await get(
      'SELECT id FROM location_shares WHERE user_id = ? AND pack_id = ?',
      [req.user.userId, packId || null]
    );

    if (existingShare) {
      await run(`
        UPDATE location_shares 
        SET latitude = ?, longitude = ?, heading = ?, speed = ?, 
            updated_at = NOW(), expires_at = DATE_ADD(NOW(), INTERVAL 1 HOUR)
        WHERE id = ?
      `, [latitude, longitude, heading || null, speed || null, existingShare.id]);
    } else {
      await run(`
        INSERT INTO location_shares (
          user_id, pack_id, latitude, longitude, heading, speed, 
          created_at, updated_at, expires_at
        ) VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW(), DATE_ADD(NOW(), INTERVAL 1 HOUR))
      `, [req.user.userId, packId || null, latitude, longitude, heading || null, speed || null]);
    }

    res.json({ message: 'Location shared successfully' });
  } catch (error) {
    console.error('Share location error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get nearby riders
router.get('/nearby', authenticateToken, async (req, res) => {
  try {
    const { latitude, longitude, radius = 5 } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({ error: 'Latitude and longitude are required' });
    }

    // Validate and limit radius
    const maxRadius = 50; // 50km max
    const searchRadius = Math.min(parseFloat(radius) || 5, maxRadius);

    // Get shared locations within radius
    const locations = await query(`
      SELECT ls.user_id, ls.latitude, ls.longitude, ls.heading, ls.speed, ls.updated_at,
             u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             u.motorcycle_make, u.motorcycle_model, u.safety_score
      FROM location_shares ls
      JOIN users u ON ls.user_id = u.id
      WHERE ls.user_id != ? 
      AND ls.expires_at > NOW()
      ORDER BY ls.updated_at DESC
      LIMIT 25
    `, [req.user.userId]);

    // Filter by distance (simple calculation) and limit results
    const nearbyRiders = locations.filter(location => {
      const distance = calculateDistance(
        parseFloat(latitude), 
        parseFloat(longitude),
        location.latitude, 
        location.longitude
      );
      return distance <= searchRadius;
    }).map(location => ({
      id: location.user_id,
      name: `${location.first_name || ''} ${location.last_name || ''}`.trim(),
      bike: location.motorcycle_make && location.motorcycle_model 
        ? `${location.motorcycle_make} ${location.motorcycle_model}` 
        : 'Unknown Bike',
      latitude: location.latitude,
      longitude: location.longitude,
      distance: calculateDistance(
        parseFloat(latitude), 
        parseFloat(longitude),
        location.latitude, 
        location.longitude
      ),
      isRiding: location.speed > 0, // Consider riding if speed > 0
      lastSeen: location.updated_at
    })).slice(0, 10);

    res.json({ success: true, riders: nearbyRiders, searchRadius });
  } catch (error) {
    console.error('Get nearby riders error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get pack member locations
router.get('/pack/:packId', authenticateToken, async (req, res) => {
  try {
    const { packId } = req.params;

    // Verify user is member of this pack
    const membership = await get(
      'SELECT id FROM pack_members WHERE pack_id = ? AND user_id = ?',
      [packId, req.user.userId]
    );

    if (!membership) {
      return res.status(403).json({ error: 'You are not a member of this pack' });
    }

    // Get locations of pack members
    const packLocations = await query(`
      SELECT ls.*, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             u.motorcycle_make, u.motorcycle_model
      FROM location_shares ls
      JOIN users u ON ls.user_id = u.id
      JOIN pack_members pm ON u.id = pm.user_id
      WHERE pm.pack_id = ? 
      AND ls.expires_at > NOW()
      ORDER BY ls.updated_at DESC
    `, [packId]);

    res.json({ packLocations });
  } catch (error) {
    console.error('Get pack locations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Stop sharing location
router.delete('/share', authenticateToken, async (req, res) => {
  try {
    const { packId } = req.body;

    await run(
      'DELETE FROM location_shares WHERE user_id = ? AND pack_id = ?',
      [req.user.userId, packId || null]
    );

    res.json({ message: 'Location sharing stopped' });
  } catch (error) {
    console.error('Stop sharing location error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get weather data (mock endpoint)
router.get('/weather', authenticateToken, async (req, res) => {
  try {
    const { latitude, longitude } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({ error: 'Latitude and longitude are required' });
    }

    // Mock weather data - in production, integrate with weather API
    const mockWeather = {
      temperature: Math.floor(Math.random() * 40) + 50, // 50-90°F
      condition: ['sunny', 'cloudy', 'rainy', 'windy'][Math.floor(Math.random() * 4)],
      windSpeed: Math.floor(Math.random() * 20) + 5, // 5-25 mph
      humidity: Math.floor(Math.random() * 50) + 30, // 30-80%
      visibility: Math.floor(Math.random() * 5) + 5, // 5-10 miles
      uvIndex: Math.floor(Math.random() * 11), // 0-10
      precipitation: Math.floor(Math.random() * 100), // 0-100%
      alerts: Math.random() > 0.8 ? ['High wind warning'] : []
    };

    res.json({ weather: mockWeather });
  } catch (error) {
    console.error('Get weather error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get gas stations nearby (mock endpoint)
router.get('/gas-stations', authenticateToken, async (req, res) => {
  try {
    const { latitude, longitude, radius = 10 } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({ error: 'Latitude and longitude are required' });
    }

    // Mock gas station data - in production, integrate with places API
    const mockGasStations = [
      {
        id: 1,
        name: 'Shell Station',
        brand: 'Shell',
        address: '123 Main St',
        latitude: parseFloat(latitude) + 0.01,
        longitude: parseFloat(longitude) + 0.01,
        distance: 0.7,
        price: 3.45,
        amenities: ['restroom', 'convenience_store', 'car_wash']
      },
      {
        id: 2,
        name: 'Chevron',
        brand: 'Chevron',
        address: '456 Oak Ave',
        latitude: parseFloat(latitude) - 0.01,
        longitude: parseFloat(longitude) - 0.01,
        distance: 0.9,
        price: 3.42,
        amenities: ['restroom', 'convenience_store']
      },
      {
        id: 3,
        name: 'BP Station',
        brand: 'BP',
        address: '789 Pine St',
        latitude: parseFloat(latitude) + 0.02,
        longitude: parseFloat(longitude) - 0.02,
        distance: 1.2,
        price: 3.48,
        amenities: ['restroom', 'convenience_store', 'air_pump']
      }
    ].filter(station => station.distance <= parseFloat(radius));

    res.json({ gasStations: mockGasStations });
  } catch (error) {
    console.error('Get gas stations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get points of interest
router.get('/poi', authenticateToken, async (req, res) => {
  try {
    const { latitude, longitude, radius = 10, type } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({ error: 'Latitude and longitude are required' });
    }

    // Mock POI data - in production, integrate with places API
    const mockPOIs = [
      {
        id: 1,
        name: 'Scenic Overlook',
        type: 'scenic',
        latitude: parseFloat(latitude) + 0.03,
        longitude: parseFloat(longitude) + 0.03,
        distance: 2.1,
        rating: 4.5,
        description: 'Beautiful mountain view'
      },
      {
        id: 2,
        name: 'Motorcycle Museum',
        type: 'attraction',
        latitude: parseFloat(latitude) - 0.02,
        longitude: parseFloat(longitude) + 0.02,
        distance: 1.8,
        rating: 4.2,
        description: 'Historic motorcycle collection'
      },
      {
        id: 3,
        name: 'Biker Cafe',
        type: 'restaurant',
        latitude: parseFloat(latitude) + 0.01,
        longitude: parseFloat(longitude) - 0.01,
        distance: 0.8,
        rating: 4.7,
        description: 'Popular motorcycle gathering spot'
      }
    ].filter(poi => {
      const withinRadius = poi.distance <= parseFloat(radius);
      const matchesType = !type || poi.type === type;
      return withinRadius && matchesType;
    });

    res.json({ pointsOfInterest: mockPOIs });
  } catch (error) {
    console.error('Get POI error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user's location history
router.get('/history', authenticateToken, async (req, res) => {
  try {
    const { limit = 100, offset = 0, startDate, endDate } = req.query;
    
    let whereClause = 'WHERE user_id = ?';
    let params = [req.user.userId];
    
    if (startDate) {
      whereClause += ' AND created_at >= ?';
      params.push(startDate);
    }
    
    if (endDate) {
      whereClause += ' AND created_at <= ?';
      params.push(endDate);
    }

    const locationHistory = await query(`
      SELECT latitude, longitude, heading, speed, created_at
      FROM location_shares 
      ${whereClause}
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), parseInt(offset)]);

    res.json({ locationHistory });
  } catch (error) {
    console.error('Get location history error:', error);
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