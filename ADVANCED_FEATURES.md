# RooFi Advanced Features (v3.2)

## Overview

RooFi Advanced adds enterprise-grade features for power users and production environments:

1. **TUI Mode** - htop-like live monitoring interface
2. **Network Profiles** - Save and switch between network configurations
3. **Auto-Reconnect** - Intelligent fallback with priority-based reconnection
4. **Logging System** - Comprehensive logging and debug export

---

## 1. TUI Mode (Live Monitor)

### Launch TUI
```bash
./roofi-advanced.sh --tui
```

### Features
- Real-time connection status updates
- Live signal strength meter
- Available networks list (refreshes every 2s)
- System stats (uptime, load average)
- Monitor daemon status
- Interactive keyboard controls

### TUI Interface
```
╔═══════════════════════════════════════════════════════════════════════════╗
║                      RooFi v3.2 - Live Monitor                            ║
╚═══════════════════════════════════════════════════════════════════════════╝

Updated: 2026-03-27 19:25:00

Connection Status
───────────────────────────────────────────────────────────────────────────
Status:      CONNECTED
SSID:        HomeNetwork
Interface:   wlan0
Signal:      ▮▮▮▮▮▮▮▮▯▯  85%
Frequency:   2437 MHz
Security:    WPA2
IP Address:  192.168.1.100

Available Networks
───────────────────────────────────────────────────────────────────────────
HomeNetwork                    ▮▮▮▮▮▮▮▮▯▯  85%  WPA2
OfficeWiFi                     ▮▮▮▮▮▮▯▯▯▯  65%  WPA2
CoffeeShop                     ▮▮▮▯▯▯▯▯▯▯  35%  Open

System Stats
───────────────────────────────────────────────────────────────────────────
Uptime:       2 days, 5:30
Load Avg:     0.15, 0.20, 0.18
Monitor:      RUNNING (PID: 12345)

───────────────────────────────────────────────────────────────────────────
  [Q]uit  [R]econnect  [P]rofiles  [F]allback  [L]ogs  [E]xport
```

### Keyboard Controls
- **Q** - Quit TUI mode
- **R** - Trigger reconnect now
- **P** - Open profile management
- **F** - Configure fallback networks
- **L** - View logs
- **E** - Export logs

---

## 2. Network Profiles

### Save a Profile
```bash
# Interactive
./roofi-advanced.sh --save-profile home "HomeNetwork"
Enter password: ********
✓ Profile 'home' saved

# From menu
./roofi-advanced.sh
→ Advanced Features → Profile Management → Create new profile
```

### Connect Using Profile
```bash
# CLI
./roofi-advanced.sh --connect-profile home
✓ Connected to 'HomeNetwork' using profile 'home'

# From menu
./roofi-advanced.sh
→ Advanced Features → Profile Management → Connect using profile
```

### List Profiles
```bash
./roofi-advanced.sh --list-profiles

Saved Profiles:
───────────────────────────────────────────────────────
 1. home                 SSID: HomeNetwork        [🔒 Encrypted]
 2. office               SSID: OfficeWiFi         [🔒 Encrypted]
 3. cafe                 SSID: CoffeeShop         [Open]
```

### Profile File Structure
```
~/.config/roofi/profiles/
├── home.profile
├── office.profile
└── cafe.profile
```

### Profile File Format
```ini
# RooFi Network Profile
PROFILE_NAME="home"
SSID="HomeNetwork"
ENCRYPTED="yes"
CREATED="2026-03-27 19:00:00"
PASSWORD_ENCODED="base64encodedpassword"
```

### Use Cases
- Quick switching between home/office/public networks
- Pre-configured networks for different locations
- Automated deployment on multiple devices
- Backup network configurations

---

## 3. Auto-Reconnect & Fallback Logic

### Add Fallback Network
```bash
# Priority 1 (highest)
./roofi-advanced.sh --add-fallback "HomeNetwork" 1

# Priority 5 (medium)
./roofi-advanced.sh --add-fallback "OfficeWiFi" 5

# Priority 10 (lowest)
./roofi-advanced.sh --add-fallback "PublicWiFi" 10
```

### List Fallback Networks
```bash
./roofi-advanced.sh

Fallback Networks (by priority):
───────────────────────────────────────────────────────
 1. [Priority 1] HomeNetwork
 2. [Priority 5] OfficeWiFi
 3. [Priority 10] PublicWiFi
```

### Manual Auto-Reconnect
```bash
./roofi-advanced.sh --auto-reconnect

[INFO] Auto-reconnect initiated
[INFO] Trying fallback network: HomeNetwork (priority: 1)
[SUCCESS] Connected to fallback network: HomeNetwork
```

### Start Connection Monitor
```bash
# Start background daemon
./roofi-advanced.sh --start-monitor
✓ Connection monitor started (PID: 12345)

# Monitor checks connection every 30s
# Auto-reconnects if connection lost
```

### Stop Connection Monitor
```bash
./roofi-advanced.sh --stop-monitor
✓ Monitor stopped
```

### Reconnection Logic

1. **Check current connection** - If connected, do nothing
2. **Try fallback networks** - In priority order (1-10)
3. **Try saved profiles** - If fallback fails
4. **Log all attempts** - For debugging

### Use Cases
- **Roaming devices** - Laptop moving between locations
- **Unreliable networks** - Auto-reconnect on drops
- **Failover** - Primary network down, switch to backup
- **Unattended systems** - Servers/routers maintaining connectivity

---

## 4. Logging System

### View Logs
```bash
# CLI
./roofi-advanced.sh --view-logs

# From menu
./roofi-advanced.sh
→ Advanced Features → View Logs
```

### Export Logs
```bash
# Default filename (timestamped)
./roofi-advanced.sh --export-logs

# Custom filename
./roofi-advanced.sh --export-logs my_debug.log

# Output
✓ Logs exported to: my_debug.log
```

### Log File Location
```
~/.config/roofi/roofi.log
```

### Log Format
```
[2026-03-27 19:25:00] [INFO] TUI mode started
[2026-03-27 19:25:15] [INFO] Trying fallback network: HomeNetwork (priority: 1)
[2026-03-27 19:25:17] [SUCCESS] Connected to fallback network: HomeNetwork
[2026-03-27 19:26:00] [WARN] Connection lost - attempting auto-reconnect
[2026-03-27 19:26:05] [ERROR] Failed to connect to 'OfficeWiFi'
```

### Exported Log Contents
- System information (hostname, kernel, backend)
- RooFi operation logs
- NetworkManager status (Linux)
- UCI wireless config (OpenWrt)
- Timestamp and metadata

### Log Rotation
- Automatic rotation at 1MB
- Old log saved as `roofi.log.old`
- Prevents disk space issues

### Use Cases
- **Debugging** - Troubleshoot connection issues
- **Router diagnostics** - Export logs from headless systems
- **Support tickets** - Attach logs when reporting issues
- **Audit trail** - Track network changes

---

## Integration with Main RooFi

### Option 1: Standalone
```bash
# Use as separate tool
./roofi-advanced.sh --tui
./roofi-advanced.sh --connect-profile home
```

### Option 2: Source in RooFi.sh
Add to RooFi.sh:
```sh
# Load advanced features if available
if [ -f "$(dirname "$0")/roofi-advanced.sh" ]; then
    . "$(dirname "$0")/roofi-advanced.sh"
    # Add to main menu: "12) Advanced Features"
fi
```

---

## Complete CLI Reference

### Basic Commands (RooFi.sh)
```bash
roofi --scan
roofi --connect "SSID"
roofi --disconnect
roofi --status
roofi --auto-connect
roofi --list-interfaces
```

### Advanced Commands (roofi-advanced.sh)
```bash
roofi-advanced --tui
roofi-advanced --save-profile NAME SSID
roofi-advanced --connect-profile NAME
roofi-advanced --list-profiles
roofi-advanced --add-fallback SSID PRIORITY
roofi-advanced --auto-reconnect
roofi-advanced --start-monitor
roofi-advanced --stop-monitor
roofi-advanced --export-logs [FILE]
roofi-advanced --view-logs
```

---

## Automation Examples

### Boot Script with Fallback
```bash
#!/bin/sh
# /etc/rc.local

# Start connection monitor
/usr/local/bin/roofi-advanced --start-monitor

# Try to connect
/usr/local/bin/roofi-advanced --auto-reconnect
```

### Systemd Service
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

### Cron Job for Monitoring
```cron
# Check connection every 5 minutes
*/5 * * * * /usr/local/bin/roofi-advanced --auto-reconnect >> /var/log/roofi-cron.log 2>&1
```

### Profile Switching Script
```bash
#!/bin/sh
# Switch profiles based on location

case "$(hostname)" in
    laptop-home)
        roofi-advanced --connect-profile home
        ;;
    laptop-office)
        roofi-advanced --connect-profile office
        ;;
    *)
        roofi-advanced --auto-reconnect
        ;;
esac
```

---

## Security Notes

### Profile Storage
- Passwords are base64 encoded (obfuscation, not encryption)
- Profile files have 600 permissions (user-only)
- Not suitable for highly sensitive environments
- Consider using system keyring for production

### Recommendations
- Use WPA3 when available
- Rotate passwords regularly
- Limit profile sharing
- Review logs for unauthorized access attempts

---

## Performance

| Operation | Time | Memory |
|-----------|------|--------|
| TUI refresh | 2s | <5MB |
| Profile load | <0.01s | <1KB |
| Auto-reconnect | 1-5s | <2MB |
| Log export | <0.1s | <1MB |

---

## Troubleshooting

### TUI not updating
```bash
# Check if tput is available
command -v tput

# Install ncurses
sudo apt install ncurses-bin  # Linux
opkg install terminfo          # OpenWrt
```

### Monitor not starting
```bash
# Check if already running
cat ~/.config/roofi/monitor.pid
ps aux | grep roofi

# Kill old process
kill $(cat ~/.config/roofi/monitor.pid)
rm ~/.config/roofi/monitor.pid
```

### Profiles not working
```bash
# Check profiles directory
ls -la ~/.config/roofi/profiles/

# Check permissions
chmod 700 ~/.config/roofi/profiles
chmod 600 ~/.config/roofi/profiles/*.profile
```

### Logs not exporting
```bash
# Check log file
ls -lh ~/.config/roofi/roofi.log

# Check permissions
chmod 644 ~/.config/roofi/roofi.log
```

---

## Compatibility

- ✅ Linux (nmcli backend)
- ✅ OpenWrt (uci/iwinfo backend)
- ✅ POSIX shell (sh, ash, bash, dash)
- ✅ Works with RooFi v3.0/3.1
- ✅ Standalone or integrated

---

## 5. NAC Bypass

Network Access Control bypass module with **zero additional dependencies** — uses only `ip`, `iw`/`iwinfo`, `wget`/`curl`, and `hostname` (all pre-existing on Linux/OpenWrt).

> ⚠️ **Legal Notice:** These features are intended for authorized penetration testing, security research, and network management only. MAC spoofing and NAC bypass may violate terms of service or local laws.

### MAC Address Spoofing

#### Randomize MAC
```bash
# Generate a random locally-administered unicast MAC
./roofi-advanced.sh --mac-random

# Specify interface
./roofi-advanced.sh --mac-random wlan1
```

#### Clone a Specific MAC
```bash
# Clone an authorized device's MAC
./roofi-advanced.sh --mac-clone aa:bb:cc:dd:ee:ff

# Scan network devices then clone
./roofi-advanced.sh
→ NAC Bypass → Scan devices → pick MAC to clone
```

#### Restore Original MAC
```bash
./roofi-advanced.sh --mac-restore
```

### Captive Portal Detection & Bypass

#### Detect
```bash
./roofi-advanced.sh --portal-detect

# Output:
# ⚠ Captive portal detected!
# Portal URL: http://portal.example.com/login
```

#### Auto-Bypass
```bash
./roofi-advanced.sh --portal-bypass

# 4-step process:
# [1/4] Detecting portal...
# [2/4] Setting public DNS (bypass DNS hijack)...
# [3/4] Fetching portal login page...
# [4/4] Trying bypass methods...
# ✓ Portal bypass successful — internet access confirmed
```

### DHCP Fingerprint Spoofing

```bash
# Appear as different device types to NAC systems
./roofi-advanced.sh --spoof-dhcp printer
./roofi-advanced.sh --spoof-dhcp phone
./roofi-advanced.sh --spoof-dhcp iphone
./roofi-advanced.sh --spoof-dhcp windows
./roofi-advanced.sh --spoof-dhcp linux
./roofi-advanced.sh --spoof-dhcp iot
```

Each type sets appropriate DHCP vendor class identifier and hostname.

### Hostname Randomization

```bash
# Randomize
./roofi-advanced.sh --random-hostname

# Restore
./roofi-advanced.sh --restore-hostname
```

### Full Automated NAC Bypass

```bash
# Run all steps automatically:
# 1. Randomize MAC
# 2. Randomize hostname
# 3. Spoof DHCP fingerprint (as phone)
# 4. Detect & bypass captive portal
./roofi-advanced.sh --nac-bypass

# Restore all changes
./roofi-advanced.sh --nac-restore
```

### NAC Bypass CLI Reference

```bash
roofi-advanced --mac-random [IFACE]        # Randomize MAC address
roofi-advanced --mac-clone MAC [IFACE]     # Clone a specific MAC
roofi-advanced --mac-restore [IFACE]       # Restore original MAC
roofi-advanced --portal-detect             # Detect captive portal
roofi-advanced --portal-bypass             # Bypass captive portal
roofi-advanced --spoof-dhcp TYPE [IFACE]   # Spoof DHCP fingerprint
roofi-advanced --random-hostname           # Randomize hostname
roofi-advanced --restore-hostname          # Restore hostname
roofi-advanced --nac-bypass                # Full automated bypass
roofi-advanced --nac-restore               # Restore all changes
```

### Dependencies

| Tool | Used For | Pre-installed? |
|------|----------|---------------|
| `ip` | MAC address changes | ✅ Linux core |
| `ifconfig` | MAC fallback (OpenWrt) | ✅ OpenWrt |
| `curl` / `wget` | Portal detection/bypass | ✅ Always one present |
| `hostname` | Hostname changes | ✅ Always present |
| `od` | Random MAC generation | ✅ coreutils |
| `nmcli` / `uci` | DHCP fingerprint spoofing | ✅ Backend-specific |

**No additional packages required.**

---

## Future Enhancements (v3.3+)

- [ ] Encrypted profile storage (GPG)
- [ ] Network quality scoring
- [ ] Bandwidth usage tracking
- [ ] Connection speed test
- [ ] Email/webhook notifications
- [ ] Web dashboard
- [ ] Mobile app integration
- [ ] 802.1X bypass (optional `wpa_supplicant` integration)

---

**Author:** Krishnendu Paul (@bidhata)  
**License:** GNU GPL 2.0  
**Support:** https://github.com/bidhata/RooFi
