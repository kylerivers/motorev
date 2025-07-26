const express = require('express');
const { query, get, run } = require('../database/connection');
const { authenticateToken } = require('../middleware/auth');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const router = express.Router();

// Helper function to save base64 image to file
async function saveBase64Image(base64Data, userId) {
  try {
    // Remove data URL prefix if present (data:image/jpeg;base64,)
    const matches = base64Data.match(/^data:image\/([a-zA-Z]+);base64,(.+)$/);
    let imageData, extension;
    
    if (matches) {
      extension = matches[1] === 'jpeg' ? 'jpg' : matches[1];
      imageData = matches[2];
    } else {
      // Assume it's already base64 without prefix
      extension = 'jpg';
      imageData = base64Data;
    }
    
    // Generate unique filename
    const timestamp = Date.now();
    const randomHash = crypto.randomBytes(8).toString('hex');
    const filename = `profile_${userId}_${timestamp}_${randomHash}.${extension}`;
    
    // Ensure uploads directory exists
    const uploadsDir = path.join(__dirname, '../../uploads/profile-pictures');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }
    
    // Save file
    const filePath = path.join(uploadsDir, filename);
    const buffer = Buffer.from(imageData, 'base64');
    fs.writeFileSync(filePath, buffer);
    
    // Return URL path for serving the image
    return `/uploads/profile-pictures/${filename}`;
    
  } catch (error) {
    console.error('Error saving profile image:', error);
    throw new Error('Failed to save profile image');
  }
}

// Get user profile by ID
router.get('/:userId', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    
    const user = await get(`
      SELECT id, username, email, first_name, last_name, phone,
             motorcycle_make, motorcycle_model, motorcycle_year,
             profile_picture_url, bio, safety_score, total_miles, total_rides,
             posts_count, followers_count, following_count, status,
             location_sharing_enabled, is_verified, created_at, updated_at
      FROM users WHERE id = ?
    `, [userId]);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Transform to camelCase for iOS compatibility
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
      profilePictureUrl: user.profile_picture_url,
      bio: user.bio,
      safetyScore: user.safety_score || 100,
      totalMiles: parseFloat(user.total_miles) || 0,
      totalRides: user.total_rides || 0,
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

// Get user profile by username
router.get('/username/:username', authenticateToken, async (req, res) => {
  try {
    const { username } = req.params;
    
    const user = await get(`
      SELECT id, username, email, first_name, last_name, phone,
             motorcycle_make, motorcycle_model, motorcycle_year,
             profile_picture_url, bio, safety_score, total_miles, total_rides,
             posts_count, followers_count, following_count, status,
             location_sharing_enabled, is_verified, created_at, updated_at
      FROM users WHERE username = ?
    `, [username]);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Transform to camelCase for iOS compatibility
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
      profilePictureUrl: user.profile_picture_url,
      bio: user.bio,
      safetyScore: user.safety_score || 100,
      totalMiles: parseFloat(user.total_miles) || 0,
      totalRides: user.total_rides || 0,
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
    console.error('Get user by username error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update user profile - Complete implementation
router.put('/profile', authenticateToken, async (req, res) => {
  try {
    const { 
      firstName, 
      lastName, 
      phoneNumber, 
      motorcycleMake, 
      motorcycleModel, 
      motorcycleYear, 
      ridingExperience, 
      bio, 
      profilePicture 
    } = req.body;

    console.log('Profile update request:', { 
      firstName, 
      lastName, 
      phoneNumber, 
      motorcycleMake, 
      motorcycleModel, 
      motorcycleYear, 
      ridingExperience, 
      bio, 
      profilePicture: profilePicture ? 'Image data provided' : 'No image',
      userId: req.user.id 
    });

    // Build dynamic SQL query to only update provided fields
    const updateFields = [];
    const updateValues = [];

    if (firstName !== undefined) {
      updateFields.push('first_name = ?');
      updateValues.push(firstName);
    }
    if (lastName !== undefined) {
      updateFields.push('last_name = ?');
      updateValues.push(lastName);
    }
    if (phoneNumber !== undefined) {
      updateFields.push('phone = ?');
      updateValues.push(phoneNumber);
    }
    if (motorcycleMake !== undefined) {
      updateFields.push('motorcycle_make = ?');
      updateValues.push(motorcycleMake);
    }
    if (motorcycleModel !== undefined) {
      updateFields.push('motorcycle_model = ?');
      updateValues.push(motorcycleModel);
    }
    if (motorcycleYear !== undefined) {
      updateFields.push('motorcycle_year = ?');
      updateValues.push(motorcycleYear ? parseInt(motorcycleYear) : null);
    }
    if (ridingExperience !== undefined) {
      updateFields.push('riding_experience = ?');
      updateValues.push(ridingExperience);
    }
    if (bio !== undefined) {
      updateFields.push('bio = ?');
      updateValues.push(bio);
    }
    if (profilePicture !== undefined) {
      // Process profile picture: save base64 image as file and get URL
      let profilePictureUrl = profilePicture;
      if (profilePicture && profilePicture.length > 100) {
        // This looks like base64 data, save it as a file
        try {
          profilePictureUrl = await saveBase64Image(profilePicture, req.user.id);
          console.log('Profile picture saved as file:', profilePictureUrl);
        } catch (error) {
          console.error('Failed to save profile picture:', error);
          return res.status(400).json({ error: 'Failed to process profile picture' });
        }
      }
      updateFields.push('profile_picture_url = ?');
      updateValues.push(profilePictureUrl);
    }

    // Always update the updated_at timestamp
    updateFields.push('updated_at = NOW()');
    updateValues.push(req.user.id);

    if (updateFields.length === 1) { // Only updated_at was added
      return res.status(400).json({ error: 'No fields to update' });
    }

    const updateSQL = `UPDATE users SET ${updateFields.join(', ')} WHERE id = ?`;
    await run(updateSQL, updateValues);

    // Get updated user data with proper camelCase transformation
    const updatedUser = await get(`
      SELECT id, username, email, first_name, last_name, phone,
             motorcycle_make, motorcycle_model, motorcycle_year, riding_experience,
             bio, profile_picture_url, safety_score, total_miles, 
             posts_count, followers_count, following_count, status,
             location_sharing_enabled, is_verified, created_at, updated_at
      FROM users WHERE id = ?
    `, [req.user.id]);

    // Transform to camelCase for iOS compatibility
    const userResponse = {
      id: updatedUser.id,
      username: updatedUser.username,
      email: updatedUser.email,
      firstName: updatedUser.first_name,
      lastName: updatedUser.last_name,
      phone: updatedUser.phone,
      motorcycleMake: updatedUser.motorcycle_make,
      motorcycleModel: updatedUser.motorcycle_model,
      motorcycleYear: updatedUser.motorcycle_year,
      ridingExperience: updatedUser.riding_experience || 'beginner',
      bio: updatedUser.bio,
      profilePictureUrl: updatedUser.profile_picture_url,
      safetyScore: updatedUser.safety_score || 100,
      totalMiles: parseFloat(updatedUser.total_miles) || 0,
      postsCount: updatedUser.posts_count || 0,
      followersCount: updatedUser.followers_count || 0,
      followingCount: updatedUser.following_count || 0,
      status: updatedUser.status || 'offline',
      locationSharingEnabled: Boolean(updatedUser.location_sharing_enabled),
      isVerified: Boolean(updatedUser.is_verified),
      createdAt: updatedUser.created_at,
      updatedAt: updatedUser.updated_at
    };

    console.log('Profile updated successfully:', userResponse);

    res.json({ 
      message: 'Profile updated successfully',
      user: userResponse
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search users
router.get('/search/:query', authenticateToken, async (req, res) => {
  try {
    const { query: searchQuery } = req.params;
    const { limit = 20, offset = 0 } = req.query;
    
    const users = await query(`
      SELECT id, username, first_name, last_name, profile_picture_url as profile_picture, 
             motorcycle_make, motorcycle_model, safety_score, total_rides
      FROM users 
      WHERE (username LIKE ? OR first_name LIKE ? OR last_name LIKE ?)
      AND id != ?
      ORDER BY safety_score DESC, total_rides DESC
      LIMIT ? OFFSET ?
    `, [
      `%${searchQuery}%`,
      `%${searchQuery}%`,
      `%${searchQuery}%`,
      req.user.id,
      parseInt(limit),
      parseInt(offset)
    ]);

    res.json({ users });
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user's posts
router.get('/:userId/posts', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 20, offset = 0 } = req.query;
    
    const posts = await query(`
      SELECT p.*, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             COUNT(pl.id) as like_count,
             COUNT(pc.id) as comment_count
      FROM posts p
      JOIN users u ON p.user_id = u.id
      LEFT JOIN post_likes pl ON p.id = pl.post_id
      LEFT JOIN post_comments pc ON p.id = pc.post_id
      WHERE p.user_id = ?
      GROUP BY p.id
      ORDER BY p.created_at DESC
      LIMIT ? OFFSET ?
    `, [userId, parseInt(limit), parseInt(offset)]);

    res.json({ posts });
  } catch (error) {
    console.error('Get user posts error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user's followers
router.get('/:userId/followers', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 50, offset = 0 } = req.query;
    
    const followers = await query(`
      SELECT u.id, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             u.motorcycle_make, u.motorcycle_model, u.safety_score
      FROM followers f
      JOIN users u ON f.follower_id = u.id
      WHERE f.followed_id = ?
      ORDER BY f.created_at DESC
      LIMIT ? OFFSET ?
    `, [userId, parseInt(limit), parseInt(offset)]);

    res.json({ followers });
  } catch (error) {
    console.error('Get followers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user's following
router.get('/:userId/following', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 50, offset = 0 } = req.query;
    
    const following = await query(`
      SELECT u.id, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             u.motorcycle_make, u.motorcycle_model, u.safety_score
      FROM followers f
      JOIN users u ON f.followed_id = u.id
      WHERE f.follower_id = ?
      ORDER BY f.created_at DESC
      LIMIT ? OFFSET ?
    `, [userId, parseInt(limit), parseInt(offset)]);

    res.json({ following });
  } catch (error) {
    console.error('Get following error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get leaderboard
router.get('/leaderboard/safety', authenticateToken, async (req, res) => {
  try {
    const { limit = 50, offset = 0 } = req.query;
    
    const leaderboard = await query(`
      SELECT id, username, first_name, last_name, profile_picture_url as profile_picture,
             motorcycle_make, motorcycle_model, safety_score, total_miles, total_rides
      FROM users
      ORDER BY safety_score DESC, total_miles DESC
      LIMIT ? OFFSET ?
    `, [parseInt(limit), parseInt(offset)]);

    res.json({ leaderboard });
  } catch (error) {
    console.error('Get leaderboard error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user statistics
router.get('/:userId/stats', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Get basic user stats
    const user = await get(`
      SELECT safety_score, total_miles, total_rides, created_at
      FROM users WHERE id = ?
    `, [userId]);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Get followers/following count
    const followStats = await query(`
      SELECT 
        (SELECT COUNT(*) FROM followers WHERE followed_id = ?) as follower_count,
        (SELECT COUNT(*) FROM followers WHERE follower_id = ?) as following_count
    `, [userId, userId]);

    // Get posts count
    const postStats = await get(`
      SELECT COUNT(*) as post_count FROM posts WHERE user_id = ?
    `, [userId]);

    // Get recent rides
    const recentRides = await query(`
      SELECT id, distance, duration, average_speed, max_speed, safety_score, created_at
      FROM rides 
      WHERE user_id = ?
      ORDER BY created_at DESC
      LIMIT 10
    `, [userId]);

    res.json({
      stats: {
        safetyScore: user.safety_score,
        totalMiles: user.total_miles,
        totalRides: user.total_rides,
        memberSince: user.created_at,
        followerCount: followStats[0]?.follower_count || 0,
        followingCount: followStats[0]?.following_count || 0,
        postCount: postStats?.post_count || 0,
        recentRides: recentRides || []
      }
    });
  } catch (error) {
    console.error('Get user stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router; 