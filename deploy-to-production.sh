#!/bin/bash

# MotoRev Production Deployment Script
# This script helps you deploy your MotoRev backend to production

set -e

echo "🏍️ MotoRev Production Deployment"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "MotoRevBackend/package.json" ]; then
    print_error "Please run this script from the MotoRev project root directory"
    exit 1
fi

print_status "Starting MotoRev production deployment..."

# Step 1: Check prerequisites
print_status "Checking prerequisites..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install npm first."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    print_error "Node.js version 18+ is required. Current version: $(node -v)"
    exit 1
fi

print_success "Prerequisites check passed"

# Step 2: Install Railway CLI
print_status "Installing Railway CLI..."
if ! command -v railway &> /dev/null; then
    npm install -g @railway/cli
    print_success "Railway CLI installed"
else
    print_status "Railway CLI already installed"
fi

# Step 3: Login to Railway
print_status "Logging into Railway..."
if ! railway whoami &> /dev/null; then
    print_warning "Please login to Railway in your browser..."
    railway login
else
    print_success "Already logged into Railway"
fi

# Step 4: Create Railway project
print_status "Setting up Railway project..."
if [ ! -f ".railway" ]; then
    print_status "Creating new Railway project..."
    railway init
    print_success "Railway project created"
else
    print_status "Railway project already exists"
fi

# Step 5: Add MySQL database
print_status "Setting up MySQL database..."
print_warning "Please manually add MySQL database in Railway dashboard:"
print_warning "1. Go to your Railway project"
print_warning "2. Click 'New' → 'Database' → 'MySQL'"
print_warning "3. Railway will auto-configure the connection"

# Step 6: Set environment variables
print_status "Setting up environment variables..."

# Generate a secure JWT secret
JWT_SECRET=$(openssl rand -base64 32)

# Set environment variables
railway variables set NODE_ENV=production
railway variables set JWT_SECRET="$JWT_SECRET"
railway variables set CORS_ORIGIN="*"

print_success "Environment variables configured"

# Step 7: Deploy the application
print_status "Deploying to Railway..."
railway up

# Step 8: Get the deployment URL
print_status "Getting deployment URL..."
DEPLOY_URL=$(railway status --json | grep -o '"url":"[^"]*"' | cut -d'"' -f4)

if [ -z "$DEPLOY_URL" ]; then
    print_error "Could not get deployment URL"
    exit 1
fi

print_success "Deployed to: $DEPLOY_URL"

# Step 9: Setup database
print_status "Setting up database..."
railway run npm run db:setup
railway run npm run db:migrate
railway run npm run db:seed

print_success "Database setup complete"

# Step 10: Create admin user
print_status "Creating admin user..."
ADMIN_PASSWORD=$(openssl rand -base64 12)
echo "Admin password: $ADMIN_PASSWORD" > admin_credentials.txt

# Create admin user via API
curl -X POST "$DEPLOY_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"admin\",
    \"email\": \"admin@motorev.com\",
    \"password\": \"$ADMIN_PASSWORD\",
    \"firstName\": \"Admin\",
    \"lastName\": \"User\"
  }"

print_success "Admin user created"
print_warning "Admin credentials saved to admin_credentials.txt"

# Step 11: Update iOS app configuration
print_status "Updating iOS app configuration..."

# Create a configuration file for the iOS app
cat > ios_production_config.swift << EOF
// MotoRev Production Configuration
// Update this in your NetworkManager.swift

import Foundation

struct ProductionConfig {
    static let baseURL = "$DEPLOY_URL"
    static let adminURL = "$DEPLOY_URL/admin"
    
    // Admin credentials (keep secure)
    static let adminEmail = "admin@motorev.com"
    static let adminPassword = "$ADMIN_PASSWORD"
}
EOF

print_success "iOS configuration file created: ios_production_config.swift"

# Step 12: Test the deployment
print_status "Testing deployment..."

# Test health endpoint
HEALTH_RESPONSE=$(curl -s "$DEPLOY_URL/health")
if echo "$HEALTH_RESPONSE" | grep -q "OK"; then
    print_success "Health check passed"
else
    print_error "Health check failed"
    echo "Response: $HEALTH_RESPONSE"
fi

# Test admin endpoint
ADMIN_RESPONSE=$(curl -s "$DEPLOY_URL/admin")
if echo "$ADMIN_RESPONSE" | grep -q "MotoRev Admin Dashboard"; then
    print_success "Admin dashboard accessible"
else
    print_warning "Admin dashboard may not be accessible"
fi

# Step 13: Display final information
echo ""
echo "🎉 MotoRev Production Deployment Complete!"
echo "=========================================="
echo ""
echo "📱 Production URL: $DEPLOY_URL"
echo "🔧 Admin Dashboard: $DEPLOY_URL/admin"
echo "📊 Health Check: $DEPLOY_URL/health"
echo ""
echo "👤 Admin Credentials:"
echo "   Email: admin@motorev.com"
echo "   Password: $ADMIN_PASSWORD"
echo ""
echo "📋 Next Steps:"
echo "1. Update your iOS app's NetworkManager.swift with the production URL"
echo "2. Test all features with the production backend"
echo "3. Submit your app to the App Store"
echo "4. Monitor your Railway dashboard for usage and costs"
echo ""
echo "🔒 Security Notes:"
echo "- Keep your admin credentials secure"
echo "- Monitor your Railway usage to avoid unexpected costs"
echo "- Set up proper monitoring and alerts"
echo ""
echo "📚 Documentation:"
echo "- Railway Dashboard: https://railway.app"
echo "- Admin Guide: $DEPLOY_URL/admin"
echo "- API Documentation: $DEPLOY_URL/api/docs"
echo ""

print_success "Deployment script completed successfully!" 