#!/bin/bash

# RooFi - Simple WiFi Manager for Linux
# Author: Krishnendu Paul @bidhata
# Version: 1.0
# Description: User-friendly nmcli frontend for WiFi management

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to display the header
show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════╗"
    echo "║           RooFi WiFi Manager          ║"
    echo "║     Author: Krishnendu Paul @bidhata  ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to check if nmcli is installed
check_requirements() {
    if ! command -v nmcli &> /dev/null; then
        echo -e "${RED}Error: NetworkManager is not installed!${NC}"
        echo "Please install it using your package manager:"
        echo "  Ubuntu/Debian: sudo apt install network-manager"
        echo "  Fedora: sudo dnf install NetworkManager"
        echo "  Arch: sudo pacman -S networkmanager"
        exit 1
    fi
}

# Function to show current WiFi status
show_wifi_status() {
    show_header
    echo -e "${BOLD}Current WiFi Status:${NC}"
    echo "═══════════════════════════════════════"
    
    # Check if WiFi is enabled
    wifi_state=$(nmcli radio wifi)
    echo -e "WiFi Radio: ${CYAN}$wifi_state${NC}"
    
    # Show current connection
    current=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
    if [ -n "$current" ]; then
        echo -e "Connected to: ${GREEN}$current${NC}"
        
        # Show connection details
        echo -e "\n${BOLD}Connection Details:${NC}"
        nmcli -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list | grep "*" | head -1
    else
        echo -e "Status: ${YELLOW}Not connected${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to list available networks
list_networks() {
    show_header
    echo -e "${BOLD}Scanning for WiFi Networks...${NC}\n"
    
    # Rescan for networks
    nmcli dev wifi rescan 2>/dev/null
    sleep 2
    
    echo -e "${BOLD}Available Networks:${NC}"
    echo "═══════════════════════════════════════"
    
    # List networks with formatting
    nmcli -f SSID,SIGNAL,SECURITY dev wifi list | head -20
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to connect to a network
connect_network() {
    show_header
    echo -e "${BOLD}Connect to WiFi Network${NC}"
    echo "═══════════════════════════════════════"
    
    # Show available networks
    echo -e "${CYAN}Available Networks:${NC}"
    nmcli -f SSID dev wifi list | tail -n +2 | head -10 | nl -w2 -s'. '
    
    echo ""
    read -p "Enter network name (or number from list): " network_choice
    
    # Check if input is a number
    if [[ "$network_choice" =~ ^[0-9]+$ ]]; then
        network_name=$(nmcli -f SSID dev wifi list | tail -n +2 | sed -n "${network_choice}p" | xargs)
    else
        network_name="$network_choice"
    fi
    
    if [ -z "$network_name" ]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "\nConnecting to: ${CYAN}$network_name${NC}"
    
    # Check if network requires password
    security=$(nmcli -f SSID,SECURITY dev wifi list | grep "^$network_name" | awk '{$1=""; print $0}' | xargs)
    
    if [[ "$security" == *"--"* ]] || [[ "$security" == "" ]]; then
        echo "Open network detected. Connecting..."
        nmcli dev wifi connect "$network_name"
    else
        read -sp "Enter WiFi password: " password
        echo ""
        echo "Connecting..."
        nmcli dev wifi connect "$network_name" password "$password"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Successfully connected to $network_name!${NC}"
    else
        echo -e "\n${RED}Failed to connect. Please check the network name and password.${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to disconnect from current network
disconnect_network() {
    show_header
    echo -e "${BOLD}Disconnect from WiFi${NC}"
    echo "═══════════════════════════════════════"
    
    current=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
    
    if [ -n "$current" ]; then
        echo -e "Currently connected to: ${CYAN}$current${NC}"
        read -p "Are you sure you want to disconnect? (y/n): " confirm
        
        if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
            nmcli con down "$current"
            echo -e "\n${GREEN}Disconnected successfully!${NC}"
        else
            echo "Cancelled."
        fi
    else
        echo -e "${YELLOW}You are not connected to any network.${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to show saved networks
show_saved_networks() {
    show_header
    echo -e "${BOLD}Saved WiFi Networks${NC}"
    echo "═══════════════════════════════════════"
    
    saved_count=$(nmcli -t -f NAME,TYPE con show | grep ":802-11-wireless$" | wc -l)
    
    if [ $saved_count -eq 0 ]; then
        echo -e "${YELLOW}No saved networks found.${NC}"
    else
        echo -e "${CYAN}Your saved networks:${NC}\n"
        nmcli -f NAME,TYPE con show | grep "802-11-wireless" | awk '{print $1}' | nl -w2 -s'. '
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to forget a saved network
forget_network() {
    show_header
    echo -e "${BOLD}Forget Saved Network${NC}"
    echo "═══════════════════════════════════════"
    
    # List saved networks
    echo -e "${CYAN}Saved Networks:${NC}"
    nmcli -f NAME,TYPE con show | grep "802-11-wireless" | awk '{print $1}' | nl -w2 -s'. '
    
    echo ""
    read -p "Enter network number to forget (or 0 to cancel): " choice
    
    if [ "$choice" = "0" ]; then
        return
    fi
    
    network_name=$(nmcli -f NAME,TYPE con show | grep "802-11-wireless" | awk '{print $1}' | sed -n "${choice}p")
    
    if [ -n "$network_name" ]; then
        read -p "Remove '$network_name'? (y/n): " confirm
        if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
            nmcli con delete "$network_name"
            echo -e "\n${GREEN}Network forgotten successfully!${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to toggle WiFi on/off
toggle_wifi() {
    show_header
    echo -e "${BOLD}WiFi Radio Control${NC}"
    echo "═══════════════════════════════════════"
    
    wifi_state=$(nmcli radio wifi)
    echo -e "Current WiFi state: ${CYAN}$wifi_state${NC}\n"
    
    if [ "$wifi_state" = "enabled" ]; then
        read -p "Turn WiFi OFF? (y/n): " confirm
        if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
            nmcli radio wifi off
            echo -e "\n${YELLOW}WiFi turned OFF${NC}"
        fi
    else
        read -p "Turn WiFi ON? (y/n): " confirm
        if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
            nmcli radio wifi on
            echo -e "\n${GREEN}WiFi turned ON${NC}"
        fi
    fi
    
    read -p "Press Enter to continue..."
}

# Function to show network details
show_network_details() {
    show_header
    echo -e "${BOLD}Network Details${NC}"
    echo "═══════════════════════════════════════"
    
    current=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
    
    if [ -n "$current" ]; then
        echo -e "Connected to: ${GREEN}$current${NC}\n"
        
        # Get detailed info
        echo -e "${CYAN}Connection Information:${NC}"
        nmcli con show "$current" | grep -E "ipv4.addresses|ipv4.gateway|ipv4.dns|connection.uuid|802-11-wireless.ssid|802-11-wireless.mode|802-11-wireless-security.key-mgmt" | sed 's/^/  /'
        
        echo -e "\n${CYAN}Signal Quality:${NC}"
        nmcli -f SSID,SIGNAL,RATE,BARS dev wifi list | grep "$current" | head -1
        
        echo -e "\n${CYAN}IP Configuration:${NC}"
        ip addr show | grep -A2 "wl" | grep "inet " | awk '{print "  IP Address: " $2}'
        ip route | grep default | head -1 | awk '{print "  Gateway: " $3}'
    else
        echo -e "${YELLOW}Not connected to any network.${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        show_header
        echo -e "${BOLD}Main Menu${NC}"
        echo "═══════════════════════════════════════"
        echo "1) Show WiFi Status"
        echo "2) List Available Networks"
        echo "3) Connect to Network"
        echo "4) Disconnect from Network"
        echo "5) Show Saved Networks"
        echo "6) Forget Saved Network"
        echo "7) Turn WiFi On/Off"
        echo "8) Show Network Details"
        echo "9) Exit"
        echo "═══════════════════════════════════════"
        echo ""
        read -p "Select option (1-9): " choice
        
        case $choice in
            1) show_wifi_status ;;
            2) list_networks ;;
            3) connect_network ;;
            4) disconnect_network ;;
            5) show_saved_networks ;;
            6) forget_network ;;
            7) toggle_wifi ;;
            8) show_network_details ;;
            9) 
                echo -e "\n${CYAN}Thanks for using RooFi!${NC}"
                echo -e "Created by Krishnendu Paul @bidhata\n"
                exit 0 
                ;;
            *)
                echo -e "${RED}Invalid option! Please select 1-9.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Main execution
check_requirements
main_menu