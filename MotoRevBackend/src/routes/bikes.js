const express = require('express');
const { query, get, run, all } = require('../database/connection');
const { authenticateToken } = require('../middleware/auth');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const router = express.Router();

// Helper function to save base64 image to file
async function saveBase64Image(base64Data, userId, bikeId, type = 'bike') {
  try {
    // Remove data URL prefix if present
    const matches = base64Data.match(/^data:image\/([a-zA-Z]+);base64,(.+)$/);
    let imageData, extension;
    
    if (matches) {
      extension = matches[1] === 'jpeg' ? 'jpg' : matches[1];
      imageData = matches[2];
    } else {
      extension = 'jpg';
      imageData = base64Data;
    }
    
    // Generate unique filename
    const timestamp = Date.now();
    const randomHash = crypto.randomBytes(8).toString('hex');
    const filename = `${type}_${userId}_${bikeId}_${timestamp}_${randomHash}.${extension}`;
    
    // Ensure uploads directory exists
    const uploadsDir = path.join(__dirname, '../../uploads/bikes');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }
    
    // Save file
    const filePath = path.join(uploadsDir, filename);
    const buffer = Buffer.from(imageData, 'base64');
    fs.writeFileSync(filePath, buffer);
    
    return `/uploads/bikes/${filename}`;
    
  } catch (error) {
    console.error('Error saving bike image:', error);
    throw new Error('Failed to save bike image');
  }
}

// Get all bikes for current user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const bikes = await query(`
      SELECT id, user_id, name, year, make, model, color, engine_size, bike_type,
             current_mileage, purchase_date, notes, is_primary, photos, modifications,
             created_at, updated_at
      FROM bikes 
      WHERE user_id = ? 
      ORDER BY is_primary DESC, created_at DESC
    `, [req.user.id]);

    // Parse JSON fields
    const bikesWithParsedData = bikes.map(bike => {
      let photos = [];
      let modifications = [];
      
      try {
        photos = bike.photos && bike.photos !== 'null' ? JSON.parse(bike.photos) : [];
      } catch (error) {
        console.error('Error parsing photos JSON:', error);
        photos = [];
      }
      
      try {
        modifications = bike.modifications && bike.modifications !== 'null' ? JSON.parse(bike.modifications) : [];
      } catch (error) {
        console.error('Error parsing modifications JSON:', error);
        modifications = [];
      }
      
      return {
      ...bike,
        photos: photos,
        modifications: modifications
      };
    });

    res.json({ 
      success: true,
      bikes: bikesWithParsedData 
    });
  } catch (error) {
    console.error('Get bikes error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get single bike by ID
router.get('/:bikeId', authenticateToken, async (req, res) => {
  try {
    const { bikeId } = req.params;
    
    const bike = await get(`
      SELECT id, user_id, name, year, make, model, color, engine_size, bike_type,
             current_mileage, purchase_date, notes, is_primary, photos, modifications,
             created_at, updated_at
      FROM bikes 
      WHERE id = ? AND user_id = ?
    `, [bikeId, req.user.id]);

    if (!bike) {
      return res.status(404).json({ error: 'Bike not found' });
    }

    // Parse JSON fields
    try {
      bike.photos = bike.photos && bike.photos !== 'null' ? JSON.parse(bike.photos) : [];
    } catch (error) {
      console.error('Error parsing photos JSON:', error);
      bike.photos = [];
    }
    
    try {
      bike.modifications = bike.modifications && bike.modifications !== 'null' ? JSON.parse(bike.modifications) : [];
    } catch (error) {
      console.error('Error parsing modifications JSON:', error);
      bike.modifications = [];
    }

    res.json({ 
      success: true,
      bike: bike 
    });
  } catch (error) {
    console.error('Get bike error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new bike
router.post('/', authenticateToken, async (req, res) => {
  try {
    const {
      name,
      year,
      make,
      model,
      color,
      engineSize,
      bikeType,
      currentMileage,
      purchaseDate,
      notes,
      isPrimary,
      photos,
      modifications
    } = req.body;

    console.log('Creating bike:', { name, make, model, year, bikeType });

    // If this is being set as primary, remove primary from other bikes
    if (isPrimary) {
      await run(`
        UPDATE bikes SET is_primary = FALSE WHERE user_id = ?
      `, [req.user.id]);
    }

    // Process photos if provided
    let processedPhotos = [];
    if (photos && Array.isArray(photos)) {
      for (let i = 0; i < photos.length; i++) {
        const photo = photos[i];
        if (photo && photo.length > 100) {
          try {
            const photoUrl = await saveBase64Image(photo, req.user.id, 'temp', 'bike');
            processedPhotos.push(photoUrl);
          } catch (error) {
            console.error('Error processing photo:', error);
          }
        } else if (photo && photo.startsWith('/uploads/')) {
          processedPhotos.push(photo);
        }
      }
    }

    // Insert new bike
    const result = await run(`
      INSERT INTO bikes (
        user_id, name, year, make, model, color, engine_size, bike_type,
        current_mileage, purchase_date, notes, is_primary, photos, modifications
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      req.user.id,
      name,
      year || null,
      make || null,
      model || null,
      color || null,
      engineSize || null,
      bikeType || 'other',
      currentMileage || 0,
      purchaseDate || null,
      notes || null,
      isPrimary || false,
      JSON.stringify(processedPhotos),
      JSON.stringify(modifications || [])
    ]);

    // Get the created bike
    const newBike = await get(`
      SELECT id, user_id, name, year, make, model, color, engine_size, bike_type,
             current_mileage, purchase_date, notes, is_primary, photos, modifications,
             created_at, updated_at
      FROM bikes WHERE id = ?
    `, [result.insertId]);

    // Parse JSON fields
    try {
      newBike.photos = newBike.photos && newBike.photos !== 'null' ? JSON.parse(newBike.photos) : [];
    } catch (error) {
      console.error('Error parsing photos JSON:', error);
      newBike.photos = [];
    }
    
    try {
      newBike.modifications = newBike.modifications && newBike.modifications !== 'null' ? JSON.parse(newBike.modifications) : [];
    } catch (error) {
      console.error('Error parsing modifications JSON:', error);
      newBike.modifications = [];
    }

    res.status(201).json({
      success: true,
      message: 'Bike created successfully',
      bike: newBike
    });

  } catch (error) {
    console.error('Create bike error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update bike
router.put('/:bikeId', authenticateToken, async (req, res) => {
  try {
    const { bikeId } = req.params;
    const {
      name,
      year,
      make,
      model,
      color,
      engineSize,
      bikeType,
      currentMileage,
      purchaseDate,
      notes,
      isPrimary,
      photos,
      modifications
    } = req.body;

    // Verify bike ownership
    const existingBike = await get(`
      SELECT id FROM bikes WHERE id = ? AND user_id = ?
    `, [bikeId, req.user.id]);

    if (!existingBike) {
      return res.status(404).json({ error: 'Bike not found' });
    }

    // If this is being set as primary, remove primary from other bikes
    if (isPrimary) {
      await run(`
        UPDATE bikes SET is_primary = FALSE WHERE user_id = ? AND id != ?
      `, [req.user.id, bikeId]);
    }

    // Process photos if provided
    let processedPhotos = [];
    if (photos && Array.isArray(photos)) {
      for (let i = 0; i < photos.length; i++) {
        const photo = photos[i];
        if (photo && photo.length > 100) {
          try {
            const photoUrl = await saveBase64Image(photo, req.user.id, bikeId, 'bike');
            processedPhotos.push(photoUrl);
          } catch (error) {
            console.error('Error processing photo:', error);
          }
        } else if (photo && photo.startsWith('/uploads/')) {
          processedPhotos.push(photo);
        }
      }
    }

    // Update bike
    await run(`
      UPDATE bikes SET
        name = ?, year = ?, make = ?, model = ?, color = ?, engine_size = ?,
        bike_type = ?, current_mileage = ?, purchase_date = ?, notes = ?,
        is_primary = ?, photos = ?, modifications = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND user_id = ?
    `, [
      name,
      year || null,
      make || null,
      model || null,
      color || null,
      engineSize || null,
      bikeType || 'other',
      currentMileage || 0,
      purchaseDate || null,
      notes || null,
      isPrimary || false,
      JSON.stringify(processedPhotos),
      JSON.stringify(modifications || []),
      bikeId,
      req.user.id
    ]);

    // Get updated bike
    const updatedBike = await get(`
      SELECT id, user_id, name, year, make, model, color, engine_size, bike_type,
             current_mileage, purchase_date, notes, is_primary, photos, modifications,
             created_at, updated_at
      FROM bikes WHERE id = ?
    `, [bikeId]);

    // Parse JSON fields
    try {
      updatedBike.photos = updatedBike.photos && updatedBike.photos !== 'null' ? JSON.parse(updatedBike.photos) : [];
    } catch (error) {
      console.error('Error parsing photos JSON:', error);
      updatedBike.photos = [];
    }
    
    try {
      updatedBike.modifications = updatedBike.modifications && updatedBike.modifications !== 'null' ? JSON.parse(updatedBike.modifications) : [];
    } catch (error) {
      console.error('Error parsing modifications JSON:', error);
      updatedBike.modifications = [];
    }

    res.json({
      success: true,
      message: 'Bike updated successfully',
      bike: updatedBike
    });

  } catch (error) {
    console.error('Update bike error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete bike
router.delete('/:bikeId', authenticateToken, async (req, res) => {
  try {
    const { bikeId } = req.params;

    // Verify bike ownership
    const bike = await get(`
      SELECT id, photos FROM bikes WHERE id = ? AND user_id = ?
    `, [bikeId, req.user.id]);

    if (!bike) {
      return res.status(404).json({ error: 'Bike not found' });
    }

    // Delete associated photos from filesystem
    if (bike.photos) {
      try {
        const photos = JSON.parse(bike.photos);
        photos.forEach(photoUrl => {
          if (photoUrl.startsWith('/uploads/bikes/')) {
            const filePath = path.join(__dirname, '../..', photoUrl);
            if (fs.existsSync(filePath)) {
              fs.unlinkSync(filePath);
            }
          }
        });
      } catch (error) {
        console.error('Error deleting bike photos:', error);
      }
    }

    // Delete bike (cascade will handle maintenance records)
    await run(`
      DELETE FROM bikes WHERE id = ? AND user_id = ?
    `, [bikeId, req.user.id]);

    res.json({
      success: true,
      message: 'Bike deleted successfully'
    });

  } catch (error) {
    console.error('Delete bike error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// MARK: - Maintenance Routes

// Get maintenance records for a bike
router.get('/:bikeId/maintenance', authenticateToken, async (req, res) => {
  try {
    const { bikeId } = req.params;
    
    // Verify bike ownership
    const bike = await get(`
      SELECT id FROM bikes WHERE id = ? AND user_id = ?
    `, [bikeId, req.user.id]);
    
    if (!bike) {
      return res.status(404).json({ error: 'Bike not found' });
    }
    
    const records = await all(`
      SELECT 
        id,
        bike_id as bikeId,
        user_id as userId,
        maintenance_type as maintenanceType,
        title,
        description,
        cost,
        mileage_at_service as mileageAtService,
        service_date as serviceDate,
        next_service_mileage as nextServiceMileage,
        next_service_date as nextServiceDate,
        shop_name as shopName,
        parts_used as partsUsed,
        photos,
        reminder_enabled as reminderEnabled,
        completed,
        created_at as createdAt,
        updated_at as updatedAt
      FROM maintenance_records 
      WHERE bike_id = ? 
      ORDER BY service_date DESC
    `, [bikeId]);
    
    // Parse JSON fields
    const formattedRecords = records.map(record => ({
      ...record,
      partsUsed: record.partsUsed ? JSON.parse(record.partsUsed) : [],
      photos: record.photos ? JSON.parse(record.photos) : []
    }));
    
    res.json({
      success: true,
      records: formattedRecords
    });
    
  } catch (error) {
    console.error('Get maintenance records error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create maintenance record
router.post('/:bikeId/maintenance', authenticateToken, async (req, res) => {
  try {
    const { bikeId } = req.params;
    const {
      maintenanceType,
      title,
      description,
      cost,
      mileageAtService,
      serviceDate,
      nextServiceMileage,
      nextServiceDate,
      shopName,
      partsUsed,
      photos,
      reminderEnabled = true,
      completed = true
    } = req.body;
    
    // Verify bike ownership
    const bike = await get(`
      SELECT id FROM bikes WHERE id = ? AND user_id = ?
    `, [bikeId, req.user.id]);
    
    if (!bike) {
      return res.status(404).json({ error: 'Bike not found' });
    }
    
    // Insert maintenance record
    const result = await run(`
      INSERT INTO maintenance_records (
        bike_id,
        user_id,
        maintenance_type,
        title,
        description,
        cost,
        mileage_at_service,
        service_date,
        next_service_mileage,
        next_service_date,
        shop_name,
        parts_used,
        photos,
        reminder_enabled,
        completed
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      bikeId,
      req.user.id,
      maintenanceType,
      title,
      description,
      cost,
      mileageAtService,
      serviceDate,
      nextServiceMileage,
      nextServiceDate,
      shopName,
      partsUsed ? JSON.stringify(partsUsed) : null,
      photos ? JSON.stringify(photos) : null,
      reminderEnabled,
      completed
    ]);
    
    // Fetch the created record
    const record = await get(`
      SELECT 
        id,
        bike_id as bikeId,
        user_id as userId,
        maintenance_type as maintenanceType,
        title,
        description,
        cost,
        mileage_at_service as mileageAtService,
        service_date as serviceDate,
        next_service_mileage as nextServiceMileage,
        next_service_date as nextServiceDate,
        shop_name as shopName,
        parts_used as partsUsed,
        photos,
        reminder_enabled as reminderEnabled,
        completed,
        created_at as createdAt,
        updated_at as updatedAt
      FROM maintenance_records 
      WHERE id = ?
    `, [result.lastID]);
    
    // Parse JSON fields
    const formattedRecord = {
      ...record,
      partsUsed: record.partsUsed ? JSON.parse(record.partsUsed) : [],
      photos: record.photos ? JSON.parse(record.photos) : []
    };
    
    res.status(201).json({
      success: true,
      record: formattedRecord,
      message: 'Maintenance record created successfully'
    });
    
  } catch (error) {
    console.error('Create maintenance record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update maintenance record
router.put('/:bikeId/maintenance/:recordId', authenticateToken, async (req, res) => {
  try {
    const { bikeId, recordId } = req.params;
    const {
      title,
      description,
      cost,
      mileageAtService,
      serviceDate,
      nextServiceMileage,
      nextServiceDate,
      shopName,
      partsUsed,
      photos,
      reminderEnabled,
      completed
    } = req.body;
    
    // Verify bike ownership and record exists
    const record = await get(`
      SELECT mr.id 
      FROM maintenance_records mr
      JOIN bikes b ON mr.bike_id = b.id
      WHERE mr.id = ? AND mr.bike_id = ? AND b.user_id = ?
    `, [recordId, bikeId, req.user.id]);
    
    if (!record) {
      return res.status(404).json({ error: 'Maintenance record not found' });
    }
    
    // Update maintenance record
    await run(`
      UPDATE maintenance_records SET
        title = ?,
        description = ?,
        cost = ?,
        mileage_at_service = ?,
        service_date = ?,
        next_service_mileage = ?,
        next_service_date = ?,
        shop_name = ?,
        parts_used = ?,
        photos = ?,
        reminder_enabled = ?,
        completed = ?,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `, [
      title,
      description,
      cost,
      mileageAtService,
      serviceDate,
      nextServiceMileage,
      nextServiceDate,
      shopName,
      partsUsed ? JSON.stringify(partsUsed) : null,
      photos ? JSON.stringify(photos) : null,
      reminderEnabled,
      completed,
      recordId
    ]);
    
    // Fetch updated record
    const updatedRecord = await get(`
      SELECT 
        id,
        bike_id as bikeId,
        user_id as userId,
        maintenance_type as maintenanceType,
        title,
        description,
        cost,
        mileage_at_service as mileageAtService,
        service_date as serviceDate,
        next_service_mileage as nextServiceMileage,
        next_service_date as nextServiceDate,
        shop_name as shopName,
        parts_used as partsUsed,
        photos,
        reminder_enabled as reminderEnabled,
        completed,
        created_at as createdAt,
        updated_at as updatedAt
      FROM maintenance_records 
      WHERE id = ?
    `, [recordId]);
    
    // Parse JSON fields
    const formattedRecord = {
      ...updatedRecord,
      partsUsed: updatedRecord.partsUsed ? JSON.parse(updatedRecord.partsUsed) : [],
      photos: updatedRecord.photos ? JSON.parse(updatedRecord.photos) : []
    };
    
    res.json({
      success: true,
      record: formattedRecord,
      message: 'Maintenance record updated successfully'
    });
    
  } catch (error) {
    console.error('Update maintenance record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete maintenance record
router.delete('/:bikeId/maintenance/:recordId', authenticateToken, async (req, res) => {
  try {
    const { bikeId, recordId } = req.params;
    
    // Verify bike ownership and record exists
    const record = await get(`
      SELECT mr.id 
      FROM maintenance_records mr
      JOIN bikes b ON mr.bike_id = b.id
      WHERE mr.id = ? AND mr.bike_id = ? AND b.user_id = ?
    `, [recordId, bikeId, req.user.id]);
    
    if (!record) {
      return res.status(404).json({ error: 'Maintenance record not found' });
    }
    
    // Delete maintenance record
    await run(`
      DELETE FROM maintenance_records WHERE id = ?
    `, [recordId]);
    
    res.json({
      success: true,
      message: 'Maintenance record deleted successfully'
    });
    
  } catch (error) {
    console.error('Delete maintenance record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router; 