#!/bin/bash

# AudioSafety iOS - Quick Setup Script

echo "======================================"
echo "  AudioSafety iOS Setup"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -f "Podfile" ]; then
    echo "❌ Error: Please run this script from the AudioSafety directory"
    exit 1
fi

echo "✅ Found Podfile"

# Check if workspace exists
if [ ! -d "AudioSafety.xcworkspace" ]; then
    echo "❌ Error: AudioSafety.xcworkspace not found"
    echo "   Run 'pod install' first"
    exit 1
fi

echo "✅ Found workspace"

# Check for Agora App ID
if grep -q "YOUR_APP_ID" AudioSafety.swift 2>/dev/null; then
    echo ""
    echo "⚠️  WARNING: You need to configure your Agora App ID!"
    echo ""
    echo "   1. Get a free App ID from https://console.agora.io/"
    echo "   2. Open AudioSafety.swift"
    echo "   3. Replace 'YOUR_APP_ID' with your actual App ID"
    echo ""
fi

echo ""
echo "======================================"
echo "  Setup Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Open the workspace:"
echo "   open AudioSafety.xcworkspace"
echo ""
echo "2. Configure your Agora App ID in AudioSafety.swift"
echo ""
echo "3. Select your target device/simulator"
echo ""
echo "4. Press Cmd+R to build and run"
echo ""
echo "======================================"
