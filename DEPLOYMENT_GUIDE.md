# MotoRev Backend Deployment Guide

## 🚀 Quick Deploy Options

### Option 1: Railway (Recommended - Free & Easy)

1. **Sign up for Railway**
   - Go to [railway.app](https://railway.app)
   - Sign up with GitHub
   - Create a new project

2. **Deploy from GitHub**
   - Connect your GitHub repository
   - Railway will automatically detect it's a Node.js app
   - Deploy with one click

3. **Set Environment Variables**
   ```
   NODE_ENV=production
   JWT_SECRET=your-super-secret-jwt-key-here
   DB_HOST=your-mysql-host
   DB_USER=your-mysql-user
   DB_PASSWORD=your-mysql-password
   DB_NAME=motorev
   ```

4. **Get Your Production URL**
   - Railway will give you a URL like: `https://motorev-backend-production.up.railway.app`
   - Update the NetworkManager.swift baseURL for production builds

### Option 2: Heroku (Alternative)

1. **Install Heroku CLI**
   ```bash
   brew install heroku/brew/heroku
   ```

2. **Login and Deploy**
   ```bash
   heroku login
   heroku create motorev-backend
   git push heroku main
   ```

3. **Set Environment Variables**
   ```bash
   heroku config:set NODE_ENV=production
   heroku config:set JWT_SECRET=your-secret-key
   ```

### Option 3: DigitalOcean App Platform

1. **Create App**
   - Go to DigitalOcean App Platform
   - Connect your GitHub repo
   - Select Node.js environment

2. **Configure Environment**
   - Set environment variables
   - Configure database connection

## 🗄️ Database Setup

### Option A: Railway MySQL (Easiest)
- Railway provides managed MySQL databases
- Automatically handles connection strings
- Free tier includes 1GB storage

### Option B: PlanetScale (Recommended for Production)
- Serverless MySQL platform
- Excellent performance and scaling
- Free tier with 1GB storage

### Option C: AWS RDS
- Full control over database
- More complex setup
- Pay-as-you-go pricing

## 🔧 Environment Configuration

Create a `.env` file for production:

```env
NODE_ENV=production
PORT=3000
JWT_SECRET=your-super-secret-jwt-key-here
DB_HOST=your-database-host
DB_USER=your-database-user
DB_PASSWORD=your-database-password
DB_NAME=motorev
CORS_ORIGIN=https://your-frontend-domain.com
```

## 📱 iOS App Configuration

The NetworkManager is already configured to use:
- `localhost:3000` for DEBUG builds (development)
- `https://motorev-backend-production.up.railway.app` for RELEASE builds (production)

## 🔒 Security Checklist

- [ ] Use HTTPS in production
- [ ] Set strong JWT_SECRET
- [ ] Configure CORS properly
- [ ] Use environment variables for secrets
- [ ] Enable rate limiting
- [ ] Set up proper database backups

## 📊 Monitoring

### Railway Dashboard
- Built-in monitoring
- Logs and metrics
- Automatic restarts

### Alternative: Sentry
- Error tracking
- Performance monitoring
- Real-time alerts

## 🚀 Deployment Commands

```bash
# Railway
railway login
railway link
railway up

# Heroku
heroku login
heroku create motorev-backend
git push heroku main

# DigitalOcean
doctl apps create --spec app.yaml
```

## 🔄 Continuous Deployment

Set up GitHub Actions for automatic deployment:

```yaml
name: Deploy to Railway
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: railway/action@v1
        with:
          railway_token: ${{ secrets.RAILWAY_TOKEN }}
```

## 📞 Support

- Railway: [docs.railway.app](https://docs.railway.app)
- Heroku: [devcenter.heroku.com](https://devcenter.heroku.com)
- DigitalOcean: [docs.digitalocean.com](https://docs.digitalocean.com)

## 🎯 Next Steps

1. Choose your hosting platform
2. Deploy the backend
3. Update the iOS app with production URL
4. Test all features
5. Set up monitoring and alerts
6. Configure automatic backups 