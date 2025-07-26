# MotoRev Logo Setup Instructions

## Quick Fix: Add Your Logo Images

To make your custom logo appear on the splash screen:

### Step 1: Prepare Image Files
1. Take the attached motorcycle logo image
2. Save it as `moto-logo.png` (1x resolution, recommended: 100x100px)
3. Create larger versions:
   - `moto-logo@2x.png` (2x resolution, 200x200px)
   - `moto-logo@3x.png` (3x resolution, 300x300px)

### Step 2: Add to Asset Catalog
1. Copy all three image files to: `MotoRev/Assets.xcassets/MotoRevLogo.imageset/`
2. The files must be in this exact directory with these exact names

### Step 3: Test
1. Build the project: `xcodebuild -project MotoRev.xcodeproj -scheme MotoRev build`
2. The splash screen will now show your custom logo in a circular frame

## Current Status
- ✅ Code is ready to use MotoRevLogo asset
- ❌ Image files are missing (causing build warnings)
- 🔄 Currently showing temporary speedometer + motorcycle icon

## Expected Result
Once image files are added, the splash screen will display your circular motorcycle logo instead of the temporary SF Symbol icons. 