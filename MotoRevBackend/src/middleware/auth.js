const jwt = require('jsonwebtoken');
const { query } = require('../database/connection');

// Middleware to authenticate JWT tokens
async function authenticateToken(req, res, next) {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({
        error: 'Access token required',
        message: 'Please provide a valid authorization token'
      });
    }

    // Development test token bypass - check before JWT verification
    if (token === 'test-token-for-development') {
      // Find a test user to use for development
      const testUserResult = await query(
        'SELECT id, email, username FROM users WHERE username = ?',
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
    }

    // Verify JWT token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if user still exists
    const userResult = await query(
      'SELECT id, email, username FROM users WHERE id = ?',
      [decoded.userId]
    );

    if (userResult.length === 0) {
      return res.status(401).json({
        error: 'Invalid token',
        message: 'User not found'
      });
    }

    // Skip session check for now
    // const sessionResult = await query(
    //   'SELECT is_active, expires_at FROM user_sessions WHERE user_id = ? AND is_active = true ORDER BY created_at DESC LIMIT 1',
    //   [decoded.userId]
    // );

    // if (sessionResult.length === 0) {
    //   return res.status(401).json({
    //     error: 'Session expired',
    //     message: 'Please log in again'
    //   });
    // }

    // const session = sessionResult[0];
    // if (new Date() > new Date(session.expires_at)) {
    //   return res.status(401).json({
    //     error: 'Session expired',
    //     message: 'Please log in again'
    //   });
    // }

    // Add user info to request
    req.user = {
      id: decoded.userId,
      email: decoded.email,
      username: decoded.username
    };

    next();

  } catch (error) {
    console.error('Authentication error:', error);

    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: 'Invalid token',
        message: 'Token is malformed or invalid'
      });
    }

    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Token expired',
        message: 'Please log in again'
      });
    }

    return res.status(500).json({
      error: 'Authentication failed',
      message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
}

// Optional authentication middleware (doesn't fail if no token)
async function optionalAuth(req, res, next) {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return next(); // Continue without authentication
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const userResult = await query(
      'SELECT id, email, username, is_active FROM users WHERE id = $1',
      [decoded.userId]
    );

    if (userResult.rows.length > 0 && userResult.rows[0].is_active) {
      req.userId = decoded.userId;
      req.email = decoded.email;
      req.username = decoded.username;
    }

    next();

  } catch (error) {
    // Ignore authentication errors for optional auth
    next();
  }
}

// Middleware to check if user is verified
function requireVerified(req, res, next) {
  // This would check if user is verified, but for now we'll skip it
  // since we don't have email verification implemented yet
  next();
}

// Middleware to check if user is admin
async function requireAdmin(req, res, next) {
  try {
    if (!req.userId) {
      return res.status(401).json({
        error: 'Authentication required'
      });
    }

    const userResult = await query(
      'SELECT preferences FROM users WHERE id = $1',
      [req.userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({
        error: 'User not found'
      });
    }

    const preferences = userResult.rows[0].preferences || {};
    if (!preferences.isAdmin) {
      return res.status(403).json({
        error: 'Admin access required',
        message: 'You do not have permission to access this resource'
      });
    }

    next();

  } catch (error) {
    console.error('Admin check error:', error);
    res.status(500).json({
      error: 'Authorization check failed',
      message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
}

module.exports = {
  authenticateToken,
  optionalAuth,
  requireVerified,
  requireAdmin
}; 