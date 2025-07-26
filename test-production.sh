#!/bin/bash

echo "🧪 Testing MotoRev Production Deployment"
echo "========================================"
echo ""

# Get the production URL from Railway
if command -v railway &> /dev/null; then
    PROD_URL=$(railway status --json 2>/dev/null | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
else
    echo "⚠️  Railway CLI not found. Please enter your production URL manually:"
    read -p "Production URL (e.g., https://motorev-backend-production.up.railway.app): " PROD_URL
fi

if [ -z "$PROD_URL" ]; then
    echo "❌ No production URL found. Please deploy first using ./deploy-to-production.sh"
    exit 1
fi

echo "🌐 Testing production URL: $PROD_URL"
echo ""

# Test health endpoint
echo "🔍 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s "$PROD_URL/health")
if [[ $HEALTH_RESPONSE == *"success"* ]]; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    echo "Response: $HEALTH_RESPONSE"
fi

# Test API endpoint
echo "🔍 Testing API endpoint..."
API_RESPONSE=$(curl -s "$PROD_URL/api")
if [[ $API_RESPONSE == *"MotoRev API"* ]]; then
    echo "✅ API endpoint working"
else
    echo "❌ API endpoint failed"
    echo "Response: $API_RESPONSE"
fi

# Test bike endpoint with auth
echo "🔍 Testing bike endpoint (with auth)..."
BIKE_RESPONSE=$(curl -s -H "Authorization: Bearer test-token-for-development" "$PROD_URL/api/bikes")
if [[ $BIKE_RESPONSE == *"success"* ]] || [[ $BIKE_RESPONSE == *"bikes"* ]]; then
    echo "✅ Bike endpoint working"
else
    echo "❌ Bike endpoint failed"
    echo "Response: $BIKE_RESPONSE"
fi

echo ""
echo "🎉 Production testing complete!"
echo "📱 Your iOS app should now connect to: $PROD_URL"
echo "🌍 Any user with the app can connect to this server!" 