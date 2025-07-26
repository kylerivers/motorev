#!/bin/bash

echo "🚀 MotoRev Backend Deployment Script"
echo "====================================="

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Installing..."
    npm install -g @railway/cli
fi

# Check if logged in to Railway
if ! railway whoami &> /dev/null; then
    echo "🔑 Please login to Railway..."
    railway login
fi

# Deploy to Railway
echo "📦 Deploying to Railway..."
cd MotoRevBackend
railway up

echo "✅ Deployment complete!"
echo "🌐 Your app should be available at: https://motorev-backend-production.up.railway.app"
echo "📊 View logs and metrics at: https://railway.app/dashboard" 