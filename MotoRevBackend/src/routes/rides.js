const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const { query } = require('../database/connection');

// TEMPORARY: Events endpoint until Railway deployment issue is fixed
router.get('/events', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        // Get public events and user's private events
        const events = await query(`
            SELECT e.*, u.username as organizer_username,
                   COUNT(ep.user_id) as participant_count,
                   CASE WHEN ep.user_id = ? THEN 1 ELSE 0 END as is_participating
            FROM ride_events e
            JOIN users u ON e.organizer_id = u.id
            LEFT JOIN event_participants ep ON e.id = ep.event_id
            WHERE e.is_public = 1 OR e.organizer_id = ? OR ep.user_id = ?
            GROUP BY e.id, u.username
            ORDER BY e.start_time ASC
        `, [userId, userId, userId]);
        
        res.json({ events });
    } catch (error) {
        console.error('Error fetching events:', error);
        res.status(500).json({ error: 'Failed to fetch events' });
    }
});

// Helper function to update user statistics
async function updateUserStats(participants, distance, duration) {
    try {
        for (const participant of participants) {
            await query(`
                UPDATE users SET 
                    total_rides = COALESCE(total_rides, 0) + 1,
                    total_miles = COALESCE(total_miles, 0) + ?,
                    total_ride_time = COALESCE(total_ride_time, 0) + ?
                WHERE id = ?
            `, [distance, duration, participant.id]);
        }
    } catch (error) {
        console.error('Error updating user stats:', error);
    }
}

// Save completed ride
router.post('/completed', authenticateToken, async (req, res) => {
    try {
        console.log('🚨🚨🚨 [RIDES] POST /completed called');
        console.log('🚨🚨🚨 [RIDES] Request body:', JSON.stringify(req.body, null, 2));
        console.log('🚨🚨🚨 [RIDES] User ID:', req.user.id);
        
        const { 
            rideId, 
            rideType, 
            startTime, 
            endTime, 
            duration, 
            distance, 
            averageSpeed, 
            maxSpeed, 
            route, 
            participants, 
            safetyScore 
        } = req.body;
        
        const userId = req.user.id;
        
        // Insert completed ride
        const routeDataJson = JSON.stringify(route);
        
        await query(`
            INSERT INTO completed_rides (
                id, user_id, ride_type, start_time, end_time, duration, 
                distance, average_speed, max_speed, route_data, safety_score, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        `, [
            rideId, userId, rideType, startTime, endTime, duration,
            distance, averageSpeed, maxSpeed, routeDataJson, safetyScore
        ]);
        
        console.log('🚨🚨🚨 [RIDES] About to update user stats for participants:', participants);
        
        // Update user stats for current user only (since participants might have invalid IDs)
        await updateUserStats([{ id: userId }], distance, duration);
        
        res.json({ 
            success: true, 
            message: 'Ride saved successfully',
            rideId: rideId
        });
        
    } catch (error) {
        console.error('Error in save completed ride:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get completed rides for user
router.get('/completed', authenticateToken, async (req, res) => {
    try {
        console.log('🚨🚨🚨 [RIDES] GET /completed called for user:', req.user.id);
        
        const userId = req.user.id;
        
        const rows = await query(`
            SELECT 
                cr.*,
                u.username,
                u.first_name,
                u.last_name
            FROM completed_rides cr
            JOIN users u ON cr.user_id = u.id
            WHERE cr.user_id = ?
            ORDER BY cr.start_time DESC
            LIMIT 50
        `, [userId]);
        
        const rides = rows.map(row => ({
            id: row.id,
            rideType: row.ride_type,
            startTime: row.start_time,
            endTime: row.end_time,
            duration: row.duration,
            distance: row.distance,
            averageSpeed: row.average_speed,
            maxSpeed: row.max_speed,
            route: JSON.parse(row.route_data || '[]'),
            participants: [{
                id: row.user_id.toString(),
                username: row.username,
                name: `${row.first_name || ''} ${row.last_name || ''}`.trim(),
                isCurrentUser: true
            }],
            safetyScore: row.safety_score
        }));
        
        console.log('🚨🚨🚨 [RIDES] Found', rows.length, 'completed rides for user', userId);
        console.log('🚨🚨🚨 [RIDES] Returning', rides.length, 'formatted rides');
        
        res.json({ rides });
        
    } catch (error) {
        console.error('Error in get completed rides:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get ride statistics for user
router.get('/stats', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        const statsResult = await query(`
            SELECT 
                COUNT(*) as totalRides,
                COALESCE(SUM(distance), 0) as totalDistance,
                COALESCE(SUM(duration), 0) as totalDuration,
                COALESCE(AVG(safety_score), 100) as averageSafetyScore,
                COALESCE(MAX(max_speed), 0) as topSpeed
            FROM completed_rides 
            WHERE user_id = ?
        `, [userId]);
        
        const stats = statsResult[0] || {
            totalRides: 0,
            totalDistance: 0,
            totalDuration: 0,
            averageSafetyScore: 100,
            topSpeed: 0
        };
        
        res.json({ stats });
        
    } catch (error) {
        console.error('Error in get ride stats:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Delete completed ride
router.delete('/completed/:rideId', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const rideId = req.params.rideId;
        
        // Check if ride belongs to user
        const rides = await query(`
            SELECT id, distance, duration FROM completed_rides 
            WHERE id = ? AND user_id = ?
        `, [rideId, userId]);
        
        if (!rides || rides.length === 0) {
            return res.status(404).json({ error: 'Ride not found or access denied' });
        }
        
        const ride = rides[0];
        
        // Delete the ride
        await query(`DELETE FROM completed_rides WHERE id = ? AND user_id = ?`, [rideId, userId]);
        
        // Update user stats (subtract this ride's data)
        await query(`
            UPDATE users SET 
                total_rides = GREATEST(COALESCE(total_rides, 0) - 1, 0),
                total_miles = GREATEST(COALESCE(total_miles, 0) - ?, 0),
                total_ride_time = GREATEST(COALESCE(total_ride_time, 0) - ?, 0)
            WHERE id = ?
        `, [ride.distance, ride.duration, userId]);
        
        res.json({ message: 'Ride deleted successfully' });
        
    } catch (error) {
        console.error('Error deleting ride:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Test endpoint to add sample ride data (for development)
router.post('/test-data', authenticateToken, async (req, res) => {
    try {
        console.log('🚨🚨🚨 [RIDES] POST /test-data called');
        console.log('🚨🚨🚨 [RIDES] User ID:', req.user.id);
        
        const userId = req.user.id;
        
        const sampleRides = [
            {
                id: `test-ride-${Date.now()}-1`,
                ride_type: 'Solo',
                start_time: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
                end_time: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000 + 45 * 60 * 1000), // 45 min ride
                duration: 2700, // 45 minutes in seconds
                distance: 25000, // 25 km in meters
                average_speed: 35, // mph
                max_speed: 65, // mph
                route_data: JSON.stringify([]),
                safety_score: 95
            },
            {
                id: `test-ride-${Date.now()}-2`,
                ride_type: 'Group',
                start_time: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000), // 5 days ago
                end_time: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000 + 90 * 60 * 1000), // 90 min ride
                duration: 5400, // 90 minutes in seconds  
                distance: 75000, // 75 km in meters
                average_speed: 45, // mph
                max_speed: 80, // mph
                route_data: JSON.stringify([]),
                safety_score: 88
            },
            {
                id: `test-ride-${Date.now()}-3`,
                ride_type: 'Solo',
                start_time: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000), // 1 day ago
                end_time: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000 + 20 * 60 * 1000), // 20 min ride
                duration: 1200, // 20 minutes in seconds
                distance: 12000, // 12 km in meters
                average_speed: 30, // mph
                max_speed: 45, // mph
                route_data: JSON.stringify([]),
                safety_score: 92
            }
        ];

        for (const ride of sampleRides) {
            await query(`
                INSERT INTO completed_rides (
                    id, user_id, ride_type, start_time, end_time, duration,
                    distance, average_speed, max_speed, route_data, safety_score, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
                ON DUPLICATE KEY UPDATE id = id
            `, [
                ride.id, userId, ride.ride_type, ride.start_time, ride.end_time, 
                ride.duration, ride.distance, ride.average_speed, ride.max_speed, 
                ride.route_data, ride.safety_score
            ]);
        }

        res.json({ 
            success: true, 
            message: `Added ${sampleRides.length} sample rides for testing`,
            rides: sampleRides.length
        });

    } catch (error) {
        console.error('Error adding test ride data:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;