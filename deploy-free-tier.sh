#!/bin/bash

echo "🚀 MotoRev Free Tier Deployment"
echo "==============================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status "Setting up Railway project..."

# Navigate to backend directory
cd MotoRevBackend

# Deploy to Railway
print_status "Deploying to Railway..."
railway up

if [ $? -eq 0 ]; then
    print_success "Deployment successful!"
    
    # Get the deployment URL
    DEPLOY_URL=$(railway status --json | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
    
    echo ""
    echo "🎉 MotoRev Backend is now live!"
    echo "================================="
    echo "🌐 Production URL: $DEPLOY_URL"
    echo "🔗 Health Check: $DEPLOY_URL/health"
    echo "📊 Dashboard: https://railway.app/dashboard"
    echo ""
    echo "📱 Your iOS app is already configured to use this URL for production builds!"
    echo "🔧 For development, it will still use localhost:3000"
    echo ""
    echo "✅ Any user with the app can now connect to this server!"
    echo ""
    print_success "Deployment complete! Your app is ready for production use."
else
    print_warning "Deployment failed. This might be due to plan limitations."
    echo ""
    echo "🔧 To fix this:"
    echo "1. Go to https://railway.com/account/plans"
    echo "2. Upgrade to Pro plan ($5/month)"
    echo "3. Run this script again"
    echo ""
    echo "💡 Alternative: Use Heroku (free tier available)"
    echo "   Run: ./deploy-heroku.sh"
fi 