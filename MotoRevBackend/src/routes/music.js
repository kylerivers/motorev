const express = require('express');
const router = express.Router();
const { run, all, get } = require('../database/connection');
const { authenticateToken } = require('../middleware/auth');

// Share music with group
router.post('/share', authenticateToken, async (req, res) => {
    try {
        const { trackTitle, artist, groupId } = req.body;
        const userId = req.user.userId;
        
        if (!trackTitle || !artist || !groupId) {
            return res.status(400).json({ error: 'Track title, artist, and group ID are required' });
        }
        
        // Verify user is in the group
        const membership = await get(`
            SELECT * FROM pack_members 
            WHERE pack_id = ? AND user_id = ?
        `, [groupId, userId]);
        
        if (!membership) {
            return res.status(403).json({ error: 'You are not a member of this group' });
        }
        
        // Store the shared track
        await run(`
            INSERT INTO shared_music (pack_id, user_id, track_title, artist, shared_at)
            VALUES (?, ?, ?, ?, NOW())
        `, [groupId, userId, trackTitle, artist]);
        
        // Update group's current track
        await run(`
            UPDATE riding_packs SET current_track = ?, current_artist = ?, track_updated_at = NOW()
            WHERE id = ?
        `, [trackTitle, artist, groupId]);
        
        res.json({ message: 'Track shared successfully' });
    } catch (error) {
        console.error('Error sharing music:', error);
        res.status(500).json({ error: 'Failed to share music' });
    }
});

// Get group music session
router.get('/session/:groupId', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        
        // Verify user is in the group
        const membership = await get(`
            SELECT * FROM pack_members 
            WHERE pack_id = ? AND user_id = ?
        `, [groupId, userId]);
        
        if (!membership) {
            return res.status(403).json({ error: 'You are not a member of this group' });
        }
        
        // Get group's current music session
        const group = await get(`
            SELECT current_track, current_artist, track_updated_at 
            FROM riding_packs WHERE id = ?
        `, [groupId]);
        
        if (!group) {
            return res.status(404).json({ error: 'Group not found' });
        }
        
        // Get participants in music session
        const participants = await all(`
            SELECT u.username FROM pack_members grm
            JOIN users u ON grm.user_id = u.id
            WHERE grm.pack_id = ? AND grm.is_music_connected = 1
        `, [groupId]);
        
        const session = {
            id: `music-${groupId}`,
            groupId: groupId,
            currentTrack: group.current_track,
            currentArtist: group.current_artist,
            isPlaying: true, // Simplified for now
            participants: participants.map(p => p.username)
        };
        
        res.json({ session });
    } catch (error) {
        console.error('Error getting music session:', error);
        res.status(500).json({ error: 'Failed to get music session' });
    }
});

// Join music session
router.post('/session/:groupId/join', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        
        // Update user's music connection status
        await run(`
            UPDATE pack_members SET is_music_connected = 1
            WHERE pack_id = ? AND user_id = ?
        `, [groupId, userId]);
        
        res.json({ message: 'Joined music session successfully' });
    } catch (error) {
        console.error('Error joining music session:', error);
        res.status(500).json({ error: 'Failed to join music session' });
    }
});

// Leave music session
router.post('/session/:groupId/leave', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        
        // Update user's music connection status
        await run(`
            UPDATE pack_members SET is_music_connected = 0
            WHERE pack_id = ? AND user_id = ?
        `, [groupId, userId]);
        
        res.json({ message: 'Left music session successfully' });
    } catch (error) {
        console.error('Error leaving music session:', error);
        res.status(500).json({ error: 'Failed to leave music session' });
    }
});

module.exports = router;
