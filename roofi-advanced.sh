#!/bin/sh
# RooFi Advanced - TUI Mode, Profiles, Auto-Reconnect & Logging
# Author: Krishnendu Paul @bidhata
# Version: 3.2
# Features: htop-like TUI, network profiles, auto-reconnect, logging

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Configuration
CONFIG_DIR="${HOME}/.config/roofi"
PROFILES_DIR="${CONFIG_DIR}/profiles"
LOG_FILE="${CONFIG_DIR}/roofi.log"
FALLBACK_FILE="${CONFIG_DIR}/fallback_networks"
MONITOR_PID_FILE="${CONFIG_DIR}/monitor.pid"
TUI_REFRESH=2
MAX_LOG_SIZE=1048576  # 1MB

# Global state
TUI_MODE=0
MONITOR_RUNNING=0
SELECTED_PROFILE=""

# ─── Logging System ───────────────────────────────────────────────────────────

init_logging() {
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE" 2>/dev/null
    
    # Rotate log if too large
    if [ -f "$LOG_FILE" ]; then
        size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "${LOG_FILE}.old" 2>/dev/null
            touch "$LOG_FILE"
            log_message "INFO" "Log rotated (size: ${size} bytes)"
        fi
    fi
}

log_message() {
    level="$1"
    message="$2"
    timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
    
    # Console output if not in TUI
    if [ "${TUI_MODE:-0}" -eq 0 ]; then
        case "$level" in
            ERROR) printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$message" ;;
            WARN)  printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$message" ;;
            INFO)  printf "%b[INFO]%b %s\n" "$CYAN" "$NC" "$message" ;;
            SUCCESS) printf "%b[SUCCESS]%b %s\n" "$GREEN" "$NC" "$message" ;;
        esac
    fi
}

export_logs() {
    if [ -n "$1" ]; then
        output="$1"
    else
        output="roofi_debug_$(date +%Y%m%d_%H%M%S).log"
    fi
    
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}No logs to export.${NC}"
        return 1
    fi
    
    export_date=$(date)
    cat > "$output" << EOF
╔═══════════════════════════════════════════════════════╗
║              RooFi Debug Log Export                   ║
║              ${export_date}
╚═══════════════════════════════════════════════════════╝

System Information:
Hostname: $(hostname)
Kernel: $(uname -r)
Backend: ${BACKEND:-unknown}
Interface: ${WIFI_INTERFACE:-unknown}

RooFi Logs:
───────────────────────────────────────────────────────
EOF
    
    cat "$LOG_FILE" >> "$output" 2>/dev/null
    
    if command -v nmcli > /dev/null 2>&1; then
        echo -e "\n\nNetworkManager Status:\n───────────────────────────────────────────────────────" >> "$output"
        nmcli general status >> "$output" 2>&1
        nmcli device status >> "$output" 2>&1
    elif command -v uci > /dev/null 2>&1; then
        echo -e "\n\nOpenWrt Config:\n───────────────────────────────────────────────────────" >> "$output"
        uci show wireless >> "$output" 2>&1
    fi
    
    printf "%b✓ Logs exported to: %s%b\n" "$GREEN" "$output" "$NC"
    log_message "INFO" "Logs exported to $output"
}

view_logs() {
    clear
    printf "%b%bRooFi Logs (last 100 lines)%b\n" "$BOLD" "$CYAN" "$NC"
    echo "═══════════════════════════════════════════════════════"
    
    if [ -f "$LOG_FILE" ]; then
        tail -100 "$LOG_FILE" 2>/dev/null | while read -r line; do
            case "$line" in
                *ERROR*) printf "%b%s%b\n" "$RED" "$line" "$NC" ;;
                *WARN*) printf "%b%s%b\n" "$YELLOW" "$line" "$NC" ;;
                *SUCCESS*) printf "%b%s%b\n" "$GREEN" "$line" "$NC" ;;
                *) echo "$line" ;;
            esac
        done
    else
        echo -e "${YELLOW}No logs found.${NC}"
    fi
    
    echo ""
    printf "Press Enter to continue..."; read -r _
}

clear_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}No log file found.${NC}"
        return 0
    fi
    > "$LOG_FILE" 2>/dev/null
    printf "%b✓ Logs cleared%b\n" "$GREEN" "$NC"
    log_message "INFO" "Logs cleared by user"
}

# ─── Profile Management ───────────────────────────────────────────────────────

init_profiles() {
    mkdir -p "$PROFILES_DIR" 2>/dev/null
    [ ! -f "$FALLBACK_FILE" ] && touch "$FALLBACK_FILE" 2>/dev/null
}

save_profile() {
    profile_name="$1"
    ssid="$2"
    
    if [ -z "$profile_name" ] || [ -z "$ssid" ]; then
        log_message "ERROR" "Profile name and SSID required"
        return 1
    fi
    
    profile_file="${PROFILES_DIR}/${profile_name}.profile"
    
    printf "Enter password (blank for open network): "
    stty -echo 2>/dev/null; read -r password; stty echo 2>/dev/null; echo ""
    
    cat > "$profile_file" << EOF
# RooFi Network Profile
PROFILE_NAME="$profile_name"
SSID="$ssid"
ENCRYPTED="$([ -n "$password" ] && echo "yes" || echo "no")"
CREATED="$(date)"
EOF
    
    # Store encrypted password if provided
    if [ -n "$password" ]; then
        # Simple base64 encoding (not secure, just obfuscation)
        encoded=$(printf "%s" "$password" | base64 2>/dev/null || echo "$password")
        echo "PASSWORD_ENCODED=\"$encoded\"" >> "$profile_file"
        password=""
        encoded=""
    fi
    
    chmod 600 "$profile_file" 2>/dev/null
    printf "%b✓ Profile '%s' saved%b\n" "$GREEN" "$profile_name" "$NC"
    log_message "SUCCESS" "Profile '$profile_name' created for SSID '$ssid'"
}

list_profiles() {
    if [ ! -d "$PROFILES_DIR" ] || [ -z "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No profiles found.${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Saved Profiles:${NC}"
    echo "───────────────────────────────────────────────────────"
    
    count=1
    for profile in "$PROFILES_DIR"/*.profile; do
        [ ! -f "$profile" ] && continue
        . "$profile" 2>/dev/null
        printf "%2d. %-20s SSID: %-20s %s\n" "$count" "$PROFILE_NAME" "$SSID" \
            "$([ "$ENCRYPTED" = "yes" ] && echo "[🔒 Encrypted]" || echo "[Open]")"
        count=$((count + 1))
    done
    
    return 0
}

connect_profile() {
    profile_name="$1"
    profile_file="${PROFILES_DIR}/${profile_name}.profile"
    
    if [ ! -f "$profile_file" ]; then
        log_message "ERROR" "Profile '$profile_name' not found"
        return 1
    fi
    
    . "$profile_file" 2>/dev/null
    
    log_message "INFO" "Connecting using profile '$profile_name' to SSID '$SSID'"
    
    if [ "$ENCRYPTED" = "yes" ] && [ -n "$PASSWORD_ENCODED" ]; then
        password=$(printf "%s" "$PASSWORD_ENCODED" | base64 -d 2>/dev/null || echo "$PASSWORD_ENCODED")
    else
        password=""
    fi
    
    # Connect based on backend
    result=1
    if command -v nmcli > /dev/null 2>&1; then
        iface=$(nmcli device | awk '/wifi/ {print $1; exit}')
        if [ -n "$password" ]; then
            nmcli dev wifi connect "$SSID" password "$password" ifname "$iface" 2>&1
        else
            nmcli dev wifi connect "$SSID" ifname "$iface" 2>&1
        fi
        result=$?
    elif command -v uci > /dev/null 2>&1; then
        uci set wireless.@wifi-iface[0].ssid="$SSID"
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
    fi
    
    password=""
    
    if [ "$result" -eq 0 ]; then
        log_message "SUCCESS" "Connected to '$SSID' using profile '$profile_name'"
        return 0
    else
        log_message "ERROR" "Failed to connect to '$SSID'"
        return 1
    fi
}

delete_profile() {
    profile_name="$1"
    profile_file="${PROFILES_DIR}/${profile_name}.profile"
    
    if [ ! -f "$profile_file" ]; then
        echo -e "${RED}Profile not found.${NC}"
        return 1
    fi
    
    rm -f "$profile_file"
    printf "%b✓ Profile '%s' deleted%b\n" "$GREEN" "$profile_name" "$NC"
    log_message "INFO" "Profile '$profile_name' deleted"
}

profile_menu() {
    while true; do
        clear
        printf "%b%bProfile Management%b\n" "$BOLD" "$CYAN" "$NC"
        echo "═══════════════════════════════════════════════════════"
        
        list_profiles
        
        echo ""
        echo "1) Create new profile"
        echo "2) Connect using profile"
        echo "3) Delete profile"
        echo "0) Back"
        echo "───────────────────────────────────────────────────────"
        printf "Select: "; read -r choice
        
        case "$choice" in
            1)
                printf "Profile name: "; read -r pname
                printf "SSID: "; read -r ssid
                save_profile "$pname" "$ssid"
                printf "Press Enter..."; read -r _
                ;;
            2)
                printf "Profile name: "; read -r pname
                connect_profile "$pname"
                printf "Press Enter..."; read -r _
                ;;
            3)
                printf "Profile name to delete: "; read -r pname
                delete_profile "$pname"
                printf "Press Enter..."; read -r _
                ;;
            0) return ;;
        esac
    done
}

# ─── Auto-Reconnect & Fallback Logic ──────────────────────────────────────────

add_fallback_network() {
    ssid="$1"
    priority="${2:-5}"
    
    if [ -z "$ssid" ]; then
        echo -e "${RED}SSID required.${NC}"
        return 1
    fi
    
    # Remove if SSID already exists (any priority)
    grep -v ":${ssid}$" "$FALLBACK_FILE" > "${FALLBACK_FILE}.tmp" 2>/dev/null
    mv "${FALLBACK_FILE}.tmp" "$FALLBACK_FILE" 2>/dev/null
    
    # Add with priority
    echo "${priority}:${ssid}" >> "$FALLBACK_FILE"
    
    # Sort by priority
    sort -t: -k1 -n "$FALLBACK_FILE" > "${FALLBACK_FILE}.tmp" 2>/dev/null
    mv "${FALLBACK_FILE}.tmp" "$FALLBACK_FILE" 2>/dev/null
    
    printf "%b✓ Added '%s' with priority %d%b\n" "$GREEN" "$ssid" "$priority" "$NC"
    log_message "INFO" "Fallback network added: $ssid (priority: $priority)"
}

list_fallback_networks() {
    if [ ! -f "$FALLBACK_FILE" ] || [ ! -s "$FALLBACK_FILE" ]; then
        echo -e "${YELLOW}No fallback networks configured.${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Fallback Networks (by priority):${NC}"
    echo "───────────────────────────────────────────────────────"
    
    count=1
    while IFS=':' read -r priority ssid; do
        printf "%2d. [Priority %d] %s\n" "$count" "$priority" "$ssid"
        count=$((count + 1))
    done < "$FALLBACK_FILE"
    
    return 0
}

auto_reconnect() {
    log_message "INFO" "Auto-reconnect initiated"
    
    # Check if already connected
    if command -v nmcli > /dev/null 2>&1; then
        current=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
        if [ -n "$current" ]; then
            log_message "INFO" "Already connected to '$current'"
            return 0
        fi
    fi
    
    # Try fallback networks in priority order
    if [ -f "$FALLBACK_FILE" ] && [ -s "$FALLBACK_FILE" ]; then
        while IFS=':' read -r priority ssid; do
            log_message "INFO" "Trying fallback network: $ssid (priority: $priority)"
            
            # Check if network is available
            if command -v nmcli > /dev/null 2>&1; then
                if nmcli -t -f SSID dev wifi list 2>/dev/null | grep -qx "$ssid"; then
                    # Try to connect using saved connection
                    if nmcli con up id "$ssid" 2>/dev/null; then
                        log_message "SUCCESS" "Connected to fallback network: $ssid"
                        return 0
                    fi
                fi
            fi
        done < "$FALLBACK_FILE"
    fi
    
    # Try profiles
    if [ -d "$PROFILES_DIR" ]; then
        for profile in "$PROFILES_DIR"/*.profile; do
            [ ! -f "$profile" ] && continue
            pname=$(basename "$profile" .profile)
            log_message "INFO" "Trying profile: $pname"
            if connect_profile "$pname" > /dev/null 2>&1; then
                log_message "SUCCESS" "Connected using profile: $pname"
                return 0
            fi
        done
    fi
    
    log_message "ERROR" "Auto-reconnect failed - no networks available"
    return 1
}

start_monitor() {
    if [ -f "$MONITOR_PID_FILE" ]; then
        old_pid=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
        if kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${YELLOW}Monitor already running (PID: $old_pid)${NC}"
            return 1
        fi
    fi
    
    # Start background monitor
    (
        while true; do
            sleep 30
            
            # Check connection
            if command -v nmcli > /dev/null 2>&1; then
                if ! nmcli -t -f active dev wifi 2>/dev/null | grep -q "^yes"; then
                    log_message "WARN" "Connection lost - attempting auto-reconnect"
                    auto_reconnect
                fi
            fi
        done
    ) &
    
    echo $! > "$MONITOR_PID_FILE"
    printf "%b✓ Connection monitor started (PID: %d)%b\n" "$GREEN" "$!" "$NC"
    log_message "INFO" "Connection monitor started"
}

stop_monitor() {
    if [ ! -f "$MONITOR_PID_FILE" ]; then
        echo -e "${YELLOW}Monitor not running.${NC}"
        return 1
    fi
    
    pid=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
    if kill "$pid" 2>/dev/null; then
        rm -f "$MONITOR_PID_FILE"
        printf "%b✓ Monitor stopped%b\n" "$GREEN" "$NC"
        log_message "INFO" "Connection monitor stopped"
    else
        echo -e "${YELLOW}Monitor not running.${NC}"
        rm -f "$MONITOR_PID_FILE"
    fi
}

fallback_menu() {
    while true; do
        clear
        printf "%b%bFallback Networks & Auto-Reconnect%b\n" "$BOLD" "$CYAN" "$NC"
        echo "═══════════════════════════════════════════════════════"
        
        list_fallback_networks
        
        echo ""
        echo "1) Add fallback network"
        echo "2) Remove fallback network"
        echo "3) Test auto-reconnect now"
        echo "4) Start connection monitor"
        echo "5) Stop connection monitor"
        echo "0) Back"
        echo "───────────────────────────────────────────────────────"
        printf "Select: "; read -r choice
        
        case "$choice" in
            1)
                printf "SSID: "; read -r ssid
                printf "Priority (1-10, lower=higher priority): "; read -r priority
                add_fallback_network "$ssid" "$priority"
                printf "Press Enter..."; read -r _
                ;;
            2)
                list_fallback_networks
                printf "SSID to remove: "; read -r ssid
                grep -v ":${ssid}$" "$FALLBACK_FILE" > "${FALLBACK_FILE}.tmp" 2>/dev/null
                mv "${FALLBACK_FILE}.tmp" "$FALLBACK_FILE" 2>/dev/null
                printf "%b✓ Removed%b\n" "$GREEN" "$NC"
                log_message "INFO" "Fallback network removed: $ssid"
                printf "Press Enter..."; read -r _
                ;;
            3)
                echo -e "${CYAN}Testing auto-reconnect...${NC}"
                auto_reconnect
                printf "Press Enter..."; read -r _
                ;;
            4)
                start_monitor
                printf "Press Enter..."; read -r _
                ;;
            5)
                stop_monitor
                printf "Press Enter..."; read -r _
                ;;
            0) return ;;
        esac
    done
}

# ─── TUI Mode (htop-like) ─────────────────────────────────────────────────────

get_connection_info() {
    if command -v nmcli > /dev/null 2>&1; then
        iface=$(nmcli device | awk '/wifi.*connected/ {print $1; exit}')
        if [ -n "$iface" ]; then
            ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
            signal=$(nmcli -t -f active,signal dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
            freq=$(nmcli -t -f active,freq dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
            security=$(nmcli -f ACTIVE,SECURITY dev wifi 2>/dev/null | grep "^\*" | awk '{print $2}')
            ip=$(nmcli -t -f IP4.ADDRESS dev show "$iface" 2>/dev/null | cut -d: -f2 | cut -d/ -f1)
            
            echo "CONNECTED:$ssid:$signal:$freq:$security:$ip:$iface"
        else
            echo "DISCONNECTED"
        fi
    elif command -v iwinfo > /dev/null 2>&1; then
        iface=$(iw dev | awk '/Interface/ {print $2; exit}')
        if [ -n "$iface" ]; then
            info=$(iwinfo "$iface" info 2>/dev/null)
            if echo "$info" | grep -q "ESSID"; then
                ssid=$(echo "$info" | awk -F'"' '/ESSID/ {print $2}')
                signal=$(echo "$info" | awk '/Signal/ {print $2}')
                ip=$(ip addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
                echo "CONNECTED:$ssid:$signal:unknown:unknown:$ip:$iface"
            else
                echo "DISCONNECTED"
            fi
        else
            echo "DISCONNECTED"
        fi
    else
        echo "UNKNOWN"
    fi
}

draw_tui_header() {
    printf "%b%b" "$BOLD" "$CYAN"
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                       RooFi v3.2 - Live Monitor                         ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    printf "%b" "$NC"
}

draw_tui_footer() {
    printf "%b%b" "$DIM" "$CYAN"
    echo "───────────────────────────────────────────────────────────────────────────"
    echo "  [Q]uit  [R]econnect  [P]rofiles  [F]allback  [L]ogs  [E]xport"
    printf "%b" "$NC"
}

draw_signal_meter() {
    signal="$1"
    case "$signal" in
        ''|*[!0-9-]*) signal=0 ;;
    esac
    
    # Handle negative dBm values
    if [ "$signal" -lt 0 ]; then
        signal=$((100 + signal))
        [ "$signal" -lt 0 ] && signal=0
    fi
    [ "$signal" -gt 100 ] && signal=100
    
    bars=$((signal / 10))
    i=0
    meter=""
    while [ $i -lt 10 ]; do
        if [ $i -lt $bars ]; then
            if [ $i -lt 3 ]; then
                meter="${meter}${RED}▮${NC}"
            elif [ $i -lt 7 ]; then
                meter="${meter}${YELLOW}▮${NC}"
            else
                meter="${meter}${GREEN}▮${NC}"
            fi
        else
            meter="${meter}${DIM}▯${NC}"
        fi
        i=$((i + 1))
    done
    
    printf "%b %3d%%" "$meter" "$signal"
}

tui_mode() {
    TUI_MODE=1
    log_message "INFO" "TUI mode started"
    
    # Hide cursor
    printf "\033[?25l"
    
    # Trap to restore cursor on exit
    trap 'printf "\033[?25h"; TUI_MODE=0; clear; exit' INT TERM EXIT
    
    while true; do
        clear
        draw_tui_header
        
        # Get current time
        current_time=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
        printf "\n%bUpdated: %s%b\n\n" "$DIM" "$current_time" "$NC"
        
        # Connection status
        conn_info=$(get_connection_info)
        
        printf "%b%bConnection Status%b\n" "$BOLD" "$CYAN" "$NC"
        echo "───────────────────────────────────────────────────────────────────────────"
        
        case "$conn_info" in
            CONNECTED:*)
                IFS=':' read -r status ssid signal freq security ip iface << EOF
$conn_info
EOF
                printf "%bStatus:%b      %b%bCONNECTED%b\n" "$BOLD" "$NC" "$GREEN" "$BOLD" "$NC"
                printf "%bSSID:%b        %b%s%b\n" "$BOLD" "$NC" "$CYAN" "$ssid" "$NC"
                printf "%bInterface:%b   %s\n" "$BOLD" "$NC" "$iface"
                printf "%bSignal:%b      %b\n" "$BOLD" "$NC" "$(draw_signal_meter "$signal")"
                [ "$freq" != "unknown" ] && printf "%bFrequency:%b   %s MHz\n" "$BOLD" "$NC" "$freq"
                [ "$security" != "unknown" ] && printf "%bSecurity:%b    %s\n" "$BOLD" "$NC" "$security"
                [ "$ip" != "unknown" ] && printf "%bIP Address:%b  %s\n" "$BOLD" "$NC" "$ip"
                ;;
            DISCONNECTED)
                printf "%bStatus:%b      %b%bDISCONNECTED%b\n" "$BOLD" "$NC" "$RED" "$BOLD" "$NC"
                ;;
            *)
                printf "%bStatus:%b      %b%bUNKNOWN%b\n" "$BOLD" "$NC" "$YELLOW" "$BOLD" "$NC"
                ;;
        esac
        
        echo ""
        
        # Available networks (top 10)
        printf "%b%bAvailable Networks%b\n" "$BOLD" "$CYAN" "$NC"
        echo "───────────────────────────────────────────────────────────────────────────"
        
        if command -v nmcli > /dev/null 2>&1; then
            nmcli -t -f SSID,SIGNAL,SECURITY dev wifi 2>/dev/null | head -10 | while IFS=':' read -r s sig sec; do
                [ -z "$s" ] && continue
                meter=$(draw_signal_meter "$sig")
                printf "%-30s %b  %-15s\n" "$s" "$meter" "$sec"
            done
        elif command -v iwinfo > /dev/null 2>&1; then
            iface=$(iw dev | awk '/Interface/ {print $2; exit}')
            iwinfo "$iface" scan 2>/dev/null | awk '
                /ESSID/ { ssid=$0; gsub(/.*ESSID: "/,"",ssid); gsub(/".*$/,"",ssid) }
                /Signal/ { sig=$0; gsub(/.*Signal: -/,"",sig); gsub(/ .*/,"",sig) }
                /Encryption/ { enc=$0; gsub(/.*Encryption: /,"",enc); printf "%-30s %s%%  %s\n", ssid, sig, enc }
            ' | head -10
        fi
        
        echo ""
        
        # System stats
        printf "%b%bSystem Stats%b\n" "$BOLD" "$CYAN" "$NC"
        echo "───────────────────────────────────────────────────────────────────────────"
        printf "%bUptime:%b       %s\n" "$BOLD" "$NC" "$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
        printf "%bLoad Avg:%b    %s\n" "$BOLD" "$NC" "$(uptime | awk -F'load average:' '{print $2}')"
        
        # Monitor status
        if [ -f "$MONITOR_PID_FILE" ]; then
            pid=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
            if kill -0 "$pid" 2>/dev/null; then
                printf "%bMonitor:%b     %b%bRUNNING%b (PID: %d)\n" "$BOLD" "$NC" "$GREEN" "$BOLD" "$NC" "$pid"
            else
                printf "%bMonitor:%b     %b%bSTOPPED%b\n" "$BOLD" "$NC" "$RED" "$BOLD" "$NC"
                rm -f "$MONITOR_PID_FILE"
            fi
        else
            printf "%bMonitor:%b     %b%bSTOPPED%b\n" "$BOLD" "$NC" "$YELLOW" "$BOLD" "$NC"
        fi
        
        echo ""
        draw_tui_footer
        
        # Wait for input with timeout (native POSIX non-blocking read)
        old_stty=$(stty -g 2>/dev/null)
        stty -icanon time $((TUI_REFRESH * 10)) min 0 2>/dev/null
        read -r key 2>/dev/null
        stty "$old_stty" 2>/dev/null

        case "$key" in
            q|Q) break ;;
            r|R) auto_reconnect; sleep 2 ;;
            p|P) printf "\033[?25h"; profile_menu; printf "\033[?25l" ;;
            f|F) printf "\033[?25h"; fallback_menu; printf "\033[?25l" ;;
            l|L) printf "\033[?25h"; view_logs; printf "\033[?25l" ;;
            e|E) printf "\033[?25h"; export_logs; sleep 2; printf "\033[?25l" ;;
        esac
    done
    
    # Restore cursor
    printf "\033[?25h"
    TUI_MODE=0
    log_message "INFO" "TUI mode exited"
}

# ─── NAC Bypass Module ────────────────────────────────────────────────────────
# Feature requested by: fb.com/Encryption.is.everything24

# Store original MAC for restoration
ORIG_MAC_FILE="${CONFIG_DIR}/original_mac"
PORTAL_DETECT_URLS="http://connectivitycheck.gstatic.com/generate_204 http://www.msftncsi.com/ncsi.txt http://captive.apple.com/hotspot-detect.html"

# --- MAC Address Functions ---

get_wifi_interface() {
    if command -v nmcli > /dev/null 2>&1; then
        nmcli device | awk '/wifi/ {print $1; exit}'
    elif command -v iw > /dev/null 2>&1; then
        iw dev | awk '/Interface/ {print $2; exit}'
    else
        echo ""
    fi
}

get_current_mac() {
    iface="${1:-$(get_wifi_interface)}"
    [ -z "$iface" ] && return 1
    ip link show "$iface" 2>/dev/null | awk '/ether/ {print $2; exit}'
}

save_original_mac() {
    iface="${1:-$(get_wifi_interface)}"
    [ -z "$iface" ] && return 1
    
    if [ ! -f "$ORIG_MAC_FILE" ]; then
        mkdir -p "$CONFIG_DIR" 2>/dev/null
        mac=$(get_current_mac "$iface")
        if [ -n "$mac" ]; then
            echo "${iface}:${mac}" > "$ORIG_MAC_FILE"
            chmod 600 "$ORIG_MAC_FILE" 2>/dev/null
            log_message "INFO" "Saved original MAC: $mac ($iface)"
        fi
    fi
}

generate_random_mac() {
    # Generate a locally-administered unicast MAC
    # Byte 1: set bit 1 (locally administered), clear bit 0 (unicast)
    if [ -r /dev/urandom ]; then
        hex=$(od -An -tx1 -N6 /dev/urandom 2>/dev/null | tr -d ' \n')
    else
        # Fallback: use date + PID for entropy
        hex=$(printf '%012x' "$(($(date +%s%N 2>/dev/null || echo $RANDOM$RANDOM) ^ $$))" | tail -c 12)
    fi
    
    # Extract bytes
    b1=$(echo "$hex" | cut -c1-2)
    b2=$(echo "$hex" | cut -c3-4)
    b3=$(echo "$hex" | cut -c5-6)
    b4=$(echo "$hex" | cut -c7-8)
    b5=$(echo "$hex" | cut -c9-10)
    b6=$(echo "$hex" | cut -c11-12)
    
    # Force locally administered unicast: set bit 1, clear bit 0 of first byte
    b1_dec=$(printf '%d' "0x${b1}" 2>/dev/null || echo 0)
    b1_dec=$(( (b1_dec | 2) & 254 ))  # OR 0x02, AND 0xFE
    b1=$(printf '%02x' "$b1_dec")
    
    printf '%s:%s:%s:%s:%s:%s' "$b1" "$b2" "$b3" "$b4" "$b5" "$b6"
}

set_mac_address() {
    iface="$1"
    new_mac="$2"
    
    [ -z "$iface" ] || [ -z "$new_mac" ] && return 1
    
    # Validate MAC format
    if ! echo "$new_mac" | grep -qE '^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$'; then
        log_message "ERROR" "Invalid MAC format: $new_mac"
        return 1
    fi
    
    save_original_mac "$iface"
    
    # Bring interface down, change MAC, bring back up
    log_message "INFO" "Changing MAC on $iface to $new_mac"
    
    if command -v nmcli > /dev/null 2>&1; then
        # Disconnect first if connected
        nmcli device disconnect "$iface" 2>/dev/null
        sleep 1
    fi
    
    ip link set "$iface" down 2>/dev/null
    result=1
    
    if ip link set "$iface" address "$new_mac" 2>/dev/null; then
        result=0
    elif command -v ifconfig > /dev/null 2>&1; then
        # OpenWrt fallback
        ifconfig "$iface" hw ether "$new_mac" 2>/dev/null
        result=$?
    fi
    
    ip link set "$iface" up 2>/dev/null
    
    if [ "$result" -eq 0 ]; then
        log_message "SUCCESS" "MAC changed to $new_mac on $iface"
        printf "%b✓ MAC changed: %s → %s%b\n" "$GREEN" "$iface" "$new_mac" "$NC"
    else
        log_message "ERROR" "Failed to change MAC on $iface"
        printf "%b✗ Failed to change MAC%b\n" "$RED" "$NC"
    fi
    
    return $result
}

mac_randomize() {
    iface="${1:-$(get_wifi_interface)}"
    if [ -z "$iface" ]; then
        printf "%bNo WiFi interface found%b\n" "$RED" "$NC"
        return 1
    fi
    
    old_mac=$(get_current_mac "$iface")
    new_mac=$(generate_random_mac)
    
    printf "%bInterface:%b  %s\n" "$BOLD" "$NC" "$iface"
    printf "%bCurrent:%b    %s\n" "$BOLD" "$NC" "$old_mac"
    printf "%bNew MAC:%b    %s\n" "$BOLD" "$NC" "$new_mac"
    
    set_mac_address "$iface" "$new_mac"
}

mac_clone() {
    target_mac="$1"
    iface="${2:-$(get_wifi_interface)}"
    
    if [ -z "$iface" ]; then
        printf "%bNo WiFi interface found%b\n" "$RED" "$NC"
        return 1
    fi
    
    if [ -z "$target_mac" ]; then
        printf "%bTarget MAC required%b\n" "$RED" "$NC"
        return 1
    fi
    
    old_mac=$(get_current_mac "$iface")
    printf "%bInterface:%b  %s\n" "$BOLD" "$NC" "$iface"
    printf "%bCurrent:%b    %s\n" "$BOLD" "$NC" "$old_mac"
    printf "%bCloning:%b    %s\n" "$BOLD" "$NC" "$target_mac"
    
    set_mac_address "$iface" "$target_mac"
}

mac_restore() {
    iface="${1:-$(get_wifi_interface)}"
    
    if [ ! -f "$ORIG_MAC_FILE" ]; then
        printf "%bNo saved original MAC found%b\n" "$YELLOW" "$NC"
        return 1
    fi
    
    saved_line=$(grep "^${iface}:" "$ORIG_MAC_FILE" 2>/dev/null)
    if [ -z "$saved_line" ]; then
        # Try first line as fallback
        saved_line=$(head -1 "$ORIG_MAC_FILE" 2>/dev/null)
    fi
    
    orig_mac=$(echo "$saved_line" | cut -d: -f2-7)
    if [ -z "$orig_mac" ]; then
        printf "%bCould not read original MAC%b\n" "$RED" "$NC"
        return 1
    fi
    
    current_mac=$(get_current_mac "$iface")
    printf "%bInterface:%b  %s\n" "$BOLD" "$NC" "$iface"
    printf "%bCurrent:%b    %s\n" "$BOLD" "$NC" "$current_mac"
    printf "%bOriginal:%b   %s\n" "$BOLD" "$NC" "$orig_mac"
    
    set_mac_address "$iface" "$orig_mac"
    
    if [ $? -eq 0 ]; then
        rm -f "$ORIG_MAC_FILE" 2>/dev/null
    fi
}

scan_connected_macs() {
    iface="${1:-$(get_wifi_interface)}"
    
    printf "%b%bDevices on network (ARP table):%b\n" "$BOLD" "$CYAN" "$NC"
    echo "───────────────────────────────────────────────────────"
    
    count=0
    if [ -r /proc/net/arp ]; then
        # Skip header, skip incomplete entries
        tail -n +2 /proc/net/arp 2>/dev/null | while read -r ip _ flags mac _ dev; do
            [ "$flags" = "0x0" ] && continue
            [ "$mac" = "00:00:00:00:00:00" ] && continue
            count=$((count + 1))
            printf "  %2d. %-18s  %s  (%s)\n" "$count" "$mac" "$ip" "$dev"
        done
    elif command -v ip > /dev/null 2>&1; then
        ip neigh show 2>/dev/null | while read -r line; do
            ip_addr=$(echo "$line" | awk '{print $1}')
            mac=$(echo "$line" | awk '/lladdr/ {for(i=1;i<=NF;i++) if($i=="lladdr") print $(i+1)}')
            state=$(echo "$line" | awk '{print $NF}')
            [ -z "$mac" ] && continue
            [ "$state" = "FAILED" ] && continue
            count=$((count + 1))
            printf "  %2d. %-18s  %s  [%s]\n" "$count" "$mac" "$ip_addr" "$state"
        done
    else
        printf "  %bNo ARP data available%b\n" "$YELLOW" "$NC"
        return 1
    fi
}

# --- Captive Portal Functions ---

detect_captive_portal() {
    log_message "INFO" "Checking for captive portal"
    
    portal_detected=0
    redirect_url=""
    
    for url in $PORTAL_DETECT_URLS; do
        if command -v curl > /dev/null 2>&1; then
            response=$(curl -sI -o /dev/null -w '%{http_code}:%{redirect_url}' -m 5 "$url" 2>/dev/null)
            http_code=$(echo "$response" | cut -d: -f1)
            redir=$(echo "$response" | cut -d: -f2-)
        elif command -v wget > /dev/null 2>&1; then
            tmpfile=$(mktemp /tmp/roofi_portal.XXXXXX 2>/dev/null) || tmpfile="/tmp/roofi_portal.$$"
            wget -q -S -O "$tmpfile" --max-redirect=0 -T 5 "$url" 2>"${tmpfile}.hdr" || true
            http_code=$(grep 'HTTP/' "${tmpfile}.hdr" 2>/dev/null | tail -1 | awk '{print $2}')
            redir=$(grep -i 'Location:' "${tmpfile}.hdr" 2>/dev/null | tail -1 | awk '{print $2}' | tr -d '\r')
            rm -f "$tmpfile" "${tmpfile}.hdr" 2>/dev/null
        else
            log_message "WARN" "Neither curl nor wget available for portal detection"
            return 2
        fi
        
        case "$http_code" in
            200)
                # For generate_204, 200 means portal intercept
                case "$url" in
                    *generate_204*)
                        portal_detected=1
                        log_message "WARN" "Captive portal detected (got 200 instead of 204)"
                        ;;
                    *ncsi*)
                        # Check if response is correct
                        ;;
                esac
                ;;
            204)
                # Correct response for connectivity check = no portal
                ;;
            301|302|303|307|308)
                portal_detected=1
                redirect_url="$redir"
                log_message "WARN" "Captive portal detected (redirect to: $redir)"
                ;;
        esac
        
        [ "$portal_detected" -eq 1 ] && break
    done
    
    if [ "$portal_detected" -eq 1 ]; then
        printf "%b%b⚠ Captive portal detected!%b\n" "$BOLD" "$YELLOW" "$NC"
        if [ -n "$redirect_url" ]; then
            printf "%bPortal URL:%b %s\n" "$BOLD" "$NC" "$redirect_url"
        fi
        return 0
    else
        printf "%b%b✓ No captive portal detected%b\n" "$BOLD" "$GREEN" "$NC"
        log_message "INFO" "No captive portal detected"
        return 1
    fi
}

bypass_captive_portal() {
    log_message "INFO" "Attempting captive portal bypass"
    
    printf "%b%bCaptive Portal Bypass%b\n" "$BOLD" "$CYAN" "$NC"
    echo "───────────────────────────────────────────────────────"
    
    # Step 1: Detect the portal
    printf "\n%b[1/4] Detecting portal...%b\n" "$CYAN" "$NC"
    
    portal_url=""
    for url in $PORTAL_DETECT_URLS; do
        if command -v curl > /dev/null 2>&1; then
            response=$(curl -sI -o /dev/null -w '%{http_code}:%{redirect_url}' -m 5 "$url" 2>/dev/null)
            http_code=$(echo "$response" | cut -d: -f1)
            redir=$(echo "$response" | cut -d: -f2-)
        elif command -v wget > /dev/null 2>&1; then
            tmpfile=$(mktemp /tmp/roofi_portal.XXXXXX 2>/dev/null) || tmpfile="/tmp/roofi_portal.$$"
            wget -q -S -O "$tmpfile" --max-redirect=0 -T 5 "$url" 2>"${tmpfile}.hdr" || true
            http_code=$(grep 'HTTP/' "${tmpfile}.hdr" 2>/dev/null | tail -1 | awk '{print $2}')
            redir=$(grep -i 'Location:' "${tmpfile}.hdr" 2>/dev/null | tail -1 | awk '{print $2}' | tr -d '\r')
            rm -f "$tmpfile" "${tmpfile}.hdr" 2>/dev/null
        fi
        
        case "$http_code" in
            301|302|303|307|308)
                portal_url="$redir"
                break
                ;;
            200)
                case "$url" in
                    *generate_204*) portal_url="$url" ; break ;;
                esac
                ;;
        esac
    done
    
    if [ -z "$portal_url" ]; then
        printf "%b  No portal redirect found — may not need bypass%b\n" "$GREEN" "$NC"
        return 0
    fi
    
    printf "  Portal URL: %s\n" "$portal_url"
    
    # Step 2: Try DNS-based bypass (use public DNS)
    printf "\n%b[2/4] Setting public DNS (bypass DNS hijack)...%b\n" "$CYAN" "$NC"
    
    iface=$(get_wifi_interface)
    if command -v nmcli > /dev/null 2>&1; then
        current_conn=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep "$iface" | cut -d: -f1)
        if [ -n "$current_conn" ]; then
            nmcli con mod "$current_conn" ipv4.dns "1.1.1.1 8.8.8.8" ipv4.ignore-auto-dns yes 2>/dev/null
            nmcli con up "$current_conn" 2>/dev/null
            printf "  %b✓ DNS set to 1.1.1.1, 8.8.8.8%b\n" "$GREEN" "$NC"
        fi
    elif command -v uci > /dev/null 2>&1; then
        uci set network.wan.dns='1.1.1.1 8.8.8.8' 2>/dev/null
        uci set network.wan.peerdns='0' 2>/dev/null
        uci commit network 2>/dev/null
        /etc/init.d/network reload 2>/dev/null
        printf "  %b✓ DNS set to 1.1.1.1, 8.8.8.8%b\n" "$GREEN" "$NC"
    else
        # Direct resolv.conf override
        if [ -w /etc/resolv.conf ]; then
            cp /etc/resolv.conf /etc/resolv.conf.roofi.bak 2>/dev/null
            printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
            printf "  %b✓ DNS overridden in resolv.conf%b\n" "$GREEN" "$NC"
        fi
    fi
    
    # Step 3: Try fetching the portal page and auto-accepting
    printf "\n%b[3/4] Fetching portal login page...%b\n" "$CYAN" "$NC"
    
    tmpdir=$(mktemp -d /tmp/roofi_bypass.XXXXXX 2>/dev/null) || tmpdir="/tmp/roofi_bypass.$$"
    mkdir -p "$tmpdir" 2>/dev/null
    
    if command -v curl > /dev/null 2>&1; then
        curl -sL -c "${tmpdir}/cookies" -o "${tmpdir}/portal.html" -m 10 "$portal_url" 2>/dev/null
    elif command -v wget > /dev/null 2>&1; then
        wget -q --save-cookies="${tmpdir}/cookies" -O "${tmpdir}/portal.html" -T 10 "$portal_url" 2>/dev/null
    fi
    
    if [ -f "${tmpdir}/portal.html" ] && [ -s "${tmpdir}/portal.html" ]; then
        # Extract form action URL
        form_action=$(grep -oi 'action="[^"]*"' "${tmpdir}/portal.html" 2>/dev/null | head -1 | sed 's/action="//;s/"//')
        
        # Look for common accept/login buttons
        has_accept=$(grep -ci 'accept\|agree\|connect\|login\|submit' "${tmpdir}/portal.html" 2>/dev/null)
        
        printf "  Page fetched (%s bytes)\n" "$(wc -c < "${tmpdir}/portal.html" 2>/dev/null)"
        [ -n "$form_action" ] && printf "  Form action: %s\n" "$form_action"
        [ "$has_accept" -gt 0 ] && printf "  Found %d accept/login references\n" "$has_accept"
    else
        printf "  %bCould not fetch portal page%b\n" "$YELLOW" "$NC"
    fi
    
    # Step 4: Attempt common portal bypass techniques
    printf "\n%b[4/4] Trying bypass methods...%b\n" "$CYAN" "$NC"
    
    bypass_success=0
    
    # Method A: POST to form action with empty/default credentials
    if [ -n "$form_action" ]; then
        # Resolve relative URL
        case "$form_action" in
            http*) post_url="$form_action" ;;
            /*) 
                base_host=$(echo "$portal_url" | sed 's|^\(https\?://[^/]*\).*|\1|')
                post_url="${base_host}${form_action}"
                ;;
            *)
                base_path=$(echo "$portal_url" | sed 's|/[^/]*$|/|')
                post_url="${base_path}${form_action}"
                ;;
        esac
        
        printf "  Submitting form to: %s\n" "$post_url"
        
        if command -v curl > /dev/null 2>&1; then
            curl -sL -b "${tmpdir}/cookies" -d '' -o /dev/null -m 10 "$post_url" 2>/dev/null
        elif command -v wget > /dev/null 2>&1; then
            wget -q --load-cookies="${tmpdir}/cookies" --post-data='' -O /dev/null -T 10 "$post_url" 2>/dev/null
        fi
    fi
    
    # Method B: Try direct connectivity after DNS bypass
    sleep 2
    if command -v curl > /dev/null 2>&1; then
        test_code=$(curl -sI -o /dev/null -w '%{http_code}' -m 5 "http://connectivitycheck.gstatic.com/generate_204" 2>/dev/null)
    elif command -v wget > /dev/null 2>&1; then
        tmptest=$(mktemp /tmp/roofi_test.XXXXXX 2>/dev/null) || tmptest="/tmp/roofi_test.$$"
        wget -q -S -O "$tmptest" -T 5 "http://connectivitycheck.gstatic.com/generate_204" 2>"${tmptest}.hdr" || true
        test_code=$(grep 'HTTP/' "${tmptest}.hdr" 2>/dev/null | tail -1 | awk '{print $2}')
        rm -f "$tmptest" "${tmptest}.hdr" 2>/dev/null
    fi
    
    if [ "$test_code" = "204" ]; then
        bypass_success=1
    fi
    
    # Cleanup
    rm -rf "$tmpdir" 2>/dev/null
    
    echo ""
    if [ "$bypass_success" -eq 1 ]; then
        printf "%b%b✓ Portal bypass successful — internet access confirmed%b\n" "$BOLD" "$GREEN" "$NC"
        log_message "SUCCESS" "Captive portal bypass successful"
        return 0
    else
        printf "%b%b⚠ Auto-bypass may not have worked%b\n" "$BOLD" "$YELLOW" "$NC"
        printf "  Try: MAC cloning an authorized device, or manual login\n"
        log_message "WARN" "Captive portal auto-bypass inconclusive"
        return 1
    fi
}

# --- DHCP Fingerprint Spoofing ---

spoof_dhcp_fingerprint() {
    device_type="$1"
    iface="${2:-$(get_wifi_interface)}"
    
    printf "%b%bDHCP Fingerprint Spoofing%b\n" "$BOLD" "$CYAN" "$NC"
    echo "───────────────────────────────────────────────────────"
    
    # Common vendor class IDs by device type
    case "$device_type" in
        printer|Printer)
            vendor_class="HP LaserJet"
            spoof_hostname="HP$(date +%s | tail -c 7)"
            ;;
        phone|Phone|android|Android)
            vendor_class="android-dhcp-12"
            spoof_hostname="android-$(od -An -tx1 -N4 /dev/urandom 2>/dev/null | tr -d ' ' || echo 'a1b2c3d4')"
            ;;
        iphone|iPhone|ios|iOS)
            vendor_class="APPLE:dhcp-no-change"
            spoof_hostname="iPhone"
            ;;
        windows|Windows)
            vendor_class="MSFT 5.0"
            spoof_hostname="DESKTOP-$(od -An -tx1 -N3 /dev/urandom 2>/dev/null | tr -d ' ' | tr 'a-f' 'A-F' || echo 'A1B2C3')"
            ;;
        linux|Linux)
            vendor_class="dhclient"
            spoof_hostname="localhost"
            ;;
        iot|IoT)
            vendor_class="udhcp 1.24.2"
            spoof_hostname="ESP-$(od -An -tx1 -N3 /dev/urandom 2>/dev/null | tr -d ' ' || echo 'aabbcc')"
            ;;
        *)
            printf "  %bUnknown device type: %s%b\n" "$RED" "$device_type" "$NC"
            printf "  Available: printer, phone, iphone, windows, linux, iot\n"
            return 1
            ;;
    esac
    
    printf "%bSpoofing as:%b   %s\n" "$BOLD" "$NC" "$device_type"
    printf "%bVendor class:%b  %s\n" "$BOLD" "$NC" "$vendor_class"
    printf "%bHostname:%b      %s\n" "$BOLD" "$NC" "$spoof_hostname"
    echo ""
    
    if command -v nmcli > /dev/null 2>&1; then
        current_conn=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep "$iface" | cut -d: -f1)
        if [ -n "$current_conn" ]; then
            nmcli con mod "$current_conn" ipv4.dhcp-vendor-class-identifier "$vendor_class" 2>/dev/null
            nmcli con mod "$current_conn" ipv4.dhcp-hostname "$spoof_hostname" 2>/dev/null
            printf "%b✓ DHCP fingerprint set via NetworkManager%b\n" "$GREEN" "$NC"
            printf "  Reconnect to apply: nmcli con up '%s'\n" "$current_conn"
        else
            printf "%bNo active connection on %s%b\n" "$YELLOW" "$iface" "$NC"
        fi
    elif command -v uci > /dev/null 2>&1; then
        uci set network.wan.vendorid="$vendor_class" 2>/dev/null
        uci set network.wan.hostname="$spoof_hostname" 2>/dev/null
        uci commit network 2>/dev/null
        printf "%b✓ DHCP fingerprint set via UCI%b\n" "$GREEN" "$NC"
        printf "  Run 'ifdown wan && ifup wan' to apply\n"
    elif [ -d /etc/dhcp ] || command -v dhclient > /dev/null 2>&1; then
        dhclient_conf="/etc/dhcp/dhclient.conf"
        [ ! -f "$dhclient_conf" ] && dhclient_conf="/etc/dhclient.conf"
        
        if [ -f "$dhclient_conf" ]; then
            cp "$dhclient_conf" "${dhclient_conf}.roofi.bak" 2>/dev/null
        fi
        
        cat >> "$dhclient_conf" 2>/dev/null << DHCEOF
# RooFi NAC bypass spoofing
send vendor-class-identifier "$vendor_class";
send host-name "$spoof_hostname";
DHCEOF
        printf "%b✓ Written to %s%b\n" "$GREEN" "$dhclient_conf" "$NC"
        printf "  Run 'dhclient -r %s && dhclient %s' to apply\n" "$iface" "$iface"
    else
        printf "%bNo supported DHCP client found%b\n" "$RED" "$NC"
        return 1
    fi
    
    log_message "SUCCESS" "DHCP fingerprint spoofed as $device_type (vendor=$vendor_class, hostname=$spoof_hostname)"
}

# --- Hostname Randomization ---

randomize_hostname() {
    old_hostname=$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null)
    
    # Generate random hostname
    rand_suffix=$(od -An -tx1 -N4 /dev/urandom 2>/dev/null | tr -d ' ' || printf '%08x' "$$")
    new_hostname="host-${rand_suffix}"
    
    printf "%bCurrent hostname:%b %s\n" "$BOLD" "$NC" "$old_hostname"
    printf "%bNew hostname:%b     %s\n" "$BOLD" "$NC" "$new_hostname"
    
    # Save original
    if [ ! -f "${CONFIG_DIR}/original_hostname" ]; then
        echo "$old_hostname" > "${CONFIG_DIR}/original_hostname" 2>/dev/null
    fi
    
    if hostname "$new_hostname" 2>/dev/null; then
        printf "%b✓ Hostname changed%b\n" "$GREEN" "$NC"
        log_message "SUCCESS" "Hostname changed from '$old_hostname' to '$new_hostname'"
    else
        # Try sysctl fallback
        if [ -w /proc/sys/kernel/hostname ]; then
            echo "$new_hostname" > /proc/sys/kernel/hostname 2>/dev/null
            printf "%b✓ Hostname changed via sysctl%b\n" "$GREEN" "$NC"
            log_message "SUCCESS" "Hostname changed to '$new_hostname'"
        else
            printf "%b✗ Failed (need root?)%b\n" "$RED" "$NC"
            return 1
        fi
    fi
}

restore_hostname() {
    if [ ! -f "${CONFIG_DIR}/original_hostname" ]; then
        printf "%bNo saved hostname to restore%b\n" "$YELLOW" "$NC"
        return 1
    fi
    
    orig=$(cat "${CONFIG_DIR}/original_hostname" 2>/dev/null)
    current=$(hostname 2>/dev/null)
    
    printf "%bCurrent:%b   %s\n" "$BOLD" "$NC" "$current"
    printf "%bOriginal:%b  %s\n" "$BOLD" "$NC" "$orig"
    
    if hostname "$orig" 2>/dev/null || echo "$orig" > /proc/sys/kernel/hostname 2>/dev/null; then
        rm -f "${CONFIG_DIR}/original_hostname" 2>/dev/null
        printf "%b✓ Hostname restored%b\n" "$GREEN" "$NC"
        log_message "SUCCESS" "Hostname restored to '$orig'"
    else
        printf "%b✗ Failed to restore hostname%b\n" "$RED" "$NC"
        return 1
    fi
}

# --- Full NAC Bypass (Automated) ---

full_nac_bypass() {
    printf "%b%b╔═══════════════════════════════════════════════════════╗%b\n" "$BOLD" "$CYAN" "$NC"
    printf "%b%b║            Full NAC Bypass Sequence                   ║%b\n" "$BOLD" "$CYAN" "$NC"
    printf "%b%b╚═══════════════════════════════════════════════════════╝%b\n" "$BOLD" "$CYAN" "$NC"
    echo ""
    
    printf "%b%b⚠ WARNING:%b This will change your MAC, hostname, and DHCP fingerprint.%b\n" "$BOLD" "$YELLOW" "$BOLD" "$NC"
    printf "All changes are reversible via the restore options.\n"
    printf "Proceed? (y/n): "; read -r confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return 0
    echo ""
    
    log_message "INFO" "Starting full NAC bypass sequence"
    
    # Step 1: Randomize MAC
    printf "%b━━━ Step 1/4: MAC Randomization ━━━%b\n" "$CYAN" "$NC"
    mac_randomize
    echo ""
    sleep 1
    
    # Step 2: Randomize hostname
    printf "%b━━━ Step 2/4: Hostname Randomization ━━━%b\n" "$CYAN" "$NC"
    randomize_hostname
    echo ""
    sleep 1
    
    # Step 3: DHCP fingerprint (default to 'phone' as most permissive)
    printf "%b━━━ Step 3/4: DHCP Fingerprint Spoof ━━━%b\n" "$CYAN" "$NC"
    spoof_dhcp_fingerprint "phone"
    echo ""
    sleep 1
    
    # Step 4: Check for captive portal
    printf "%b━━━ Step 4/4: Captive Portal Check ━━━%b\n" "$CYAN" "$NC"
    if detect_captive_portal 2>/dev/null; then
        printf "\nAttempting portal bypass...\n"
        bypass_captive_portal
    else
        printf "%b✓ No captive portal — direct internet access%b\n" "$GREEN" "$NC"
    fi
    
    echo ""
    printf "%b%b═══════════════════════════════════════════════════════%b\n" "$BOLD" "$CYAN" "$NC"
    printf "%bNAC bypass sequence complete%b\n" "$BOLD" "$NC"
    printf "Use the NAC Bypass menu to restore original settings.\n"
    log_message "SUCCESS" "Full NAC bypass sequence complete"
}

restore_all_nac() {
    printf "%b%bRestoring all NAC bypass changes...%b\n\n" "$BOLD" "$CYAN" "$NC"
    
    printf "%b━━━ Restoring MAC ━━━%b\n" "$CYAN" "$NC"
    mac_restore 2>/dev/null || printf "  (no change needed)\n"
    echo ""
    
    printf "%b━━━ Restoring Hostname ━━━%b\n" "$CYAN" "$NC"
    restore_hostname 2>/dev/null || printf "  (no change needed)\n"
    echo ""
    
    printf "%b✓ Restore complete%b\n" "$GREEN" "$NC"
    log_message "INFO" "All NAC bypass changes restored"
}

# --- NAC Bypass Menu ---

nac_bypass_menu() {
    while true; do
        clear
        printf "%b%bNAC Bypass%b\n" "$BOLD" "$CYAN" "$NC"
        echo "═══════════════════════════════════════════════════════"
        
        # Show current state
        iface=$(get_wifi_interface)
        if [ -n "$iface" ]; then
            current_mac=$(get_current_mac "$iface")
            printf "%bInterface:%b  %s\n" "$BOLD" "$NC" "$iface"
            printf "%bMAC:%b        %s" "$BOLD" "$NC" "$current_mac"
            [ -f "$ORIG_MAC_FILE" ] && printf "  %b(spoofed)%b" "$YELLOW" "$NC"
            echo ""
            printf "%bHostname:%b   %s" "$BOLD" "$NC" "$(hostname 2>/dev/null)"
            [ -f "${CONFIG_DIR}/original_hostname" ] && printf "  %b(spoofed)%b" "$YELLOW" "$NC"
            echo ""
        fi
        
        echo "───────────────────────────────────────────────────────"
        echo ""
        echo "  MAC Spoofing:"
        echo "    1) 🎲 Randomize MAC"
        echo "    2) 📋 Clone MAC (from target)"
        echo "    3) 🔍 Scan devices (pick MAC to clone)"
        echo "    4) ↩️  Restore original MAC"
        echo ""
        echo "  Portal Bypass:"
        echo "    5) 🔎 Detect captive portal"
        echo "    6) 🚀 Bypass captive portal"
        echo ""
        echo "  Fingerprint:"
        echo "    7) 🖨️  Spoof DHCP fingerprint"
        echo "    8) 🔀 Randomize hostname"
        echo "    9) ↩️  Restore hostname"
        echo ""
        echo "  Automated:"
        echo "   10) ⚡ Full NAC bypass (all steps)"
        echo "   11) ↩️  Restore everything"
        echo ""
        echo "    0) ← Back"
        echo "───────────────────────────────────────────────────────"
        printf "Select: "; read -r choice
        
        case "$choice" in
            1)
                mac_randomize
                printf "\nPress Enter..."; read -r _
                ;;
            2)
                printf "Enter target MAC (xx:xx:xx:xx:xx:xx): "; read -r tmac
                mac_clone "$tmac"
                printf "\nPress Enter..."; read -r _
                ;;
            3)
                scan_connected_macs
                echo ""
                printf "Enter MAC to clone (or 0 to cancel): "; read -r tmac
                if [ -n "$tmac" ] && [ "$tmac" != "0" ]; then
                    mac_clone "$tmac"
                fi
                printf "\nPress Enter..."; read -r _
                ;;
            4)
                mac_restore
                printf "\nPress Enter..."; read -r _
                ;;
            5)
                detect_captive_portal
                printf "\nPress Enter..."; read -r _
                ;;
            6)
                bypass_captive_portal
                printf "\nPress Enter..."; read -r _
                ;;
            7)
                echo "Device types: printer, phone, iphone, windows, linux, iot"
                printf "Spoof as: "; read -r dtype
                spoof_dhcp_fingerprint "$dtype"
                printf "\nPress Enter..."; read -r _
                ;;
            8)
                randomize_hostname
                printf "\nPress Enter..."; read -r _
                ;;
            9)
                restore_hostname
                printf "\nPress Enter..."; read -r _
                ;;
            10)
                full_nac_bypass
                printf "\nPress Enter..."; read -r _
                ;;
            11)
                restore_all_nac
                printf "\nPress Enter..."; read -r _
                ;;
            0) return ;;
            *)
                echo -e "${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# ─── Main Menu Integration ────────────────────────────────────────────────────

advanced_menu() {
    while true; do
        clear
        printf "%b%bRooFi Advanced Features%b\n" "$BOLD" "$CYAN" "$NC"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        echo "1) 📊 TUI Mode (Live Monitor)"
        echo "2) 💾 Profile Management"
        echo "3) 🔄 Fallback Networks & Auto-Reconnect"
        echo "4) 🛡️  NAC Bypass"
        echo "5) 📋 View Logs"
        echo "6) 📤 Export Logs"
        echo "7) 🗑️  Clear Logs"
        echo "0) ← Back to Main Menu"
        echo "───────────────────────────────────────────────────────"
        printf "Select: "; read -r choice
        
        case "$choice" in
            1) tui_mode ;;
            2) profile_menu ;;
            3) fallback_menu ;;
            4) nac_bypass_menu ;;
            5) view_logs ;;
            6) 
                printf "Export filename (default: auto): "; read -r fname
                export_logs "$fname"
                printf "Press Enter..."; read -r _
                ;;
            7) 
                printf "Clear all logs? (y/n): "; read -r confirm
                [ "$confirm" = "y" ] && clear_logs
                printf "Press Enter..."; read -r _
                ;;
            0) return ;;
            *)
                echo -e "${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# ─── CLI Extensions ───────────────────────────────────────────────────────────

handle_advanced_cli() {
    case "$1" in
        --tui)
            init_logging
            init_profiles
            tui_mode
            exit 0
            ;;
        --save-profile)
            init_logging
            init_profiles
            save_profile "$2" "$3"
            exit 0
            ;;
        --connect-profile)
            init_logging
            init_profiles
            connect_profile "$2"
            exit 0
            ;;
        --list-profiles)
            init_profiles
            list_profiles
            exit 0
            ;;
        --add-fallback)
            init_logging
            add_fallback_network "$2" "$3"
            exit 0
            ;;
        --auto-reconnect)
            init_logging
            init_profiles
            auto_reconnect
            exit 0
            ;;
        --start-monitor)
            init_logging
            start_monitor
            exit 0
            ;;
        --stop-monitor)
            stop_monitor
            exit 0
            ;;
        --export-logs)
            init_logging
            export_logs "$2"
            exit 0
            ;;
        --view-logs)
            init_logging
            view_logs
            exit 0
            ;;
        --mac-random)
            init_logging
            mac_randomize "$2"
            exit 0
            ;;
        --mac-clone)
            init_logging
            mac_clone "$2" "$3"
            exit 0
            ;;
        --mac-restore)
            init_logging
            mac_restore "$2"
            exit 0
            ;;
        --portal-detect)
            init_logging
            detect_captive_portal
            exit $?
            ;;
        --portal-bypass)
            init_logging
            bypass_captive_portal
            exit $?
            ;;
        --spoof-dhcp)
            init_logging
            spoof_dhcp_fingerprint "$2" "$3"
            exit 0
            ;;
        --random-hostname)
            init_logging
            randomize_hostname
            exit 0
            ;;
        --restore-hostname)
            init_logging
            restore_hostname
            exit 0
            ;;
        --nac-bypass)
            init_logging
            full_nac_bypass
            exit 0
            ;;
        --nac-restore)
            init_logging
            restore_all_nac
            exit 0
            ;;
    esac
}

# Show advanced help
show_advanced_help() {
    cat << 'EOF'
RooFi Advanced v3.2 - Extended Features

ADVANCED OPTIONS:
    --tui                       Launch TUI mode (live monitor)
    --save-profile NAME SSID    Save network profile
    --connect-profile NAME      Connect using saved profile
    --list-profiles             List all saved profiles
    --add-fallback SSID PRI     Add fallback network (priority 1-10)
    --auto-reconnect            Try to reconnect using fallback networks
    --start-monitor             Start connection monitor daemon
    --stop-monitor              Stop connection monitor daemon
    --export-logs [FILE]        Export debug logs
    --view-logs                 View recent logs

NAC BYPASS:
    --mac-random [IFACE]        Randomize MAC address
    --mac-clone MAC [IFACE]     Clone a specific MAC address
    --mac-restore [IFACE]       Restore original MAC address
    --portal-detect             Detect captive portal
    --portal-bypass             Attempt to bypass captive portal
    --spoof-dhcp TYPE [IFACE]   Spoof DHCP fingerprint
                                Types: printer, phone, iphone, windows, linux, iot
    --random-hostname           Randomize system hostname
    --restore-hostname          Restore original hostname
    --nac-bypass                Run full automated NAC bypass
    --nac-restore               Restore all NAC changes

TUI MODE:
    Interactive live monitor with real-time updates
    Keys: [Q]uit [R]econnect [P]rofiles [F]allback [L]ogs [E]xport

PROFILES:
    Save network credentials for quick switching
    Stored in: ~/.config/roofi/profiles/

FALLBACK NETWORKS:
    Configure priority-based auto-reconnect
    Monitor daemon checks connection every 30s

LOGGING:
    All operations logged to: ~/.config/roofi/roofi.log
    Export logs for debugging on routers

EXAMPLES:
    roofi-advanced.sh --tui
    roofi-advanced.sh --save-profile home "HomeNetwork"
    roofi-advanced.sh --connect-profile home
    roofi-advanced.sh --add-fallback "HomeNetwork" 1
    roofi-advanced.sh --auto-reconnect
    roofi-advanced.sh --start-monitor
    roofi-advanced.sh --export-logs debug.log
    roofi-advanced.sh --mac-random
    roofi-advanced.sh --mac-clone aa:bb:cc:dd:ee:ff
    roofi-advanced.sh --portal-detect
    roofi-advanced.sh --nac-bypass

EOF
}

# ─── Entry Point ──────────────────────────────────────────────────────────────

# Check for advanced CLI arguments
if [ $# -gt 0 ]; then
    case "$1" in
        --help-advanced)
            show_advanced_help
            exit 0
            ;;
        --tui|--save-profile|--connect-profile|--list-profiles|--add-fallback|--auto-reconnect|--start-monitor|--stop-monitor|--export-logs|--view-logs|--mac-random|--mac-clone|--mac-restore|--portal-detect|--portal-bypass|--spoof-dhcp|--random-hostname|--restore-hostname|--nac-bypass|--nac-restore)
            handle_advanced_cli "$@"
            ;;
    esac
fi

# If sourced, make functions available
case "${0##*/}" in
    roofi-advanced.sh|roofi-advanced) ;; # Running directly
    *) return 0 2>/dev/null || true ;;   # Being sourced
esac

# If run directly, show menu
init_logging
init_profiles
advanced_menu
