const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const { query } = require('../database/connection');

// Get all events (public and user's events)
router.get('/', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        // Check if ride_events table exists first
        try {
            await query('SELECT 1 FROM ride_events LIMIT 1');
            console.log('✅ ride_events table exists and is accessible');
        } catch (tableError) {
            console.error('❌ ride_events table error:', tableError.message);
            return res.status(500).json({ 
                error: 'Database table not found', 
                details: 'ride_events table does not exist or is not accessible'
            });
        }
        
        // Get public events and user's private events
        const events = await query(`
            SELECT e.*, u.username as organizer_username,
                   COUNT(ep.user_id) as participant_count,
                   MAX(CASE WHEN ep.user_id = ? THEN 1 ELSE 0 END) as is_participating
            FROM ride_events e
            JOIN users u ON e.organizer_id = u.id
            LEFT JOIN event_participants ep ON e.id = ep.event_id
            WHERE e.is_public = 1 OR e.organizer_id = ? OR ep.user_id = ?
            GROUP BY e.id, u.username, u.id, e.organizer_id, e.title, e.description, e.start_time, e.end_time, e.location, e.max_participants, e.is_public, e.created_at
            ORDER BY e.start_time ASC
        `, [userId, userId, userId]);
        
        console.log(`✅ Found ${events.length} events for user ${userId}`);
        res.json({ events });
    } catch (error) {
        console.error('Error fetching events:', error);
        res.status(500).json({ error: 'Failed to fetch events', details: error.message });
    }
});

// Get single event details
router.get('/:id', authenticateToken, async (req, res) => {
    try {
        const eventId = req.params.id;
        const userId = req.user.id;
        
        const events = await query(`
            SELECT e.*, u.username as organizer_username,
                   COUNT(ep.user_id) as participant_count,
                   MAX(CASE WHEN ep.user_id = ? THEN 1 ELSE 0 END) as is_participating
            FROM ride_events e
            JOIN users u ON e.organizer_id = u.id
            LEFT JOIN event_participants ep ON e.id = ep.event_id
            WHERE e.id = ? AND (e.is_public = 1 OR e.organizer_id = ? OR ep.user_id = ?)
            GROUP BY e.id, u.username, u.id, e.organizer_id, e.title, e.description, e.start_time, e.end_time, e.location, e.max_participants, e.is_public, e.created_at
        `, [userId, eventId, userId, userId]);
        
        if (!events || events.length === 0) {
            return res.status(404).json({ error: 'Event not found or access denied' });
        }
        
        const event = events[0];
        
        // Get participants
        const participants = await query(`
            SELECT u.id, u.username, u.email, ep.joined_at
            FROM event_participants ep
            JOIN users u ON ep.user_id = u.id
            WHERE ep.event_id = ?
            ORDER BY ep.joined_at ASC
        `, [eventId]);
        
        res.json({ event: { ...event, participants } });
    } catch (error) {
        console.error('Error fetching event:', error);
        res.status(500).json({ error: 'Failed to fetch event' });
    }
});

// Create new event
router.post('/', authenticateToken, async (req, res) => {
    try {
        const { title, description, start_time, end_time, location, max_participants, is_public } = req.body;
        const organizerId = req.user.id;
        
        if (!title || !start_time || !location) {
            return res.status(400).json({ error: 'Title, start time, and location are required' });
        }
        
        const result = await query(`
            INSERT INTO ride_events (
                organizer_id, title, description, start_time, end_time, 
                location, max_participants, is_public, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
        `, [
            organizerId, title, description || null, start_time, end_time || null,
            location, max_participants || null, is_public ? 1 : 0
        ]);
        
        // Organizer automatically joins their own event
        await query(`
            INSERT INTO event_participants (event_id, user_id, joined_at)
            VALUES (?, ?, NOW())
        `, [result.insertId, organizerId]);
        
        res.status(201).json({ 
            message: 'Event created successfully', 
            eventId: result.insertId 
        });
    } catch (error) {
        console.error('Error creating event:', error);
        res.status(500).json({ error: 'Failed to create event' });
    }
});

// Join event
router.post('/:id/join', authenticateToken, async (req, res) => {
    try {
        const eventId = req.params.id;
        const userId = req.user.id;
        
        // Check if event exists and user can join
        const events = await query(`
            SELECT e.*, COUNT(ep.user_id) as participant_count
            FROM ride_events e
            LEFT JOIN event_participants ep ON e.id = ep.event_id
            WHERE e.id = ? AND (e.is_public = 1 OR e.organizer_id = ?)
            GROUP BY e.id
        `, [eventId, userId]);
        
        if (!events || events.length === 0) {
            return res.status(404).json({ error: 'Event not found or access denied' });
        }
        
        const event = events[0];
        
        // Check if event is full
        if (event.max_participants && event.participant_count >= event.max_participants) {
            return res.status(400).json({ error: 'Event is full' });
        }
        
        // Check if user already joined
        const existing = await query(`
            SELECT id FROM event_participants 
            WHERE event_id = ? AND user_id = ?
        `, [eventId, userId]);
        
        if (existing && existing.length > 0) {
            return res.status(400).json({ error: 'Already joined this event' });
        }
        
        // Join event
        await query(`
            INSERT INTO event_participants (event_id, user_id, joined_at)
            VALUES (?, ?, NOW())
        `, [eventId, userId]);
        
        res.json({ message: 'Successfully joined event' });
    } catch (error) {
        console.error('Error joining event:', error);
        res.status(500).json({ error: 'Failed to join event' });
    }
});

// Leave event
router.post('/:id/leave', authenticateToken, async (req, res) => {
    try {
        const eventId = req.params.id;
        const userId = req.user.id;
        
        // Check if user is in the event
        const participation = await query(`
            SELECT id FROM event_participants 
            WHERE event_id = ? AND user_id = ?
        `, [eventId, userId]);
        
        if (!participation || participation.length === 0) {
            return res.status(400).json({ error: 'Not participating in this event' });
        }
        
        // Check if user is organizer
        const events = await query(`
            SELECT organizer_id FROM ride_events WHERE id = ?
        `, [eventId]);
        
        if (events && events.length > 0 && events[0].organizer_id === userId) {
            return res.status(400).json({ error: 'Organizer cannot leave their own event. Delete the event instead.' });
        }
        
        // Leave event
        await query(`
            DELETE FROM event_participants 
            WHERE event_id = ? AND user_id = ?
        `, [eventId, userId]);
        
        res.json({ message: 'Successfully left event' });
    } catch (error) {
        console.error('Error leaving event:', error);
        res.status(500).json({ error: 'Failed to leave event' });
    }
});

// Update event (organizer only)
router.put('/:id', authenticateToken, async (req, res) => {
    try {
        const eventId = req.params.id;
        const userId = req.user.id;
        const { title, description, start_time, end_time, location, max_participants, is_public } = req.body;
        
        // Check if user is organizer
        const events = await query(`
            SELECT organizer_id FROM ride_events WHERE id = ?
        `, [eventId]);
        
        if (!events || events.length === 0) {
            return res.status(404).json({ error: 'Event not found' });
        }
        
        if (events[0].organizer_id !== userId) {
            return res.status(403).json({ error: 'Only organizer can update event' });
        }
        
        // Update event
        await query(`
            UPDATE ride_events SET
                title = COALESCE(?, title),
                description = COALESCE(?, description),
                start_time = COALESCE(?, start_time),
                end_time = COALESCE(?, end_time),
                location = COALESCE(?, location),
                max_participants = COALESCE(?, max_participants),
                is_public = COALESCE(?, is_public),
                updated_at = NOW()
            WHERE id = ?
        `, [title, description, start_time, end_time, location, max_participants, is_public ? 1 : 0, eventId]);
        
        res.json({ message: 'Event updated successfully' });
    } catch (error) {
        console.error('Error updating event:', error);
        res.status(500).json({ error: 'Failed to update event' });
    }
});

// Delete event (organizer only)
router.delete('/:id', authenticateToken, async (req, res) => {
    try {
        const eventId = req.params.id;
        const userId = req.user.id;
        
        // Check if user is organizer
        const events = await query(`
            SELECT organizer_id FROM ride_events WHERE id = ?
        `, [eventId]);
        
        if (!events || events.length === 0) {
            return res.status(404).json({ error: 'Event not found' });
        }
        
        if (events[0].organizer_id !== userId) {
            return res.status(403).json({ error: 'Only organizer can delete event' });
        }
        
        // Delete participants first (due to foreign key constraint)
        await query(`DELETE FROM event_participants WHERE event_id = ?`, [eventId]);
        
        // Delete event
        await query(`DELETE FROM ride_events WHERE id = ?`, [eventId]);
        
        res.json({ message: 'Event deleted successfully' });
    } catch (error) {
        console.error('Error deleting event:', error);
        res.status(500).json({ error: 'Failed to delete event' });
    }
});

// Get events by location/radius (for discovery)
router.get('/nearby/:lat/:lon', authenticateToken, async (req, res) => {
    try {
        const { lat, lon } = req.params;
        const radius = req.query.radius || 50; // km
        const userId = req.user.id;
        
        // Simple distance calculation (for more accurate, use spatial functions)
        const events = await query(`
            SELECT e.*, u.username as organizer_username,
                   COUNT(ep.user_id) as participant_count,
                   CASE WHEN ep.user_id = ? THEN 1 ELSE 0 END as is_participating,
                   (
                       6371 * acos(
                           cos(radians(?)) * cos(radians(CAST(SUBSTRING_INDEX(e.location, ',', 1) AS DECIMAL(10,8)))) *
                           cos(radians(CAST(SUBSTRING_INDEX(e.location, ',', -1) AS DECIMAL(11,8))) - radians(?)) +
                           sin(radians(?)) * sin(radians(CAST(SUBSTRING_INDEX(e.location, ',', 1) AS DECIMAL(10,8))))
                       )
                   ) AS distance
            FROM ride_events e
            JOIN users u ON e.organizer_id = u.id
            LEFT JOIN event_participants ep ON e.id = ep.event_id AND ep.user_id = ?
            WHERE e.is_public = 1 AND e.start_time > NOW()
            GROUP BY e.id, u.username
            HAVING distance <= ?
            ORDER BY distance ASC, e.start_time ASC
        `, [userId, lat, lon, lat, userId, radius]);
        
        res.json({ events });
    } catch (error) {
        console.error('Error fetching nearby events:', error);
        res.status(500).json({ error: 'Failed to fetch nearby events' });
    }
});

module.exports = router;