#!/bin/bash
#
# Restore Loopback to Native macOS State
# This script removes all network services on lo0 and restores
# the loopback interface to its default configuration
# Uses only native macOS commands - no installations required
#

set -e  # Exit on any error

echo "🔄 Restoring loopback interface to native macOS state..."

# Step 1: Find all network services on lo0
echo "  → Finding network services on lo0..."
LOOPBACK_SERVICES=()

for service in $(networksetup -listallnetworkservices | grep -v "^An asterisk" | grep -v "^\*"); do
    # Check if this service is on lo0
    if networksetup -listnetworkserviceorder | grep -A1 "^([0-9]*) $service$" | grep -q "Device: lo0"; then
        LOOPBACK_SERVICES+=("$service")
        echo "  ✓ Found service on lo0: $service"
    fi
done

# Also check for disabled services
for service in $(networksetup -listallnetworkservices | grep "^\*" | sed 's/^\*//'); do
    # Check if this service is on lo0
    if networksetup -listnetworkserviceorder | grep -A1 "^([\*0-9]*) $service$" | grep -q "Device: lo0"; then
        LOOPBACK_SERVICES+=("$service")
        echo "  ✓ Found disabled service on lo0: $service"
    fi
done

# Step 2: Remove all network services from lo0
if [ ${#LOOPBACK_SERVICES[@]} -eq 0 ]; then
    echo "  ℹ️  No network services found on lo0"
else
    echo "  → Removing network services from lo0..."
    
    # Get the count and last index
    total_count=${#LOOPBACK_SERVICES[@]}
    last_index=$((total_count - 1))
    
    # Remove all but the last service
    for ((i=0; i<last_index; i++)); do
        service="${LOOPBACK_SERVICES[$i]}"
        echo "    - Removing: $service"
        sudo networksetup -removenetworkservice "$service"
    done
    
    # For the last service, we need to directly edit the preferences.plist
    # because macOS won't let us remove the last service on lo0
    last_service="${LOOPBACK_SERVICES[$last_index]}"
    echo "    - Removing final service: $last_service"
    
    # Convert plist to XML, find the UUID, then remove it
    PLIST_FILE="/Library/Preferences/SystemConfiguration/preferences.plist"
    
    # Create a temporary XML version
    TEMP_XML="/tmp/preferences_temp_$$.xml"
    sudo plutil -convert xml1 "$PLIST_FILE" -o "$TEMP_XML"
    
    # Find the UUID for the service - look for the service name in XML
    # The structure is: <key>UUID</key> followed by <dict> containing <key>UserDefinedName</key><string>ServiceName</string>
    SERVICE_UUID=$(sudo awk -v service="$last_service" '
        /<key>[A-F0-9-]+<\/key>/ {uuid=$0; gsub(/.*<key>|<\/key>.*/, "", uuid)}
        /<key>UserDefinedName<\/key>/ {getline; if ($0 ~ service) print uuid}
    ' "$TEMP_XML" | head -1)
    
    sudo rm -f "$TEMP_XML"
    
    if [ -n "$SERVICE_UUID" ]; then
        echo "    ✓ Found service UUID: $SERVICE_UUID"
        
        # Remove from NetworkServices
        sudo /usr/libexec/PlistBuddy -c "Delete :NetworkServices:$SERVICE_UUID" \
            "$PLIST_FILE" 2>/dev/null || true
        
        # Find all Sets and remove from ServiceOrder
        SET_COUNT=$(sudo /usr/libexec/PlistBuddy -c "Print :Sets" "$PLIST_FILE" 2>/dev/null | grep "Dict {" | wc -l)
        
        for ((set_idx=0; set_idx<SET_COUNT; set_idx++)); do
            # Get the set key name
            SET_KEY=$(sudo /usr/libexec/PlistBuddy -c "Print :Sets" "$PLIST_FILE" 2>/dev/null | \
                grep -E "^    [A-F0-9-]+ = Dict" | sed -n "$((set_idx+1))p" | awk '{print $1}')
            
            if [ -n "$SET_KEY" ]; then
                # Count service orders in this set
                ORDER_COUNT=$(sudo /usr/libexec/PlistBuddy -c "Print :Sets:$SET_KEY:Network:Global:IPv4:ServiceOrder" "$PLIST_FILE" 2>/dev/null | grep "    " | wc -l)
                
                # Find and remove the UUID from ServiceOrder
                for ((order_idx=0; order_idx<ORDER_COUNT; order_idx++)); do
                    ORDER_UUID=$(sudo /usr/libexec/PlistBuddy -c "Print :Sets:$SET_KEY:Network:Global:IPv4:ServiceOrder:$order_idx" "$PLIST_FILE" 2>/dev/null || echo "")
                    
                    if [ "$ORDER_UUID" = "$SERVICE_UUID" ]; then
                        sudo /usr/libexec/PlistBuddy -c "Delete :Sets:$SET_KEY:Network:Global:IPv4:ServiceOrder:$order_idx" \
                            "$PLIST_FILE" 2>/dev/null || true
                        break
                    fi
                done
            fi
        done
        
        echo "    ✓ Removed $last_service"
    else
        echo "    ⚠️  Could not find UUID for $last_service"
    fi
fi

# Step 3: Remove any additional IP addresses from lo0 (keep only 127.0.0.1)
echo "  → Cleaning IP addresses on lo0..."
CURRENT_IPS=$(ifconfig lo0 | grep "inet " | awk '{print $2}')

for ip in $CURRENT_IPS; do
    if [ "$ip" != "127.0.0.1" ]; then
        echo "    - Removing IP: $ip"
        sudo ifconfig lo0 -alias "$ip"
    fi
done

echo "  ✓ Only 127.0.0.1 remains on lo0"

# Step 4: Reload network configuration
echo "  → Reloading network configuration..."
sudo killall -HUP configd 2>/dev/null || true

sleep 2

echo ""
echo "✅ Loopback interface restored to native macOS state!"
echo ""
echo "Current lo0 configuration:"
ifconfig lo0 | grep -E "flags|inet "
echo ""
echo "Network services:"
networksetup -listallnetworkservices
echo ""
