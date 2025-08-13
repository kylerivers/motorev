const express = require('express');
const router = express.Router();
const sqlite3 = require('sqlite3').verbose();
const { authenticateToken } = require('../middleware/auth');

// Database connection
const db = new sqlite3.Database('./src/database/database.db');

// Save completed ride
router.post('/completed', authenticateToken, async (req, res) => {
    try {
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
        const insertRideQuery = `
            INSERT INTO completed_rides (
                id, user_id, ride_type, start_time, end_time, duration, 
                distance, average_speed, max_speed, route_data, safety_score, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
        `;
        
        const routeDataJson = JSON.stringify(route);
        
        db.run(insertRideQuery, [
            rideId, userId, rideType, startTime, endTime, duration,
            distance, averageSpeed, maxSpeed, routeDataJson, safetyScore
        ], function(err) {
            if (err) {
                console.error('Error saving completed ride:', err);
                return res.status(500).json({ error: 'Failed to save ride' });
            }
            
            // Update user stats for all participants
            updateUserStats(participants, distance, duration);
            
            res.json({ 
                success: true, 
                message: 'Ride saved successfully',
                rideId: rideId
            });
        });
        
    } catch (error) {
        console.error('Error in save completed ride:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get completed rides for user
router.get('/completed', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        const query = `
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
        `;
        
        db.all(query, [userId], (err, rows) => {
            if (err) {
                console.error('Error fetching completed rides:', err);
                return res.status(500).json({ error: 'Failed to fetch rides' });
            }
            
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
            
            res.json({ rides });
        });
        
    } catch (error) {
        console.error('Error in get completed rides:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get ride statistics for user
router.get('/stats', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        const statsQuery = `
            SELECT 
                COUNT(*) as totalRides,
                COALESCE(SUM(distance), 0) as totalDistance,
                COALESCE(SUM(duration), 0) as totalDuration,
                COALESCE(AVG(safety_score), 100) as averageSafetyScore,
                COALESCE(MAX(max_speed), 0) as topSpeed
            FROM completed_rides 
            WHERE user_id = ?
        `;
        
        db.get(statsQuery, [userId], (err, row) => {
            if (err) {
                console.error('Error fetching ride stats:', err);
                return res.status(500).json({ error: 'Failed to fetch stats' });
            }
            
            res.json({
                totalRides: row.totalRides || 0,
                totalDistance: row.totalDistance || 0,
                totalDuration: row.totalDuration || 0,
                averageSafetyScore: Math.round(row.averageSafetyScore || 100),
                topSpeed: row.topSpeed || 0
            });
        });
        
    } catch (error) {
        console.error('Error in get ride stats:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Helper function to update user stats
function updateUserStats(participants, distance, duration) {
    const distanceInMiles = distance * 0.000621371; // Convert meters to miles
    const durationInHours = duration / 3600; // Convert seconds to hours
    
    participants.forEach(participant => {
        // Update user profile with new ride data
        const updateQuery = `
            UPDATE users SET 
                total_rides = COALESCE(total_rides, 0) + 1,
                total_miles = COALESCE(total_miles, 0) + ?,
                total_ride_time = COALESCE(total_ride_time, 0) + ?
            WHERE id = ?
        `;
        
        db.run(updateQuery, [distanceInMiles, durationInHours, participant.id], (err) => {
            if (err) {
                console.error('Error updating user stats for participant:', participant.id, err);
            } else {
                console.log('Updated stats for user:', participant.username);
            }
        });
    });
}

module.exports = router;