#!/bin/bash

echo "🚀 MotoRev Heroku Deployment"
echo "============================"
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

# Check if Heroku CLI is installed
print_status "Checking Heroku CLI..."
if ! command -v heroku &> /dev/null; then
    print_warning "Heroku CLI not found. Installing..."
    brew tap heroku/brew && brew install heroku
    if [ $? -ne 0 ]; then
        print_warning "Failed to install Heroku CLI. Please install manually:"
        echo "   brew tap heroku/brew && brew install heroku"
        exit 1
    fi
fi
print_success "Heroku CLI is ready"

# Check if logged in to Heroku
print_status "Checking Heroku authentication..."
if ! heroku auth:whoami &> /dev/null; then
    print_warning "Not logged in to Heroku. Please login..."
    heroku login
    if [ $? -ne 0 ]; then
        print_warning "Failed to login to Heroku. Please try again."
        exit 1
    fi
fi
print_success "Authenticated with Heroku"

# Create Heroku app
print_status "Creating Heroku app..."
APP_NAME="motorev-backend-$(date +%s)"
heroku create $APP_NAME

if [ $? -eq 0 ]; then
    print_success "Heroku app created: $APP_NAME"
    
    # Set environment variables
    print_status "Setting up environment variables..."
    heroku config:set NODE_ENV=production
    heroku config:set JWT_SECRET=$(openssl rand -base64 32)
    heroku config:set CORS_ORIGIN=*
    
    # Add MySQL database
    print_status "Adding MySQL database..."
    heroku addons:create jawsdb:kitefin
    
    # Deploy to Heroku
    print_status "Deploying to Heroku..."
    cd MotoRevBackend
    git init
    git add .
    git commit -m "Initial deployment"
    git push heroku main
    
    if [ $? -eq 0 ]; then
        print_success "Deployment successful!"
        
        # Get the deployment URL
        DEPLOY_URL="https://$APP_NAME.herokuapp.com"
        
        echo ""
        echo "🎉 MotoRev Backend is now live on Heroku!"
        echo "=========================================="
        echo "🌐 Production URL: $DEPLOY_URL"
        echo "🔗 Health Check: $DEPLOY_URL/health"
        echo "📊 Dashboard: https://dashboard.heroku.com/apps/$APP_NAME"
        echo ""
        echo "📱 Your iOS app is already configured to use this URL for production builds!"
        echo "🔧 For development, it will still use localhost:3000"
        echo ""
        echo "✅ Any user with the app can now connect to this server!"
        echo ""
        print_success "Deployment complete! Your app is ready for production use."
    else
        print_warning "Deployment failed. Please check the logs above."
    fi
else
    print_warning "Failed to create Heroku app. Please try again."
fi 