#!/bin/bash

# Script to add the new Swift files to Xcode project
# This needs to be run after the files are manually added to Xcode

echo "🔧 Adding new Swift files to Xcode project..."

# The files that need to be added:
echo "Files to add to Xcode project:"
echo "- MotoRev/Views/GroupCommunicationView.swift"
echo "- MotoRev/Views/SearchPlacesView.swift"

echo ""
echo "📱 Manual Steps Required:"
echo "1. Open Xcode (should already be open)"
echo "2. Right-click on the 'Views' folder in the project navigator"
echo "3. Select 'Add Files to MotoRev'"
echo "4. Navigate to MotoRev/Views/ and select:"
echo "   - GroupCommunicationView.swift"
echo "   - SearchPlacesView.swift"
echo "5. Make sure 'Add to target: MotoRev' is checked"
echo "6. Click 'Add'"
echo ""
echo "✅ After adding, the compiler errors should be resolved!"
