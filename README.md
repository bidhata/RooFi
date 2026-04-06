# RooFi - Advanced WiFi Manager

```text
 ____   __    __  ____  __  
(  _ \ /  \  /  \(  __)(  ) 
 )   /(  O )(  O )) _)  )(  
(__\_) \__/  \__/(__)  (__) 
```

**Author:** [@bidhata](https://github.com/bidhata)  
**Version:** 3.2  
**Email:** me@krishnendu.com  
**License:** GNU GPL 2.0

---

## 📌 Overview

RooFi is a powerful, user-friendly WiFi manager for Linux and OpenWrt that works via command-line interface. It provides both an interactive menu and CLI commands for automation, supporting NetworkManager (Linux) and UCI (OpenWrt) backends.

### Key Features
- 🔍 Scan & list WiFi networks with signal strength bars
- 🔑 Connect to networks (open, WPA2, WPA3)
- 📶 Show detailed connection status
- 🔄 Auto-detect backend (nmcli or OpenWrt UCI)
- 🌐 Dual platform support (Linux & OpenWrt)
- 🔥 WiFi Hotspot creation (AP mode)
- ⚡ Power management (TX power, power saving)
- 🖥 POSIX shell compatible (bash, ash, dash, sh)
- 💻 Full CLI mode for automation & scripting
- 📝 Configuration file support
- 📚 Connection history tracking (auto-saved on connect)
- 🔄 Auto-connect to known networks
- 📊 TUI live monitor (htop-like, v3.2)
- 💾 Network profiles with quick switching (v3.2)
- 🛡 Priority-based auto-reconnect & fallback (v3.2)
- 🗒 Comprehensive logging with rotation & export (v3.2)
- 🕵️ NAC bypass: MAC spoofing, captive portal bypass, DHCP fingerprint spoofing (v3.2)

---

## 📁 File Structure

```
RooFi/
├── RooFi.sh              # Core interactive + CLI manager (v3.2)
├── roofi-advanced.sh     # Advanced features: TUI, profiles, logging (v3.2)
├── ADVANCED_FEATURES.md  # Detailed guide for v3.2 features
├── LICENSE               # GNU GPL 2.0
└── README.md             # This file
```

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
chmod +x RooFi.sh roofi-advanced.sh
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
sudo cp RooFi.sh /usr/local/bin/roofi
sudo cp roofi-advanced.sh /usr/local/bin/roofi-advanced
chmod +x /usr/local/bin/roofi /usr/local/bin/roofi-advanced
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

### CLI Mode (RooFi.sh / roofi)
```bash
roofi --scan                    # Scan and list networks
roofi --connect "NetworkName"   # Connect to network (prompts for password)
roofi --disconnect              # Disconnect
roofi --status                  # Show current status
roofi --auto-connect            # Auto-connect to known networks (from history)
roofi --list-interfaces         # List WiFi interfaces
roofi --interface wlan1 --scan  # Use a specific interface
roofi --help                    # Show help
roofi --version                 # Show version
```

### Advanced CLI (roofi-advanced.sh)
```bash
roofi-advanced --tui                          # Live TUI monitor
roofi-advanced --save-profile home "HomeNet"  # Save a network profile
roofi-advanced --connect-profile home         # Connect using profile
roofi-advanced --list-profiles                # List all profiles
roofi-advanced --add-fallback "HomeNet" 1     # Add fallback network (priority 1)
roofi-advanced --auto-reconnect               # Try fallback networks
roofi-advanced --start-monitor                # Start background monitor daemon
roofi-advanced --stop-monitor                 # Stop monitor daemon
roofi-advanced --export-logs [file]           # Export debug logs
roofi-advanced --view-logs                    # View recent logs
```

### NAC Bypass CLI (roofi-advanced.sh)
```bash
roofi-advanced --mac-random [IFACE]           # Randomize MAC address
roofi-advanced --mac-clone MAC [IFACE]        # Clone a specific MAC address
roofi-advanced --mac-restore [IFACE]          # Restore original MAC address
roofi-advanced --portal-detect                # Detect captive portal
roofi-advanced --portal-bypass                # Attempt captive portal bypass
roofi-advanced --spoof-dhcp TYPE [IFACE]      # Spoof DHCP fingerprint
                                              # Types: printer, phone, iphone,
                                              #        windows, linux, iot
roofi-advanced --random-hostname              # Randomize system hostname
roofi-advanced --restore-hostname             # Restore original hostname
roofi-advanced --nac-bypass                   # Full automated NAC bypass
roofi-advanced --nac-restore                  # Restore all NAC changes
```

---

## 📖 CLI Examples

**Scan for networks:**
```bash
$ roofi --scan
Scanning for WiFi Networks...

SSID                          SIGNAL        SECURITY       CHANNEL
───────────────────────────────────────────────────────
HomeNetwork                   ████████░░ 80% WPA2           6
OfficeWiFi                    ██████░░░░ 65% WPA2           11
CoffeeShop                    ███░░░░░░░ 35% Open           1
```

**Connect to network:**
```bash
$ roofi --connect "HomeNetwork"
Enter WiFi password for 'HomeNetwork': ********
Successfully connected to HomeNetwork!
```

**Check status:**
```bash
$ roofi --status
Current WiFi Status:
───────────────────────────────────────────────────────
Interface Details:
  GENERAL.DEVICE: wlan0
  GENERAL.STATE:  100 (connected)
  IP4.ADDRESS:    192.168.1.100/24
```

**Auto-connect from history:**
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

# Color scheme (default/minimal/none)
COLOR_SCHEME="default"
```

### File Structure
```
~/.config/roofi/
├── roofi.conf          # Configuration file
├── history             # Connection history (SSIDs only, no passwords)
├── favorites           # Favorite networks
├── roofi.log           # Operation log (v3.2)
├── fallback_networks   # Fallback priority list (v3.2)
├── monitor.pid         # Monitor daemon PID (v3.2)
├── original_mac        # Saved MAC before spoofing (v3.2)
├── original_hostname   # Saved hostname before spoofing (v3.2)
└── profiles/           # Network profiles (v3.2)
    ├── home.profile
    ├── office.profile
    └── cafe.profile
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
*/5 * * * * /usr/local/bin/roofi-advanced --auto-reconnect >> /var/log/roofi.log 2>&1
```

### Profile Switching by Location
```bash
#!/bin/sh
case "$(hostname)" in
    laptop-home)   roofi-advanced --connect-profile home ;;
    laptop-office) roofi-advanced --connect-profile office ;;
    *)             roofi-advanced --auto-reconnect ;;
esac
```

### Systemd Service (Connection Monitor)
```ini
[Unit]
Description=RooFi Connection Monitor
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/roofi-advanced --start-monitor
ExecStop=/usr/local/bin/roofi-advanced --stop-monitor
Restart=on-failure

[Install]
WantedBy=multi-user.target
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
```

### Script won't run
```bash
chmod +x RooFi.sh roofi-advanced.sh
```

### Config not loading
```bash
mkdir -p ~/.config/roofi
ls -la ~/.config/roofi/
```

### History not saving
```bash
ls -la ~/.config/roofi/history
chmod 644 ~/.config/roofi/history
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

| Operation              | Time     | Memory |
|------------------------|----------|--------|
| Config initialization  | <0.1s    | <1MB   |
| CLI commands           | <0.1s    | <1MB   |
| History operations     | <0.01s   | <1KB   |
| TUI refresh            | 2s cycle | <5MB   |
| Profile load           | <0.01s   | <1KB   |
| Auto-reconnect         | 1–5s     | <2MB   |
| Monitor daemon         | 30s cycle| <2MB   |
| Log export             | <0.1s    | <1MB   |

---

## 🔒 Security

- ✅ Passwords never stored in plain text
- ✅ Hidden password input (`stty -echo`)
- ✅ User-only file permissions (600 on profiles)
- ✅ No credential exposure in process list
- ✅ Secure temp file handling
- ✅ History contains only SSIDs (no credentials)
- ✅ Log rotation prevents disk exhaustion
- ✅ Original MAC/hostname saved & restorable after NAC bypass
- ✅ Generated MACs use locally-administered unicast bit (IEEE-compliant)
- ⚠️ Profile passwords are base64-obfuscated (not encrypted) — use system keyring for high-security environments
- ⚠️ NAC bypass features are for authorized testing/research only — may violate ToS or local laws

---

## 📋 Changelog

### Version 3.2 (Current)

**Added:**
- `roofi-advanced.sh` — TUI live monitor, network profiles, auto-reconnect, logging
- TUI mode: real-time connection status, signal meter, network list, system stats
- Network profiles: save/load credentials, `chmod 600` protected
- Priority-based fallback networks & 30-second background monitor daemon
- Logging system with 1MB auto-rotation and debug log export
- `clear_logs()` function for log housekeeping
- **NAC Bypass module** (requested by [Encryption.is.everything24](https://www.facebook.com/Encryption.is.everything24)):
  - MAC address randomization, cloning, and restore
  - Captive portal detection & auto-bypass (DNS override + form submission)
  - DHCP fingerprint spoofing (printer, phone, iPhone, Windows, Linux, IoT presets)
  - Hostname randomization & restore
  - Full automated NAC bypass sequence (`--nac-bypass`) and restore (`--nac-restore`)
  - Zero additional dependencies — uses only `ip`, `iw`, `curl`/`wget`, `hostname`

**Fixed:**
- Removed duplicate global variable declarations in `RooFi.sh`
- `parse_arguments` is now correctly called at startup — CLI flags (`--scan`, `--status`, etc.) work when running `RooFi.sh` directly
- `--connect "SSID"` no longer shows the interactive network picker; connects directly to the named SSID
- `--scan` and `--status` no longer clear the screen or block on "Press Enter" in CLI mode
- `add_to_history()` is now called after every successful connection in interactive mode
- `export_logs ""` no longer writes to a file literally named `""` (empty-string arg bug)
- `connect_profile()` no longer throws a "unary operator expected" error when no WiFi backend is installed

### Version 3.1

**Added:**
- Command-line interface with 8 commands
- Configuration file support (`~/.config/roofi/roofi.conf`)
- Connection history tracking
- Auto-connect feature
- Network quality indicators
- Multiple interface support

**Changed:**
- Enhanced network listing with frequency/quality
- Improved interface detection

### Version 3.0

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

**Security:**
- Passwords no longer exposed in process list
- Secure temp file handling

### Version 2.2 (Legacy)

- Basic WiFi management via nmcli
- Network scanning and connection
- Signal strength visualization
- Saved network management
- Hotspot creation

---

## 🔮 Future Roadmap (v3.3+)

- [x] ~~MAC address randomization~~ *(done in v3.2)*
- [x] ~~NAC bypass toolkit~~ *(done in v3.2)*
- [ ] GPG-encrypted profile storage
- [ ] QR code generation for hotspot sharing
- [ ] Speed test integration
- [ ] Bandwidth monitoring
- [ ] 802.1X bypass (optional `wpa_supplicant` integration)
- [ ] Connection profiles (static IP, DNS, etc.)
- [ ] Email/webhook notifications on reconnect
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
- **v3.0:** OpenWrt support, POSIX compatibility
- **v3.1:** CLI interface, configuration, history
- **v3.2:** TUI mode, profiles, auto-reconnect, logging, bug fixes
- **NAC Bypass:** Feature requested by [Encryption.is.everything24](https://www.facebook.com/Encryption.is.everything24)

---

## 📄 License

This project is licensed under the GNU General Public License v2.0 — see the [LICENSE](LICENSE) file for details.

---

❤️ RooFi was born out of frustration while managing WiFi over SSH and TTY sessions.  
Hopefully it makes your CLI WiFi management **simple and beautiful**!

**⭐ If you find RooFi useful, please star the repository!**

👉 [Visit the Repository](https://github.com/bidhata/RooFi)
