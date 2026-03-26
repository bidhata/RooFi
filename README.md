# RooFi - Advanced WiFi Manager

```text
 ____   __    __  ____  __  
(  _ \ /  \  /  \(  __)(  ) 
 )   /(  O )(  O )) _)  )(  
(__\_) \__/  \__/(__)  (__) 
```

**Author:** [@bidhata](https://github.com/bidhata)  
**Version:** 3.1  
**Email:** me@krishnendu.com  
**License:** GNU GPL 2.0

---

## 📌 Overview

RooFi is a powerful, user-friendly WiFi manager for Linux and OpenWrt that works via command-line interface. It provides both an interactive menu and CLI commands for automation, supporting NetworkManager (Linux) and UCI (OpenWrt) backends.

### Key Features
- 🔍 Scan & list WiFi networks with signal strength bars
- 🔑 Connect to networks (open, WPA2, WPA3)
- 📶 Show detailed connection status
- 🔄 Auto-detect backend (nmcli or OpenWrt)
- 🌐 Dual platform support (Linux & OpenWrt)
- 🔥 WiFi Hotspot creation (AP mode)
- ⚡ Power management (TX power, power saving)
- 🖥 POSIX shell compatible (bash, ash, dash, sh)
- 💻 CLI mode for automation & scripting
- 📝 Configuration file support
- 📚 Connection history tracking
- 🔄 Auto-connect to known networks

---

## 🚀 Quick Start

### Linux (Ubuntu/Debian/Fedora/Arch)
```bash
# Install dependencies
sudo apt install network-manager iw  # Debian/Ubuntu
# OR
sudo dnf install NetworkManager iw   # Fedora
# OR
sudo pacman -S networkmanager iw     # Arch

# Clone and run
git clone https://github.com/bidhata/RooFi.git
cd RooFi
chmod +x RooFi.sh roofi-cli.sh
./RooFi.sh  # Interactive mode
```

### OpenWrt
```bash
# Install dependencies
opkg update && opkg install iwinfo iw

# Download and run
wget https://raw.githubusercontent.com/bidhata/RooFi/main/RooFi.sh
chmod +x RooFi.sh
./RooFi.sh
```

### System-Wide Installation
```bash
# Install CLI wrapper
sudo cp roofi-cli.sh /usr/local/bin/roofi
roofi --help
```

---

## 💻 Usage

### Interactive Mode
```bash
./RooFi.sh
```

Interactive menu with options:
1. Show WiFi Status
2. List Available Networks
3. Connect to Network
4. Disconnect from Network
5. Show Saved Networks
6. Turn WiFi On/Off
7. Show Network Details
8. Power Management
9. Advanced Options
10. Hotspot
11. Exit

### CLI Mode (v3.1)
```bash
roofi --scan                    # Scan and list networks
roofi --connect "NetworkName"   # Connect to network
roofi --disconnect              # Disconnect
roofi --status                  # Show current status
roofi --auto-connect            # Auto-connect to known networks
roofi --list-interfaces         # List WiFi interfaces
roofi --help                    # Show help
roofi --version                 # Show version
```

### CLI Examples

**Scan for networks:**
```bash
$ roofi --scan
Available Networks:
SSID              SIGNAL  SECURITY      FREQ
HomeNetwork       ████    WPA2          2437 MHz
OfficeWiFi        ███_    WPA2          5180 MHz
CoffeeShop        ██__    Open          2412 MHz
```

**Connect to network:**
```bash
$ roofi --connect "HomeNetwork"
Enter password for 'HomeNetwork': ********
Successfully connected to HomeNetwork
```

**Check status:**
```bash
$ roofi --status
WiFi Status:
Interface: wlan0
State: connected
Connection: HomeNetwork
Signal: 85%
IP Address: 192.168.1.100
```

**Auto-connect:**
```bash
$ roofi --auto-connect
Attempting to connect to known networks...
Trying: HomeNetwork
Connected to HomeNetwork
```

---

## ⚙️ Configuration

### Configuration File
Location: `~/.config/roofi/roofi.conf`

```ini
# Preferred WiFi interface (leave empty for auto-detect)
PREFERRED_INTERFACE=""

# Auto-connect to known networks on startup
AUTO_CONNECT="no"

# Show frequency band in network list
SHOW_FREQUENCY="yes"

# Maximum history entries
MAX_HISTORY=10
```

### Connection History
Location: `~/.config/roofi/history`

- Automatically tracks connected networks
- Stores last 10 networks (configurable)
- Used by `--auto-connect` feature

### File Structure
```
~/.config/roofi/
├── roofi.conf          # Configuration file
├── history             # Connection history
└── favorites           # Favorite networks
```

---

## 🤖 Automation

### Auto-Connect on Boot
```bash
# Add to /etc/rc.local or systemd service
/usr/local/bin/roofi --auto-connect
```

### Connectivity Monitor (Cron)
```cron
# Check every 5 minutes, reconnect if needed
*/5 * * * * /usr/local/bin/roofi --status || /usr/local/bin/roofi --auto-connect
```

### Network Switching Script
```bash
#!/bin/sh
if [ "$(hostname)" = "laptop" ]; then
    roofi --connect "HomeNetwork"
else
    roofi --connect "OfficeWiFi"
fi
```

---

## 🌐 OpenWrt Deployment

### Installation
```bash
opkg update
opkg install iwinfo iw
wget https://raw.githubusercontent.com/bidhata/RooFi/main/RooFi.sh
chmod +x RooFi.sh
cp RooFi.sh /usr/bin/roofi
```

### Features on OpenWrt
- ✅ WiFi scanning (via `iwinfo` or `iw`)
- ✅ Network connection (via `uci`)
- ✅ WiFi radio control
- ✅ Hotspot creation (AP mode)
- ✅ Signal strength visualization
- ✅ Power management

### Backend Detection
RooFi automatically detects OpenWrt by checking for:
1. `uci` command availability
2. `/etc/config` directory existence

### Configuration Files
- `/etc/config/wireless` - WiFi configuration

### Troubleshooting OpenWrt

**WiFi interface not detected:**
```bash
iw dev
iwinfo
uci show wireless
```

**Cannot connect:**
```bash
uci get wireless.radio0.disabled
uci set wireless.radio0.disabled=0
uci commit wireless
wifi up
```

**Manual configuration:**
```bash
uci set wireless.@wifi-iface[0].ssid="NetworkName"
uci set wireless.@wifi-iface[0].encryption="psk2"
uci set wireless.@wifi-iface[0].key="password"
uci set wireless.@wifi-iface[0].mode="sta"
uci commit wireless
wifi reload
```

---

## 🔧 Requirements

### Standard Linux
- NetworkManager with `nmcli`
- `iw` tool (optional, for power management)
- POSIX-compatible shell (bash, dash, etc.)

### OpenWrt
- `uci` command (pre-installed)
- `iwinfo` or `iw` (recommended)
- `ash` shell (busybox, pre-installed)

---

## 🛠 Troubleshooting

### "No WiFi interface detected"
```bash
# Linux
nmcli device
iw dev

# OpenWrt
iw dev
iwinfo
```

### "No supported backend found"
```bash
# Linux: Install NetworkManager
sudo apt install network-manager

# OpenWrt: Already installed
```

### Script won't run
```bash
chmod +x RooFi.sh roofi-cli.sh
```

### Config not loading
```bash
# Check config exists
ls -la ~/.config/roofi/

# Create if needed
mkdir -p ~/.config/roofi
```

### History not saving
```bash
# Check permissions
ls -la ~/.config/roofi/history
chmod 644 ~/.config/roofi/history
```

---

## 📋 Changelog

### Version 3.1 (March 2026)

**Added:**
- Command-line interface with 8 commands
- Configuration file support (`~/.config/roofi/roofi.conf`)
- Connection history tracking
- Auto-connect feature
- Network quality indicators
- Multiple interface support
- Hidden network improvements

**Changed:**
- Enhanced network listing with frequency/quality
- Improved interface detection

### Version 3.0 (2026)

**Added:**
- OpenWrt support (uci/iwinfo backend)
- POSIX shell compatibility (bash, ash, dash, sh)
- Dual backend architecture
- Signal strength conversion for OpenWrt

**Fixed:**
- Subshell counter bug in network selection
- Password exposure in CLI arguments
- Empty signal value handling
- Multi-word SSID parsing
- Exit code capture issues

**Security:**
- Passwords no longer exposed in process list
- Proper password cleanup
- Secure temp file handling

### Version 2.2 (Previous)

**Features:**
- Basic WiFi management via nmcli
- Network scanning and connection
- Signal strength visualization
- Saved network management
- WiFi radio control
- Power management
- Hotspot creation

---

## 🔒 Security

- ✅ Passwords never stored
- ✅ Hidden password input (`stty -echo`)
- ✅ User-only file permissions (600)
- ✅ No credential exposure in process list
- ✅ Secure temp file handling
- ✅ History contains only SSIDs (no credentials)

---

## 🧪 Testing

Run tests to verify installation:

```bash
# Basic compatibility test
./test_roofi.sh

# Comprehensive v3.1 test
./test_v3.1.sh
```

Expected output:
```
Total Tests: 43
Passed: 43
Failed: 0
✓ All tests passed!
```

---

## 🌍 Compatibility

### Platforms
- ✅ Ubuntu / Debian
- ✅ Fedora / RHEL / CentOS
- ✅ Arch Linux
- ✅ OpenWrt (19.07+, 21.02+ recommended)
- ✅ Raspberry Pi OS

### Shells
- ✅ bash
- ✅ sh (POSIX)
- ✅ dash
- ✅ ash (busybox)

### Backends
- ✅ nmcli (NetworkManager)
- ✅ uci/iwinfo (OpenWrt)

---

## 📊 Performance

| Operation | Time | Rating |
|-----------|------|--------|
| Config initialization | <0.1s | ⚡ Excellent |
| History operations | <0.01s | ⚡ Excellent |
| Config loading | <0.05s | ⚡ Excellent |
| CLI commands | <0.1s | ⚡ Excellent |

---

## 🔮 Future Roadmap (v3.2+)

Planned enhancements:
- [ ] QR code generation for hotspot sharing
- [ ] Speed test integration
- [ ] Bandwidth monitoring
- [ ] MAC address randomization
- [ ] Connection profiles (static IP, DNS, etc.)
- [ ] Export/import settings
- [ ] Desktop notifications
- [ ] Web UI (optional)

---

## 📞 Support

- **GitHub:** https://github.com/bidhata/RooFi
- **Issues:** https://github.com/bidhata/RooFi/issues
- **Email:** me@krishnendu.com

---

## 👏 Credits

- **Original Author:** Krishnendu Paul (@bidhata)
- **v3.0 Rewrite:** OpenWrt support, POSIX compatibility
- **v3.1 Enhancements:** CLI interface, configuration, history
- **License:** GNU GPL 2.0

---

## 📄 License

This project is licensed under the GNU General Public License v2.0 - see the [LICENSE](LICENSE) file for details.

---

## ❤️ Acknowledgments

RooFi was born out of frustration while managing WiFi over SSH and TTY sessions.  
Hopefully, it makes your CLI WiFi management **simple and beautiful**!

---

**⭐ If you find RooFi useful, please star the repository!**

👉 [Visit the Repository](https://github.com/bidhata/RooFi)
