# MotoRev Railway Deployment Guide

## 🚀 Quick Production Deployment

### Step 1: Deploy to Railway

1. **Sign up for Railway**
   - Go to [railway.app](https://railway.app)
   - Sign up with GitHub
   - Create a new project

2. **Connect Your Repository**
   - Click "Deploy from GitHub repo"
   - Select your MotoRev repository
   - Railway will auto-detect it's a Node.js app

3. **Add MySQL Database**
   - In your Railway project, click "New"
   - Select "Database" → "MySQL"
   - Railway will automatically set environment variables

4. **Set Environment Variables**
   ```
   NODE_ENV=production
   JWT_SECRET=your-super-secret-jwt-key-here
   MYSQL_HOST=${MYSQL_HOST}
   MYSQL_USER=${MYSQL_USER}
   MYSQL_PASSWORD=${MYSQL_PASSWORD}
   MYSQL_DATABASE=${MYSQL_DATABASE}
   MYSQL_PORT=${MYSQL_PORT}
   CORS_ORIGIN=*
   ```

5. **Deploy**
   - Railway will automatically deploy your app
   - Get your production URL: `https://your-app-name.railway.app`

### Step 2: Database Setup

1. **Access Railway MySQL**
   - In Railway dashboard, click on your MySQL service
   - Go to "Connect" tab
   - Use the connection details to access your database

2. **Run Database Setup**
   ```bash
   # In Railway terminal or locally with Railway CLI
   npm run db:setup
   npm run db:migrate
   npm run db:seed
   ```

### Step 3: Update iOS App

1. **Update NetworkManager.swift**
   ```swift
   // Change the baseURL to your Railway URL
   static let baseURL = "https://your-app-name.railway.app"
   ```

2. **Test Production Build**
   - Build and test your iOS app with the new backend URL
   - Ensure all features work in production

## 🔧 Admin Dashboard Access

### Admin API Endpoints

Your backend includes comprehensive admin controls:

1. **View All Users**
   ```
   GET https://your-app-name.railway.app/api/admin/users
   ```

2. **View Database Tables**
   ```
   GET https://your-app-name.railway.app/api/admin/table/users?limit=100&offset=0
   GET https://your-app-name.railway.app/api/admin/table/posts?limit=100&offset=0
   GET https://your-app-name.railway.app/api/admin/table/rides?limit=100&offset=0
   ```

3. **Manage User Permissions**
   ```
   PUT https://your-app-name.railway.app/api/admin/users/:id/status
   ```

4. **View Analytics**
   ```
   GET https://your-app-name.railway.app/api/admin/analytics
   ```

### Admin Authentication

To access admin features, you need to be authenticated as an admin user:

1. **Create Admin User**
   ```sql
   INSERT INTO users (username, email, password_hash, is_admin, created_at) 
   VALUES ('admin', 'admin@motorev.com', 'hashed_password', 1, NOW());
   ```

2. **Admin Login**
   ```
   POST https://your-app-name.railway.app/api/auth/login
   {
     "email": "admin@motorev.com",
     "password": "your_password"
   }
   ```

## 📊 Database Management

### Access Your Database

1. **Via Railway Dashboard**
   - Go to your MySQL service in Railway
   - Click "Connect" → "MySQL Client"
   - Use the provided connection details

2. **Via MySQL Workbench**
   - Use the connection details from Railway
   - Host: Your Railway MySQL host
   - Port: 3306
   - Database: motorev

3. **Via Command Line**
   ```bash
   # Install Railway CLI
   npm install -g @railway/cli
   
   # Login and connect
   railway login
   railway link
   railway connect
   ```

### Key Database Operations

1. **View All Users**
   ```sql
   SELECT id, username, email, created_at, is_admin, status 
   FROM users 
   ORDER BY created_at DESC;
   ```

2. **View User Activity**
   ```sql
   SELECT u.username, COUNT(r.id) as ride_count, 
          SUM(r.distance) as total_distance
   FROM users u
   LEFT JOIN rides r ON u.id = r.user_id
   GROUP BY u.id, u.username;
   ```

3. **Monitor Emergency Events**
   ```sql
   SELECT u.username, e.event_type, e.severity, e.created_at
   FROM emergency_events e
   JOIN users u ON e.user_id = u.id
   ORDER BY e.created_at DESC;
   ```

## 🔒 Security & Permissions

### User Permission Levels

1. **Regular Users** (default)
   - Can create posts, rides, emergency events
   - Can follow other users
   - Can join group rides

2. **Verified Users**
   - All regular user permissions
   - Can create verified content
   - Higher visibility in social feed

3. **Admin Users**
   - Full database access
   - Can manage all users
   - Can view analytics
   - Can moderate content

### Content Moderation

1. **Flagged Content**
   ```sql
   SELECT * FROM posts WHERE is_flagged = 1;
   SELECT * FROM users WHERE status = 'suspended';
   ```

2. **Moderate User**
   ```sql
   UPDATE users SET status = 'suspended' WHERE id = ?;
   UPDATE users SET status = 'active' WHERE id = ?;
   ```

## 📈 Analytics & Monitoring

### Key Metrics to Track

1. **User Growth**
   ```sql
   SELECT DATE(created_at) as date, COUNT(*) as new_users
   FROM users 
   GROUP BY DATE(created_at)
   ORDER BY date DESC;
   ```

2. **Ride Activity**
   ```sql
   SELECT DATE(created_at) as date, COUNT(*) as rides, 
          AVG(distance) as avg_distance
   FROM rides 
   GROUP BY DATE(created_at)
   ORDER BY date DESC;
   ```

3. **Emergency Events**
   ```sql
   SELECT event_type, COUNT(*) as count, 
          AVG(severity) as avg_severity
   FROM emergency_events 
   GROUP BY event_type;
   ```

## 🚨 Emergency Response

### Real-time Monitoring

1. **Active Emergency Events**
   ```sql
   SELECT u.username, e.event_type, e.location, e.created_at
   FROM emergency_events e
   JOIN users u ON e.user_id = u.id
   WHERE e.status = 'active'
   ORDER BY e.created_at DESC;
   ```

2. **Emergency Contacts**
   ```sql
   SELECT u.username, ec.name, ec.phone_number, ec.relationship
   FROM emergency_contacts ec
   JOIN users u ON ec.user_id = u.id
   WHERE u.id = ?;
   ```

## 💰 Cost Management

### Railway Pricing

- **Free Tier**: $5 credit/month
- **Pro Plan**: $20/month for more resources
- **Database**: $5/month for 1GB MySQL

### Optimization Tips

1. **Monitor Usage**
   - Check Railway dashboard for resource usage
   - Optimize database queries
   - Use caching for frequently accessed data

2. **Scale as Needed**
   - Start with free tier
   - Upgrade when you hit limits
   - Monitor user growth and scale accordingly

## 🔄 Backup & Recovery

### Automated Backups

Railway provides automatic backups for MySQL databases:

1. **Backup Frequency**: Daily
2. **Retention**: 7 days
3. **Manual Backups**: Available in Railway dashboard

### Manual Backup

```bash
# Export database
mysqldump -h your-host -u your-user -p motorev > backup.sql

# Import database
mysql -h your-host -u your-user -p motorev < backup.sql
```

## 📱 App Store Preparation

### Production Checklist

- [ ] Backend deployed and tested
- [ ] Database populated with test data
- [ ] All API endpoints working
- [ ] Admin dashboard accessible
- [ ] Security measures in place
- [ ] Analytics tracking enabled
- [ ] Backup strategy implemented
- [ ] Monitoring alerts configured

### App Store Submission

1. **Update iOS App**
   - Change NetworkManager baseURL to production
   - Test all features with production backend
   - Ensure no development URLs remain

2. **Submit to App Store**
   - Build production version
   - Submit through App Store Connect
   - Monitor for any issues

## 🆘 Support & Maintenance

### Common Issues

1. **Database Connection Issues**
   - Check Railway MySQL service status
   - Verify environment variables
   - Test connection from Railway dashboard

2. **Performance Issues**
   - Monitor database query performance
   - Check Railway resource usage
   - Optimize slow queries

3. **User Issues**
   - Check user logs in database
   - Monitor error logs in Railway
   - Use admin endpoints to investigate

### Getting Help

- Railway Documentation: https://docs.railway.app
- MySQL Documentation: https://dev.mysql.com/doc
- MotoRev Backend Issues: Check your GitHub repository 