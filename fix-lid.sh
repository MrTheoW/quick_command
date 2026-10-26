#!/bin/bash
# Shorten URL is: https://is.gd
# run as: bash <(curl -sSL https://is.gd/fix_lid)

# Color codes for clean terminal output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Track if any changes were actually made
CHANGES_MADE=false

# Error check: ensure the script is run with root (sudo) privileges
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  This script requires administrator privileges (sudo)."
  read -p "Do you want to elevate to sudo? (y/N): " response
  
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "🔑 Elevating privileges... Please enter your password if prompted."
    exec sudo bash "$0" "$@"
  else
    echo "❌ Execution cancelled. Root privileges are required."
    exit 1
  fi
fi

echo "🚀 Running with root privileges now!"
echo ""
echo "⚙️  Starting configuration updates..."
echo ""

# --- Function to update and report status ---
update_config() {
  local step=$1
  local key=$2
  
  # Check if the line is already correctly set (no hashtag, ends with ignore)
  if grep -q "^${key}=ignore" /etc/systemd/logind.conf; then
    echo -e "📝 [$step/4] $key... ${GREEN}[UNCHANGED]${NC}"
  else
    # Perform the update
    sed -i "s/^#\?${key}=.*/${key}=ignore/" /etc/systemd/logind.conf
    echo -e "📝 [$step/4] $key... ${YELLOW}[UPDATED]${NC}"
    CHANGES_MADE=true
  fi
}

# Run the checks and updates
update_config "1" "HandleLidSwitch"
update_config "2" "HandleLidSwitchExternalPower"
update_config "3" "HandleLidSwitchDocked"

# Step 4: Final logic based on changes
if [ "$CHANGES_MADE" = true ]; then
  echo "🔄 [4/4] Restarting systemd-logind service to apply changes..."
  systemctl restart systemd-logind.service
  echo ""
  echo -e "${YELLOW}✅ Done! All changes have been processed successfully.${NC}"
else
  echo -e "⏭️  [4/4] Skipping service restart... No modifications needed."
  echo ""
  echo -e "${GREEN}💡 No changes were made (settings are already on ignore).${NC}"
  echo ""
  
  # Ask user if they want to revert to stock factory defaults
  read -p "🔄 Do you want to restore the default Linux settings? (y/N): " revert_response
  if [[ "$revert_response" =~ ^[Yy]$ ]]; then
    echo ""
    echo "⚙️  Restoring stock logind.conf defaults..."
    
    # Revert to standard systemd defaults
    sed -i 's/^#\?HandleLidSwitch=.*/HandleLidSwitch=suspend/' /etc/systemd/logind.conf
    sed -i 's/^#\?HandleLidSwitchExternalPower=.*/#HandleLidSwitchExternalPower=suspend/' /etc/systemd/logind.conf
    sed -i 's/^#\?HandleLidSwitchDocked=.*/#HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf
    
    echo "🔄 Restarting systemd-logind service to apply defaults..."
    systemctl restart systemd-logind.service
    echo ""
    echo -e "${YELLOW}✅ Done! Successfully reverted to original stock settings.${NC}"
  else
    echo "❌ Revert cancelled. Keeping current settings."
  fi
fi
