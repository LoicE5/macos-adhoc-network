# macOS Internet Sharing Without Internet Connection

Three bash scripts to enable macOS Internet Sharing (Personal Hotspot) without requiring an actual internet connection. Perfect for creating local WiFi networks for development, testing, or device-to-device communication.

## ✨ Features

- **Zero dependencies** - Uses only native macOS commands
- **Smart & safe** - Preserves existing configurations
- **Reversible** - Easy setup and teardown
- **State tracking** - Remembers what was changed
- **Tested on macOS 13+** (Sonoma, Sequoia)

## 📋 The Scripts

### 1. setup-adhoc-network.sh

Creates or reuses a network service on the loopback interface and configures it for Internet Sharing.

**What it does:**

- Finds your active internet connection and saves it
- Creates "AdHoc" network service on `lo0` (or reuses existing)
- Assigns IP 10.10.10.1 if needed (preserves existing IPs)
- Saves state for safe removal

### 2. remove-adhoc-network.sh

Safely disables Internet Sharing and restores your original configuration.

**What it does:**

- Turns off Internet Sharing completely
- Re-enables your original internet connection
- Removes IP configuration (only if added by setup)
- Preserves the network service (doesn't delete it)

### 3. restore-loopback-native.sh

Completely resets the loopback interface to macOS defaults (optional cleanup).

**What it does:**

- Removes ALL network services from `lo0`
- Cleans all IP addresses except 127.0.0.1
- Restores pristine macOS state

## 🚀 Quick Start

### Installation

```bash
# Download the scripts
curl -O https://gist.github.com/[your-username]/[gist-id]/raw/setup-adhoc-network.sh
curl -O https://gist.github.com/[your-username]/[gist-id]/raw/remove-adhoc-network.sh
curl -O https://gist.github.com/[your-username]/[gist-id]/raw/restore-loopback-native.sh

# Make executable
chmod +x setup-adhoc-network.sh remove-adhoc-network.sh restore-loopback-native.sh
```

### Usage

#### Enable Internet Sharing

```bash
./setup-adhoc-network.sh
```

Then manually enable in System Settings:

1. Go to **System Settings > General > Sharing > Internet Sharing**
2. Share connection from: **AdHoc** (or the service name shown)
3. To computers using: **Wi-Fi**
4. Enable the toggle ✓

Your Mac will now broadcast a WiFi network without requiring internet!

#### Disable Internet Sharing

```bash
./remove-adhoc-network.sh
```

This will:

- ✓ Turn off Internet Sharing
- ✓ Re-enable your original internet service
- ✓ Clean up IP configuration (only what was added)
- ✓ Preserve the network service for future use

#### Complete Reset (Optional)

```bash
./restore-loopback-native.sh
```

Use this to completely remove all custom network services from `lo0` and restore to factory defaults.

## 🔍 How It Works

macOS requires an active network service with an IP address before allowing Internet Sharing. The trick:

1. **Creates a network service** on the loopback interface (`lo0`)
2. **Assigns a static IP** (10.10.10.1) to simulate an active connection
3. **macOS is tricked** into thinking there's internet available
4. **Internet Sharing becomes enabled** without requiring real internet

The scripts intelligently handle existing configurations, track changes, and provide safe cleanup.

## 🛠️ Technical Details

**All commands are native to macOS:**

- `networksetup` - Network configuration
- `ifconfig` - Interface configuration
- `/usr/libexec/PlistBuddy` - Property list editing
- `plutil` - Property list conversion
- `launchctl` - Service management
- `route` - Routing table
- Standard Unix tools: `grep`, `awk`, `sed`, `cut`, `killall`

**No installations required:**

- ✗ No Homebrew
- ✗ No Xcode Command Line Tools
- ✗ No Python or other languages
- ✓ Works on fresh macOS installation

## 📝 Requirements

- macOS 13+ (tested on Sonoma & Sequoia)
- Administrator (sudo) privileges
- Works on Intel and Apple Silicon Macs

## ⚠️ Important Notes

- The network service will remain visible in System Settings (this is normal and harmless)
- Internet Sharing will broadcast WiFi but won't provide actual internet access (as intended)
- Scripts require sudo password when run
- The `lo0` interface is only used for the trick - your actual network adapters are not affected

## 🎯 Use Cases

Perfect for:

- **Local development** - Test networked applications without internet
- **IoT device setup** - Connect devices that need WiFi configuration
- **Device-to-device communication** - Create ad-hoc networks
- **Testing** - Simulate network environments
- **Offline demos** - Present without relying on venue WiFi

## 🐛 Troubleshooting

### Internet Sharing won't enable

- Run `./remove-adhoc-network.sh` first to clean up
- Run `./setup-adhoc-network.sh` again
- Check System Settings to ensure the AdHoc service is selected

### Service not showing in Internet Sharing

- The service might be disabled - check System Settings > Network
- Run setup script again to recreate it

### Want to start completely fresh

- Run `./restore-loopback-native.sh` to reset everything
- Then run `./setup-adhoc-network.sh` to set up again

## 📖 Related Resources

- [Original Reddit Discussion](https://www.reddit.com/r/MacOS/comments/1p4hznt/how_to_enable_macos_internet_sharing_without/)
- [Apple's Internet Sharing Documentation](https://support.apple.com/guide/mac-help/share-internet-connection-mac-network-users-mchlp1540/mac)

## 📄 License

These scripts are provided as-is for educational and development purposes. Use at your own risk.

## 🙏 Credits

Created to solve the frustrating limitation of macOS Internet Sharing requiring an actual internet connection.

## 💬 Feedback

Questions, issues, or improvements? Leave a comment on the [Reddit thread](https://www.reddit.com/r/MacOS/comments/1p4hznt/how_to_enable_macos_internet_sharing_without/) or create an issue on this Gist!

---

**Last Updated:** November 2025
**Tested On:** macOS Sonoma 14.x, macOS Sequoia 15.x, Mac Studio M4 Max