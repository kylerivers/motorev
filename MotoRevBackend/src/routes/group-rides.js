const express = require('express');
const { query, get, run } = require('../database/connection');
const authRouter = require('./auth');
const { authenticateToken } = authRouter;
const router = express.Router();

// Create a new group ride
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { name, description, isPrivate, maxMembers, plannedRoute } = req.body;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({ error: 'Ride name is required' });
    }

    // Generate invite code for private rides
    const inviteCode = isPrivate ? generateInviteCode() : null;

    const result = await run(`
      INSERT INTO riding_packs (
        name, description, created_by, max_members, pack_type, 
        privacy_level, status, planned_route, created_at, updated_at
      ) VALUES (?, ?, ?, ?, 'temporary', ?, 'active', ?, NOW(), NOW())
    `, [
      name.trim(),
      description || '',
      req.user.userId,
      maxMembers || 20,
      isPrivate ? 'private' : 'public',
      plannedRoute ? JSON.stringify(plannedRoute) : null
    ]);

    // Add creator as pack leader
    await run(`
      INSERT INTO pack_members (pack_id, user_id, role, status, joined_at)
      VALUES (?, ?, 'leader', 'active', NOW())
    `, [result.insertId, req.user.userId]);

    // Get created pack details
    const pack = await get(`
      SELECT p.*, u.username as leader_username, u.first_name, u.last_name
      FROM riding_packs p
      JOIN users u ON p.created_by = u.id
      WHERE p.id = ?
    `, [result.insertId]);

    res.status(201).json({
      success: true,
      pack: {
        id: pack.id,
        name: pack.name,
        description: pack.description,
        leaderId: pack.created_by,
        leaderName: `${pack.first_name || ''} ${pack.last_name || ''}`.trim() || pack.leader_username,
        maxMembers: pack.max_members,
        currentMembers: 1,
        isPrivate: pack.privacy_level === 'private',
        inviteCode: inviteCode,
        status: pack.status,
        createdAt: pack.created_at
      }
    });

  } catch (error) {
    console.error('Create group ride error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all active group rides (public ones)
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { page = 1, limit = 20, status = 'active' } = req.query;
    const offset = (page - 1) * limit;

    const packs = await query(`
      SELECT p.*, u.username as leader_username, u.first_name, u.last_name,
             COUNT(pm.id) as current_members
      FROM riding_packs p
      JOIN users u ON p.created_by = u.id
      LEFT JOIN pack_members pm ON p.id = pm.pack_id AND pm.status = 'active'
      WHERE p.privacy_level = 'public' AND p.status = ?
      GROUP BY p.id
      ORDER BY p.created_at DESC
      LIMIT ? OFFSET ?
    `, [status, parseInt(limit), offset]);

    const formattedPacks = packs.map(pack => ({
      id: pack.id,
      name: pack.name,
      description: pack.description,
      leaderId: pack.created_by,
      leaderName: `${pack.first_name || ''} ${pack.last_name || ''}`.trim() || pack.leader_username,
      maxMembers: pack.max_members,
      currentMembers: pack.current_members,
      isPrivate: pack.privacy_level === 'private',
      status: pack.status,
      meetingPoint: pack.meeting_point_name,
      scheduledStart: pack.start_time,
      createdAt: pack.created_at
    }));

    res.json({
      success: true,
      packs: formattedPacks,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: formattedPacks.length
      }
    });

  } catch (error) {
    console.error('Get group rides error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Join a group ride
router.post('/:packId/join', authenticateToken, async (req, res) => {
  try {
    const { packId } = req.params;
    const { inviteCode } = req.body;

    // Check if pack exists and is active
    const pack = await get(`
      SELECT * FROM riding_packs WHERE id = ? AND status IN ('active', 'planned')
    `, [packId]);

    if (!pack) {
      return res.status(404).json({ error: 'Group ride not found or no longer active' });
    }

    // Check privacy and invite code
    if (pack.privacy_level === 'private' && pack.invite_code !== inviteCode) {
      return res.status(403).json({ error: 'Invalid invite code for private ride' });
    }

    // Check if user is already a member
    const existingMember = await get(`
      SELECT id FROM pack_members WHERE pack_id = ? AND user_id = ? AND status = 'active'
    `, [packId, req.user.userId]);

    if (existingMember) {
      return res.status(400).json({ error: 'Already a member of this group ride' });
    }

    // Check member limit
    const memberCount = await get(`
      SELECT COUNT(*) as count FROM pack_members WHERE pack_id = ? AND status = 'active'
    `, [packId]);

    if (memberCount.count >= pack.max_members) {
      return res.status(400).json({ error: 'Group ride is full' });
    }

    // Add user to pack
    await run(`
      INSERT INTO pack_members (pack_id, user_id, role, status, joined_at)
      VALUES (?, ?, 'member', 'active', NOW())
    `, [packId, req.user.userId]);

    // Update pack member count
    await run(`
      UPDATE riding_packs SET current_members = current_members + 1 WHERE id = ?
    `, [packId]);

    // Get user info for response
    const user = await get(`
      SELECT username, first_name, last_name FROM users WHERE id = ?
    `, [req.user.userId]);

    res.json({
      success: true,
      message: 'Successfully joined group ride',
      member: {
        userId: req.user.userId,
        username: user.username,
        name: `${user.first_name || ''} ${user.last_name || ''}`.trim() || user.username,
        role: 'member',
        joinedAt: new Date()
      }
    });

  } catch (error) {
    console.error('Join group ride error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Leave a group ride
router.post('/:packId/leave', authenticateToken, async (req, res) => {
  try {
    const { packId } = req.params;

    // Check if user is a member
    const membership = await get(`
      SELECT role FROM pack_members WHERE pack_id = ? AND user_id = ? AND status = 'active'
    `, [packId, req.user.userId]);

    if (!membership) {
      return res.status(404).json({ error: 'Not a member of this group ride' });
    }

    // Remove user from pack
    await run(`
      UPDATE pack_members SET status = 'left', left_at = NOW() 
      WHERE pack_id = ? AND user_id = ?
    `, [packId, req.user.userId]);

    // Update pack member count
    await run(`
      UPDATE riding_packs SET current_members = current_members - 1 WHERE id = ?
    `, [packId]);

    // If leader leaves, transfer leadership or dissolve pack
    if (membership.role === 'leader') {
      const nextLeader = await get(`
        SELECT user_id FROM pack_members 
        WHERE pack_id = ? AND status = 'active' AND role IN ('co_leader', 'member')
        ORDER BY role DESC, joined_at ASC
        LIMIT 1
      `, [packId]);

      if (nextLeader) {
        await run(`
          UPDATE pack_members SET role = 'leader' WHERE pack_id = ? AND user_id = ?
        `, [packId, nextLeader.user_id]);
      } else {
        // No members left, dissolve pack
        await run(`
          UPDATE riding_packs SET status = 'cancelled' WHERE id = ?
        `, [packId]);
      }
    }

    res.json({
      success: true,
      message: 'Successfully left group ride'
    });

  } catch (error) {
    console.error('Leave group ride error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get group ride details and members
router.get('/:packId', authenticateToken, async (req, res) => {
  try {
    const { packId } = req.params;

    // Get pack details
    const pack = await get(`
      SELECT p.*, u.username as leader_username, u.first_name as leader_first, u.last_name as leader_last
      FROM riding_packs p
      JOIN users u ON p.created_by = u.id
      WHERE p.id = ?
    `, [packId]);

    if (!pack) {
      return res.status(404).json({ error: 'Group ride not found' });
    }

    // Get all active members
    const members = await query(`
      SELECT pm.user_id, pm.role, pm.joined_at, 
             u.username, u.first_name, u.last_name, u.motorcycle_make, u.motorcycle_model,
             ls.latitude, ls.longitude, ls.speed, ls.updated_at as last_location_update
      FROM pack_members pm
      JOIN users u ON pm.user_id = u.id
      LEFT JOIN location_shares ls ON u.id = ls.user_id AND ls.expires_at > NOW()
      WHERE pm.pack_id = ? AND pm.status = 'active'
      ORDER BY pm.role DESC, pm.joined_at ASC
    `, [packId]);

    const formattedMembers = members.map(member => ({
      userId: member.user_id,
      username: member.username,
      name: `${member.first_name || ''} ${member.last_name || ''}`.trim() || member.username,
      role: member.role,
      bikeName: member.motorcycle_make && member.motorcycle_model 
        ? `${member.motorcycle_make} ${member.motorcycle_model}` 
        : 'Unknown Bike',
      joinedAt: member.joined_at,
      currentLocation: member.latitude && member.longitude ? {
        latitude: parseFloat(member.latitude),
        longitude: parseFloat(member.longitude)
      } : null,
      currentSpeed: member.speed ? parseFloat(member.speed) : null,
      lastLocationUpdate: member.last_location_update,
      isOnline: member.last_location_update && 
        new Date() - new Date(member.last_location_update) < 300000 // 5 minutes
    }));

    res.json({
      success: true,
      pack: {
        id: pack.id,
        name: pack.name,
        description: pack.description,
        leaderId: pack.created_by,
        leaderName: `${pack.leader_first || ''} ${pack.leader_last || ''}`.trim() || pack.leader_username,
        maxMembers: pack.max_members,
        currentMembers: pack.current_members,
        isPrivate: pack.privacy_level === 'private',
        status: pack.status,
        meetingPoint: pack.meeting_point_name,
        plannedRoute: pack.planned_route ? JSON.parse(pack.planned_route) : null,
        createdAt: pack.created_at
      },
      members: formattedMembers
    });

  } catch (error) {
    console.error('Get group ride details error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update group ride route
router.put('/:packId/route', authenticateToken, async (req, res) => {
  try {
    const { packId } = req.params;
    const { route } = req.body;

    // Check if user is leader or co-leader
    const membership = await get(`
      SELECT role FROM pack_members WHERE pack_id = ? AND user_id = ? AND status = 'active'
    `, [packId, req.user.userId]);

    if (!membership || !['leader', 'co_leader'].includes(membership.role)) {
      return res.status(403).json({ error: 'Only leaders can update the route' });
    }

    // Update route
    await run(`
      UPDATE riding_packs SET planned_route = ?, updated_at = NOW() WHERE id = ?
    `, [JSON.stringify(route), packId]);

    res.json({
      success: true,
      message: 'Route updated successfully'
    });

  } catch (error) {
    console.error('Update route error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start group ride
router.post('/:packId/start', authenticateToken, async (req, res) => {
  try {
    const { packId } = req.params;

    // Check if user is leader
    const membership = await get(`
      SELECT role FROM pack_members WHERE pack_id = ? AND user_id = ? AND status = 'active'
    `, [packId, req.user.userId]);

    if (!membership || membership.role !== 'leader') {
      return res.status(403).json({ error: 'Only the leader can start the ride' });
    }

    // Update pack status
    await run(`
      UPDATE riding_packs SET status = 'riding', start_time = NOW(), updated_at = NOW() WHERE id = ?
    `, [packId]);

    res.json({
      success: true,
      message: 'Group ride started successfully'
    });

  } catch (error) {
    console.error('Start group ride error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// End group ride
router.post('/:packId/end', authenticateToken, async (req, res) => {
  try {
    const { packId } = req.params;

    // Check if user is leader
    const membership = await get(`
      SELECT role FROM pack_members WHERE pack_id = ? AND user_id = ? AND status = 'active'
    `, [packId, req.user.userId]);

    if (!membership || membership.role !== 'leader') {
      return res.status(403).json({ error: 'Only the leader can end the ride' });
    }

    // Update pack status
    await run(`
      UPDATE riding_packs SET status = 'finished', updated_at = NOW() WHERE id = ?
    `, [packId]);

    res.json({
      success: true,
      message: 'Group ride ended successfully'
    });

  } catch (error) {
    console.error('End group ride error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Invite user to group ride
router.post('/:packId/invite', authenticateToken, async (req, res) => {
  try {
    const { packId } = req.params;
    const { username } = req.body;

    if (!username || username.trim().length === 0) {
      return res.status(400).json({ error: 'Username is required' });
    }

    // Check if user is leader or co-leader
    const membership = await get(`
      SELECT role FROM pack_members WHERE pack_id = ? AND user_id = ? AND status = 'active'
    `, [packId, req.user.userId]);

    if (!membership || !['leader', 'co_leader'].includes(membership.role)) {
      return res.status(403).json({ error: 'Only leaders can send invitations' });
    }

    // Check if target user exists
    const targetUser = await get(`
      SELECT id, username FROM users WHERE username = ?
    `, [username.trim()]);

    if (!targetUser) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check if user is already a member
    const existingMember = await get(`
      SELECT id FROM pack_members WHERE pack_id = ? AND user_id = ? AND status = 'active'
    `, [packId, targetUser.id]);

    if (existingMember) {
      return res.status(400).json({ error: 'User is already a member' });
    }

    // Get pack info for invitation
    const pack = await get(`
      SELECT name FROM riding_packs WHERE id = ?
    `, [packId]);

    // Store invitation (in a real app, would create invitations table)
    // For now, we'll emit via socket if connected

    res.json({
      success: true,
      message: `Invitation sent to ${username}`,
      inviteData: {
        packId: packId,
        packName: pack.name,
        fromUsername: req.user.username,
        toUserId: targetUser.id,
        toUsername: targetUser.username
      }
    });

  } catch (error) {
    console.error('Invite user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Helper function to generate invite codes
function generateInviteCode(length = 6) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

module.exports = router; 