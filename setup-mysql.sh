#!/bin/bash

echo "🏍️  MotoRev MySQL Setup Script"
echo "================================"
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Installing Homebrew first..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "📦 Installing MySQL..."
brew install mysql

echo "🚀 Starting MySQL service..."
brew services start mysql

echo "✅ MySQL installed and started!"
echo ""
echo "🔧 Setting up MotoRev database..."
cd MotoRevBackend

# Install Node.js dependencies if not already installed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing Node.js dependencies..."
    npm install
fi

echo "🗄️  Creating MotoRev database..."
npm run mysql:setup

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. cd MotoRevBackend"
echo "2. npm start"
echo "3. Open http://localhost:3000 in your browser"
echo ""
echo "Your MotoRev backend is now running with MySQL! 🚀" 