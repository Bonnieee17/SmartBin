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

echo "Building Android APK..."
flutter build apk --release

echo "Copying custom Vercel files..."

# Android App Links
mkdir -p build/web/.well-known
cp web/.well-known/assetlinks.json \
   build/web/.well-known/assetlinks.json

# Download page
mkdir -p build/web/download
cp web/download/index.html \
   build/web/download/index.html

# Claim page
mkdir -p build/web/claim
cp web/claim/index.html \
   build/web/claim/index.html

# Copy APK to Vercel output
cp build/app/outputs/flutter-apk/app-release.apk \
   build/web/app-release.apk

echo "=================================="
echo "Flutter Web build completed!"
echo "Android APK build completed!"
echo "APK copied to Vercel output!"
echo "=================================="