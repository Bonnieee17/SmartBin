#!/bin/bash

set -e

echo "Installing Flutter..."

git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"

export PATH="$HOME/flutter/bin:$PATH"

echo "Flutter version:"
flutter --version

echo "Getting dependencies..."
flutter pub get

echo "Building Flutter Web..."
flutter build web --release

echo "Copying custom Vercel web files..."

# Android App Links
mkdir -p build/web/.well-known
if [ -f web/.well-known/assetlinks.json ]; then
  cp web/.well-known/assetlinks.json build/web/.well-known/assetlinks.json
fi

# Download page
mkdir -p build/web/download
if [ -f web/download/index.html ]; then
  cp web/download/index.html build/web/download/index.html
fi

# Claim page
mkdir -p build/web/claim
if [ -f web/claim/index.html ]; then
  cp web/claim/index.html build/web/claim/index.html
fi

# Copy pre-built APK if present
if [ -f web/download/app-release.apk ]; then
  cp web/download/app-release.apk build/web/app-release.apk
fi

echo "=================================="
echo "Flutter Web build completed successfully!"
echo "=================================="
