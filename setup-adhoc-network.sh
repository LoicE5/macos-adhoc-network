#!/bin/bash
#
# Setup Ad Hoc Network Service
# This script finds the active internet connection, saves it, 
# and intelligently manages the loopback network service
#

set -e  # Exit on any error

# File to store the active network service and state
STATE_FILE="$HOME/.adhoc-network-state"

echo "🔧 Setting up Ad Hoc network service..."

# Find the network service that currently has internet connection
echo "  → Finding active internet connection..."
ACTIVE_SERVICE=$(networksetup -listnetworkserviceorder | grep -B1 "$(route -n get default 2>/dev/null | grep 'interface:' | awk '{print $2}')" | grep '([0-9])' | sed 's/^([0-9]*) //' | head -1)

if [ -z "$ACTIVE_SERVICE" ]; then
    echo "  ⚠️  No active internet connection found. Checking all services..."
    # Try to find first enabled service with IP
    for service in $(networksetup -listallnetworkservices | grep -v "^An asterisk" | grep -v "^\*"); do
        if networksetup -getinfo "$service" 2>/dev/null | grep -q "IP address:"; then
            ACTIVE_SERVICE="$service"
            break
        fi
    done
fi

if [ -z "$ACTIVE_SERVICE" ]; then
    echo "  ❌ Could not find any active network service"
    exit 1
fi

echo "  ✓ Found active service: $ACTIVE_SERVICE"

# Step 1: Check if there's already a network service on lo0
echo "  → Checking for existing service on lo0..."
LOOPBACK_SERVICE=""

# Get all services and check which one is on lo0
for service in $(networksetup -listallnetworkservices | grep -v "^An asterisk" | grep -v "^\*"); do
    # Check if this service is on lo0
    if networksetup -listnetworkserviceorder | grep -A1 "^([0-9]*) $service$" | grep -q "Device: lo0"; then
        LOOPBACK_SERVICE="$service"
        echo "  ✓ Found existing service on lo0: $LOOPBACK_SERVICE"
        break
    fi
done

# If no service exists on lo0, create AdHoc
if [ -z "$LOOPBACK_SERVICE" ]; then
    echo "  → Creating AdHoc network service on lo0..."
    sudo networksetup -createnetworkservice "AdHoc" lo0 2>/dev/null || {
        echo "  ⚠️  Failed to create service, checking if it exists..."
        LOOPBACK_SERVICE="AdHoc"
    }
    LOOPBACK_SERVICE="AdHoc"
    echo "  ✓ Created service: $LOOPBACK_SERVICE"
fi

# Step 2: Check if there's any IP address other than 127.0.0.1 on that service
echo "  → Checking IP addresses on $LOOPBACK_SERVICE..."
SERVICE_INFO=$(sudo networksetup -getinfo "$LOOPBACK_SERVICE" 2>/dev/null || echo "")
CURRENT_IP=$(echo "$SERVICE_INFO" | grep "IP address:" | awk '{print $3}')

NO_DELETION="no"

if [ -n "$CURRENT_IP" ] && [ "$CURRENT_IP" != "127.0.0.1" ]; then
    echo "  ✓ Service already has IP: $CURRENT_IP"
    echo "  ℹ️  Will not modify existing IP configuration"
    NO_DELETION="yes"
else
    echo "  → Configuring $LOOPBACK_SERVICE with IP 10.10.10.1..."
    sudo networksetup -setmanual "$LOOPBACK_SERVICE" 10.10.10.1 255.255.255.255
    echo "  ✓ IP configured"
    NO_DELETION="no"
fi

# Save state to file: ACTIVE_SERVICE|LOOPBACK_SERVICE|NO_DELETION
echo "$ACTIVE_SERVICE|$LOOPBACK_SERVICE|$NO_DELETION" > "$STATE_FILE"
echo "  ✓ Saved state to: $STATE_FILE"

echo ""
echo "✅ Ad Hoc network service setup complete!"
echo ""
echo "Active internet service: $ACTIVE_SERVICE"
echo "Loopback service name: $LOOPBACK_SERVICE"
echo "IP preservation mode: $NO_DELETION"
echo ""
echo "📝 Next steps:"
echo "   1. Go to System Settings > General > Sharing > Internet Sharing"
echo "   2. Share connection from: $LOOPBACK_SERVICE"
echo "   3. To computers using: Wi-Fi"
echo "   4. Enable Internet Sharing"
echo ""
