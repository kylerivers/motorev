# 🚀 Quick Deploy to Railway (5 minutes)

## Step 1: Sign up for Railway
1. Go to [railway.app](https://railway.app)
2. Sign up with your GitHub account
3. Create a new project

## Step 2: Connect Your Repository
1. Click "Deploy from GitHub repo"
2. Select your MotoRev repository
3. Railway will auto-detect it's a Node.js app

## Step 3: Add Database
1. Click "New" → "Database" → "MySQL"
2. Railway will automatically set environment variables
3. Your database will be ready in seconds

## Step 4: Set Environment Variables
In your Railway project settings, add these variables:
```
NODE_ENV=production
JWT_SECRET=your-super-secret-jwt-key-here
```

## Step 5: Deploy
1. Railway will automatically deploy your app
2. You'll get a URL like: `https://motorev-backend-production.up.railway.app`
3. Test the health endpoint: `https://motorev-backend-production.up.railway.app/health`

## Step 6: Update iOS App
The NetworkManager is already configured to use the production URL for release builds!

## 🎉 Done!
Your backend is now running 24/7 and any phone can connect to it!

## 📊 Monitor Your App
- View logs: Railway dashboard
- Monitor performance: Built-in metrics
- Automatic restarts: Railway handles crashes

## 🔄 Automatic Deployments
Every time you push to GitHub, Railway will automatically redeploy your app! 