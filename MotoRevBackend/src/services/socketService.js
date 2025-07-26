const jwt = require('jsonwebtoken');
const { query } = require('../database/connection');

// Store active socket connections
const connectedUsers = new Map(); // userId -> socket
const userRooms = new Map(); // userId -> Set of room names
const packRooms = new Map(); // packId -> Set of userIds

// Setup Socket.IO event handlers
function setupSocketHandlers(io) {
  // Authentication middleware for WebSocket
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
      
      if (!token) {
        return next(new Error('Authentication token required'));
      }

      // Verify JWT token
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      // Check if user exists (SQLite doesn't have is_active column in our schema)
      const userResult = await query(
        'SELECT id, username, first_name, last_name FROM users WHERE id = ?',
        [decoded.userId]
      );

      if (userResult.length === 0) {
        return next(new Error('Invalid token or user not found'));
      }

      // Add user info to socket
      socket.userId = decoded.userId;
      socket.username = decoded.username;
      socket.userInfo = userResult[0];

      next();
    } catch (error) {
      console.error('Socket authentication error:', error);
      next(new Error('Authentication failed'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.userId;
    const username = socket.username;
    
    console.log(`🔌 User connected: ${username} (${userId})`);
    
    // Store connection
    connectedUsers.set(userId, socket);
    userRooms.set(userId, new Set());

    // Join user to their personal room
    socket.join(`user:${userId}`);
    userRooms.get(userId).add(`user:${userId}`);

    // Join user to their pack rooms
    try {
      const packResult = await query(
        `SELECT p.id as pack_id, p.name 
         FROM pack_members pm 
         JOIN riding_packs p ON pm.pack_id = p.id 
         WHERE pm.user_id = ? AND pm.status = 'active'`,
        [userId]
      );

      for (const pack of packResult) {
        const roomName = `pack:${pack.pack_id}`;
        socket.join(roomName);
        userRooms.get(userId).add(roomName);
        
        // Track pack membership
        if (!packRooms.has(pack.pack_id)) {
          packRooms.set(pack.pack_id, new Set());
        }
        packRooms.get(pack.pack_id).add(userId);
        
        console.log(`👥 ${username} joined pack room: ${pack.name}`);
      }
    } catch (error) {
      console.error('Error joining pack rooms:', error);
    }

    // Handle location updates
    socket.on('location_update', async (data) => {
      try {
        const { latitude, longitude, speed, heading, accuracy, rideId } = data;

        if (!latitude || !longitude) {
          socket.emit('error', { message: 'Latitude and longitude are required' });
          return;
        }

        // Broadcast to pack members
        const userPacks = Array.from(userRooms.get(userId) || [])
          .filter(room => room.startsWith('pack:'));

        for (const packRoom of userPacks) {
          socket.to(packRoom).emit('member_location_update', {
            userId,
            username,
            location: {
              latitude: parseFloat(latitude),
              longitude: parseFloat(longitude),
              speed: parseFloat(speed) || null,
              heading: parseFloat(heading) || null,
              accuracy: parseFloat(accuracy) || null,
              timestamp: new Date().toISOString()
            },
            rideId
          });
        }

        // Store location update if associated with an active ride
        if (rideId) {
          const { run } = require('../database/connection');
          await run(
            `INSERT INTO location_updates (
              ride_id, user_id, latitude, longitude, speed, heading, accuracy, timestamp
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [rideId, userId, latitude, longitude, speed || null, heading || null, accuracy || null, new Date().toISOString()]
          );
        }

        console.log(`📍 Location update from ${username}: ${latitude}, ${longitude}`);
        
      } catch (error) {
        console.error('Location update error:', error);
        socket.emit('error', { message: 'Failed to process location update' });
      }
    });

    // Handle emergency alerts
    socket.on('emergency_alert', async (data) => {
      try {
        const { eventType, severity, location, rideId, sensorData } = data;

        if (!eventType || !location) {
          socket.emit('error', { message: 'Event type and location are required' });
          return;
        }

        // Store emergency event
        const { run } = require('../database/connection');
        const result = await run(
          `INSERT INTO emergency_events (
            user_id, ride_id, event_type, severity, latitude, longitude, 
            description, auto_detected
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            userId,
            rideId || null,
            eventType,
            severity || 'high',
            location.latitude,
            location.longitude,
            sensorData ? JSON.stringify(sensorData) : 'Emergency alert',
            true
          ]
        );

        const emergencyEvent = {
          id: result.lastID,
          event_type: eventType,
          severity: severity || 'high',
          location: location,
          auto_detected: true,
          created_at: new Date().toISOString()
        };

        // Get user's emergency contacts - simplified for SQLite
        const userResult = await query(
          'SELECT emergency_contact_name, emergency_contact_phone FROM users WHERE id = ?',
          [userId]
        );

        const emergencyContacts = userResult[0] || {};

        // Broadcast to pack members
        const userPacks = Array.from(userRooms.get(userId) || [])
          .filter(room => room.startsWith('pack:'));

        const emergencyData = {
          eventId: emergencyEvent.id,
          userId,
          username,
          eventType: emergencyEvent.event_type,
          severity: emergencyEvent.severity,
          location: emergencyEvent.location,
          timestamp: emergencyEvent.created_at,
          rideId
        };

        for (const packRoom of userPacks) {
          socket.to(packRoom).emit('member_emergency', emergencyData);
        }

        // TODO: In a real implementation, this would also:
        // - Send push notifications to emergency contacts
        // - Contact emergency services based on severity
        // - Send SMS/email alerts
        // - Trigger automated response protocols

        console.log(`🚨 Emergency alert from ${username}: ${eventType} (${severity}) at ${JSON.stringify(location)}`);

        socket.emit('emergency_alert_sent', {
          message: 'Emergency alert sent successfully',
          eventId: emergencyEvent.id,
          contactsNotified: emergencyContacts.length
        });

      } catch (error) {
        console.error('Emergency alert error:', error);
        socket.emit('error', { message: 'Failed to send emergency alert' });
      }
    });

    // Handle ride status updates
    socket.on('ride_update', async (data) => {
      try {
        const { rideId, status, location, stats } = data;

        if (!rideId || !status) {
          socket.emit('error', { message: 'Ride ID and status are required' });
          return;
        }

        // Verify ride ownership
        const rideResult = await query(
          'SELECT user_id, title FROM rides WHERE id = $1',
          [rideId]
        );

        if (rideResult.rows.length === 0 || rideResult.rows[0].user_id !== userId) {
          socket.emit('error', { message: 'Ride not found or access denied' });
          return;
        }

        const ride = rideResult.rows[0];

        // Broadcast to pack members
        const userPacks = Array.from(userRooms.get(userId) || [])
          .filter(room => room.startsWith('pack:'));

        const rideUpdate = {
          rideId,
          userId,
          username,
          rideTitle: ride.title,
          status,
          location,
          stats,
          timestamp: new Date().toISOString()
        };

        for (const packRoom of userPacks) {
          socket.to(packRoom).emit('member_ride_update', rideUpdate);
        }

        console.log(`🏍️ Ride update from ${username}: ${status} (${rideId})`);

      } catch (error) {
        console.error('Ride update error:', error);
        socket.emit('error', { message: 'Failed to process ride update' });
      }
    });

    // Handle social notifications
    socket.on('social_notification', async (data) => {
      try {
        const { targetUserId, type, message, postId, storyId } = data;

        if (!targetUserId || !type || !message) {
          socket.emit('error', { message: 'Target user, type, and message are required' });
          return;
        }

        // Store notification
        await query(
          `INSERT INTO notifications (
            id, user_id, type, title, message, data
          ) VALUES (uuid_generate_v4(), $1, $2, $3, $4, $5)`,
          [
            targetUserId,
            type,
            `Social Notification`,
            message,
            JSON.stringify({ sourceUserId: userId, username, postId, storyId })
          ]
        );

        // Send to target user if they're connected
        const targetSocket = connectedUsers.get(targetUserId);
        if (targetSocket) {
          targetSocket.emit('notification', {
            type,
            message,
            sourceUser: {
              id: userId,
              username,
              firstName: socket.userInfo.first_name,
              lastName: socket.userInfo.last_name
            },
            data: { postId, storyId },
            timestamp: new Date().toISOString()
          });
        }

        console.log(`🔔 Social notification from ${username} to user ${targetUserId}: ${message}`);

      } catch (error) {
        console.error('Social notification error:', error);
        socket.emit('error', { message: 'Failed to send notification' });
      }
    });

    // Handle pack invitations
    socket.on('pack_invite', async (data) => {
      try {
        const { packId, targetUserId } = data;

        // Verify pack ownership/admin status
        const packMemberResult = await query(
          `SELECT role FROM pack_members 
           WHERE pack_id = $1 AND user_id = $2 AND status = 'active' 
           AND role IN ('owner', 'admin')`,
          [packId, userId]
        );

        if (packMemberResult.rows.length === 0) {
          socket.emit('error', { message: 'You do not have permission to invite to this pack' });
          return;
        }

        // Get pack info
        const packResult = await query(
          'SELECT name, description FROM packs WHERE id = $1',
          [packId]
        );

        if (packResult.rows.length === 0) {
          socket.emit('error', { message: 'Pack not found' });
          return;
        }

        const pack = packResult.rows[0];

        // Create pack invitation (add as invited member)
        await query(
          `INSERT INTO pack_members (id, pack_id, user_id, role, status)
           VALUES (uuid_generate_v4(), $1, $2, 'member', 'invited')
           ON CONFLICT (pack_id, user_id) DO UPDATE SET status = 'invited'`,
          [packId, targetUserId]
        );

        // Send notification to target user
        const targetSocket = connectedUsers.get(targetUserId);
        if (targetSocket) {
          targetSocket.emit('pack_invitation', {
            packId,
            packName: pack.name,
            packDescription: pack.description,
            invitedBy: {
              id: userId,
              username,
              firstName: socket.userInfo.first_name,
              lastName: socket.userInfo.last_name
            },
            timestamp: new Date().toISOString()
          });
        }

        console.log(`👥 Pack invitation sent by ${username} to user ${targetUserId} for pack ${pack.name}`);

      } catch (error) {
        console.error('Pack invite error:', error);
        socket.emit('error', { message: 'Failed to send pack invitation' });
      }
    });

    // Handle disconnection
    socket.on('disconnect', (reason) => {
      console.log(`🔌 User disconnected: ${username} (${reason})`);
      
      // Remove from connected users
      connectedUsers.delete(userId);
      
      // Remove from pack rooms
      const userRoomSet = userRooms.get(userId);
      if (userRoomSet) {
        for (const room of userRoomSet) {
          if (room.startsWith('pack:')) {
            const packId = room.split(':')[1];
            const packUserSet = packRooms.get(packId);
            if (packUserSet) {
              packUserSet.delete(userId);
              if (packUserSet.size === 0) {
                packRooms.delete(packId);
              }
            }
          }
        }
        userRooms.delete(userId);
      }
    });

    // Send connection success
    socket.emit('connected', {
      message: 'Connected to MotoRev real-time service',
      userId,
      username,
      timestamp: new Date().toISOString()
    });
  });

  // Utility functions for external use
  return {
    // Send notification to specific user
    sendNotificationToUser: (userId, notification) => {
      const socket = connectedUsers.get(userId);
      if (socket) {
        socket.emit('notification', notification);
        return true;
      }
      return false;
    },

    // Broadcast to pack members
    broadcastToPack: (packId, event, data) => {
      const packUserSet = packRooms.get(packId);
      if (packUserSet) {
        for (const userId of packUserSet) {
          const socket = connectedUsers.get(userId);
          if (socket) {
            socket.emit(event, data);
          }
        }
        return packUserSet.size;
      }
      return 0;
    },

    // Get online users count
    getOnlineUsersCount: () => connectedUsers.size,

    // Get pack online members
    getPackOnlineMembers: (packId) => {
      const packUserSet = packRooms.get(packId);
      return packUserSet ? Array.from(packUserSet) : [];
    }
  };
}

module.exports = { setupSocketHandlers }; 