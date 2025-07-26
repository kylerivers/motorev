const express = require('express');
const { query } = require('../database/connection');
const { authenticateToken } = require('../middleware/auth');
const router = express.Router();

// Get social feed
router.get('/feed', authenticateToken, async (req, res) => {
  try {
    const { limit = 20, offset = 0 } = req.query;
    
    // Limit the maximum number of posts to prevent large responses
    const maxLimit = 50;
    const safeLimit = Math.min(parseInt(limit) || 20, maxLimit);
    const safeOffset = Math.max(parseInt(offset) || 0, 0);
    
    const posts = await query(`
      SELECT p.id, p.user_id, p.content, p.image_url, p.video_url, p.location_lat, p.location_lng, p.location_name, p.created_at,
             u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             0 as like_count,
             0 as comment_count,
             false as is_liked
      FROM posts p
      JOIN users u ON p.user_id = u.id
      ORDER BY p.created_at DESC
      LIMIT 20
    `);

    // Convert posts to app format
    const formattedPosts = posts.map(post => ({
      id: post.id.toString(),
      userId: post.user_id.toString(),
      username: post.username,
      content: post.content,
      timestamp: post.created_at,
      likesCount: post.like_count || 0,
      commentsCount: post.comment_count || 0,
      isLiked: Boolean(post.is_liked),
      rideData: null // We'll handle ride data later if needed
    }));

    res.json({ 
      success: true,
      posts: formattedPosts,
      message: `Loaded ${formattedPosts.length} posts`
    });
  } catch (error) {
    console.error('Get feed error:', error);
    res.status(500).json({ 
      success: false,
      posts: [],
      error: 'Internal server error' 
    });
  }
});

// Create post
router.post('/posts', authenticateToken, async (req, res) => {
  try {
    const { content, imageUrl, videoUrl, location, rideId } = req.body;

    if (!content && !imageUrl && !videoUrl) {
      return res.status(400).json({ error: 'Post must have content, image, or video' });
    }

    // Parse location if provided as string
    let locationLat = null, locationLng = null, locationName = null;
    if (location) {
      if (typeof location === 'string') {
        const coords = location.split(',');
        if (coords.length === 2) {
          locationLat = parseFloat(coords[0]);
          locationLng = parseFloat(coords[1]);
        }
      } else if (location.latitude && location.longitude) {
        locationLat = location.latitude;
        locationLng = location.longitude;
        locationName = location.name;
      }
    }

    const result = await query(`
      INSERT INTO posts (user_id, content, image_url, video_url, location_lat, location_lng, location_name, ride_id, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    `, [
      req.user.id,
      content || null,
      imageUrl || null,
      videoUrl || null,
      locationLat,
      locationLng,
      locationName || null,
      rideId || null
    ]);

    const postId = result.insertId;

    // Get the created post with user data
    const posts = await query(`
      SELECT p.*, u.username, u.first_name, u.last_name, u.profile_picture_url
      FROM posts p
      JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `, [postId]);
    
    const post = posts[0];

    // Format the post response to match app expectations
    const formattedPost = {
      id: post.id,
      userId: post.user_id,
      username: post.username,
      content: post.content,
      timestamp: post.created_at,
      likesCount: 0,
      commentsCount: 0,
      isLiked: false,
      rideData: null
    };

    res.status(201).json({ 
      success: true,
      post: formattedPost,
      message: 'Post created successfully'
    });
  } catch (error) {
    console.error('Create post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Like/unlike post
router.post('/posts/:postId/like', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;

    // Check if already liked
    const existingLike = await get(
      'SELECT id FROM post_likes WHERE post_id = ? AND user_id = ?',
      [postId, req.user.id]
    );

    if (existingLike) {
      // Unlike
      await run('DELETE FROM post_likes WHERE post_id = ? AND user_id = ?', [postId, req.user.id]);
      res.json({ message: 'Post unliked', liked: false });
    } else {
      // Like
      await run(`
        INSERT INTO post_likes (post_id, user_id, created_at)
        VALUES (?, ?, NOW())
      `, [postId, req.user.id]);
      res.json({ message: 'Post liked', liked: true });
    }
  } catch (error) {
    console.error('Like post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Add comment to post
router.post('/posts/:postId/comments', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const { content } = req.body;

    if (!content || content.trim().length === 0) {
      return res.status(400).json({ error: 'Comment content is required' });
    }

    const result = await run(`
      INSERT INTO post_comments (post_id, user_id, content, created_at)
      VALUES (?, ?, ?, NOW())
    `, [postId, req.user.id, content.trim()]);

    const commentId = result.insertId;

    // Get the created comment with user data
    const comment = await get(`
      SELECT pc.*, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture
      FROM post_comments pc
      JOIN users u ON pc.user_id = u.id
      WHERE pc.id = ?
    `, [commentId]);

    res.status(201).json({ 
      message: 'Comment added successfully',
      comment: comment 
    });
  } catch (error) {
    console.error('Add comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get post comments

// Get comments for a post
router.get('/posts/:postId/comments', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const { limit = 20, offset = 0 } = req.query;

    const comments = await query(`
      SELECT pc.id, pc.content, pc.created_at,
             u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture
      FROM post_comments pc
      JOIN users u ON pc.user_id = u.id
      WHERE pc.post_id = ?
      ORDER BY pc.created_at ASC
      LIMIT ? OFFSET ?
    `, [postId, parseInt(limit), parseInt(offset)]);

    const formattedComments = comments.map(comment => ({
      id: comment.id,
      postId: postId,
      userId: comment.user_id,
      username: comment.username,
      content: comment.content,
      timestamp: comment.created_at,
      likesCount: 0
    }));

    res.json({
      success: true,
      comments: formattedComments,
      message: `Loaded ${formattedComments.length} comments`
    });
  } catch (error) {
    console.error('Get comments error:', error);
    res.status(500).json({ 
      success: false,
      comments: [],
      error: 'Internal server error' 
    });
  }
});

// Add comment to post
router.post('/posts/:postId/comments', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const { content } = req.body;

    if (!content || content.trim().length === 0) {
      return res.status(400).json({ error: 'Comment content is required' });
    }

    // Insert comment
    const result = await run(`
      INSERT INTO post_comments (post_id, user_id, content, created_at)
      VALUES (?, ?, ?, NOW())
    `, [postId, req.user.id, content.trim()]);

    const commentId = result.insertId;

    // Get the created comment with user data
    const comment = await get(`
      SELECT pc.id, pc.content, pc.created_at,
             u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture
      FROM post_comments pc
      JOIN users u ON pc.user_id = u.id
      WHERE pc.id = ?
    `, [commentId]);

    const formattedComment = {
      id: comment.id,
      postId: postId,
      userId: req.user.id,
      username: comment.username,
      content: comment.content,
      timestamp: comment.created_at,
      likesCount: 0
    };

    res.status(201).json({
      success: true,
      comment: formattedComment,
      message: 'Comment added successfully'
    });
  } catch (error) {
    console.error('Add comment error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// Share post
router.post('/posts/:postId/share', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const { caption } = req.body;

    // Get original post
    const originalPost = await get(`
      SELECT p.*, u.username as original_username
      FROM posts p
      JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `, [postId]);

    if (!originalPost) {
      return res.status(404).json({ error: 'Post not found' });
    }

    // Create shared post
    const shareContent = caption ? 
      `${caption}\n\n--- Shared from @${originalPost.original_username} ---\n${originalPost.content}` :
      `--- Shared from @${originalPost.original_username} ---\n${originalPost.content}`;

    const result = await run(`
      INSERT INTO posts (user_id, content, image_url, video_url, location_lat, location_lng, location_name, shared_from_post_id, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    `, [
      req.user.id,
      shareContent,
      originalPost.image_url,
      originalPost.video_url,
      originalPost.location_lat,
      originalPost.location_lng,
      originalPost.location_name,
      postId
    ]);

    const newPostId = result.insertId;

    // Get the created shared post
    const sharedPost = await get(`
      SELECT p.*, u.username, u.first_name, u.last_name, u.profile_picture_url
      FROM posts p
      JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `, [newPostId]);

    const formattedPost = {
      id: sharedPost.id,
      userId: sharedPost.user_id,
      username: sharedPost.username,
      content: sharedPost.content,
      timestamp: sharedPost.created_at,
      likesCount: 0,
      commentsCount: 0,
      isLiked: false,
      rideData: null
    };

    res.status(201).json({
      success: true,
      post: formattedPost,
      message: 'Post shared successfully'
    });
  } catch (error) {
    console.error('Share post error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// Follow/unfollow user
router.post('/follow/:userId', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;

    if (userId === req.user.id.toString()) {
      return res.status(400).json({ error: 'Cannot follow yourself' });
    }

    // Check if already following
    const existingFollow = await get(
      'SELECT id FROM followers WHERE follower_id = ? AND followed_id = ?',
      [req.user.id, userId]
    );

    if (existingFollow) {
      // Unfollow
      await run('DELETE FROM followers WHERE follower_id = ? AND followed_id = ?', [req.user.id, userId]);
      res.json({ message: 'User unfollowed', following: false });
    } else {
      // Follow
      await run(`
        INSERT INTO followers (follower_id, followed_id, created_at)
        VALUES (?, ?, NOW())
      `, [req.user.id, userId]);
      res.json({ message: 'User followed', following: true });
    }
  } catch (error) {
    console.error('Follow user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create story
router.post('/stories', authenticateToken, async (req, res) => {
  try {
    const { content, imageUrl, videoUrl, backgroundColor, location, duration = 24 } = req.body;

    if (!content && !imageUrl && !videoUrl) {
      return res.status(400).json({ error: 'Story must have content, image, or video' });
    }

    // Parse location if provided
    let locationLat = null, locationLng = null, locationName = null;
    if (location) {
      if (typeof location === 'string') {
        const coords = location.split(',');
        if (coords.length === 2) {
          locationLat = parseFloat(coords[0]);
          locationLng = parseFloat(coords[1]);
        }
      } else if (location.latitude && location.longitude) {
        locationLat = location.latitude;
        locationLng = location.longitude;
        locationName = location.name;
      }
    }

    const result = await run(`
      INSERT INTO stories (user_id, content, image_url, video_url, background_color, location_lat, location_lng, location_name, expires_at, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ${duration} HOUR), NOW())
    `, [
      req.user.id,
      content || null,
      imageUrl || null,
      videoUrl || null,
      backgroundColor || null,
      locationLat,
      locationLng,
      locationName || null
    ]);

    const storyId = result.insertId;

    // Get the created story with user data
    const story = await get(`
      SELECT s.*, u.username, u.first_name, u.last_name, u.profile_picture_url
      FROM stories s
      JOIN users u ON s.user_id = u.id
      WHERE s.id = ?
    `, [storyId]);

    res.status(201).json({ 
      message: 'Story created successfully',
      story: story 
    });
  } catch (error) {
    console.error('Create story error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get stories from followed users
router.get('/stories', authenticateToken, async (req, res) => {
  try {
    const stories = await query(`
      SELECT s.*, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             EXISTS(SELECT 1 FROM story_views sv WHERE sv.story_id = s.id AND sv.user_id = ?) as is_viewed
      FROM stories s
      JOIN users u ON s.user_id = u.id
      LEFT JOIN followers f ON s.user_id = f.followed_id AND f.follower_id = ?
      WHERE (s.user_id = ? OR f.follower_id = ?) 
      AND s.expires_at > NOW()
      ORDER BY s.created_at DESC
    `, [req.user.id, req.user.id, req.user.id, req.user.id]);

    res.json({ stories });
  } catch (error) {
    console.error('Get stories error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Mark story as viewed
router.post('/stories/:storyId/view', authenticateToken, async (req, res) => {
  try {
    const { storyId } = req.params;

    // Check if already viewed
    const existingView = await get(
      'SELECT id FROM story_views WHERE story_id = ? AND user_id = ?',
      [storyId, req.user.id]
    );

    if (!existingView) {
      await run(`
        INSERT INTO story_views (story_id, user_id, viewed_at)
        VALUES (?, ?, NOW())
      `, [storyId, req.user.id]);
    }

    res.json({ message: 'Story marked as viewed' });
  } catch (error) {
    console.error('View story error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get story viewers
router.get('/stories/:storyId/viewers', authenticateToken, async (req, res) => {
  try {
    const { storyId } = req.params;

    // Check if user owns the story
    const story = await get('SELECT user_id FROM stories WHERE id = ?', [storyId]);
    if (!story || story.user_id !== req.user.id) {
      return res.status(403).json({ error: 'Can only view viewers of your own stories' });
    }

    const viewers = await query(`
      SELECT u.id, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture, sv.viewed_at
      FROM story_views sv
      JOIN users u ON sv.user_id = u.id
      WHERE sv.story_id = ?
      ORDER BY sv.viewed_at DESC
    `, [storyId]);

    res.json({ viewers });
  } catch (error) {
    console.error('Get story viewers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get notifications
router.get('/notifications', authenticateToken, async (req, res) => {
  try {
    const { limit = 50, offset = 0 } = req.query;

    // Get likes on user's posts
    const likes = await query(`
      SELECT 'like' as type, pl.created_at, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             p.id as post_id, p.content as post_content
      FROM post_likes pl
      JOIN users u ON pl.user_id = u.id
      JOIN posts p ON pl.post_id = p.id
      WHERE p.user_id = ? AND pl.user_id != ?
      ORDER BY pl.created_at DESC
      LIMIT ? OFFSET ?
    `, [req.user.id, req.user.id, parseInt(limit), parseInt(offset)]);

    // Get comments on user's posts
    const comments = await query(`
      SELECT 'comment' as type, pc.created_at, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             p.id as post_id, p.content as post_content, pc.content as comment_content
      FROM post_comments pc
      JOIN users u ON pc.user_id = u.id
      JOIN posts p ON pc.post_id = p.id
      WHERE p.user_id = ? AND pc.user_id != ?
      ORDER BY pc.created_at DESC
      LIMIT ? OFFSET ?
    `, [req.user.id, req.user.id, parseInt(limit), parseInt(offset)]);

    // Get new followers
    const follows = await query(`
      SELECT 'follow' as type, f.created_at, u.username, u.first_name, u.last_name, u.profile_picture_url
      FROM followers f
      JOIN users u ON f.follower_id = u.id
      WHERE f.followed_id = ?
      ORDER BY f.created_at DESC
      LIMIT ? OFFSET ?
    `, [req.user.id, parseInt(limit), parseInt(offset)]);

    // Combine and sort all notifications
    const allNotifications = [...likes, ...comments, ...follows]
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
      .slice(0, parseInt(limit));

    res.json({ notifications: allNotifications });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search posts
router.get('/search/posts', authenticateToken, async (req, res) => {
  try {
    const { query: searchQuery, limit = 20, offset = 0 } = req.query;
    
    if (!searchQuery || searchQuery.trim().length < 2) {
      return res.status(400).json({ error: 'Search query must be at least 2 characters' });
    }

    const posts = await query(`
      SELECT p.id, p.user_id, p.content, p.image_url, p.video_url, p.location_lat, p.location_lng, p.location_name, p.created_at,
             u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             p.likes_count, p.comments_count,
             false as is_liked
      FROM posts p
      JOIN users u ON p.user_id = u.id
      WHERE p.content LIKE ? 
      AND p.visibility = 'public'
      ORDER BY p.created_at DESC
      LIMIT ? OFFSET ?
    `, [`%${searchQuery}%`, parseInt(limit), parseInt(offset)]);

    // Format posts for app
    const formattedPosts = posts.map(post => ({
      id: post.id.toString(),
      userId: post.user_id.toString(),
      username: post.username,
      content: post.content,
      timestamp: post.created_at,
      likesCount: post.likes_count || 0,
      commentsCount: post.comments_count || 0,
      isLiked: Boolean(post.is_liked),
      rideData: null
    }));

    res.json({ 
      success: true,
      posts: formattedPosts,
      query: searchQuery,
      total: formattedPosts.length
    });
  } catch (error) {
    console.error('Search posts error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search stories
router.get('/search/stories', authenticateToken, async (req, res) => {
  try {
    const { query: searchQuery, limit = 20, offset = 0 } = req.query;
    
    if (!searchQuery || searchQuery.trim().length < 2) {
      return res.status(400).json({ error: 'Search query must be at least 2 characters' });
    }

    const stories = await query(`
      SELECT s.*, u.username, u.first_name, u.last_name, u.profile_picture_url as profile_picture,
             EXISTS(SELECT 1 FROM story_views sv WHERE sv.story_id = s.id AND sv.user_id = ?) as is_viewed
      FROM stories s
      JOIN users u ON s.user_id = u.id
      WHERE (s.content LIKE ? OR u.username LIKE ?)
      AND s.expires_at > NOW()
      ORDER BY s.created_at DESC
      LIMIT ? OFFSET ?
    `, [req.user.id, `%${searchQuery}%`, `%${searchQuery}%`, parseInt(limit), parseInt(offset)]);

    res.json({ 
      success: true,
      stories: stories,
      query: searchQuery,
      total: stories.length
    });
  } catch (error) {
    console.error('Search stories error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search users - Query database instead of mock data
router.get('/search/users', authenticateToken, async (req, res) => {
  try {
    const { query: searchQuery, limit = 20, offset = 0 } = req.query;
    
    if (!searchQuery || searchQuery.trim().length < 2) {
      return res.status(400).json({ error: 'Search query must be at least 2 characters' });
    }

    // Search users in database - simplified test
    console.log('Search query:', searchQuery, 'limit:', limit, 'offset:', offset);
    
    const users = await query(`
      SELECT id, username, first_name, last_name 
      FROM users 
      WHERE username LIKE ?
      LIMIT 10
    `, [
      `%${searchQuery}%`
    ]);
    
    console.log('Found users:', users.length);

    // Transform to match iOS SearchUser model
    const searchUsers = users.map(user => ({
      id: user.id,
      username: user.username,
      firstName: user.first_name,
      lastName: user.last_name,
      profilePicture: null, // Will add this back when query is fixed
      motorcycleMake: null, // Will add this back when query is fixed
      motorcycleModel: null, // Will add this back when query is fixed  
      motorcycleYear: null, // Will add this back when query is fixed
      safetyScore: 100,
      totalRides: 0,
      bio: null, // Will add this back when query is fixed
      isVerified: false
    }));

    console.log(`Found ${searchUsers.length} users for search query: "${searchQuery}"`);

    res.json({ 
      success: true,
      users: searchUsers,
      query: searchQuery,
      total: searchUsers.length
    });
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search suggestions for real-time autofill
router.get('/search/suggestions', authenticateToken, async (req, res) => {
  try {
    const { query: searchQuery, limit = 5 } = req.query;
    
    if (!searchQuery || searchQuery.trim().length < 1) {
      return res.json({ 
        success: true,
        suggestions: [],
        query: searchQuery
      });
    }

    // For now, return suggestion if query matches current user
    const suggestions = [];
    
    if ("47industries".startsWith(searchQuery.toLowerCase()) || 
        "kyle".startsWith(searchQuery.toLowerCase()) || 
        "rivers".startsWith(searchQuery.toLowerCase())) {
      suggestions.push({
        id: 6,
        type: 'user',
        username: '47industries',
        displayText: '@47industries',
        subtitle: 'Kyle Rivers',
        profilePicture: null
      });
    }

    res.json({ 
      success: true,
      suggestions: suggestions,
      query: searchQuery
    });
  } catch (error) {
    console.error('Search suggestions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Search packs
router.get('/search/packs', authenticateToken, async (req, res) => {
  try {
    const { query: searchQuery, limit = 20, offset = 0 } = req.query;
    
    if (!searchQuery || searchQuery.trim().length < 2) {
      return res.status(400).json({ error: 'Search query must be at least 2 characters' });
    }

    const packs = await query(`
      SELECT rp.*, u.username as leader_username, u.first_name as leader_first_name, u.last_name as leader_last_name,
             COUNT(pm.id) as member_count
      FROM riding_packs rp
      JOIN users u ON rp.created_by = u.id
      LEFT JOIN pack_members pm ON rp.id = pm.pack_id AND pm.status = 'active'
      WHERE (rp.name LIKE ? OR rp.description LIKE ?)
      AND rp.privacy_level IN ('public', 'invite_only')
      GROUP BY rp.id
      ORDER BY rp.created_at DESC
      LIMIT ? OFFSET ?
    `, [`%${searchQuery}%`, `%${searchQuery}%`, parseInt(limit), parseInt(offset)]);

    res.json({ 
      success: true,
      packs: packs,
      query: searchQuery,
      total: packs.length
    });
  } catch (error) {
    console.error('Search packs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// General search endpoint (searches across all content types)
router.get('/search', authenticateToken, async (req, res) => {
  try {
    const { query: searchQuery, limit = 10 } = req.query;
    
    if (!searchQuery || searchQuery.trim().length < 2) {
      return res.status(400).json({ error: 'Search query must be at least 2 characters' });
    }

    // Search users
    const users = await query(`
      SELECT id, username, first_name, last_name, profile_picture_url as profile_picture, 
             motorcycle_make, motorcycle_model, safety_score, is_verified, 'user' as content_type
      FROM users 
      WHERE (username LIKE ? OR first_name LIKE ? OR last_name LIKE ?)
      AND id != ?
      ORDER BY is_verified DESC, safety_score DESC
      LIMIT ?
    `, [`%${searchQuery}%`, `%${searchQuery}%`, `%${searchQuery}%`, req.user.id, parseInt(limit)]);

    // Search posts
    const posts = await query(`
      SELECT p.id, p.content, p.created_at, u.username, u.profile_picture_url as profile_picture, 'post' as content_type
      FROM posts p
      JOIN users u ON p.user_id = u.id
      WHERE p.content LIKE ? 
      AND p.visibility = 'public'
      ORDER BY p.created_at DESC
      LIMIT ?
    `, [`%${searchQuery}%`, parseInt(limit)]);

    // Search packs
    const packs = await query(`
      SELECT rp.id, rp.name, rp.description, rp.created_at, u.username as leader_username, 'pack' as content_type
      FROM riding_packs rp
      JOIN users u ON rp.created_by = u.id
      WHERE (rp.name LIKE ? OR rp.description LIKE ?)
      AND rp.privacy_level IN ('public', 'invite_only')
      ORDER BY rp.created_at DESC
      LIMIT ?
    `, [`%${searchQuery}%`, `%${searchQuery}%`, parseInt(limit)]);

    res.json({ 
      success: true,
      results: {
        users: users,
        posts: posts,
        packs: packs
      },
      query: searchQuery,
      total: users.length + posts.length + packs.length
    });
  } catch (error) {
    console.error('General search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router; 