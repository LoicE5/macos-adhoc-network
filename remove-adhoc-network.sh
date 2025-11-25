#!/bin/bash
#
# Remove Ad Hoc Network Service
# This script stops the hotspot, re-enables the original internet connection,
# and conditionally removes IP configuration based on saved state
#

set -e  # Exit on any error

# File to store the active network service
STATE_FILE="$HOME/.adhoc-network-state"

echo "🗑️  Removing Ad Hoc network configuration..."

# Stop Internet Sharing / Hotspot
echo "  → Disabling Internet Sharing..."

# First, disable via System Preferences (works for macOS 13+)
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.nat NAT -dict Enabled -int 0

# Also disable the AirPort/WiFi sharing component
sudo /usr/libexec/PlistBuddy -c 'Set :NAT:Enabled 0' \
    /Library/Preferences/SystemConfiguration/com.apple.nat.plist 2>/dev/null || true

sudo /usr/libexec/PlistBuddy -c 'Set :NAT:AirPort:Enabled 0' \
    /Library/Preferences/SystemConfiguration/com.apple.nat.plist 2>/dev/null || true

# Stop the Internet Sharing service
sudo launchctl stop com.apple.InternetSharing 2>/dev/null || true
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.InternetSharing.plist 2>/dev/null || true

# Ensure bootpd (part of Internet Sharing) is also stopped
sudo launchctl stop com.apple.bootpd 2>/dev/null || true

# Kill any remaining Internet Sharing processes
sudo killall -TERM InternetSharing 2>/dev/null || true

# Give the system time to process the changes
sleep 1

echo "  ✓ Internet Sharing disabled"

# Read state from file
if [ -f "$STATE_FILE" ]; then
    STATE_DATA=$(cat "$STATE_FILE")
    ORIGINAL_SERVICE=$(echo "$STATE_DATA" | cut -d'|' -f1)
    LOOPBACK_SERVICE=$(echo "$STATE_DATA" | cut -d'|' -f2)
    NO_DELETION=$(echo "$STATE_DATA" | cut -d'|' -f3)
    
    echo "  ✓ Read state:"
    echo "    - Original service: $ORIGINAL_SERVICE"
    echo "    - Loopback service: $LOOPBACK_SERVICE"
    echo "    - IP preservation mode: $NO_DELETION"
else
    echo "  ⚠️  State file not found ($STATE_FILE)"
    echo "      Cannot determine configuration details"
    NO_DELETION="yes"  # Default to safe mode - don't delete anything
fi

# Re-enable the original network service
if [ -n "$ORIGINAL_SERVICE" ]; then
    echo "  → Re-enabling original service: $ORIGINAL_SERVICE"
    
    # Check if service is disabled (has asterisk)
    if networksetup -listallnetworkservices | grep -q "^\*$ORIGINAL_SERVICE$"; then
        sudo networksetup -setnetworkserviceenabled "$ORIGINAL_SERVICE" on
        echo "  ✓ Service re-enabled"
    else
        echo "  ℹ️  Service is already enabled"
    fi
fi

# Handle IP address based on NO_DELETION flag
if [ -n "$LOOPBACK_SERVICE" ]; then
    if [ "$NO_DELETION" = "yes" ]; then
        echo "  ℹ️  Preserving existing IP configuration on $LOOPBACK_SERVICE"
        echo "      (IP was already configured before setup)"
    else
        echo "  → Removing IP configuration from $LOOPBACK_SERVICE..."
        # Set to DHCP to clear manual IP configuration
        sudo networksetup -setdhcp "$LOOPBACK_SERVICE" 2>/dev/null || \
            echo "  ⚠️  Could not set DHCP (service may not support it)"
        echo "  ✓ IP configuration cleared"
    fi
    
    echo "  ℹ️  Network service '$LOOPBACK_SERVICE' preserved (not removed)"
fi

# Restore NAT configuration to default
echo "  → Restoring NAT configuration..."
sudo /usr/libexec/PlistBuddy -c 'Set :NAT:PrimaryInterface:Device lo0' \
    /Library/Preferences/SystemConfiguration/com.apple.nat.plist 2>/dev/null || true

# Clean up state file
if [ -f "$STATE_FILE" ]; then
    rm "$STATE_FILE"
    echo "  ✓ State file cleaned up"
fi

echo ""
echo "✅ Ad Hoc configuration removed successfully!"
echo ""
if [ -n "$ORIGINAL_SERVICE" ]; then
    echo "Original service '$ORIGINAL_SERVICE' has been re-enabled."
fi
if [ -n "$LOOPBACK_SERVICE" ]; then
    echo "Loopback service '$LOOPBACK_SERVICE' has been preserved."
fi
echo ""
echo "Verifying Internet Sharing status..."
IS_ENABLED=$(sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.nat NAT 2>/dev/null | grep "Enabled" | head -1 | grep -o "[01]" || echo "0")
if [ "$IS_ENABLED" = "0" ]; then
    echo "  ✓ Internet Sharing is DISABLED in System Settings"
else
    echo "  ⚠️  Internet Sharing may still be enabled - please check System Settings"
fi
echo ""
