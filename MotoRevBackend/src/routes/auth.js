const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { query, get, run } = require('../database/connection');
const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRES_IN = '7d';

// Middleware to verify JWT token
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  // Development test token bypass
  if (token === 'test-token-for-development') {
    try {
      // Find a test user to use for development
      const testUserResult = await query(
        'SELECT id, email, username FROM users WHERE username = ? AND deleted_at IS NULL',
        ['rider_alex']
      );
      
      if (testUserResult.length > 0) {
        const user = testUserResult[0];
        req.user = {
          id: user.id,
          email: user.email,
          username: user.username,
          userId: user.id
        };
        req.userId = user.id;
        req.email = user.email;
        req.username = user.username;
        console.log('🧪 Using test token with user:', user.username);
        return next();
      }
    } catch (error) {
      console.error('Test token error:', error);
    }
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Register new user
router.post('/register', async (req, res) => {
  try {
    const {
      username,
      email,
      password,
      firstName,
      lastName,
      phoneNumber,
      motorcycleMake,
      motorcycleModel,
      motorcycleYear
    } = req.body;

    // Validate required fields
    if (!username || !email || !password || !firstName || !lastName) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Check if user already exists
    const existingUser = await get(
      'SELECT id FROM users WHERE username = ? OR email = ?',
      [username, email]
    );

    if (existingUser) {
      return res.status(409).json({ error: 'Username or email already exists' });
    }

    // Hash password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // Create user
    const result = await run(`
      INSERT INTO users (
        username, email, password_hash, first_name, last_name, phone,
        motorcycle_make, motorcycle_model, motorcycle_year
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      username,
      email,
      hashedPassword,
      firstName,
      lastName,
      phoneNumber || null,
      motorcycleMake || null,
      motorcycleModel || null,
      motorcycleYear || null
    ]);

    const userId = result.insertId;

    // Generate JWT token
    const token = jwt.sign(
      { userId: userId, username: username },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    // Create session
    await run(`
      INSERT INTO user_sessions (user_id, refresh_token, expires_at)
      VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))
    `, [userId, token]);

    // Get user data (without password)
    const userData = await get(`
      SELECT id, username, email, first_name, last_name, phone,
             motorcycle_make, motorcycle_model, motorcycle_year,
             profile_picture_url, bio, safety_score, total_miles,
             created_at, updated_at
      FROM users WHERE id = ?
    `, [userId]);

    res.status(201).json({
      message: 'User registered successfully',
      user: userData,
      token: token,
      expiresIn: JWT_EXPIRES_IN
    });

  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Login user
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    // Find user by username or email
    const user = await get(`
      SELECT id, username, email, password_hash, first_name, last_name, phone,
             motorcycle_make, motorcycle_model, motorcycle_year,
             profile_picture_url, bio, safety_score, total_miles,
             created_at, updated_at
      FROM users WHERE username = ? OR email = ?
    `, [username, username]);

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    // Create session
    await run(`
      INSERT INTO user_sessions (user_id, refresh_token, expires_at)
      VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))
    `, [user.id, token]);

    // Remove password from response and convert to camelCase for iOS
    const { password_hash, ...dbUser } = user;
    
    // Transform database user to iOS expected format
    const userData = {
      id: dbUser.id,
      username: dbUser.username,
      email: dbUser.email,
      firstName: dbUser.first_name,
      lastName: dbUser.last_name,
      phone: dbUser.phone,
      bio: dbUser.bio,
      motorcycleMake: dbUser.motorcycle_make,
      motorcycleModel: dbUser.motorcycle_model,
      motorcycleYear: dbUser.motorcycle_year,
      ridingExperience: null, // Not in current schema
      totalMiles: parseFloat(dbUser.total_miles) || 0,
      totalRides: 0, // Not in current schema
      safetyScore: dbUser.safety_score,
      postsCount: 0, // Not in current schema
      followersCount: 0, // Not in current schema
      followingCount: 0, // Not in current schema
      status: "active", // Default status
      locationSharingEnabled: false, // Not in current schema
      isVerified: false, // Not in current schema
      createdAt: dbUser.created_at,
      updatedAt: dbUser.updated_at
    };

    res.json({
      success: true,
      message: 'Login successful',
      user: userData,
      token: token
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Logout user
router.post('/logout', authenticateToken, async (req, res) => {
  try {
    const token = req.headers['authorization'].split(' ')[1];
    
    // Delete session
    await run('DELETE FROM user_sessions WHERE refresh_token = ?', [token]);
    
    res.json({ message: 'Logout successful' });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Refresh token
router.post('/refresh', authenticateToken, async (req, res) => {
  try {
    const oldToken = req.headers['authorization'].split(' ')[1];
    
    // Generate new token
    const newToken = jwt.sign(
      { userId: req.user.userId, username: req.user.username },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    // Update session
    await run(`
      UPDATE user_sessions 
      SET refresh_token = ?, expires_at = DATE_ADD(NOW(), INTERVAL 7 DAY)
      WHERE refresh_token = ?
    `, [newToken, oldToken]);

    res.json({
      message: 'Token refreshed',
      token: newToken,
      expiresIn: JWT_EXPIRES_IN
    });

  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get current user
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const user = await get(`
      SELECT id, username, email, first_name, last_name, phone,
             motorcycle_make, motorcycle_model, motorcycle_year, riding_experience,
             profile_picture_url, bio, safety_score, total_miles,
             posts_count, followers_count, following_count, status,
             location_sharing_enabled, is_verified, created_at, updated_at
      FROM users WHERE id = ?
    `, [req.user.userId]);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Transform to camelCase for iOS compatibility (same as profile endpoint)
    const userResponse = {
      id: user.id,
      username: user.username,
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
      phone: user.phone,
      motorcycleMake: user.motorcycle_make,
      motorcycleModel: user.motorcycle_model,
      motorcycleYear: user.motorcycle_year,
      ridingExperience: user.riding_experience || 'beginner',
      bio: user.bio,
      profilePictureUrl: user.profile_picture_url,
      safetyScore: user.safety_score || 100,
      totalMiles: parseFloat(user.total_miles) || 0,
      postsCount: user.posts_count || 0,
      followersCount: user.followers_count || 0,
      followingCount: user.following_count || 0,
      status: user.status || 'offline',
      locationSharingEnabled: Boolean(user.location_sharing_enabled),
      isVerified: Boolean(user.is_verified),
      createdAt: user.created_at,
      updatedAt: user.updated_at
    };

    res.json({ user: userResponse });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Change password
router.post('/change-password', authenticateToken, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current password and new password required' });
    }

    // Get current user
    const user = await get('SELECT password_hash FROM users WHERE id = ?', [req.user.userId]);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Verify current password
    const isValidPassword = await bcrypt.compare(currentPassword, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    // Hash new password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);

    // Update password
    await run(`
      UPDATE users 
      SET password_hash = ?
      WHERE id = ?
    `, [hashedPassword, req.user.userId]);

    res.json({ message: 'Password changed successfully' });

  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete account
router.delete('/account', authenticateToken, async (req, res) => {
  try {
    const { password } = req.body;

    if (!password) {
      return res.status(400).json({ error: 'Password required to delete account' });
    }

    // Get current user
    const user = await get('SELECT password_hash FROM users WHERE id = ?', [req.user.userId]);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid password' });
    }

    // Delete user sessions
    await run('DELETE FROM user_sessions WHERE user_id = ?', [req.user.userId]);
    
    // Delete user (cascade should handle related data)
    await run('DELETE FROM users WHERE id = ?', [req.user.userId]);

    res.json({ message: 'Account deleted successfully' });

  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
module.exports.authenticateToken = authenticateToken; 