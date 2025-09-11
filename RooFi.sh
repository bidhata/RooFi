#!/bin/bash

# RooFi - Advanced WiFi Manager for Linux
# Author: Krishnendu Paul @bidhata
# Email: me@krishnendu.com
# Version: 2.2
# Description: User-friendly nmcli frontend for WiFi management

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configure terminal settings for proper backspace handling
configure_terminal() {
    # Save current terminal settings
    stty_orig=$(stty -g)
    # Set erase character to handle backspace (^H)
    stty erase '^H'
}

# Restore terminal settings
restore_terminal() {
    stty "$stty_orig"
}

# Detect wireless interface
detect_wifi_interface() {
    WIFI_INTERFACE=$(nmcli device | awk '/wifi/ {print $1}' | head -n1)
    if [ -z "$WIFI_INTERFACE" ]; then
        WIFI_INTERFACE=$(iw dev | awk '/Interface/ {print $2}' | head -n1)
    fi
    
    if [ -z "$WIFI_INTERFACE" ]; then
        echo -e "${RED}Error: No WiFi interface detected!${NC}"
        exit 1
    fi
}

# Function to create a visual bar for signal strength
draw_signal_bar() {
    local strength=$1
    local bar=""
    local filled=$((strength / 10))
    local empty=$((10 - filled))
    
    # Create filled portion
    for ((i=0; i<filled; i++)); do
        if [ $i -lt 3 ]; then
            bar+="${RED}█${NC}"  # Low signal
        elif [ $i -lt 7 ]; then
            bar+="${YELLOW}█${NC}"  # Medium signal
        else
            bar+="${GREEN}█${NC}"  # High signal
        fi
    done
    
    # Create empty portion
    for ((i=0; i<empty; i++)); do
        bar+="${NC}░${NC}"
    done
    
    echo -e "$bar $strength%"
}

# Function to display the header
show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║                RooFi WiFi Manager v2.2               ║"
    echo "║           Author: Krishnendu Paul @bidhata           ║"
    echo "║           Email: me@krishnendu.com                  ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Show current interface and status
    wifi_state=$(nmcli radio wifi)
    current_ssid=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
    echo -e "${BOLD}Interface:${NC} ${PURPLE}$WIFI_INTERFACE${NC} | ${BOLD}Status:${NC} ${CYAN}$wifi_state${NC}"
    
    if [ -n "$current_ssid" ]; then
        signal_strength=$(nmcli -t -f active,ssid,signal dev wifi | grep "^yes" | cut -d: -f3)
        echo -e "${BOLD}Connected to:${NC} ${GREEN}$current_ssid${NC} | ${BOLD}Signal:${NC} $(draw_signal_bar $signal_strength)"
    fi
    echo "═══════════════════════════════════════════════════════"
}

# Function to check if nmcli is installed and hotspot is supported
check_requirements() {
    if ! command -v nmcli &> /dev/null; then
        echo -e "${RED}Error: NetworkManager is not installed!${NC}"
        echo "Please install it using your package manager:"
        echo "  Ubuntu/Debian: sudo apt install network-manager"
        echo "  Fedora: sudo dnf install NetworkManager"
        echo "  Arch: sudo pacman -S networkmanager"
        exit 1
    fi
    
    # Check for iw (needed for power management and hotspot support check)
    if ! command -v iw &> /dev/null; then
        echo -e "${YELLOW}Warning: 'iw' tool not found. Power management features and hotspot support check will be limited.${NC}"
        echo "Install with: sudo apt install iw (or your package manager equivalent)"
        sleep 2
        HOTSPOT_SUPPORTED="unknown"
    else
        # Check if WiFi interface supports AP mode
        if iw list | grep -A 10 "Supported interface modes" | grep -q "AP"; then
            HOTSPOT_SUPPORTED="yes"
        else
            HOTSPOT_SUPPORTED="no"
        fi
    fi

    # Check for dnsmasq (needed for hotspot DHCP)
    if ! command -v dnsmasq &> /dev/null; then
        echo -e "${YELLOW}Warning: 'dnsmasq' not found. Hotspot functionality may not work.${NC}"
        echo "Install with: sudo apt install dnsmasq (or your package manager equivalent)"
        sleep 2
    fi
}

# Function to show current WiFi status
show_wifi_status() {
    show_header
    echo -e "${BOLD}Current WiFi Status:${NC}"
    echo "───────────────────────────────────────────────────────"
    
    # Show detailed interface information
    echo -e "${CYAN}Interface Details:${NC}"
    nmcli device show $WIFI_INTERFACE | grep -E "(GENERAL|IP4|WIFI)" | head -10
    
    # Show current connection details
    current=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
    if [ -n "$current" ]; then
        echo -e "\n${CYAN}Connection Details:${NC}"
        nmcli -f SSID,BSSID,SIGNAL,FREQ,SECURITY,CHAN dev wifi list | grep "*" | head -1
    fi
    
    echo ""
    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to list available networks with visual signal bars
list_networks() {
    show_header
    echo -e "${BOLD}Scanning for WiFi Networks...${NC}\n"
    
    # Rescan for networks
    nmcli dev wifi rescan 2>/dev/null
    sleep 2
    
    echo -e "${BOLD}Available Networks:${NC}"
    echo "───────────────────────────────────────────────────────"
    
    # List networks with visual signal bars
    echo -e "${CYAN}SSID                          SIGNAL        SECURITY       CHANNEL${NC}"
    echo "───────────────────────────────────────────────────────"
    
    # Get network list and process with visual bars
    nmcli -t -f SSID,SIGNAL,SECURITY,CHAN dev wifi | head -20 | while IFS=':' read -r ssid signal security chan; do
        # Trim whitespace
        ssid=$(echo "$ssid" | xargs)
        security=$(echo "$security" | xargs)
        chan=$(echo "$chan" | xargs)
        
        # Format output with visual signal bar
        printf "%-28s %-20s %-14s %-4s\n" "$ssid" "$(draw_signal_bar $signal)" "$security" "$chan"
    done
    
    echo ""
    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to connect to a network with more options
connect_network() {
    show_header
    echo -e "${BOLD}Connect to WiFi Network${NC}"
    echo "───────────────────────────────────────────────────────"
    
    # Show available networks with numbers and signal bars
    echo -e "${CYAN}Available Networks:${NC}"
    count=1
    nmcli -t -f SSID,SIGNAL dev wifi | head -10 | while IFS=':' read -r ssid signal; do
        # Trim whitespace
        ssid=$(echo "$ssid" | xargs)
        printf "%-2s. %-25s %s\n" "$count" "$ssid" "$(draw_signal_bar $signal)"
        ((count++))
    done
    
    echo ""
    read -e -p "Enter network name (or number from list): " network_choice  # Use -e for readline support
    
    # Check if input is a number
    if [[ "$network_choice" =~ ^[0-9]+$ ]]; then
        network_name=$(nmcli -f SSID dev wifi list | tail -n +2 | sed -n "${network_choice}p" | xargs)
    else
        network_name="$network_choice"
    fi
    
    if [ -z "$network_name" ]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -e -p "Press Enter to continue..."  # Use -e for readline support
        return
    fi
    
    echo -e "\nConnecting to: ${CYAN}$network_name${NC}"
    
    # Check if network requires password
    security=$(nmcli -f SSID,SECURITY dev wifi list | grep "^$network_name" | awk '{$1=""; print $0}' | xargs)
    
    if [[ "$security" == *"--"* ]] || [[ "$security" == "" ]]; then
        echo "Open network detected. Connecting..."
        nmcli dev wifi connect "$network_name" ifname $WIFI_INTERFACE
    else
        read -sp "Enter WiFi password: " password  # Use -sp for password, no -e
        echo ""
        
        # Advanced connection options
        echo -e "\n${CYAN}Connection Options:${NC}"
        echo "1) Standard connection"
        echo "2) Hidden network (requires SSID broadcast)"
        read -e -p "Select option [1]: " conn_option  # Use -e for readline support
        
        if [[ "$conn_option" == "2" ]]; then
            echo "Connecting to hidden network..."
            nmcli dev wifi connect "$network_name" password "$password" ifname $WIFI_INTERFACE hidden yes
        else
            echo "Connecting..."
            nmcli dev wifi connect "$network_name" password "$password" ifname $WIFI_INTERFACE
        fi
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Successfully connected to $network_name!${NC}"
    else
        echo -e "\n${RED}Failed to connect. Please check the network name and password.${NC}"
    fi
    
    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to disconnect from current network
disconnect_network() {
    show_header
    echo -e "${BOLD}Disconnect from WiFi${NC}"
    echo "───────────────────────────────────────────────────────"
    
    current=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
    
    if [ -n "$current" ]; then
        echo -e "Currently connected to: ${CYAN}$current${NC}"
        read -e -p "Are you sure you want to disconnect? (y/n): " confirm  # Use -e for readline support
        
        if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
            nmcli con down id "$current"
            echo -e "\n${GREEN}Disconnected successfully!${NC}"
        else
            echo "Cancelled."
        fi
    else
        echo -e "${YELLOW}You are not connected to any network.${NC}"
    fi
    
    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to show saved networks with options to forget or delete all
show_saved_networks() {
    show_header
    echo -e "${BOLD}Saved WiFi Networks${NC}"
    echo "───────────────────────────────────────────────────────"
    
    # List saved WiFi networks
    saved_count=$(nmcli -t -f NAME,TYPE connection show | grep -i "wireless\|wifi" | wc -l)
    
    if [ $saved_count -eq 0 ]; then
        echo -e "${YELLOW}No saved networks found.${NC}"
        read -e -p "Press Enter to continue..."  # Use -e for readline support
        return
    fi
    
    echo -e "${CYAN}Your saved networks:${NC}\n"
    nmcli -t -f NAME,TYPE connection show | grep -i "wireless\|wifi" | cut -d: -f1 | nl -w2 -s'. '
    
    echo -e "\n${CYAN}Options:${NC}"
    echo "1) Forget a specific network"
    echo "2) Delete all saved networks"
    echo "0) Back to main menu"
    
    read -e -p "Select option (0-2): " choice  # Use -e for readline support
    
    case $choice in
        1)
            echo -e "\n${CYAN}Saved Networks:${NC}"
            nmcli -t -f NAME,TYPE connection show | grep -i "wireless\|wifi" | cut -d: -f1 | nl -w2 -s'. '
            echo ""
            read -e -p "Enter network number to forget (or 0 to cancel): " network_choice  # Use -e for readline support
            
            if [ "$network_choice" = "0" ]; then
                echo "Cancelled."
                read -e -p "Press Enter to continue..."  # Use -e for readline support
                return
            fi
            
            network_name=$(nmcli -t -f NAME,TYPE connection show | grep -i "wireless\|wifi" | cut -d: -f1 | sed -n "${network_choice}p")
            
            if [ -n "$network_name" ]; then
                read -e -p "Remove '$network_name'? (y/n): " confirm  # Use -e for readline support
                if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
                    nmcli con delete "$network_name"
                    echo -e "\n${GREEN}Network forgotten successfully!${NC}"
                else
                    echo "Cancelled."
                fi
            else
                echo -e "${RED}Invalid selection!${NC}"
            fi
            ;;
        2)
            echo -e "\n${YELLOW}Warning: This will delete ALL saved WiFi networks!${NC}"
            read -e -p "Are you sure you want to proceed? (y/n): " confirm  # Use -e for readline support
            
            if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
                nmcli -t -f NAME,TYPE connection show | grep -i "wireless\|wifi" | cut -d: -f1 | while read -r network_name; do
                    nmcli con delete "$network_name"
                    echo -e "${GREEN}Deleted network: $network_name${NC}"
                done
                echo -e "\n${GREEN}All saved networks deleted successfully!${NC}"
            else
                echo -e "${CYAN}Operation cancelled.${NC}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
    
    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to toggle WiFi on/off
toggle_wifi() {
    show_header
    echo -e "${BOLD}WiFi Radio Control${NC}"
    echo "───────────────────────────────────────────────────────"
    
    wifi_state=$(nmcli radio wifi)
    echo -e "Current WiFi state: ${CYAN}$wifi_state${NC}\n"
    
    if [ "$wifi_state" = "enabled" ]; then
        read -e -p "Turn WiFi OFF? (y/n): " confirm  # Use -e for readline support
        if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
            nmcli radio wifi off
            echo -e "\n${YELLOW}WiFi turned OFF${NC}"
        fi
    else
        read -e -p "Turn WiFi ON? (y/n): " confirm  # Use -e for readline support
        if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
            nmcli radio wifi on
            echo -e "\n${GREEN}WiFi turned ON${NC}"
        fi
    fi
    
    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to show advanced network details
show_network_details() {
    show_header
    echo -e "${BOLD}Advanced Network Details${NC}"
    echo "───────────────────────────────────────────────────────"
    
    current=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
    
    if [ -n "$current" ]; then
        echo -e "Connected to: ${GREEN}$current${NC}\n"
        
        # Get detailed info
        echo -e "${CYAN}Connection Information:${NC}"
        nmcli con show "$current" | grep -E "(connection\.|ipv4\.|802-11-wireless|802-11-wireless-security)" | \
        grep -E "(id|uuid|type|autoconnect|ipv4\.|ssid|mode|security)" | sed 's/^/  /'
        
        echo -e "\n${CYAN}Signal Quality:${NC}"
        signal_strength=$(nmcli -t -f active,ssid,signal dev wifi | grep "^yes" | cut -d: -f3)
        echo -e "  Strength: $(draw_signal_bar $signal_strength)"
        
        echo -e "\n${CYAN}IP Configuration:${NC}"
        ip addr show $WIFI_INTERFACE | grep "inet " | awk '{print "  IP Address: " $2}'
        ip route | grep default | head -1 | awk '{print "  Gateway: " $3}'
        
        # Show DNS information
        echo -e "\n${CYAN}DNS Configuration:${NC}"
        nmcli dev show $WIFI_INTERFACE | grep "DNS" | sed 's/^/  /'
    else
        echo -e "${YELLOW}Not connected to any network.${NC}"
    fi
    
    echo ""
    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to manage WiFi power settings with power increase option
manage_power() {
    show_header
    echo -e "${BOLD}WiFi Power Management${NC}"
    echo "───────────────────────────────────────────────────────"
    
    if ! command -v iw &> /dev/null; then
        echo -e "${RED}Error: 'iw' command not available.${NC}"
        echo "Please install it to use power management features."
        echo "Install with: sudo apt install iw"
        read -e -p "Press Enter to continue..."  # Use -e for readline support
        return
    fi
    
    # Check current power save state
    current_power=$(iw $WIFI_INTERFACE get power_save 2>/dev/null | grep "Power save" | awk '{print $3}')
    if [ -z "$current_power" ]; then
        current_power="unknown"
    fi
    echo -e "Current power save mode: ${CYAN}$current_power${NC}"
    
    # Check current TX power using different methods
    tx_power=$(iw $WIFI_INTERFACE get txpower 2>/dev/null | grep "dBm" | awk '{print $2}')
    if [ -z "$tx_power" ]; then
        tx_power=$(iwconfig $WIFI_INTERFACE 2>/dev/null | grep "Tx-Power" | awk '{print $4}' | cut -d'=' -f2)
    fi
    if [ -z "$tx_power" ]; then
        tx_power="unknown"
    fi
    echo -e "Current TX power: ${CYAN}$tx_power${NC}"
    
    echo -e "\n${CYAN}Power Management Options:${NC}"
    echo "1) Enable power saving (default)"
    echo "2) Disable power saving (may improve performance)"
    echo "3) Increase TX power (may improve range)"
    echo "4) Reset TX power to default"
    echo "5) View current power settings"
    echo "0) Back to main menu"
    
    read -e -p "Select option: " power_choice  # Use -e for readline support
    
    case $power_choice in
        1)
            iw $WIFI_INTERFACE set power_save on 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Power saving enabled${NC}"
            else
                echo -e "${RED}Failed to enable power saving${NC}"
                echo "Your device may not support this feature"
            fi
            ;;
        2)
            iw $WIFI_INTERFACE set power_save off 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Power saving disabled${NC}"
            else
                echo -e "${RED}Failed to disable power saving${NC}"
                echo "Your device may not support this feature"
            fi
            ;;
        3)
            echo -e "\n${YELLOW}Warning: Increasing TX power may violate local regulations${NC}"
            echo "and could interfere with other devices. Use with caution."
            echo ""
            echo "Current TX power: $tx_power"
            read -e -p "Enter new TX power in dBm (typically 15-30): " new_power  # Use -e for readline support
            
            if [[ "$new_power" =~ ^[0-9]+$ ]] && [ "$new_power" -ge 1 ] && [ "$new_power" -le 30 ]; then
                sudo iw $WIFI_INTERFACE set txpower fixed ${new_power}dBm 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}TX power increased to ${new_power}dBm${NC}"
                else
                    echo -e "${RED}Failed to set TX power.${NC}"
                    echo "Your device may not support manual power adjustment."
                fi
            else
                echo -e "${RED}Invalid power value. Please enter a number between 1 and 30.${NC}"
            fi
            ;;
        4)
            sudo iw $WIFI_INTERFACE set txpower auto 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}TX power reset to auto mode${NC}"
            else
                echo -e "${RED}Failed to reset TX power.${NC}"
                echo "Your device may not support power adjustment."
            fi
            ;;
        5)
            echo -e "\n${CYAN}Detailed Power Information:${NC}"
            echo "Power save status:"
            iw $WIFI_INTERFACE get power_save 2>/dev/null || echo "  Not available"
            echo ""
            echo "TX power information:"
            iw $WIFI_INTERFACE get txpower 2>/dev/null || echo "  Not available"
            echo ""
            echo "Interface information:"
            iw $WIFI_INTERFACE info 2>/dev/null || echo "  Not available"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
    
    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to show advanced nmcli options
advanced_options() {
    show_header
    echo -e "${BOLD}Advanced nmcli Options${NC}"
    echo "───────────────────────────────────────────────────────"
    
    echo -e "${CYAN}Advanced Network Management:${NC}"
    echo "1) Show all network devices"
    echo "2) Show NetworkManager status"
    echo "3) Rescan WiFi networks"
    echo "4) Show connection statistics"
    echo "0) Back to main menu"
    
    read -e -p "Select option: " advanced_choice  # Use -e for readline support
    
    case $advanced_choice in
        1)
            echo -e "\n${CYAN}All Network Devices:${NC}"
            nmcli device status
            ;;
        2)
            echo -e "\n${CYAN}NetworkManager Status:${NC}"
            nmcli general status
            ;;
        3)
            echo -e "\n${CYAN}Rescanning WiFi networks...${NC}"
            nmcli dev wifi rescan
            echo -e "${GREEN}Scan complete!${NC}"
            ;;
        4)
            echo -e "\n${CYAN}Connection Statistics:${NC}"
            nmcli -f device,type,state,connection dev
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
    
    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to start a WiFi hotspot
start_hotspot() {
    show_header
    echo -e "${BOLD}Start WiFi Hotspot${NC}"
    echo "───────────────────────────────────────────────────────"

    if [ "$HOTSPOT_SUPPORTED" != "yes" ]; then
        echo -e "${RED}Error: Hotspot creation is not supported on this system or WiFi adapter.${NC}"
        if command -v iw &> /dev/null; then
            echo -e "${YELLOW}Reason: WiFi adapter does not support Access Point (AP) mode.${NC}"
            echo "Check supported modes with: iw list | grep -A 10 'Supported interface modes'"
        else
            echo -e "${YELLOW}Reason: Unable to verify AP mode support (iw not installed).${NC}"
            echo "Install iw to check: sudo apt install iw"
        fi
        echo -e "Ensure your WiFi adapter supports AP mode and NetworkManager is configured correctly."
        read -e -p "Press Enter to continue..."  # Use -e for readline support
        return
    fi

    # Check if already connected to a network
    current=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
    if [ -n "$current" ]; then
        echo -e "${YELLOW}You are currently connected to: ${CYAN}$current${NC}"
        echo -e "${YELLOW}Starting a hotspot will disconnect you from the current network.${NC}"
        read -e -p "Proceed to disconnect and start hotspot? (y/n): " confirm  # Use -e for readline support
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Cancelled."
            read -e -p "Press Enter to continue..."  # Use -e for readline support
            return
        fi
        nmcli con down id "$current"
    fi

    # Check if a hotspot is already running
    hotspot_con=$(nmcli -t -f NAME,TYPE connection show --active | grep "wifi" | grep "hotspot" | cut -d: -f1)
    if [ -n "$hotspot_con" ]; then
        echo -e "${YELLOW}Hotspot '$hotspot_con' is already active.${NC}"
        read -e -p "Stop the current hotspot and create a new one? (y/n): " stop_confirm  # Use -e for readline support
        if [[ "$stop_confirm" == "y" || "$stop_confirm" == "Y" ]]; then
            nmcli con down id "$hotspot_con"
            nmcli con delete id "$hotspot_con"
            echo -e "${GREEN}Previous hotspot stopped and removed.${NC}"
        else
            echo "Cancelled."
            read -e -p "Press Enter to continue..."  # Use -e for readline support
            return
        fi
    fi

    # Prompt for SSID and password
    default_ssid="RooFi-Hotspot-$(date +%s | cut -c 6-10)"
    echo -e "${CYAN}Enter Hotspot SSID${NC} (default: $default_ssid):"
    read -e -p "" hotspot_ssid  # Use -e for readline support
    hotspot_ssid=${hotspot_ssid:-$default_ssid}  # Use default if empty

    # Validate SSID (basic check for length and characters)
    if [[ ${#hotspot_ssid} -lt 1 || ${#hotspot_ssid} -gt 32 || "$hotspot_ssid" =~ [^a-zA-Z0-9_-] ]]; then
        echo -e "${RED}Invalid SSID! Must be 1-32 characters and contain only letters, numbers, '_', or '-'.${NC}"
        read -e -p "Press Enter to continue..."  # Use -e for readline support
        return
    fi

    echo -e "${CYAN}Enter Hotspot Password${NC} (minimum 8 characters, leave blank for open network):"
    read -sp "" hotspot_password  # Use -sp for password, no -e
    echo ""

    # Create hotspot command
    if [ -z "$hotspot_password" ]; then
        # Open network
        nmcli con add type wifi ifname "$WIFI_INTERFACE" con-name "RooFi-Hotspot" ssid "$hotspot_ssid" wifi.mode ap ipv4.method shared
    else
        # Password-protected network (WPA2-PSK)
        if [[ ${#hotspot_password} -lt 8 ]]; then
            echo -e "${RED}Password must be at least 8 characters long!${NC}"
            read -e -p "Press Enter to continue..."  # Use -e for readline support
            return
        fi
        nmcli con add type wifi ifname "$WIFI_INTERFACE" con-name "RooFi-Hotspot" ssid "$hotspot_ssid" wifi.mode ap wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$hotspot_password" ipv4.method shared
    fi

    # Activate hotspot and capture error message
    error_output=$(nmcli con up "RooFi-Hotspot" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Hotspot '$hotspot_ssid' started successfully!${NC}"
        echo -e "${CYAN}IP Address:${NC} $(ip addr show $WIFI_INTERFACE | grep "inet " | awk '{print $2}' | cut -d'/' -f1)"
        echo -e "${CYAN}Connect other devices to '$hotspot_ssid' using the provided password (if set).${NC}"
    else
        echo -e "\n${RED}Failed to start hotspot: ${error_output}${NC}"
        echo -e "Please check your WiFi adapter, NetworkManager settings, and ensure 'dnsmasq' is installed."
        nmcli con delete "RooFi-Hotspot" &>/dev/null
    fi

    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function to stop a WiFi hotspot
stop_hotspot() {
    show_header
    echo -e "${BOLD}Stop WiFi Hotspot${NC}"
    echo "───────────────────────────────────────────────────────"

    # Check if a hotspot is running
    hotspot_con=$(nmcli -t -f NAME,TYPE connection show --active | grep "wifi" | grep "hotspot" | cut -d: -f1)
    if [ -n "$hotspot_con" ]; then
        echo -e "${CYAN}Active hotspot: ${hotspot_con}${NC}"
        read -e -p "Stop and delete the hotspot? (y/n): " confirm  # Use -e for readline support
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            nmcli con down id "$hotspot_con"
            nmcli con delete id "$hotspot_con"
            echo -e "\n${GREEN}Hotspot stopped and deleted successfully!${NC}"
        else
            echo -e "${CYAN}Operation cancelled.${NC}"
        fi
    else
        echo -e "${YELLOW}No active hotspot found.${NC}"
    fi

    read -e -p "Press Enter to continue..."  # Use -e for readline support
}

# Function for hotspot submenu
hotspot_menu() {
    while true; do
        show_header
        echo -e "${BOLD}Hotspot Menu${NC}"
        echo "───────────────────────────────────────────────────────"
        echo "1) Start WiFi Hotspot"
        echo "2) Stop WiFi Hotspot"
        echo "0) Back to main menu"
        echo "───────────────────────────────────────────────────────"
        echo ""
        read -e -p "Select option (0-2): " choice  # Use -e for readline support
        
        case $choice in
            1) start_hotspot ;;
            2) stop_hotspot ;;
            0) return ;;
            *)
                echo -e "${RED}Invalid option! Please select 0-2.${NC}"
                read -e -p "Press Enter to continue..."  # Use -e for readline support
                ;;
        esac
    done
}

# Main menu
main_menu() {
    configure_terminal  # Set terminal settings
    trap restore_terminal EXIT  # Restore settings on script exit
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
        echo ""
        read -e -p "Select option (1-11): " choice  # Use -e for readline support
        
        case $choice in
            1) show_wifi_status ;;
            2) list_networks ;;
            3) connect_network ;;
            4) disconnect_network ;;
            5) show_saved_networks ;;
            6) toggle_wifi ;;
            7) show_network_details ;;
            8) manage_power ;;
            9) advanced_options ;;
            10) hotspot_menu ;;
            11) 
                echo -e "\n${CYAN}Thanks for using RooFi!${NC}"
                echo -e "Created by Krishnendu Paul @bidhata | Email: me@krishnendu.com\n"
                exit 0 
                ;;
            *)
                echo -e "${RED}Invalid option! Please select 1-11.${NC}"
                read -e -p "Press Enter to continue..."  # Use -e for readline support
                ;;
        esac
    done
}

# Main execution
check_requirements
detect_wifi_interface
main_menu