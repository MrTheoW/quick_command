#!/bin/bash
# Shorten URL is: https://is.gd/fix_lid

# Error check: ensure the script is run with root (sudo) privileges
# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  This script requires administrator privileges (sudo)."
  read -p "Do you want to elevate to sudo? (y/N): " response
  
  # Convert response to lowercase and check it
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "🔑 Elevating privileges... Please enter your password if prompted."
    # Restart the script with sudo, passing the exact same arguments
    exec sudo bash "$0" "$@"
  else
    echo "❌ Execution cancelled. Root privileges are required."
    exit 1
  fi
fi

echo "🚀 Running with root privileges now!"

# These changes are made so closing the lid will NOT let the laptop go to sleep.
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sed -i 's/#HandleLidSwitchDocked=ignore/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf
systemctl restart systemd-logind.service
