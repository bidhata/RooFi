#!/bin/sh
# RooFi CLI Wrapper - Adds command-line interface to RooFi
# Version: 3.1
# Usage: Source this at the beginning of RooFi.sh or use as standalone wrapper

# Configuration
CONFIG_DIR="${HOME}/.config/roofi"
CONFIG_FILE="${CONFIG_DIR}/roofi.conf"
HISTORY_FILE="${CONFIG_DIR}/history"
FAVORITES_FILE="${CONFIG_DIR}/favorites"

# Initialize configuration
init_roofi_config() {
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# RooFi Configuration
PREFERRED_INTERFACE=""
AUTO_CONNECT="no"
SHOW_FREQUENCY="yes"
MAX_HISTORY=10
EOF
    fi
    
    [ ! -f "$HISTORY_FILE" ] && touch "$HISTORY_FILE" 2>/dev/null
    [ ! -f "$FAVORITES_FILE" ] && touch "$FAVORITES_FILE" 2>/dev/null
    
    # Load config
    [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE" 2>/dev/null
}

# Add network to history
add_to_roofi_history() {
    ssid="$1"
    [ -z "$ssid" ] || [ ! -f "$HISTORY_FILE" ] && return
    
    grep -v "^${ssid}$" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null
    echo "$ssid" | cat - "${HISTORY_FILE}.tmp" > "$HISTORY_FILE" 2>/dev/null
    rm -f "${HISTORY_FILE}.tmp"
    
    head -n "${MAX_HISTORY:-10}" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null
}

# CLI: Scan networks
cli_scan() {
    if command -v nmcli > /dev/null 2>&1; then
        nmcli dev wifi rescan 2>/dev/null
        sleep 1
        echo "Available Networks:"
        nmcli -f SSID,SIGNAL,SECURITY,FREQ dev wifi list 2>/dev/null | head -20
    elif command -v iwinfo > /dev/null 2>&1; then
        iface=$(iw dev | awk '/Interface/ {print $2; exit}')
        echo "Scanning on $iface..."
        iwinfo "$iface" scan 2>/dev/null | grep -E "ESSID|Signal|Encryption" | head -60
    else
        echo "Error: No supported WiFi tool found"
        exit 1
    fi
}

# CLI: Show status
cli_status() {
    if command -v nmcli > /dev/null 2>&1; then
        iface=$(nmcli device | awk '/wifi.*connected/ {print $1; exit}')
        if [ -n "$iface" ]; then
            echo "WiFi Status:"
            nmcli device show "$iface" | grep -E "GENERAL.DEVICE|GENERAL.STATE|GENERAL.CONNECTION|IP4.ADDRESS"
            nmcli -f ACTIVE,SSID,SIGNAL,FREQ dev wifi | grep "^\*"
        else
            echo "Not connected to any WiFi network"
        fi
    elif command -v iwinfo > /dev/null 2>&1; then
        iface=$(iw dev | awk '/Interface/ {print $2; exit}')
        echo "WiFi Status ($iface):"
        iwinfo "$iface" info 2>/dev/null
    else
        echo "Error: No supported WiFi tool found"
        exit 1
    fi
}

# CLI: Connect to network
cli_connect() {
    ssid="$1"
    [ -z "$ssid" ] && echo "Error: SSID required" && exit 1
    
    if command -v nmcli > /dev/null 2>&1; then
        iface=$(nmcli device | awk '/wifi/ {print $1; exit}')
        
        # Check if network requires password
        security=$(nmcli -f SSID,SECURITY dev wifi list | awk -v s="$ssid" '$1==s {print $2}')
        
        if [ "$security" = "--" ] || [ -z "$security" ]; then
            echo "Connecting to open network: $ssid"
            nmcli dev wifi connect "$ssid" ifname "$iface"
        else
            printf "Enter password for '%s': " "$ssid"
            stty -echo 2>/dev/null
            read -r password
            stty echo 2>/dev/null
            echo ""
            nmcli dev wifi connect "$ssid" password "$password" ifname "$iface"
            password=""
        fi
        
        if [ $? -eq 0 ]; then
            echo "Successfully connected to $ssid"
            add_to_roofi_history "$ssid"
        else
            echo "Failed to connect to $ssid"
            exit 1
        fi
    elif command -v uci > /dev/null 2>&1; then
        printf "Enter password for '%s' (blank for open): " "$ssid"
        stty -echo 2>/dev/null
        read -r password
        stty echo 2>/dev/null
        echo ""
        
        uci set wireless.@wifi-iface[0].ssid="$ssid"
        uci set wireless.@wifi-iface[0].mode="sta"
        if [ -n "$password" ]; then
            uci set wireless.@wifi-iface[0].encryption="psk2"
            uci set wireless.@wifi-iface[0].key="$password"
        else
            uci set wireless.@wifi-iface[0].encryption="none"
        fi
        uci commit wireless
        wifi reload
        
        echo "Configuration updated. Connecting to $ssid..."
        add_to_roofi_history "$ssid"
        password=""
    else
        echo "Error: No supported WiFi tool found"
        exit 1
    fi
}

# CLI: Disconnect
cli_disconnect() {
    if command -v nmcli > /dev/null 2>&1; then
        current=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
        if [ -n "$current" ]; then
            nmcli con down id "$current"
            echo "Disconnected from $current"
        else
            echo "Not connected to any network"
        fi
    elif command -v wifi > /dev/null 2>&1; then
        wifi down
        echo "WiFi disconnected"
    else
        echo "Error: No supported WiFi tool found"
        exit 1
    fi
}

# CLI: Auto-connect to known networks
cli_auto_connect() {
    [ ! -f "$HISTORY_FILE" ] && echo "No connection history found" && exit 1
    
    echo "Attempting to connect to known networks..."
    while read -r ssid; do
        [ -z "$ssid" ] && continue
        echo "Trying: $ssid"
        
        if command -v nmcli > /dev/null 2>&1; then
            # Check if network is available
            if nmcli -f SSID dev wifi list | grep -qx "$ssid"; then
                nmcli con up id "$ssid" 2>/dev/null && echo "Connected to $ssid" && exit 0
            fi
        fi
    done < "$HISTORY_FILE"
    
    echo "Could not connect to any known network"
    exit 1
}

# CLI: List interfaces
cli_list_interfaces() {
    echo "Available WiFi Interfaces:"
    if command -v nmcli > /dev/null 2>&1; then
        nmcli device | awk 'NR==1 || /wifi/'
    elif command -v iw > /dev/null 2>&1; then
        iw dev | grep -E "Interface|addr|type"
    else
        echo "Error: No supported WiFi tool found"
        exit 1
    fi
}

# Show help
show_roofi_help() {
    cat << 'EOF'
RooFi - Advanced WiFi Manager v3.1

Usage: roofi [OPTIONS]

OPTIONS:
    --scan, -s              Scan and list available networks
    --connect SSID, -c      Connect to specified network
    --disconnect, -d        Disconnect from current network
    --status, -S            Show current WiFi status
    --auto-connect, -a      Auto-connect to known networks
    --list-interfaces, -l   List all WiFi interfaces
    --help, -h              Show this help message
    --version, -v           Show version information

INTERACTIVE MODE:
    roofi                   Launch interactive menu (default)

EXAMPLES:
    roofi --scan
    roofi --connect "MyNetwork"
    roofi --status
    roofi --auto-connect

CONFIGURATION:
    Config file: ~/.config/roofi/roofi.conf
    History: ~/.config/roofi/history
    Favorites: ~/.config/roofi/favorites

EOF
}

# Main CLI handler
handle_roofi_cli() {
    init_roofi_config
    
    case "$1" in
        --help|-h)
            show_roofi_help
            exit 0
            ;;
        --version|-v)
            echo "RooFi v3.1 - Advanced WiFi Manager"
            exit 0
            ;;
        --scan|-s)
            cli_scan
            exit 0
            ;;
        --connect|-c)
            cli_connect "$2"
            exit 0
            ;;
        --disconnect|-d)
            cli_disconnect
            exit 0
            ;;
        --status|-S)
            cli_status
            exit 0
            ;;
        --auto-connect|-a)
            cli_auto_connect
            exit 0
            ;;
        --list-interfaces|-l)
            cli_list_interfaces
            exit 0
            ;;
        "")
            # No arguments - continue to interactive mode
            return 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# If script is run directly (not sourced), handle CLI
if [ "${0##*/}" = "roofi-cli.sh" ]; then
    handle_roofi_cli "$@"
fi
