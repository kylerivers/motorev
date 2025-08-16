require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');

// Import database setup
const { setupDatabase } = require('./src/database/setupDatabase');
const { closePool } = require('./src/database/connection');

// Import routes
const authRoutes = require('./src/routes/auth');
const userRoutes = require('./src/routes/users');
const bikesRoutes = require('./src/routes/bikes');
const socialRoutes = require('./src/routes/social');
const rideRoutes = require('./src/routes/rides');
const safetyRoutes = require('./src/routes/safety');
const locationRoutes = require('./src/routes/location');
const adminRoutes = require('./src/routes/admin');
const analyticsRoutes = require('./src/routes/analytics');
const placesRoutes = require('./src/routes/places');

// Import WebSocket service
const { setupSocketHandlers } = require('./src/services/socketService');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.CORS_ORIGIN || "*",
    methods: ["GET", "POST", "PUT", "DELETE"],
    credentials: true
  }
});

const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      scriptSrcAttr: ["'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  crossOriginEmbedderPolicy: false
}));

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Compression and parsing middleware
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    service: 'MotoRev API',
    version: '2.2.1',
    database: 'MySQL'
  });
});

// Test endpoint to verify deployment
app.get('/test-deploy', (req, res) => {
  res.json({ 
    message: 'New deployment successful',
    timestamp: new Date().toISOString(),
    routes: {
      events: '/api/events',
      rides: '/api/rides/completed'
    }
  });
});




// Root OK endpoint (some platforms probe '/')
app.get('/', (req, res) => {
  res.status(200).json({ status: 'OK' });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/bikes', bikesRoutes);
app.use('/api/social', socialRoutes);
app.use('/api/rides', rideRoutes);
app.use('/api/group-rides', require('./src/routes/group-rides'));
app.use('/api/safety', safetyRoutes);
app.use('/api/location', locationRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/fuel', require('./src/routes/fuel'));
app.use('/api/recordings', require('./src/routes/recordings'));
app.use('/api/events', require('./src/routes/events'));
app.use('/api/music', require('./src/routes/music'));
app.use('/api/voice', require('./src/routes/voice'));
app.use('/api/places', placesRoutes);

// Serve static files for uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Serve profile pictures with proper headers
app.use('/uploads/profile-pictures', express.static(path.join(__dirname, 'uploads/profile-pictures'), {
  maxAge: '1d', // Cache for 1 day
  setHeaders: (res, path) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, max-age=86400'); // 24 hours
  }
}));

// Serve analytics dashboard
app.get('/analytics', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'analytics.html'));
});

// Database admin interface (beautiful modern CRUD interface)
app.get('/', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html>
<head>
    <title>MotoRev Database Admin</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        
        body { 
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #2d3748;
            min-height: 100vh;
            overflow-x: hidden;
        }

        /* Animated Background */
        body::before {
            content: '';
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: 
                radial-gradient(circle at 20% 80%, rgba(120, 119, 198, 0.3) 0%, transparent 50%),
                radial-gradient(circle at 80% 20%, rgba(255, 119, 198, 0.3) 0%, transparent 50%),
                radial-gradient(circle at 40% 40%, rgba(120, 219, 255, 0.3) 0%, transparent 50%);
            z-index: -1;
            animation: backgroundShift 20s ease-in-out infinite;
        }

        @keyframes backgroundShift {
            0%, 100% { transform: translateX(0) translateY(0); }
            25% { transform: translateX(-20px) translateY(-10px); }
            50% { transform: translateX(20px) translateY(10px); }
            75% { transform: translateX(-10px) translateY(20px); }
        }

        .header { 
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(20px);
            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
            color: white; 
            padding: 30px 0; 
            position: sticky;
            top: 0;
            z-index: 100;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            padding: 0 30px; 
        }
        
        .header h1 { 
            margin: 0; 
            font-size: 3em; 
            font-weight: 800;
            display: flex; 
            align-items: center; 
            gap: 20px;
            background: linear-gradient(45deg, #fff, #f7fafc);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            animation: titleGlow 3s ease-in-out infinite alternate;
        }

        @keyframes titleGlow {
            from { filter: drop-shadow(0 0 20px rgba(255, 255, 255, 0.5)); }
            to { filter: drop-shadow(0 0 30px rgba(255, 255, 255, 0.8)); }
        }
        
        .header .subtitle { 
            margin-top: 10px; 
            opacity: 0.9; 
            font-size: 1.2em;
            font-weight: 300;
        }
        
        .stats-bar { 
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(10px);
            padding: 25px 0; 
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .stats-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
        }
        
        .stat-card { 
            background: linear-gradient(135deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.05));
            backdrop-filter: blur(15px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            color: white; 
            padding: 25px; 
            border-radius: 16px; 
            text-align: center;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
        }

        .stat-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.1), transparent);
            transition: left 0.5s;
        }

        .stat-card:hover::before {
            left: 100%;
        }
        
        .stat-card:hover { 
            transform: translateY(-8px) scale(1.02); 
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
            border-color: rgba(255, 255, 255, 0.3);
        }
        
        .stat-card h3 { 
            font-size: 2.5em; 
            margin-bottom: 8px; 
            font-weight: 700;
            background: linear-gradient(45deg, #fff, #e2e8f0);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .stat-card p { 
            opacity: 0.9; 
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 1px;
            font-size: 0.9em;
        }
        
        .main-content { 
            padding: 40px 0; 
        }
        
        .glass-panel {
            background: rgba(255, 255, 255, 0.9);
            backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.3);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
        }
        
        .table-selector select { 
            padding: 16px 24px; 
            font-size: 16px; 
            border: 2px solid #e2e8f0; 
            border-radius: 12px; 
            background: white; 
            min-width: 300px;
            transition: all 0.3s ease;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
        }

        .table-selector select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        .table-controls { 
            display: flex; 
            gap: 15px; 
            margin-bottom: 25px; 
            flex-wrap: wrap; 
            align-items: center; 
        }
        
        .btn { 
            padding: 12px 24px; 
            border: none; 
            border-radius: 10px; 
            cursor: pointer; 
            font-size: 14px; 
            font-weight: 600; 
            text-decoration: none; 
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
        }

        .btn::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
            transition: left 0.5s;
        }

        .btn:hover::before {
            left: 100%;
        }
        
        .btn-primary { 
            background: linear-gradient(135deg, #667eea, #764ba2); 
            color: white;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
        }
        
        .btn-success { 
            background: linear-gradient(135deg, #48bb78, #38a169); 
            color: white;
            box-shadow: 0 4px 15px rgba(72, 187, 120, 0.3);
        }
        
        .btn-danger { 
            background: linear-gradient(135deg, #f56565, #e53e3e); 
            color: white;
            box-shadow: 0 4px 15px rgba(245, 101, 101, 0.3);
        }
        
        .btn-warning { 
            background: linear-gradient(135deg, #ed8936, #dd6b20); 
            color: white;
            box-shadow: 0 4px 15px rgba(237, 137, 54, 0.3);
        }
        
        .btn-secondary { 
            background: linear-gradient(135deg, #a0aec0, #718096); 
            color: white;
            box-shadow: 0 4px 15px rgba(160, 174, 192, 0.3);
        }
        
        .btn:hover { 
            transform: translateY(-3px); 
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.2);
        }

        .btn:active {
            transform: translateY(-1px);
        }
        
        .table-container { 
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(20px);
            border-radius: 20px; 
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1); 
            overflow: hidden;
            border: 1px solid rgba(255, 255, 255, 0.3);
        }
        
        .table-header { 
            background: linear-gradient(135deg, #f7fafc, #edf2f7);
            padding: 25px; 
            border-bottom: 2px solid #e2e8f0; 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
        }

        .table-header h3 {
            color: #2d3748;
            font-size: 1.5em;
            font-weight: 700;
        }
        
        .table-wrapper { 
            overflow-x: auto; 
            max-height: 70vh;
        }
        
        table { 
            width: 100%; 
            border-collapse: collapse; 
        }
        
        th, td { 
            padding: 16px 20px; 
            text-align: left; 
            border-bottom: 1px solid #e2e8f0; 
        }
        
        th { 
            background: linear-gradient(135deg, #f7fafc, #edf2f7);
            font-weight: 700; 
            color: #2d3748; 
            white-space: nowrap;
            position: sticky;
            top: 0;
            z-index: 10;
        }
        
        tr:hover { 
            background: linear-gradient(135deg, #f7fafc, #edf2f7);
            transform: scale(1.001);
            transition: all 0.2s ease;
        }
        
        .record-actions { 
            display: flex; 
            gap: 8px; 
            justify-content: center;
        }
        
        .record-actions button { 
            padding: 8px 16px; 
            font-size: 12px;
            border-radius: 8px;
        }
        
        .modal { 
            display: none; 
            position: fixed; 
            top: 0; 
            left: 0; 
            right: 0; 
            bottom: 0; 
            background: rgba(0, 0, 0, 0.6);
            backdrop-filter: blur(5px);
            z-index: 1000;
            animation: fadeIn 0.3s ease;
        }

        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }

        @keyframes slideIn {
            from { transform: translate(-50%, -60%) scale(0.9); opacity: 0; }
            to { transform: translate(-50%, -50%) scale(1); opacity: 1; }
        }
        
        .modal-content { 
            position: absolute; 
            top: 50%; 
            left: 50%; 
            transform: translate(-50%, -50%); 
            background: white; 
            border-radius: 20px; 
            padding: 40px; 
            max-width: 600px; 
            width: 90%; 
            max-height: 80vh; 
            overflow-y: auto;
            box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
            animation: slideIn 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }
        
        .modal-header { 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 2px solid #e2e8f0;
        }
        
        .modal-header h3 { 
            margin: 0; 
            color: #2d3748;
            font-size: 1.5em;
            font-weight: 700;
        }
        
        .close { 
            background: none; 
            border: none; 
            font-size: 28px; 
            cursor: pointer; 
            color: #a0aec0;
            transition: all 0.3s ease;
            width: 40px;
            height: 40px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .close:hover {
            background: #f7fafc;
            color: #2d3748;
            transform: scale(1.1);
        }
        
        .form-group { 
            margin-bottom: 25px; 
        }
        
        .form-group label { 
            display: block; 
            margin-bottom: 8px; 
            font-weight: 600; 
            color: #2d3748;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .form-group input, .form-group textarea, .form-group select { 
            width: 100%; 
            padding: 14px 18px; 
            border: 2px solid #e2e8f0; 
            border-radius: 10px; 
            font-size: 16px;
            transition: all 0.3s ease;
            background: #f7fafc;
        }
        
        .form-group input:focus, .form-group textarea:focus, .form-group select:focus { 
            outline: none; 
            border-color: #667eea;
            background: white;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
            transform: translateY(-2px);
        }
        
        .form-actions { 
            display: flex; 
            gap: 15px; 
            justify-content: flex-end; 
            margin-top: 30px;
            padding-top: 20px;
            border-top: 2px solid #e2e8f0;
        }
        
        .search-box { 
            padding: 12px 18px; 
            border: 2px solid #e2e8f0; 
            border-radius: 10px; 
            width: 300px;
            transition: all 0.3s ease;
            background: white;
        }

        .search-box:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        #recordCount { 
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 10px 20px; 
            border-radius: 20px; 
            font-weight: 600;
            font-size: 14px;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
        }
        
        .loading { 
            text-align: center; 
            padding: 60px; 
            color: #667eea;
            font-size: 1.2em;
            font-weight: 600;
        }

        .loading::after {
            content: '';
            display: inline-block;
            width: 40px;
            height: 40px;
            margin-left: 20px;
            border: 4px solid #e2e8f0;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .error { 
            background: linear-gradient(135deg, #fed7d7, #feb2b2);
            color: #c53030; 
            padding: 20px; 
            border-radius: 12px; 
            margin-bottom: 20px;
            border-left: 4px solid #e53e3e;
            box-shadow: 0 4px 15px rgba(229, 62, 62, 0.2);
        }
        
        .success { 
            background: linear-gradient(135deg, #c6f6d5, #9ae6b4);
            color: #22543d; 
            padding: 20px; 
            border-radius: 12px; 
            margin-bottom: 20px;
            border-left: 4px solid #38a169;
            box-shadow: 0 4px 15px rgba(56, 161, 105, 0.2);
        }

        /* Status indicators for user data */
        .status-online { color: #38a169; font-weight: 600; }
        .status-riding { color: #ed8936; font-weight: 600; }
        .status-offline { color: #a0aec0; font-weight: 600; }

        /* Responsive design */
        @media (max-width: 768px) {
            .container { padding: 0 20px; }
            .header h1 { font-size: 2.2em; }
            .table-controls { flex-direction: column; align-items: stretch; }
            .search-box { width: 100%; }
            .stats-grid { grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); }
        }

        /* Custom scrollbar */
        ::-webkit-scrollbar { width: 8px; }
        ::-webkit-scrollbar-track { background: #f1f1f1; border-radius: 4px; }
        ::-webkit-scrollbar-thumb { background: linear-gradient(135deg, #667eea, #764ba2); border-radius: 4px; }
        ::-webkit-scrollbar-thumb:hover { background: linear-gradient(135deg, #5a6fd8, #6b46a3); }
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <h1><i class="fas fa-motorcycle"></i> MotoRev Database Admin</h1>
            <div class="subtitle">Professional database management with complete CRUD operations</div>
        </div>
    </div>

    <div class="stats-bar">
        <div class="container">
            <div class="stats-grid" id="statsGrid">
                <!-- Stats will be loaded here -->
            </div>
        </div>
    </div>

    <div class="main-content">
        <div class="container">
            <!-- Table Selector -->
            <div class="glass-panel">
                <div class="table-selector">
                    <select id="tableSelect" onchange="loadTable()">
                        <option value="">🎯 Select a table to manage...</option>
                        <option value="users">👥 Users - Rider Profiles</option>
                        <option value="posts">📱 Posts - Social Content</option>
                        <option value="stories">🚩 Stories - Temporary Content</option>
                        <option value="rides">🏍️ Rides - Journey Data</option>
                        <option value="emergency_events">🚨 Emergency Events</option>
                        <option value="hazard_reports">⚠️ Hazard Reports</option>
                        <option value="followers">👫 Followers - Social Network</option>
                        <option value="post_likes">❤️ Post Likes</option>
                        <option value="post_comments">💬 Post Comments</option>
                        <option value="location_updates">📍 Location Updates</option>
                        <option value="riding_packs">🏁 Riding Packs</option>
                        <option value="pack_members">👥 Pack Members</option>
                    </select>
                </div>
            </div>

            <!-- Table Controls -->
            <div class="glass-panel" id="tableControls" style="display: none;">
                <div class="table-controls">
                    <button class="btn btn-success" onclick="showCreateModal()">
                        <i class="fas fa-plus"></i> Add New Record
                    </button>
                    <button class="btn btn-primary" onclick="loadTable()">
                        <i class="fas fa-sync-alt"></i> Refresh
                    </button>
                    <button class="btn btn-warning" onclick="exportTable()">
                        <i class="fas fa-download"></i> Export CSV
                    </button>
                    <button class="btn btn-danger" onclick="clearTable()">
                        <i class="fas fa-trash-alt"></i> Clear Table
                    </button>
                    <input type="text" class="search-box" id="searchBox" placeholder="🔍 Search records..." onkeyup="searchRecords()">
                    <div id="recordCount">0 records</div>
                </div>
            </div>

            <!-- Alert Messages -->
            <div id="alertContainer"></div>

            <!-- Table Container -->
            <div class="table-container" id="tableContainer" style="display: none;">
                <div class="table-header">
                    <h3 id="tableTitle">📊 Table Data</h3>
                </div>
                <div class="table-wrapper">
                    <table id="dataTable">
                        <thead id="tableHead"></thead>
                        <tbody id="tableBody"></tbody>
                    </table>
                </div>
            </div>

            <!-- Loading State -->
            <div class="loading" id="loading" style="display: none;">
                Loading your data...
            </div>
        </div>
    </div>

    <!-- Edit/Create Modal -->
    <div class="modal" id="recordModal">
        <div class="modal-content">
            <div class="modal-header">
                <h3 id="modalTitle">✏️ Edit Record</h3>
                <button class="close" onclick="closeModal()">
                    <i class="fas fa-times"></i>
                </button>
            </div>
            <form id="recordForm">
                <div id="formFields"></div>
                <div class="form-actions">
                    <button type="button" class="btn btn-secondary" onclick="closeModal()">
                        <i class="fas fa-times"></i> Cancel
                    </button>
                    <button type="submit" class="btn btn-primary">
                        <i class="fas fa-save"></i> Save Changes
                    </button>
                </div>
            </form>
        </div>
    </div>

    <script>
        let currentTable = '';
        let currentPage = 0;
        let recordsPerPage = 50;
        let totalRecords = 0;
        let allRecords = [];

        // Load initial stats
        loadStats();

        async function loadStats() {
            try {
                const response = await fetch('/api/admin/stats');
                const stats = await response.json();
                
                const statsGrid = document.getElementById('statsGrid');
                const tableIcons = {
                    users: '👥', posts: '📱', stories: '🚩', rides: '🏍️', 
                    emergency_events: '🚨', hazard_reports: '⚠️', followers: '👫',
                    post_likes: '❤️', post_comments: '💬', location_updates: '📍',
                    riding_packs: '🏁', pack_members: '👥', user_sessions: '🔑',
                    story_views: '👀', hazard_confirmations: '✅'
                };
                
                statsGrid.innerHTML = Object.entries(stats).map(([table, count]) => 
                    \`<div class="stat-card">
                        <h3>\${count}</h3>
                        <p>\${tableIcons[table] || '📊'} \${table.replace(/_/g, ' ').toUpperCase()}</p>
                    </div>\`
                ).join('');
            } catch (error) {
                console.error('Error loading stats:', error);
            }
        }

        async function loadTable() {
            const tableSelect = document.getElementById('tableSelect');
            currentTable = tableSelect.value;
            
            if (!currentTable) return;
            
            document.getElementById('loading').style.display = 'block';
            document.getElementById('tableContainer').style.display = 'none';
            document.getElementById('tableControls').style.display = 'none';
            
            try {
                const response = await fetch(\`/api/admin/table/\${currentTable}?limit=1000\`);
                const data = await response.json();
                
                allRecords = data.rows;
                totalRecords = data.total;
                
                displayTable(allRecords);
                updateRecordCount(allRecords.length);
                
                const tableIcons = {
                    users: '👥', posts: '📱', stories: '🚩', rides: '🏍️', 
                    emergency_events: '🚨', hazard_reports: '⚠️', followers: '👫',
                    post_likes: '❤️', post_comments: '💬', location_updates: '📍',
                    riding_packs: '🏁', pack_members: '👥'
                };
                
                document.getElementById('tableTitle').innerHTML = \`\${tableIcons[currentTable] || '📊'} \${currentTable.replace(/_/g, ' ').toUpperCase()} <span style="color: #667eea;">(\${totalRecords} records)</span>\`;
                document.getElementById('tableControls').style.display = 'block';
                document.getElementById('tableContainer').style.display = 'block';
                
            } catch (error) {
                showAlert('Error loading table: ' + error.message, 'error');
            }
            
            document.getElementById('loading').style.display = 'none';
        }

        function displayTable(records) {
            if (records.length === 0) {
                document.getElementById('tableBody').innerHTML = '<tr><td colspan="100%" style="text-align: center; padding: 40px; color: #a0aec0; font-style: italic;">No records found in this table</td></tr>';
                return;
            }

            const columns = Object.keys(records[0]);
            
            // Create table header
            document.getElementById('tableHead').innerHTML = 
                '<tr>' + 
                columns.map(col => \`<th><i class="fas fa-sort"></i> \${col.replace(/_/g, ' ').toUpperCase()}</th>\`).join('') + 
                '<th><i class="fas fa-cog"></i> ACTIONS</th>' +
                '</tr>';
            
            // Create table body
            document.getElementById('tableBody').innerHTML = records.map(record => 
                '<tr>' + 
                columns.map(col => {
                    let value = record[col];
                    if (value === null) {
                        value = '<em style="color: #a0aec0; font-style: italic;">NULL</em>';
                    } else if (col === 'status' && typeof value === 'string') {
                        value = \`<span class="status-\${value}">\${value.toUpperCase()}</span>\`;
                    } else if (typeof value === 'string' && value.length > 50) {
                        value = value.substring(0, 50) + '<span style="color: #a0aec0;">...</span>';
                    } else if (col.includes('date') || col.includes('time')) {
                        value = value ? new Date(value).toLocaleString() : value;
                    }
                    return \`<td>\${value}</td>\`;
                }).join('') +
                \`<td class="record-actions">
                    <button class="btn btn-primary" onclick="editRecord(\${record.id})">
                        <i class="fas fa-edit"></i> Edit
                    </button>
                    <button class="btn btn-danger" onclick="deleteRecord(\${record.id})">
                        <i class="fas fa-trash"></i> Delete
                    </button>
                </td>\` +
                '</tr>'
            ).join('');
        }

        async function editRecord(id) {
            try {
                const response = await fetch(\`/api/admin/table/\${currentTable}/\${id}\`);
                const record = await response.json();
                
                document.getElementById('modalTitle').innerHTML = \`<i class="fas fa-edit"></i> Edit \${currentTable.replace(/_/g, ' ')} Record #\${id}\`;
                await loadFormFields(record);
                document.getElementById('recordModal').style.display = 'block';
                
            } catch (error) {
                showAlert('Error loading record: ' + error.message, 'error');
            }
        }

        async function showCreateModal() {
            document.getElementById('modalTitle').innerHTML = \`<i class="fas fa-plus"></i> Create New \${currentTable.replace(/_/g, ' ')} Record\`;
            await loadFormFields({});
            document.getElementById('recordModal').style.display = 'block';
        }

        async function loadFormFields(record) {
            try {
                // Get table schema
                const response = await fetch(\`/api/admin/schema/\${currentTable}\`);
                const schema = await response.json();
                
                const formFields = document.getElementById('formFields');
                formFields.innerHTML = schema.columns.map(col => {
                    if (col.Field === 'id') return ''; // Skip ID field
                    
                    const value = record[col.Field] || '';
                    const isRequired = col.Null === 'NO' && col.Default === null;
                    
                    return \`<div class="form-group">
                        <label>\${col.Field.replace(/_/g, ' ').toUpperCase()} \${isRequired ? '<span style="color: #e53e3e;">*</span>' : ''}</label>
                        <input type="\${getInputType(col.Type)}" 
                               name="\${col.Field}" 
                               value="\${value}" 
                               \${isRequired ? 'required' : ''}
                               placeholder="Enter \${col.Field.replace(/_/g, ' ').toLowerCase()}...">
                    </div>\`;
                }).join('');
                
                // Set form action
                document.getElementById('recordForm').onsubmit = (e) => {
                    e.preventDefault();
                    saveRecord(record.id);
                };
                
            } catch (error) {
                showAlert('Error loading form: ' + error.message, 'error');
            }
        }

        function getInputType(sqlType) {
            if (sqlType.includes('int')) return 'number';
            if (sqlType.includes('decimal') || sqlType.includes('float')) return 'number';
            if (sqlType.includes('date')) return 'datetime-local';
            if (sqlType.includes('text') || sqlType.includes('longtext')) return 'textarea';
            if (sqlType.includes('email')) return 'email';
            return 'text';
        }

        async function saveRecord(id) {
            const formData = new FormData(document.getElementById('recordForm'));
            const data = Object.fromEntries(formData.entries());
            
            try {
                const url = id ? \`/api/admin/table/\${currentTable}/\${id}\` : \`/api/admin/table/\${currentTable}\`;
                const method = id ? 'PUT' : 'POST';
                
                const response = await fetch(url, {
                    method,
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });
                
                const result = await response.json();
                
                if (response.ok) {
                    showAlert('✅ ' + result.message, 'success');
                    closeModal();
                    loadTable();
                    loadStats(); // Refresh stats
                } else {
                    showAlert('❌ ' + result.error, 'error');
                }
                
            } catch (error) {
                showAlert('❌ Error saving record: ' + error.message, 'error');
            }
        }

        async function deleteRecord(id) {
            if (!confirm('⚠️ Are you sure you want to delete this record? This action cannot be undone.')) {
                return;
            }
            
            try {
                const response = await fetch(\`/api/admin/table/\${currentTable}/\${id}\`, {
                    method: 'DELETE'
                });
                
                const result = await response.json();
                
                if (response.ok) {
                    showAlert('✅ ' + result.message, 'success');
                    loadTable();
                    loadStats(); // Refresh stats
                } else {
                    showAlert('❌ ' + result.error, 'error');
                }
                
            } catch (error) {
                showAlert('❌ Error deleting record: ' + error.message, 'error');
            }
        }

        async function clearTable() {
            if (!confirm(\`⚠️ Are you sure you want to clear ALL records from \${currentTable}? This action cannot be undone and will delete ALL data in this table.\`)) {
                return;
            }
            
            try {
                const response = await fetch(\`/api/admin/table/\${currentTable}\`, {
                    method: 'DELETE'
                });
                
                const result = await response.json();
                
                if (response.ok) {
                    showAlert('✅ ' + result.message, 'success');
                    loadTable();
                    loadStats(); // Refresh stats
                } else {
                    showAlert('❌ ' + result.error, 'error');
                }
                
            } catch (error) {
                showAlert('❌ Error clearing table: ' + error.message, 'error');
            }
        }

        function searchRecords() {
            const searchTerm = document.getElementById('searchBox').value.toLowerCase();
            
            if (!searchTerm) {
                displayTable(allRecords);
                updateRecordCount(allRecords.length);
                return;
            }
            
            const filteredRecords = allRecords.filter(record => 
                Object.values(record).some(value => 
                    value && value.toString().toLowerCase().includes(searchTerm)
                )
            );
            
            displayTable(filteredRecords);
            updateRecordCount(filteredRecords.length);
        }

        function updateRecordCount(count) {
            document.getElementById('recordCount').innerHTML = \`<i class="fas fa-database"></i> \${count} records\`;
        }

        function exportTable() {
            if (allRecords.length === 0) {
                showAlert('❌ No data to export', 'error');
                return;
            }
            
            const csv = convertToCSV(allRecords);
            downloadCSV(csv, \`motorev_\${currentTable}_\${new Date().toISOString().split('T')[0]}.csv\`);
            showAlert('✅ Export completed successfully!', 'success');
        }

        function convertToCSV(records) {
            const header = Object.keys(records[0]).join(',');
            const rows = records.map(record => 
                Object.values(record).map(value => 
                    \`"\${(value || '').toString().replace(/"/g, '""')}"\`
                ).join(',')
            );
            return [header, ...rows].join('\\n');
        }

        function downloadCSV(csv, filename) {
            const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
            const link = document.createElement('a');
            if (link.download !== undefined) {
                const url = URL.createObjectURL(blob);
                link.setAttribute('href', url);
                link.setAttribute('download', filename);
                link.style.visibility = 'hidden';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            }
        }

        function closeModal() {
            document.getElementById('recordModal').style.display = 'none';
        }

        function showAlert(message, type) {
            const alertContainer = document.getElementById('alertContainer');
            const alertDiv = document.createElement('div');
            alertDiv.className = type;
            alertDiv.innerHTML = \`\${message} <button onclick="this.parentElement.remove()" style="float: right; background: none; border: none; cursor: pointer; font-size: 18px; color: inherit; opacity: 0.7; hover: opacity: 1;">&times;</button>\`;
            alertContainer.appendChild(alertDiv);
            
            setTimeout(() => {
                if (alertDiv.parentElement) {
                    alertDiv.style.opacity = '0';
                    alertDiv.style.transform = 'translateY(-20px)';
                    setTimeout(() => alertDiv.remove(), 300);
                }
            }, 5000);
        }

        // Close modal when clicking outside
        window.onclick = function(event) {
            const modal = document.getElementById('recordModal');
            if (event.target === modal) {
                closeModal();
            }
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeModal();
            }
        });
    </script>
</body>
</html>
  `);
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('Global error handler:', err);
  
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'Invalid JSON format' });
  }
  
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ error: 'File too large' });
  }
  
  res.status(500).json({ 
    error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message 
  });
});

// Graceful shutdown function
async function gracefulShutdown(signal) {
  console.log(`🛑 Received ${signal}. Starting graceful shutdown...`);
  
  // Stop accepting new connections
  server.close(() => {
    console.log('✅ HTTP server closed');
  });
  
  // Close database connections
  try {
    console.log('🔌 Closing database connections...');
    await closePool();
  } catch (error) {
    console.error('❌ Error closing database:', error);
  }
  
  console.log('✅ Graceful shutdown completed');
  process.exit(0);
}

// Initialize database and start server
async function startServer() {
  try {
    console.log('🚀 Starting MotoRev API Server...');
    
    // Setup database
    await setupDatabase();
    
    // Initialize WebSocket service
    setupSocketHandlers(io);
    
    // Start server
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`
🎉 MotoRev API Server is running!
📍 Port: ${PORT}
🌍 Environment: ${process.env.NODE_ENV || 'development'}
📝 Logs: ${process.env.NODE_ENV === 'production' ? 'combined' : 'dev'}
🔗 Health: http://localhost:${PORT}/health
📚 API: http://localhost:${PORT}/api
📱 Device Access: http://192.168.68.78:${PORT}/api
💾 Database: MySQL
      `);
    });

    // Graceful shutdown handling
    process.on('SIGTERM', gracefulShutdown);
    process.on('SIGINT', gracefulShutdown);
    
  } catch (error) {
    console.error('❌ Server startup failed:', error);
    process.exit(1);
  }
}

// Start the server
startServer(); 