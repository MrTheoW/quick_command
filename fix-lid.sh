#!/bin/bash
# Shorten URL is: https://is.gd
# run as: bash <(curl -sSL https://is.gd/fix_lid)

# Color codes for clean terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0;0m' # No Color

CONFIG_FILE="/etc/systemd/logind.conf"
SETTINGS=("HandleLidSwitch" "HandleLidSwitchExternalPower" "HandleLidSwitchDocked")
CHANGED=false

echo -e "${BLUE}[INFO] Script started for optimizing logind.conf for laptops...${NC}"

# Error check: ensure the script is run with root (sudo) privileges
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}[ERROR] Execution cancelled. Root privileges are required.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}[NOTICE] This script requires administrator privileges (sudo).${NC}"
    # Preroll sudo check so that the user enters their password immediately if necessary
    sudo -v || exit 1
fi

# Function to run commands with sudo if necessary
run_as_root() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# 1. Controleer en update de instellingen naar 'ignore'
for setting in "${SETTINGS[@]}"; do
    # Check if the line is already correctly set (no hashtag, ends with ignore)
    if grep -q "^${setting}=ignore" "$CONFIG_FILE"; then
        echo -e "${GREEN}[UNCHANGED]${NC} ${setting} is already set to 'ignore'."
    else
        echo -e "${YELLOW}[UPDATING]${NC} Changing ${setting} to 'ignore'..."
        
        # If the setting is commented out (#HandleLidSwitch=...), replace it.
        # Otherwise, if it already exists with a different value, overwrite it.
        # If it doesn't exist at all, add it to the end of the [Login] section.
        if grep -q "^#${setting}=" "$CONFIG_FILE"; then
            run_as_root sed -i "s/^#${setting}=.*/${setting}=ignore/" "$CONFIG_FILE"
        elif grep -q "^${setting}=" "$CONFIG_FILE"; then
            run_as_root sed -i "s/^${setting}=.*/${setting}=ignore/" "$CONFIG_FILE"
        else
            run_as_root sed -i "/^\[Login\]/a ${setting}=ignore" "$CONFIG_FILE"
        fi
        
        CHANGED=true
        echo -e "${GREEN}[UPDATED]${NC} ${setting} has been successfully modified."
    fi
done

# 2. Processing Based on Changes
if [ "$CHANGED" = true ]; then
    echo -e "${BLUE}[INFO] Changes detected. Restarting the systemd-logind service...${NC}"
    if run_as_root systemctl restart systemd-logind; then
        echo -e "${GREEN}[SUCCESS] System settings have been successfully applied!${NC}"
    else
        echo -e "${RED}[ERROR] Error while restarting systemd-logind.${NC}"
        exit 1
    fi
else
    echo -e "${BLUE}[INFO] No changes are needed. Everything is already set up optimally.${NC}"
    
    # INTERACTIVE PROMPT FIX: We read directly from /dev/tty so as not to interfere with cURL pipes
    echo -n -e "${YELLOW}[PROMPT] Do you want to reset the settings to their factory defaults? (y/N): ${NC}"
    read -r response < /dev/tty
    
    # Convert input to lowercase
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$response" == "y" || "$response" == "yes" ]]; then
        echo -e "${BLUE}[INFO] Restore factory settings (uncomment)...${NC}"
        
        ROLLBACK_CHANGED=false
        for setting in "${SETTINGS[@]}"; do
            # If the rule is active (does not start with #), add a # in front of it and, if necessary, reset it to a default value (optional; “suspend” is often the default)
            if grep -q "^${setting}=" "$CONFIG_FILE"; then
                echo -e "${YELLOW}[ROLLBACK]${NC} Comment out ${setting}..."
                run_as_root sed -i "s/^${setting}=.*/#${setting}=suspend/" "$CONFIG_FILE"
                ROLLBACK_CHANGED=true
            fi
        done
        
        if [ "$ROLLBACK_CHANGED" = true ]; then
            echo -e "${BLUE}[INFO] Restarting the systemd-logind service for rollback...${NC}"
            if run_as_root systemctl restart systemd-logind; then
                echo -e "${GREEN}[SUCCESS] Factory settings successfully restored!${NC}"
            else
                echo -e "${RED}[ERROR] Error restarting systemd-logind during rollback.${NC}"
                exit 1
            fi
        else
            echo -e "${GREEN}[UNCHANGED]${NC} There were no active custom settings to revert."
        fi
    else
        echo -e "${BLUE}[INFO] Rollback canceled. Script terminated.${NC}"
    fi
fi
