#!/bin/bash

# Check if Xcode is installed
if ! [ -d "/Applications/Xcode.app" ]; then
    echo "❌ Error: Xcode is not installed in /Applications"
    exit 1
fi

# Set Xcode as the active developer directory
# (Most ly working without this, then it don't require password. Uncomment if needed)
#sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Automatically detect the scheme
SCHEME=$(xcodebuild -list | sed -n '/Schemes:/,/Targets:/p' | sed -n '2p' | xargs)

if [ -z "$SCHEME" ]; then
    echo "❌ Error: No scheme found in the Xcode project."
    exit 1
fi

echo "🔍 Detected scheme: $SCHEME"

# List available simulators for debugging
echo "📱 Available simulators:"
xcrun simctl list devices | grep -E "iPhone|iPad"

# Find the first available iPhone simulator (either Shutdown or Booted)
echo "🔍 Searching for available iPhone simulators..."
SIMULATOR_INFO=$(xcrun simctl list devices available | grep -E "iPhone.*(Shutdown|Booted)" | grep -v "unavailable" | head -1)

echo "Debug - Full simulator info: $SIMULATOR_INFO"

if [ -z "$SIMULATOR_INFO" ]; then
    echo "❌ Error: No valid iPhone simulator found."
    exit 1
fi

# Extract the simulator ID (UUID) more carefully
SIMULATOR_ID=$(echo "$SIMULATOR_INFO" | grep -Eo '[A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12}')

echo "Debug - Extracted simulator ID: $SIMULATOR_ID"

# Check if SIMULATOR_ID is valid
if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ Error: Could not determine a valid simulator ID."
    exit 1
fi

# Check if simulator is already booted
if echo "$SIMULATOR_INFO" | grep -q "Shutdown"; then
    echo "🔄 Starting simulator: $SIMULATOR_ID"
    xcrun simctl boot "$SIMULATOR_ID"
else
    echo "✅ Simulator already booted: $SIMULATOR_ID"
fi

# Extract the full simulator name and OS version with better parsing
SIMULATOR_NAME=$(echo "$SIMULATOR_INFO" | sed -E 's/ \([^)]+\).*//g' | xargs)

# Get OS version using xcrun simctl list with JSON output
echo "Debug - Getting device info in JSON format:"
DEVICE_JSON=$(xcrun simctl list -j devices)

# Try to get OS version from JSON output
SIMULATOR_OS=$(echo "$DEVICE_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
target_id = '$SIMULATOR_ID'
for runtime, devices in data['devices'].items():
    if 'iOS' not in runtime:  # Skip non-iOS runtimes
        continue
    for device in devices:
        if device['udid'] == target_id:
            # Extract version from runtime string like 'com.apple.CoreSimulator.SimRuntime.iOS-18-1'
            version = runtime.split('iOS-')[-1].replace('-', '.')
            print(version)
            break
")

if [ -z "$SIMULATOR_OS" ]; then
    echo "Debug - Fallback: Getting latest iOS runtime version"
    # Fallback to getting the latest available iOS version
    SIMULATOR_OS=$(xcrun simctl list runtimes | grep -E "iOS.*available" | tail -1 | grep -Eo '[0-9]+\.[0-9]+')
fi

# Debug output
echo "Debug - Extracted name: '$SIMULATOR_NAME'"
echo "Debug - Extracted OS version: '$SIMULATOR_OS'"
echo "Debug - Full runtime list:"
xcrun simctl list runtimes
echo "Debug - Device JSON for simulator:"
echo "$DEVICE_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
target_id = '$SIMULATOR_ID'
for runtime, devices in data['devices'].items():
    for device in devices:
        if device['udid'] == target_id:
            print(f'Runtime: {runtime}')
            print(f'Device: {device}')
"

# Verify we have both name and OS version
if [ -z "$SIMULATOR_NAME" ] || [ -z "$SIMULATOR_OS" ]; then
    echo "❌ Error: Could not determine simulator name or OS version"
    echo "Name: $SIMULATOR_NAME"
    echo "OS: $SIMULATOR_OS"
    echo "Available runtimes:"
    xcrun simctl list runtimes
    exit 1
fi

echo "📱 Using simulator: $SIMULATOR_NAME with iOS $SIMULATOR_OS"

# Get available destinations
echo "Debug - Getting available destinations..."
DESTINATIONS=$(xcodebuild -showdestinations -scheme "$SCHEME")

# Extract a valid destination from the list
DESTINATION_INFO=$(echo "$DESTINATIONS" | grep "platform:iOS Simulator" | grep -v "Any iOS Simulator Device" | head -1)

# Extract components from the destination info
DEST_OS=$(echo "$DESTINATION_INFO" | grep -Eo "OS:[0-9]+\.[0-9]+" | cut -d: -f2)
DEST_NAME=$(echo "$DESTINATION_INFO" | grep -Eo "name:[^,}]+" | cut -d: -f2 | xargs)

echo "Debug - Selected destination OS: $DEST_OS"
echo "Debug - Selected destination name: $DEST_NAME"

# Function to perform build
perform_build() {
    local clean=$1
    local build_cmd="xcodebuild -scheme \"$SCHEME\" \
        -sdk iphonesimulator \
        -destination \"platform=iOS Simulator,OS=$DEST_OS,name=$DEST_NAME\""
    
    if [ "$clean" = true ]; then
        echo "🧹 Cleaning and rebuilding..."
        build_cmd="$build_cmd clean build"
    else
        echo "🏗️ Building project (using cache)..."
        build_cmd="$build_cmd build"
    fi
    
    BUILD_OUTPUT=$(eval "$build_cmd" 2>&1)
    
    # Check for errors
    if echo "$BUILD_OUTPUT" | grep -q "error:"; then
        echo "❌ Build failed with errors:"
        echo "$BUILD_OUTPUT" | grep -A 5 "error:"
        return 1
    fi
    
    # Check for warnings
    if echo "$BUILD_OUTPUT" | grep -q "warning:"; then
        echo "⚠️ Build succeeded with warnings:"
        echo "$BUILD_OUTPUT" | grep -A 5 "warning:"
    fi
    
    echo "✅ Build succeeded!"
    return 0
}

# First try building without cleaning
perform_build false

# If the first build failed, try cleaning and rebuilding
if [ $? -ne 0 ]; then
    echo "🔄 Initial build failed, trying clean build..."
    perform_build true
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi 