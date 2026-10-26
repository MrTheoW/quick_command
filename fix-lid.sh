#!/bin/bash
# Shorten URL is: https://is.gd
# run as: bash <(curl -sSL https://is.gd/fix_lid)

# Kleuren voor nette statusupdates
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0;0m' # No Color

CONFIG_FILE="/etc/systemd/logind.conf"
SETTINGS=("HandleLidSwitch" "HandleLidSwitchExternalPower" "HandleLidSwitchDocked")
CHANGED=false

echo -e "${BLUE}[INFO] Script gestart voor het optimaliseren van logind.conf...${NC}"

# Controleer of sudo beschikbaar is (indien niet uitgevoerd als root)
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}[ERROR] Dit script vereist root-rechten, maar 'sudo' is niet geïnstalleerd.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}[NOTICE] Dit script heeft incidenteel sudo-rechten nodig voor systeemaanpassingen.${NC}"
    # Preroll sudo check zodat de gebruiker direct zijn wachtwoord invoert indien nodig
    sudo -v || exit 1
fi

# Functie om op te treden met sudo indien nodig
run_as_root() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# 1. Controleer en update de instellingen naar 'ignore'
for setting in "${SETTINGS[@]}"; do
    # Controleer of de instelling al exact op 'ignore' staat (en niet is uitgecommentarieerd)
    if grep -q "^${setting}=ignore" "$CONFIG_FILE"; then
        echo -e "${GREEN}[UNCHANGED]${NC} ${setting} staat al op 'ignore'."
    else
        echo -e "${YELLOW}[UPDATING]${NC} Aanpassen van ${setting} naar 'ignore'..."
        
        # Als de instelling uitgecommentarieerd is (#HandleLidSwitch=...), vervang deze.
        # Anders, als hij al bestaat met een andere waarde, overschrijf deze.
        # Als hij helemaal niet bestaat, voeg hem toe aan het einde van de [Login] sectie.
        if grep -q "^#${setting}=" "$CONFIG_FILE"; then
            run_as_root sed -i "s/^#${setting}=.*/${setting}=ignore/" "$CONFIG_FILE"
        elif grep -q "^${setting}=" "$CONFIG_FILE"; then
            run_as_root sed -i "s/^${setting}=.*/${setting}=ignore/" "$CONFIG_FILE"
        else
            run_as_root sed -i "/^\[Login\]/a ${setting}=ignore" "$CONFIG_FILE"
        fi
        
        CHANGED=true
        echo -e "${GREEN}[UPDATED]${NC} ${setting} is succesvol aangepast."
    fi
done

# 2. Afhandeling op basis van wijzigingen
if [ "$CHANGED" = true ]; then
    echo -e "${BLUE}[INFO] Wijzigingen gedetecteerd. Herstarten van systemd-logind service...${NC}"
    if run_as_root systemctl restart systemd-logind; then
        echo -e "${GREEN}[SUCCESS] Systeeminstellingen zijn succesvol toegepast!${NC}"
    else
        echo -e "${RED}[ERROR] Fout bij het herstarten van systemd-logind.${NC}"
        exit 1
    fi
else
    echo -e "${BLUE}[INFO] Geen wijzigingen nodig. Alles staat al optimaal ingesteld.${NC}"
    
    # INTERACTIEVE PROMPT FIX: We lezen direct uit /dev/tty om cURL-pijpen niet te verstoren
    echo -n -e "${YELLOW}[PROMPT] Wil je de instellingen terugrollen naar de fabrieksinstellingen? (y/N): ${NC}"
    read -r response < /dev/tty
    
    # Converteer invoer naar kleine letters
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$response" == "y" || "$response" == "yes" ]]; then
        echo -e "${BLUE}[INFO] Terugdraaien naar fabrieksinstellingen (uitcommentariëren)...${NC}"
        
        ROLLBACK_CHANGED=false
        for setting in "${SETTINGS[@]}"; do
            # Als de regel actief is (niet begint met #), zet er dan een # voor en herstel eventueel naar een standaardwaarde (optioneel, suspend is vaak default)
            if grep -q "^${setting}=" "$CONFIG_FILE"; then
                echo -e "${YELLOW}[ROLLBACK]${NC} Uitcommentariëren van ${setting}..."
                run_as_root sed -i "s/^${setting}=.*/#${setting}=suspend/" "$CONFIG_FILE"
                ROLLBACK_CHANGED=true
            fi
        done
        
        if [ "$ROLLBACK_CHANGED" = true ]; then
            echo -e "${BLUE}[INFO] Herstarten van systemd-logind service voor rollback...${NC}"
            if run_as_root systemctl restart systemd-logind; then
                echo -e "${GREEN}[SUCCESS] Fabrieksinstellingen succesvol hersteld!${NC}"
            else
                echo -e "${RED}[ERROR] Fout bij het herstarten van systemd-logind tijdens rollback.${NC}"
                exit 1
            fi
        else
            echo -e "${GREEN}[UNCHANGED]${NC} Er waren geen actieve aangepaste instellingen om terug te draaien."
        fi
    else
        echo -e "${BLUE}[INFO] Rollback geannuleerd. Script beëindigd.${NC}"
    fi
fi
