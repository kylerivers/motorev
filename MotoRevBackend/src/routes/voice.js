const express = require('express');
const router = express.Router();
const { run, all, get } = require('../database/connection');
const { authenticateToken } = require('../middleware/auth');

// Join voice chat room
router.post('/join', authenticateToken, async (req, res) => {
    try {
        const { roomId } = req.body;
        const userId = req.user.userId;
        
        if (!roomId) {
            return res.status(400).json({ error: 'Room ID is required' });
        }
        
        // Check if it's a group room
        if (roomId.startsWith('group-')) {
            const groupId = roomId.replace('group-', '');
            
            // Verify user is in the group
            const membership = await get(`
                SELECT * FROM pack_members 
                WHERE pack_id = ? AND user_id = ?
            `, [groupId, userId]);
            
            if (!membership) {
                return res.status(403).json({ error: 'You are not a member of this group' });
            }
            
            // Update user's voice connection status
            await run(`
                UPDATE pack_members SET is_voice_connected = 1
                WHERE pack_id = ? AND user_id = ?
            `, [groupId, userId]);
        }
        
        // Store voice session
        await run(`
            INSERT INTO voice_sessions (room_id, user_id, joined_at)
            VALUES (?, ?, NOW())
            ON DUPLICATE KEY UPDATE joined_at = NOW()
        `, [roomId, userId]);
        
        res.json({ message: 'Joined voice chat successfully' });
    } catch (error) {
        console.error('Error joining voice chat:', error);
        res.status(500).json({ error: 'Failed to join voice chat' });
    }
});

// Leave voice chat room
router.post('/leave', authenticateToken, async (req, res) => {
    try {
        const { roomId } = req.body;
        const userId = req.user.userId;
        
        if (!roomId) {
            return res.status(400).json({ error: 'Room ID is required' });
        }
        
        // Check if it's a group room
        if (roomId.startsWith('group-')) {
            const groupId = roomId.replace('group-', '');
            
            // Update user's voice connection status
            await run(`
                UPDATE pack_members SET is_voice_connected = 0
                WHERE pack_id = ? AND user_id = ?
            `, [groupId, userId]);
        }
        
        // Remove from voice session
        await run(`
            DELETE FROM voice_sessions 
            WHERE room_id = ? AND user_id = ?
        `, [roomId, userId]);
        
        res.json({ message: 'Left voice chat successfully' });
    } catch (error) {
        console.error('Error leaving voice chat:', error);
        res.status(500).json({ error: 'Failed to leave voice chat' });
    }
});

// Update mute status
router.post('/mute', authenticateToken, async (req, res) => {
    try {
        const { muted } = req.body;
        const userId = req.user.userId;
        
        // Update mute status in current voice sessions
        await run(`
            UPDATE voice_sessions SET is_muted = ?
            WHERE user_id = ?
        `, [muted ? 1 : 0, userId]);
        
        res.json({ message: 'Mute status updated successfully' });
    } catch (error) {
        console.error('Error updating mute status:', error);
        res.status(500).json({ error: 'Failed to update mute status' });
    }
});

// Get room participants
router.get('/room/:roomId/participants', authenticateToken, async (req, res) => {
    try {
        const { roomId } = req.params;
        const userId = req.user.userId;
        
        // Check if it's a group room and verify access
        if (roomId.startsWith('group-')) {
            const groupId = roomId.replace('group-', '');
            
            const membership = await get(`
                SELECT * FROM pack_members 
                WHERE pack_id = ? AND user_id = ?
            `, [groupId, userId]);
            
            if (!membership) {
                return res.status(403).json({ error: 'You are not a member of this group' });
            }
        }
        
        // Get participants in the room
        const participants = await all(`
            SELECT u.username, vs.is_muted, vs.joined_at
            FROM voice_sessions vs
            JOIN users u ON vs.user_id = u.id
            WHERE vs.room_id = ?
            ORDER BY vs.joined_at ASC
        `, [roomId]);
        
        res.json({ participants });
    } catch (error) {
        console.error('Error getting room participants:', error);
        res.status(500).json({ error: 'Failed to get room participants' });
    }
});

module.exports = router;
