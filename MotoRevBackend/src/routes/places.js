const express = require('express');
const router = express.Router();
const { query } = require('../database/connection');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

// Get all approved places (public endpoint with optional user context)
router.get('/', async (req, res) => {
    try {
        const { category, lat, lng, radius = 50, search, featured, limit = 100 } = req.query;
        const userId = req.user?.id; // Optional user context for favorites
        
        let sql = `
            SELECT 
                p.*,
                u.username as submitted_by_username,
                false as is_favorited,
                (6371 * acos(cos(radians(?)) * cos(radians(p.latitude)) * 
                cos(radians(p.longitude) - radians(?)) + sin(radians(?)) * 
                sin(radians(p.latitude)))) AS distance_km
            FROM places p
            JOIN users u ON p.submitted_by = u.id
            WHERE p.status = 'approved'
        `;
        
        const params = [];
        
        // Add distance calculation parameters if location provided
        if (lat && lng) {
            params.push(parseFloat(lat), parseFloat(lng), parseFloat(lat));
        } else {
            // Dummy values for distance calculation when no location provided
            params.push(0, 0, 0);
        }
        
        // Add filters
        if (category) {
            sql += ' AND p.category = ?';
            params.push(category);
        }
        
        if (featured === 'true') {
            sql += ' AND p.featured = true';
        }
        
        if (search) {
            sql += ' AND (p.name LIKE ? OR p.description LIKE ? OR JSON_SEARCH(p.tags, "all", ?) IS NOT NULL)';
            const searchTerm = `%${search}%`;
            params.push(searchTerm, searchTerm, `%${search}%`);
        }
        
        // Add distance filter if location provided
        if (lat && lng && radius) {
            sql += ' HAVING distance_km <= ?';
            params.push(parseFloat(radius));
        }
        
        sql += ' ORDER BY p.featured DESC, p.rating DESC, distance_km ASC';
        sql += ' LIMIT ?';
        params.push(parseInt(limit));
        
        const places = await query(sql, params);
        
        // Parse JSON fields
        const formattedPlaces = places.map(place => ({
            ...place,
            amenities: place.amenities ? JSON.parse(place.amenities) : [],
            images: place.images ? JSON.parse(place.images) : [],
            tags: place.tags ? JSON.parse(place.tags) : [],
            is_favorited: place.is_favorited || false
        }));
        
        res.json({
            success: true,
            places: formattedPlaces,
            total: formattedPlaces.length
        });
        
    } catch (error) {
        console.error('Error fetching places:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get place by ID with reviews
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user?.id;
        
        // Get place details
        const placeQuery = `
            SELECT 
                p.*,
                u.username as submitted_by_username,
                ${userId ? 'CASE WHEN pf.id IS NOT NULL THEN true ELSE false END as is_favorited,' : ''}
                ap.username as approved_by_username
            FROM places p
            JOIN users u ON p.submitted_by = u.id
            LEFT JOIN users ap ON p.approved_by = ap.id
            ${userId ? 'LEFT JOIN place_favorites pf ON p.id = pf.place_id AND pf.user_id = ?' : ''}
            WHERE p.id = ? AND p.status = 'approved'
        `;
        
        const placeParams = userId ? [userId, id] : [id];
        const placeResult = await query(placeQuery, placeParams);
        
        if (placeResult.length === 0) {
            return res.status(404).json({ error: 'Place not found' });
        }
        
        // Get reviews
        const reviewsQuery = `
            SELECT 
                pr.*,
                u.username,
                u.first_name,
                u.last_name
            FROM place_reviews pr
            JOIN users u ON pr.user_id = u.id
            WHERE pr.place_id = ?
            ORDER BY pr.created_at DESC
        `;
        
        const reviews = await query(reviewsQuery, [id]);
        
        // Format place data
        const place = {
            ...placeResult[0],
            amenities: placeResult[0].amenities ? JSON.parse(placeResult[0].amenities) : [],
            images: placeResult[0].images ? JSON.parse(placeResult[0].images) : [],
            tags: placeResult[0].tags ? JSON.parse(placeResult[0].tags) : [],
            is_favorited: placeResult[0].is_favorited || false,
            reviews: reviews.map(review => ({
                ...review,
                images: review.images ? JSON.parse(review.images) : []
            }))
        };
        
        res.json({
            success: true,
            place: place
        });
        
    } catch (error) {
        console.error('Error fetching place details:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Submit a new place (requires authentication)
router.post('/', authenticateToken, async (req, res) => {
    try {
        const {
            name,
            description,
            category,
            latitude,
            longitude,
            address,
            phone,
            website,
            hours_of_operation,
            amenities = [],
            images = [],
            tags = [],
            submission_notes
        } = req.body;
        
        const userId = req.user.id;
        
        // Validate required fields
        if (!name || !category || !latitude || !longitude) {
            return res.status(400).json({ 
                error: 'Missing required fields: name, category, latitude, longitude' 
            });
        }
        
        // Validate category
        const validCategories = ['restaurant', 'gas_station', 'scenic_viewpoint', 'motorcycle_shop', 'lodging', 'parking', 'other'];
        if (!validCategories.includes(category)) {
            return res.status(400).json({ error: 'Invalid category' });
        }
        
        // Insert place
        const insertQuery = `
            INSERT INTO places (
                submitted_by, name, description, category, latitude, longitude,
                address, phone, website, hours_of_operation, amenities, images,
                tags, submission_notes, rating, review_count, status, featured
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;
        
        const result = await query(insertQuery, [
            userId, name, description, category, latitude, longitude,
            address, phone, website, hours_of_operation,
            Array.isArray(amenities) ? amenities.join(',') : (amenities || ''),
            Array.isArray(images) ? images.join(',') : (images || ''),
            Array.isArray(tags) ? tags.join(',') : (tags || ''), 
            submission_notes,
            0.0, // rating default
            0,   // review_count default  
            'pending', // status default
            false // featured default
        ]);
        
        res.status(201).json({
            success: true,
            message: 'Place submitted successfully and is pending approval',
            place_id: result.insertId
        });
        
    } catch (error) {
        console.error('Error submitting place:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Add/remove place from favorites (requires authentication)
router.post('/:id/favorite', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;
        
        // Check if place exists and is approved
        const placeExists = await query(
            'SELECT id FROM places WHERE id = ? AND status = "approved"',
            [id]
        );
        
        if (placeExists.length === 0) {
            return res.status(404).json({ error: 'Place not found' });
        }
        
        // Check if already favorited
        const existingFavorite = await query(
            'SELECT id FROM place_favorites WHERE user_id = ? AND place_id = ?',
            [userId, id]
        );
        
        if (existingFavorite.length > 0) {
            // Remove from favorites
            await query(
                'DELETE FROM place_favorites WHERE user_id = ? AND place_id = ?',
                [userId, id]
            );
            
            res.json({
                success: true,
                message: 'Place removed from favorites',
                is_favorited: false
            });
        } else {
            // Add to favorites
            await query(
                'INSERT INTO place_favorites (user_id, place_id) VALUES (?, ?)',
                [userId, id]
            );
            
            res.json({
                success: true,
                message: 'Place added to favorites',
                is_favorited: true
            });
        }
        
    } catch (error) {
        console.error('Error toggling place favorite:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Submit a review for a place (requires authentication)
router.post('/:id/review', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const { rating, review_text, images = [] } = req.body;
        const userId = req.user.id;
        
        // Validate rating
        if (!rating || rating < 1 || rating > 5) {
            return res.status(400).json({ error: 'Rating must be between 1 and 5' });
        }
        
        // Check if place exists and is approved
        const placeExists = await query(
            'SELECT id FROM places WHERE id = ? AND status = "approved"',
            [id]
        );
        
        if (placeExists.length === 0) {
            return res.status(404).json({ error: 'Place not found' });
        }
        
        // Check if user already reviewed this place
        const existingReview = await query(
            'SELECT id FROM place_reviews WHERE user_id = ? AND place_id = ?',
            [userId, id]
        );
        
        if (existingReview.length > 0) {
            // Update existing review
            await query(
                'UPDATE place_reviews SET rating = ?, review_text = ?, images = ?, updated_at = NOW() WHERE user_id = ? AND place_id = ?',
                [rating, review_text, JSON.stringify(images), userId, id]
            );
        } else {
            // Insert new review
            await query(
                'INSERT INTO place_reviews (place_id, user_id, rating, review_text, images) VALUES (?, ?, ?, ?, ?)',
                [id, userId, rating, review_text, JSON.stringify(images)]
            );
        }
        
        // Update place rating and review count
        const ratingStats = await query(
            'SELECT AVG(rating) as avg_rating, COUNT(*) as review_count FROM place_reviews WHERE place_id = ?',
            [id]
        );
        
        await query(
            'UPDATE places SET rating = ?, review_count = ? WHERE id = ?',
            [ratingStats[0].avg_rating, ratingStats[0].review_count, id]
        );
        
        res.json({
            success: true,
            message: existingReview.length > 0 ? 'Review updated successfully' : 'Review submitted successfully'
        });
        
    } catch (error) {
        console.error('Error submitting place review:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Check in to a place (requires authentication)
router.post('/:id/checkin', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const { latitude, longitude, notes, photos = [] } = req.body;
        const userId = req.user.id;
        
        // Check if place exists and is approved
        const placeExists = await query(
            'SELECT id FROM places WHERE id = ? AND status = "approved"',
            [id]
        );
        
        if (placeExists.length === 0) {
            return res.status(404).json({ error: 'Place not found' });
        }
        
        // Insert check-in
        await query(
            'INSERT INTO place_checkins (place_id, user_id, latitude, longitude, notes, photos) VALUES (?, ?, ?, ?, ?, ?)',
            [id, userId, latitude, longitude, notes, JSON.stringify(photos)]
        );
        
        res.json({
            success: true,
            message: 'Check-in recorded successfully'
        });
        
    } catch (error) {
        console.error('Error recording place check-in:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get user's submitted places (requires authentication)
router.get('/user/submissions', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        const userPlaces = await query(`
            SELECT 
                p.*,
                CASE WHEN pf.id IS NOT NULL THEN true ELSE false END as is_favorited
            FROM places p
            LEFT JOIN place_favorites pf ON p.id = pf.place_id AND pf.user_id = ?
            WHERE p.submitted_by = ?
            ORDER BY p.created_at DESC
        `, [userId, userId]);
        
        // Format places
        const formattedPlaces = userPlaces.map(place => ({
            ...place,
            amenities: place.amenities ? JSON.parse(place.amenities) : [],
            images: place.images ? JSON.parse(place.images) : [],
            tags: place.tags ? JSON.parse(place.tags) : []
        }));
        
        res.json({
            success: true,
            places: formattedPlaces
        });
        
    } catch (error) {
        console.error('Error fetching user submissions:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get user's favorite places (requires authentication)
router.get('/user/favorites', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        
        const favoritePlaces = await query(`
            SELECT 
                p.*,
                u.username as submitted_by_username,
                pf.created_at as favorited_at
            FROM place_favorites pf
            JOIN places p ON pf.place_id = p.id
            JOIN users u ON p.submitted_by = u.id
            WHERE pf.user_id = ? AND p.status = 'approved'
            ORDER BY pf.created_at DESC
        `, [userId]);
        
        // Format places
        const formattedPlaces = favoritePlaces.map(place => ({
            ...place,
            amenities: place.amenities ? JSON.parse(place.amenities) : [],
            images: place.images ? JSON.parse(place.images) : [],
            tags: place.tags ? JSON.parse(place.tags) : [],
            is_favorited: true
        }));
        
        res.json({
            success: true,
            places: formattedPlaces
        });
        
    } catch (error) {
        console.error('Error fetching user favorites:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Admin routes for place management
router.get('/admin/pending', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const pendingPlaces = await query(`
            SELECT 
                p.*,
                u.username as submitted_by_username,
                u.first_name,
                u.last_name
            FROM places p
            JOIN users u ON p.submitted_by = u.id
            WHERE p.status = 'pending'
            ORDER BY p.created_at ASC
        `);
        
        // Format places
        const formattedPlaces = pendingPlaces.map(place => ({
            ...place,
            amenities: place.amenities ? JSON.parse(place.amenities) : [],
            images: place.images ? JSON.parse(place.images) : [],
            tags: place.tags ? JSON.parse(place.tags) : []
        }));
        
        res.json({
            success: true,
            places: formattedPlaces
        });
        
    } catch (error) {
        console.error('Error fetching pending places:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Admin approve/reject place
router.patch('/admin/:id/status', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { status, approval_notes } = req.body;
        const adminId = req.user.id;
        
        // Validate status
        if (!['approved', 'rejected'].includes(status)) {
            return res.status(400).json({ error: 'Status must be "approved" or "rejected"' });
        }
        
        // Check if place exists
        const placeExists = await query('SELECT id FROM places WHERE id = ?', [id]);
        if (placeExists.length === 0) {
            return res.status(404).json({ error: 'Place not found' });
        }
        
        // Update place status
        await query(
            'UPDATE places SET status = ?, approval_notes = ?, approved_by = ?, approved_at = NOW() WHERE id = ?',
            [status, approval_notes, adminId, id]
        );
        
        res.json({
            success: true,
            message: `Place ${status} successfully`
        });
        
    } catch (error) {
        console.error('Error updating place status:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Admin toggle featured status
router.patch('/admin/:id/featured', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { featured } = req.body;
        
        // Check if place exists and is approved
        const place = await query('SELECT id, featured FROM places WHERE id = ? AND status = "approved"', [id]);
        if (place.length === 0) {
            return res.status(404).json({ error: 'Approved place not found' });
        }
        
        // Update featured status
        await query('UPDATE places SET featured = ? WHERE id = ?', [!!featured, id]);
        
        res.json({
            success: true,
            message: `Place ${featured ? 'marked as featured' : 'removed from featured'}`
        });
        
    } catch (error) {
        console.error('Error updating place featured status:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
