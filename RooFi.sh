#!/bin/sh
# RooFi - Advanced WiFi Manager for Linux & OpenWrt
# Author: Krishnendu Paul @bidhata
# Email: me@krishnendu.com
# Version: 3.2
# Description: nmcli (Linux) and uci/iwinfo (OpenWrt) frontend for WiFi management
# Shell: POSIX sh / ash compatible

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
CONFIG_DIR="${HOME}/.config/roofi"
CONFIG_FILE="${CONFIG_DIR}/roofi.conf"
HISTORY_FILE="${CONFIG_DIR}/history"
FAVORITES_FILE="${CONFIG_DIR}/favorites"

# Global variables
NON_INTERACTIVE=0
CLI_MODE=""
CLI_SSID=""

# ─── Configuration Management ─────────────────────────────────────────────────

init_config() {
    # Create config directory if it doesn't exist
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR" 2>/dev/null
    fi
    
    # Create default config if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" 2>/dev/null << 'EOF'
# RooFi Configuration File
# Preferred WiFi interface (leave empty for auto-detect)
PREFERRED_INTERFACE=""

# Auto-connect to known networks (yes/no)
AUTO_CONNECT="no"

# Show frequency band in network list (yes/no)
SHOW_FREQUENCY="yes"

# Maximum history entries
MAX_HISTORY=10

# Color scheme (default/minimal/none)
COLOR_SCHEME="default"
EOF
    fi
    
    # Load configuration
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE" 2>/dev/null
    fi
    
    # Initialize history file
    [ ! -f "$HISTORY_FILE" ] && touch "$HISTORY_FILE" 2>/dev/null
    
    # Initialize favorites file
    [ ! -f "$FAVORITES_FILE" ] && touch "$FAVORITES_FILE" 2>/dev/null
}

# Add network to history
add_to_history() {
    ssid="$1"
    [ -z "$ssid" ] || [ ! -f "$HISTORY_FILE" ] && return
    
    # Remove if already exists
    grep -v "^${ssid}$" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null
    
    # Add to top
    { echo "$ssid"; cat "$HISTORY_FILE"; } > "${HISTORY_FILE}.tmp" 2>/dev/null
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null
    
    # Keep only MAX_HISTORY entries
    max="${MAX_HISTORY:-10}"
    head -n "$max" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null
}

# Check if network is favorite
is_favorite() {
    ssid="$1"
    [ -f "$FAVORITES_FILE" ] && grep -qx "$ssid" "$FAVORITES_FILE" 2>/dev/null
}

# Toggle favorite status
toggle_favorite() {
    ssid="$1"
    [ -z "$ssid" ] || [ ! -f "$FAVORITES_FILE" ] && return
    
    if is_favorite "$ssid"; then
        grep -vx "$ssid" "$FAVORITES_FILE" > "${FAVORITES_FILE}.tmp" 2>/dev/null
        mv "${FAVORITES_FILE}.tmp" "$FAVORITES_FILE" 2>/dev/null
        echo -e "${YELLOW}Removed from favorites: ${ssid}${NC}"
    else
        echo "$ssid" >> "$FAVORITES_FILE"
        echo -e "${GREEN}Added to favorites: ${ssid}${NC}"
    fi
}

# ─── CLI Argument Parsing ─────────────────────────────────────────────────────

show_help() {
    cat << 'EOF'
RooFi - Advanced WiFi Manager v3.2

Usage: roofi [OPTIONS]

OPTIONS:
    --scan, -s              Scan and list available networks
    --connect SSID, -c      Connect to specified network
    --disconnect, -d        Disconnect from current network
    --status, -S            Show current WiFi status
    --auto-connect, -a      Auto-connect to known networks
    --interface IFACE, -i   Use specific WiFi interface
    --list-interfaces, -l   List all WiFi interfaces
    --help, -h              Show this help message
    --version, -v           Show version information

INTERACTIVE MODE:
    roofi                   Launch interactive menu (default)

EXAMPLES:
    roofi --scan
    roofi --connect "MyNetwork"
    roofi --status
    roofi --interface wlan1 --scan
    roofi --auto-connect

EOF
    exit 0
}

show_version() {
    echo "RooFi v3.2 - Advanced WiFi Manager"
    echo "Author: Krishnendu Paul @bidhata"
    echo "Backend: $BACKEND"
    exit 0
}

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                show_help
                ;;
            --version|-v)
                detect_backend
                show_version
                ;;
            --scan|-s)
                NON_INTERACTIVE=1
                CLI_MODE="scan"
                shift
                ;;
            --connect|-c)
                NON_INTERACTIVE=1
                CLI_MODE="connect"
                CLI_SSID="$2"
                shift 2
                ;;
            --disconnect|-d)
                NON_INTERACTIVE=1
                CLI_MODE="disconnect"
                shift
                ;;
            --status|-S)
                NON_INTERACTIVE=1
                CLI_MODE="status"
                shift
                ;;
            --auto-connect|-a)
                NON_INTERACTIVE=1
                CLI_MODE="auto-connect"
                shift
                ;;
            --interface|-i)
                PREFERRED_INTERFACE="$2"
                shift 2
                ;;
            --list-interfaces|-l)
                NON_INTERACTIVE=1
                CLI_MODE="list-interfaces"
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# ─── Backend Detection ────────────────────────────────────────────────────────

detect_backend() {
    if command -v nmcli > /dev/null 2>&1; then
        BACKEND="nmcli"
    elif command -v uci > /dev/null 2>&1 && [ -d /etc/config ]; then
        BACKEND="openwrt"
    else
        echo -e "${RED}Error: No supported WiFi backend found (nmcli or uci).${NC}"
        exit 1
    fi
}

# ─── Interface Detection ──────────────────────────────────────────────────────

detect_wifi_interface() {
    # Use preferred interface if set
    if [ -n "$PREFERRED_INTERFACE" ]; then
        if [ "$BACKEND" = "nmcli" ]; then
            if nmcli device | grep -q "^${PREFERRED_INTERFACE}.*wifi"; then
                WIFI_INTERFACE="$PREFERRED_INTERFACE"
                return
            fi
        else
            if iw dev | grep -q "Interface ${PREFERRED_INTERFACE}"; then
                WIFI_INTERFACE="$PREFERRED_INTERFACE"
                return
            fi
        fi
        echo -e "${YELLOW}Warning: Preferred interface '${PREFERRED_INTERFACE}' not found, auto-detecting...${NC}"
    fi
    
    if [ "$BACKEND" = "nmcli" ]; then
        WIFI_INTERFACE=$(nmcli device | awk '/wifi/ {print $1}' | head -n1)
        [ -z "$WIFI_INTERFACE" ] && WIFI_INTERFACE=$(iw dev | awk '/Interface/ {print $2}' | head -n1)
    else
        # OpenWrt: prefer wlan interfaces
        WIFI_INTERFACE=$(iw dev | awk '/Interface/ {print $2}' | head -n1)
        [ -z "$WIFI_INTERFACE" ] && WIFI_INTERFACE=$(uci get wireless.@wifi-iface[0].ifname 2>/dev/null)
    fi

    if [ -z "$WIFI_INTERFACE" ]; then
        echo -e "${RED}Error: No WiFi interface detected!${NC}"
        exit 1
    fi
}

# List all WiFi interfaces
list_wifi_interfaces() {
    echo -e "${CYAN}Available WiFi Interfaces:${NC}"
    echo "───────────────────────────────────────────────────────"
    
    if [ "$BACKEND" = "nmcli" ]; then
        nmcli device | awk 'NR==1 || /wifi/ {print}'
    else
        iw dev | grep -E "Interface|addr|type" | sed 's/^/  /'
    fi
    
    exit 0
}

# ─── Requirements Check ───────────────────────────────────────────────────────

check_requirements() {
    if [ "$BACKEND" = "nmcli" ]; then
        if ! command -v iw > /dev/null 2>&1; then
            echo -e "${YELLOW}Warning: 'iw' not found. Power management will be limited.${NC}"
            sleep 1
            HOTSPOT_SUPPORTED="unknown"
        else
            if iw list 2>/dev/null | grep -A 10 "Supported interface modes" | grep -q "AP"; then
                HOTSPOT_SUPPORTED="yes"
            else
                HOTSPOT_SUPPORTED="no"
            fi
        fi
    else
        # OpenWrt always supports AP via hostapd
        HOTSPOT_SUPPORTED="yes"
        if ! command -v iwinfo > /dev/null 2>&1 && ! command -v iw > /dev/null 2>&1; then
            echo -e "${YELLOW}Warning: Neither 'iwinfo' nor 'iw' found. Some features limited.${NC}"
            sleep 1
        fi
    fi
}

# ─── Signal Bar ───────────────────────────────────────────────────────────────

draw_signal_bar() {
    strength="${1:-0}"
    # Ensure numeric
    case "$strength" in
        ''|*[!0-9]*) strength=0 ;;
    esac
    [ "$strength" -gt 100 ] && strength=100

    filled=$((strength / 10))
    empty=$((10 - filled))
    bar=""
    i=0
    while [ $i -lt $filled ]; do
        if [ $i -lt 3 ]; then
            bar="${bar}${RED}█${NC}"
        elif [ $i -lt 7 ]; then
            bar="${bar}${YELLOW}█${NC}"
        else
            bar="${bar}${GREEN}█${NC}"
        fi
        i=$((i + 1))
    done
    i=0
    while [ $i -lt $empty ]; do
        bar="${bar}░"
        i=$((i + 1))
    done
    printf "%b %s%%\n" "$bar" "$strength"
}

# Get frequency band from frequency
get_frequency_band() {
    freq="$1"
    case "$freq" in
        ''|*[!0-9]*) echo "?" ;;
        24[0-9][0-9]) echo "2.4G" ;;
        5[0-9][0-9][0-9]) echo "5G" ;;
        6[0-9][0-9][0-9]) echo "6G" ;;
        *) echo "?" ;;
    esac
}

# Get network quality rating
get_quality_rating() {
    signal="$1"
    case "$signal" in
        ''|*[!0-9]*) echo "?" ;;
        *)
            if [ "$signal" -ge 80 ]; then
                echo "${GREEN}Excellent${NC}"
            elif [ "$signal" -ge 60 ]; then
                echo "${GREEN}Good${NC}"
            elif [ "$signal" -ge 40 ]; then
                echo "${YELLOW}Fair${NC}"
            elif [ "$signal" -ge 20 ]; then
                echo "${YELLOW}Weak${NC}"
            else
                echo "${RED}Poor${NC}"
            fi
            ;;
    esac
}

# ─── Header ───────────────────────────────────────────────────────────────────

show_header() {
    clear
    printf "%b" "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║              RooFi WiFi Manager v3.2                 ║"
    echo "║         Author: Krishnendu Paul @bidhata             ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    printf "%b" "${NC}"

    if [ "$BACKEND" = "nmcli" ]; then
        wifi_state=$(nmcli radio wifi 2>/dev/null)
        current_ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
    else
        wifi_state=$(uci get wireless.radio0.disabled 2>/dev/null)
        [ "$wifi_state" = "1" ] && wifi_state="disabled" || wifi_state="enabled"
        current_ssid=$(iwinfo "$WIFI_INTERFACE" info 2>/dev/null | awk -F'"' '/ESSID/ {print $2}')
        [ -z "$current_ssid" ] && current_ssid=$(iw dev "$WIFI_INTERFACE" link 2>/dev/null | awk '/SSID/ {for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')
    fi

    printf "%b" "${BOLD}Interface:${NC} ${PURPLE}${WIFI_INTERFACE}${NC} | ${BOLD}Backend:${NC} ${CYAN}${BACKEND}${NC} | ${BOLD}Status:${NC} ${CYAN}${wifi_state}${NC}\n"

    if [ -n "$current_ssid" ]; then
        if [ "$BACKEND" = "nmcli" ]; then
            signal=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep "^yes" | cut -d: -f3)
        else
            signal=$(iwinfo "$WIFI_INTERFACE" info 2>/dev/null | awk '/Signal/ {
                for(i=1;i<=NF;i++) {
                    if($i ~ /^-?[0-9]+$/) { print ($i < 0 ? -$i : $i); exit }
                }
            }')
            # iwinfo signal is in dBm (-100 to 0), convert to percentage
            if [ -n "$signal" ]; then
                # Convert dBm to percentage: -100 dBm = 0%, -50 dBm = 100%
                signal=$((signal > 100 ? 0 : 100 - signal))
                signal=$((signal * 2))
                [ "$signal" -gt 100 ] && signal=100
                [ "$signal" -lt 0 ] && signal=0
            else
                signal=0
            fi
        fi
        printf "%b" "${BOLD}Connected to:${NC} ${GREEN}${current_ssid}${NC} | ${BOLD}Signal:${NC} "
        draw_signal_bar "$signal"
    fi
    echo "═══════════════════════════════════════════════════════"
}

# ─── WiFi Status ──────────────────────────────────────────────────────────────

show_wifi_status() {
    [ "$NON_INTERACTIVE" -eq 0 ] && show_header
    echo -e "${BOLD}Current WiFi Status:${NC}"
    echo "───────────────────────────────────────────────────────"

    if [ "$BACKEND" = "nmcli" ]; then
        echo -e "${CYAN}Interface Details:${NC}"
        nmcli device show "$WIFI_INTERFACE" 2>/dev/null | grep -E "(GENERAL|IP4|WIFI)" | head -10
        current=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
        if [ -n "$current" ]; then
            echo -e "\n${CYAN}Connection Details:${NC}"
            nmcli -f SSID,BSSID,SIGNAL,FREQ,SECURITY,CHAN dev wifi list 2>/dev/null | grep -F "*" | head -1
        fi
    else
        echo -e "${CYAN}Interface Details:${NC}"
        iwinfo "$WIFI_INTERFACE" info 2>/dev/null || iw dev "$WIFI_INTERFACE" info 2>/dev/null
        echo -e "\n${CYAN}IP Configuration:${NC}"
        ip addr show "$WIFI_INTERFACE" 2>/dev/null | grep "inet "
    fi

    echo ""
    [ "$NON_INTERACTIVE" -eq 0 ] && { printf "Press Enter to continue..."; read -r _; }
}

# ─── List Networks ────────────────────────────────────────────────────────────

list_networks() {
    [ "$NON_INTERACTIVE" -eq 0 ] && show_header
    echo -e "${BOLD}Scanning for WiFi Networks...${NC}\n"

    if [ "$BACKEND" = "nmcli" ]; then
        nmcli dev wifi rescan 2>/dev/null
        sleep 2
        echo -e "${CYAN}SSID                          SIGNAL        SECURITY       CHANNEL${NC}"
        echo "───────────────────────────────────────────────────────"
        nmcli -t -f SSID,SIGNAL,SECURITY,CHAN dev wifi 2>/dev/null | head -20 | while IFS=':' read -r ssid signal security chan; do
            ssid=$(echo "$ssid" | tr -d '\n' | sed 's/^ *//;s/ *$//')
            security=$(echo "$security" | tr -d '\n' | sed 's/^ *//;s/ *$//')
            chan=$(echo "$chan" | tr -d '\n' | sed 's/^ *//;s/ *$//')
            sigbar=$(draw_signal_bar "$signal")
            printf "%-28s %-20b %-14s %-4s\n" "$ssid" "$sigbar" "$security" "$chan"
        done
    else
        # OpenWrt: use iwinfo scan or iw scan
        echo -e "${CYAN}SSID                          SIGNAL        ENCRYPTION${NC}"
        echo "───────────────────────────────────────────────────────"
        if command -v iwinfo > /dev/null 2>&1; then
            iwinfo "$WIFI_INTERFACE" scan 2>/dev/null | awk '
                BEGIN { ssid=""; sig=""; enc="" }
                /ESSID/ { 
                    if (ssid != "" && sig != "") {
                        printf "%-28s %-6s%%       %s\n", ssid, sig, enc
                    }
                    ssid=$0; gsub(/.*ESSID: "/,"",ssid); gsub(/".*$/,"",ssid)
                    sig=""; enc=""
                }
                /Signal/ { 
                    sig=$0; gsub(/.*Signal: -/,"",sig); gsub(/ .*/,"",sig)
                    # Convert dBm to percentage
                    if (sig ~ /^[0-9]+$/) {
                        sig = (sig > 100) ? 0 : 100 - sig
                        sig = sig * 2
                        if (sig > 100) sig = 100
                        if (sig < 0) sig = 0
                    }
                }
                /Encryption/ { 
                    enc=$0; gsub(/.*Encryption: /,"",enc)
                }
                END {
                    if (ssid != "" && sig != "") {
                        printf "%-28s %-6s%%       %s\n", ssid, sig, enc
                    }
                }
            ' | head -20
        else
            iw dev "$WIFI_INTERFACE" scan 2>/dev/null | awk '
                /SSID:/ && !/[Ee]xtended/ { ssid=$2 }
                /signal:/ { sig=$2; gsub(/[^0-9.]/,"",sig) }
                /capability:/ { printf "%-28s %s dBm\n", ssid, sig }
            ' | head -20
        fi
    fi

    echo ""
    [ "$NON_INTERACTIVE" -eq 0 ] && { printf "Press Enter to continue..."; read -r _; }
}

# ─── Connect ──────────────────────────────────────────────────────────────────

connect_network() {
    [ "$NON_INTERACTIVE" -eq 0 ] && show_header
    echo -e "${BOLD}Connect to WiFi Network${NC}"
    echo "───────────────────────────────────────────────────────"

    # In CLI mode, use the SSID provided via --connect directly
    if [ "$NON_INTERACTIVE" -eq 1 ] && [ -n "$CLI_SSID" ]; then
        network_name="$CLI_SSID"
        if [ "$BACKEND" = "nmcli" ]; then
            security=$(nmcli -t -f SSID,SECURITY dev wifi list 2>/dev/null | awk -F: -v s="$network_name" '$1==s {print $2; exit}')
            if [ -z "$security" ] || echo "$security" | grep -q "^--$"; then
                nmcli dev wifi connect "$network_name" ifname "$WIFI_INTERFACE" 2>&1
                result=$?
            else
                printf "Enter WiFi password for '%s': " "$network_name"; stty -echo 2>/dev/null; read -r password; stty echo 2>/dev/null; echo ""
                nmcli dev wifi connect "$network_name" password "$password" ifname "$WIFI_INTERFACE" 2>&1
                result=$?
                password=""; unset password
            fi
        else
            printf "Enter password for '%s' (blank for open): " "$network_name"; stty -echo 2>/dev/null; read -r password; stty echo 2>/dev/null; echo ""
            uci set wireless.@wifi-iface[0].ssid="$network_name"
            uci set wireless.@wifi-iface[0].mode="sta"
            if [ -n "$password" ]; then
                uci set wireless.@wifi-iface[0].encryption="psk2"
                uci set wireless.@wifi-iface[0].key="$password"
            else
                uci set wireless.@wifi-iface[0].encryption="none"
            fi
            uci commit wireless; wifi reload 2>&1; result=$?
            password=""; unset password
        fi
        if [ "$result" -eq 0 ]; then
            echo -e "\n${GREEN}Successfully connected to ${network_name}!${NC}"
            add_to_history "$network_name"
        else
            echo -e "\n${RED}Failed to connect. Check the SSID and password.${NC}"
        fi
        return
    fi

    if [ "$BACKEND" = "nmcli" ]; then
        echo -e "${CYAN}Available Networks:${NC}"
        # Build list into a temp file to avoid subshell counter issue
        tmpfile=$(mktemp /tmp/roofi_nets.XXXXXX 2>/dev/null) || tmpfile="/tmp/roofi_nets.$$"
        nmcli -t -f SSID,SIGNAL dev wifi 2>/dev/null | head -10 > "$tmpfile"
        
        if [ ! -s "$tmpfile" ]; then
            echo -e "${YELLOW}No networks found. Try rescanning from Advanced Options.${NC}"
            rm -f "$tmpfile"
            printf "Press Enter to continue..."; read -r _; return
        fi
        
        count=1
        while IFS=':' read -r ssid signal; do
            ssid=$(echo "$ssid" | sed 's/^ *//;s/ *$//')
            [ -z "$ssid" ] && continue
            sigbar=$(draw_signal_bar "$signal")
            printf "%2s. %-25s %b\n" "$count" "$ssid" "$sigbar"
            count=$((count + 1))
        done < "$tmpfile"
        echo ""
        printf "Enter network name (or number from list): "; read -r network_choice

        if echo "$network_choice" | grep -qE '^[0-9]+$'; then
            network_name=$(sed -n "${network_choice}p" "$tmpfile" | cut -d: -f1 | sed 's/^ *//;s/ *$//')
        else
            network_name="$network_choice"
        fi
        rm -f "$tmpfile"

        if [ -z "$network_name" ]; then
            echo -e "${RED}Invalid selection!${NC}"
            printf "Press Enter to continue..."; read -r _; return
        fi

        echo -e "\nConnecting to: ${CYAN}${network_name}${NC}"
        security=$(nmcli -t -f SSID,SECURITY dev wifi list 2>/dev/null | awk -F: -v s="$network_name" '$1==s {print $2; exit}')

        if [ -z "$security" ] || echo "$security" | grep -q "^--$"; then
            nmcli dev wifi connect "$network_name" ifname "$WIFI_INTERFACE" 2>&1
            result=$?
        else
            printf "Enter WiFi password: "; stty -echo 2>/dev/null; read -r password; stty echo 2>/dev/null; echo ""
            nmcli dev wifi connect "$network_name" password "$password" ifname "$WIFI_INTERFACE" 2>&1
            result=$?
            password=""
            unset password
        fi

    else
        # OpenWrt: write uci config
        echo -e "${CYAN}Available Networks (scan):${NC}"
        if command -v iwinfo > /dev/null 2>&1; then
            iwinfo "$WIFI_INTERFACE" scan 2>/dev/null | grep "ESSID" | head -10 | nl -w2 -s'. ' | \
                sed 's/ESSID: "//;s/"//'
        fi
        echo ""
        printf "Enter SSID to connect: "; read -r network_name
        printf "Enter password (blank for open): "; stty -echo 2>/dev/null; read -r password; stty echo 2>/dev/null; echo ""

        uci set wireless.@wifi-iface[0].ssid="$network_name"
        uci set wireless.@wifi-iface[0].mode="sta"
        if [ -n "$password" ]; then
            uci set wireless.@wifi-iface[0].encryption="psk2"
            uci set wireless.@wifi-iface[0].key="$password"
        else
            uci set wireless.@wifi-iface[0].encryption="none"
        fi
        uci commit wireless
        wifi reload 2>&1
        result=$?
        password=""
        unset password
    fi

    if [ "$result" -eq 0 ]; then
        echo -e "\n${GREEN}Successfully connected to ${network_name}!${NC}"
        add_to_history "$network_name"
    else
        echo -e "\n${RED}Failed to connect. Check the SSID and password.${NC}"
    fi

    printf "Press Enter to continue..."; read -r _
}

# ─── Disconnect ───────────────────────────────────────────────────────────────

disconnect_network() {
    show_header
    echo -e "${BOLD}Disconnect from WiFi${NC}"
    echo "───────────────────────────────────────────────────────"

    if [ "$BACKEND" = "nmcli" ]; then
        current=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
        if [ -n "$current" ]; then
            echo -e "Currently connected to: ${CYAN}${current}${NC}"
            printf "Disconnect? (y/n): "; read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                nmcli con down id "$current"
                echo -e "\n${GREEN}Disconnected.${NC}"
            else
                echo "Cancelled."
            fi
        else
            echo -e "${YELLOW}Not connected to any network.${NC}"
        fi
    else
        printf "Disconnect WiFi? (y/n): "; read -r confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            wifi down
            echo -e "\n${GREEN}WiFi disconnected.${NC}"
        fi
    fi

    printf "Press Enter to continue..."; read -r _
}

# ─── Saved Networks ───────────────────────────────────────────────────────────

show_saved_networks() {
    show_header
    echo -e "${BOLD}Saved WiFi Networks${NC}"
    echo "───────────────────────────────────────────────────────"

    if [ "$BACKEND" = "nmcli" ]; then
        saved_count=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -ic "wireless\|wifi")
        if [ "$saved_count" -eq 0 ]; then
            echo -e "${YELLOW}No saved networks found.${NC}"
            printf "Press Enter to continue..."; read -r _; return
        fi

        echo -e "${CYAN}Saved networks:${NC}\n"
        nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -i "wireless\|wifi" | cut -d: -f1 | nl -w2 -s'. '

        echo -e "\n1) Forget a network  2) Delete all  0) Back"
        printf "Select: "; read -r choice

        case $choice in
            1)
                nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -i "wireless\|wifi" | cut -d: -f1 | nl -w2 -s'. '
                printf "Enter number to forget (0 to cancel): "; read -r n
                [ "$n" = "0" ] && return
                net=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -i "wireless\|wifi" | cut -d: -f1 | sed -n "${n}p")
                if [ -n "$net" ]; then
                    printf "Remove '%s'? (y/n): " "$net"; read -r c
                    [ "$c" = "y" ] || [ "$c" = "Y" ] && nmcli con delete "$net" && echo -e "${GREEN}Forgotten.${NC}"
                fi
                ;;
            2)
                echo -e "${YELLOW}This will delete ALL saved WiFi networks!${NC}"
                printf "Confirm? (y/n): "; read -r c
                if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
                    nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -i "wireless\|wifi" | cut -d: -f1 | while read -r net; do
                        nmcli con delete "$net" && echo -e "${GREEN}Deleted: ${net}${NC}"
                    done
                fi
                ;;
        esac
    else
        # OpenWrt: list uci wifi-iface SSIDs
        echo -e "${CYAN}Configured networks (uci):${NC}\n"
        uci show wireless 2>/dev/null | grep "ssid=" | nl -w2 -s'. '
        echo -e "\n${YELLOW}To remove, edit /etc/config/wireless or use 'uci delete wireless.@wifi-iface[N]'${NC}"
    fi

    printf "Press Enter to continue..."; read -r _
}

# ─── Toggle WiFi ──────────────────────────────────────────────────────────────

toggle_wifi() {
    show_header
    echo -e "${BOLD}WiFi Radio Control${NC}"
    echo "───────────────────────────────────────────────────────"

    if [ "$BACKEND" = "nmcli" ]; then
        wifi_state=$(nmcli radio wifi 2>/dev/null)
        echo -e "Current state: ${CYAN}${wifi_state}${NC}\n"
        if [ "$wifi_state" = "enabled" ]; then
            printf "Turn WiFi OFF? (y/n): "; read -r c
            [ "$c" = "y" ] || [ "$c" = "Y" ] && nmcli radio wifi off && echo -e "${YELLOW}WiFi OFF${NC}"
        else
            printf "Turn WiFi ON? (y/n): "; read -r c
            [ "$c" = "y" ] || [ "$c" = "Y" ] && nmcli radio wifi on && echo -e "${GREEN}WiFi ON${NC}"
        fi
    else
        disabled=$(uci get wireless.radio0.disabled 2>/dev/null)
        [ "$disabled" = "1" ] && state="disabled" || state="enabled"
        echo -e "Current state: ${CYAN}${state}${NC}\n"
        if [ "$state" = "enabled" ]; then
            printf "Turn WiFi OFF? (y/n): "; read -r c
            if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
                uci set wireless.radio0.disabled=1; uci commit wireless; wifi down
                echo -e "${YELLOW}WiFi OFF${NC}"
            fi
        else
            printf "Turn WiFi ON? (y/n): "; read -r c
            if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
                uci set wireless.radio0.disabled=0; uci commit wireless; wifi up
                echo -e "${GREEN}WiFi ON${NC}"
            fi
        fi
    fi

    printf "Press Enter to continue..."; read -r _
}

# ─── Network Details ──────────────────────────────────────────────────────────

show_network_details() {
    show_header
    echo -e "${BOLD}Advanced Network Details${NC}"
    echo "───────────────────────────────────────────────────────"

    if [ "$BACKEND" = "nmcli" ]; then
        current=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
        if [ -n "$current" ]; then
            echo -e "Connected to: ${GREEN}${current}${NC}\n"
            echo -e "${CYAN}Connection Info:${NC}"
            nmcli con show "$current" 2>/dev/null | grep -E "(connection\.|ipv4\.|ssid|mode|security)" | sed 's/^/  /'
            echo -e "\n${CYAN}Signal:${NC}"
            signal=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep "^yes" | cut -d: -f3)
            printf "  Strength: %b\n" "$(draw_signal_bar "$signal")"
        else
            echo -e "${YELLOW}Not connected.${NC}"
        fi
    else
        echo -e "${CYAN}Interface Info:${NC}"
        iwinfo "$WIFI_INTERFACE" info 2>/dev/null || iw dev "$WIFI_INTERFACE" info 2>/dev/null
    fi

    echo -e "\n${CYAN}IP Configuration:${NC}"
    ip addr show "$WIFI_INTERFACE" 2>/dev/null | grep "inet " | awk '{print "  IP: " $2}'
    ip route 2>/dev/null | grep default | head -1 | awk '{print "  Gateway: " $3}'

    echo ""
    printf "Press Enter to continue..."; read -r _
}

# ─── Power Management ─────────────────────────────────────────────────────────

manage_power() {
    show_header
    echo -e "${BOLD}WiFi Power Management${NC}"
    echo "───────────────────────────────────────────────────────"

    if ! command -v iw > /dev/null 2>&1; then
        echo -e "${RED}'iw' not available. Cannot manage power settings.${NC}"
        printf "Press Enter to continue..."; read -r _; return
    fi

    current_power=$(iw "$WIFI_INTERFACE" get power_save 2>/dev/null | awk '{print $3}')
    [ -z "$current_power" ] && current_power="unknown"
    echo -e "Power save: ${CYAN}${current_power}${NC}"

    tx_power=$(iw "$WIFI_INTERFACE" get txpower 2>/dev/null | awk '/dBm/ {print $2}')
    [ -z "$tx_power" ] && tx_power="unknown"
    echo -e "TX power: ${CYAN}${tx_power}${NC}"

    echo -e "\n1) Enable power saving\n2) Disable power saving\n3) Set TX power\n4) Reset TX power to auto\n5) View details\n0) Back"
    printf "Select: "; read -r choice

    case $choice in
        1) iw "$WIFI_INTERFACE" set power_save on 2>/dev/null && echo -e "${GREEN}Power saving enabled${NC}" || echo -e "${RED}Failed${NC}" ;;
        2) iw "$WIFI_INTERFACE" set power_save off 2>/dev/null && echo -e "${GREEN}Power saving disabled${NC}" || echo -e "${RED}Failed${NC}" ;;
        3)
            echo -e "${YELLOW}Warning: Increasing TX power may violate local regulations.${NC}"
            printf "Enter TX power in dBm (1-30): "; read -r new_power
            case "$new_power" in
                ''|*[!0-9]*) echo -e "${RED}Invalid value.${NC}" ;;
                *)
                    if [ "$new_power" -ge 1 ] && [ "$new_power" -le 30 ]; then
                        iw "$WIFI_INTERFACE" set txpower fixed "${new_power}00" 2>/dev/null && \
                            echo -e "${GREEN}TX power set to ${new_power} dBm${NC}" || echo -e "${RED}Failed${NC}"
                    else
                        echo -e "${RED}Value must be 1-30.${NC}"
                    fi
                ;;
            esac
            ;;
        4) iw "$WIFI_INTERFACE" set txpower auto 2>/dev/null && echo -e "${GREEN}TX power set to auto${NC}" || echo -e "${RED}Failed${NC}" ;;
        5)
            echo -e "\n${CYAN}Power save:${NC}"; iw "$WIFI_INTERFACE" get power_save 2>/dev/null || echo "  N/A"
            echo -e "${CYAN}TX power:${NC}"; iw "$WIFI_INTERFACE" get txpower 2>/dev/null || echo "  N/A"
            echo -e "${CYAN}Interface info:${NC}"; iw "$WIFI_INTERFACE" info 2>/dev/null || echo "  N/A"
            ;;
        0) return ;;
        *) echo -e "${RED}Invalid option.${NC}" ;;
    esac

    printf "Press Enter to continue..."; read -r _
}

# ─── Advanced Options ─────────────────────────────────────────────────────────

advanced_options() {
    show_header
    echo -e "${BOLD}Advanced Options${NC}"
    echo "───────────────────────────────────────────────────────"

    if [ "$BACKEND" = "nmcli" ]; then
        echo "1) Show all devices  2) NetworkManager status  3) Rescan  4) Connection stats  0) Back"
        printf "Select: "; read -r choice
        case $choice in
            1) echo -e "\n${CYAN}Devices:${NC}"; nmcli device status ;;
            2) echo -e "\n${CYAN}NM Status:${NC}"; nmcli general status ;;
            3) nmcli dev wifi rescan 2>/dev/null && echo -e "${GREEN}Scan complete.${NC}" ;;
            4) nmcli -f device,type,state,connection dev ;;
            0) return ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
    else
        echo "1) Show wireless config  2) Show ubus network info  3) Restart WiFi  0) Back"
        printf "Select: "; read -r choice
        case $choice in
            1) echo -e "\n${CYAN}Wireless config:${NC}"; uci show wireless ;;
            2) echo -e "\n${CYAN}Network info:${NC}"; ubus call network.interface dump 2>/dev/null || ip addr ;;
            3) wifi reload && echo -e "${GREEN}WiFi restarted.${NC}" ;;
            0) return ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
    fi

    printf "Press Enter to continue..."; read -r _
}

# ─── Hotspot ──────────────────────────────────────────────────────────────────

start_hotspot() {
    show_header
    echo -e "${BOLD}Start WiFi Hotspot${NC}"
    echo "───────────────────────────────────────────────────────"

    if [ "$HOTSPOT_SUPPORTED" != "yes" ]; then
        echo -e "${RED}Hotspot not supported on this adapter.${NC}"
        printf "Press Enter to continue..."; read -r _; return
    fi

    default_ssid="RooFi-$(date +%S%M 2>/dev/null || echo "AP")"
    printf "Hotspot SSID (default: %s): " "$default_ssid"; read -r hotspot_ssid
    hotspot_ssid="${hotspot_ssid:-$default_ssid}"

    printf "Password (min 8 chars, blank for open): "; stty -echo 2>/dev/null; read -r hotspot_password; stty echo 2>/dev/null; echo ""

    if [ -n "$hotspot_password" ] && [ ${#hotspot_password} -lt 8 ]; then
        echo -e "${RED}Password must be at least 8 characters.${NC}"
        printf "Press Enter to continue..."; read -r _; return
    fi

    if [ "$BACKEND" = "nmcli" ]; then
        # Remove existing RooFi hotspot if present
        nmcli con delete "RooFi-Hotspot" > /dev/null 2>&1

        if [ -z "$hotspot_password" ]; then
            nmcli con add type wifi ifname "$WIFI_INTERFACE" con-name "RooFi-Hotspot" \
                ssid "$hotspot_ssid" wifi.mode ap ipv4.method shared
        else
            nmcli con add type wifi ifname "$WIFI_INTERFACE" con-name "RooFi-Hotspot" \
                ssid "$hotspot_ssid" wifi.mode ap \
                wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$hotspot_password" \
                ipv4.method shared
        fi

        nmcli con up "RooFi-Hotspot"
        if [ $? -eq 0 ]; then
            ip=$(ip addr show "$WIFI_INTERFACE" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
            echo -e "\n${GREEN}Hotspot '${hotspot_ssid}' started!${NC}"
            echo -e "${CYAN}IP: ${ip}${NC}"
        else
            echo -e "\n${RED}Failed to start hotspot.${NC}"
            nmcli con delete "RooFi-Hotspot" > /dev/null 2>&1
        fi

    else
        # OpenWrt: configure AP via uci
        uci set wireless.@wifi-iface[0].mode="ap"
        uci set wireless.@wifi-iface[0].ssid="$hotspot_ssid"
        if [ -n "$hotspot_password" ]; then
            uci set wireless.@wifi-iface[0].encryption="psk2"
            uci set wireless.@wifi-iface[0].key="$hotspot_password"
        else
            uci set wireless.@wifi-iface[0].encryption="none"
        fi
        uci commit wireless
        wifi reload
        echo -e "\n${GREEN}Hotspot '${hotspot_ssid}' configured and started.${NC}"
    fi

    hotspot_password=""
    unset hotspot_password
    printf "Press Enter to continue..."; read -r _
}

stop_hotspot() {
    show_header
    echo -e "${BOLD}Stop WiFi Hotspot${NC}"
    echo "───────────────────────────────────────────────────────"

    if [ "$BACKEND" = "nmcli" ]; then
        hotspot_con=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep "wifi" | grep -i "hotspot\|RooFi" | cut -d: -f1)
        if [ -n "$hotspot_con" ]; then
            printf "Stop hotspot '%s'? (y/n): " "$hotspot_con"; read -r c
            if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
                nmcli con down id "$hotspot_con"
                nmcli con delete id "$hotspot_con"
                echo -e "\n${GREEN}Hotspot stopped.${NC}"
            fi
        else
            echo -e "${YELLOW}No active hotspot found.${NC}"
        fi
    else
        printf "Stop hotspot and bring WiFi down? (y/n): "; read -r c
        if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
            wifi down
            echo -e "\n${GREEN}Hotspot stopped.${NC}"
        fi
    fi

    printf "Press Enter to continue..."; read -r _
}

hotspot_menu() {
    while true; do
        show_header
        echo -e "${BOLD}Hotspot Menu${NC}"
        echo "───────────────────────────────────────────────────────"
        echo "1) Start Hotspot  2) Stop Hotspot  0) Back"
        echo "───────────────────────────────────────────────────────"
        printf "Select (0-2): "; read -r choice
        case $choice in
            1) start_hotspot ;;
            2) stop_hotspot ;;
            0) return ;;
            *) echo -e "${RED}Invalid option.${NC}"; printf "Press Enter..."; read -r _ ;;
        esac
    done
}

# ─── Main Menu ────────────────────────────────────────────────────────────────

main_menu() {
    while true; do
        show_header
        echo -e "${BOLD}Main Menu${NC}"
        echo "───────────────────────────────────────────────────────"
        echo "1) Show WiFi Status"
        echo "2) List Available Networks"
        echo "3) Connect to Network"
        echo "4) Disconnect from Network"
        echo "5) Show Saved Networks"
        echo "6) Turn WiFi On/Off"
        echo "7) Show Network Details"
        echo "8) Power Management"
        echo "9) Advanced Options"
        echo "10) Hotspot"
        echo "11) Exit"
        echo "───────────────────────────────────────────────────────"
        printf "Select (1-11): "; read -r choice

        case $choice in
            1)  show_wifi_status ;;
            2)  list_networks ;;
            3)  connect_network ;;
            4)  disconnect_network ;;
            5)  show_saved_networks ;;
            6)  toggle_wifi ;;
            7)  show_network_details ;;
            8)  manage_power ;;
            9)  advanced_options ;;
            10) hotspot_menu ;;
            11)
                echo -e "\n${CYAN}Thanks for using RooFi!${NC}"
                echo -e "Created by Krishnendu Paul @bidhata\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-11.${NC}"
                printf "Press Enter to continue..."; read -r _
                ;;
        esac
    done
}

# ─── Entry Point ──────────────────────────────────────────────────────────────

init_config
parse_arguments "$@"
detect_backend
check_requirements
detect_wifi_interface

# Handle non-interactive CLI modes
if [ "$NON_INTERACTIVE" -eq 1 ]; then
    case "$CLI_MODE" in
        scan)             list_networks; exit 0 ;;
        connect)          connect_network; exit 0 ;;
        disconnect)       disconnect_network; exit 0 ;;
        status)           show_wifi_status; exit 0 ;;
        auto-connect)
            echo "Attempting to connect to known networks..."
            while read -r ssid; do
                [ -z "$ssid" ] && continue
                echo "Trying: $ssid"
                if command -v nmcli > /dev/null 2>&1; then
                    if nmcli -t -f SSID dev wifi list 2>/dev/null | grep -qx "$ssid"; then
                        nmcli con up id "$ssid" 2>/dev/null && echo "Connected to $ssid" && exit 0
                    fi
                fi
            done < "$HISTORY_FILE"
            echo "Could not connect to any known network"
            exit 1
            ;;
        list-interfaces)  list_wifi_interfaces ;;
    esac
fi

main_menu
