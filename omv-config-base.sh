#!/bin/bash
set -euo pipefail

# ========== Fonctions de log ==========
info()    { echo -e "[INFO] $*"; }
success() { echo -e "[SUCCESS] $*"; }
warn()    { echo -e "[WARN] $*"; }
error()   { echo -e "[ERROR] $*" >&2; }

# ========== OMV-Config-Base ==========
info "Mise à jour du système"
sudo apt update && sudo apt upgrade -y  

# Firmware AMD graphique
if dpkg -l | grep -qw firmware-amd-graphics; then
    info "Firmware AMD graphique déjà installé. Mise à jour si nécessaire..."
    sudo apt install --only-upgrade -y firmware-amd-graphics
else
    info "Firmware AMD graphique non installé. Installation..."
    sudo apt install -y firmware-amd-graphics
fi

# wget
if ! command -v wget &> /dev/null; then
    info "wget non trouvé. Installation..."
    sudo apt update && sudo apt install -y wget
else
    info "wget déjà installé."
fi

# OMV-Extras
info "Installation d'OMV-Extras"
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | bash

# Extensions OMV
EXTENSIONS=(
    openmediavault-clamav
    openmediavault-cterm
    openmediavault-diskstats
    openmediavault-fail2ban
    openmediavault-md
    openmediavault-sharerootfs
)

for ext in "${EXTENSIONS[@]}"; do
    if dpkg -l | grep -qw "$ext"; then
        info "Extension $ext déjà installée. Mise à jour si nécessaire..."
        sudo apt install --only-upgrade -y "$ext"
    else
        info "Extension $ext non installée. Installation..."
        sudo apt install -y "$ext"
    fi
done

success "Partie 1 terminée : OMV-Config-Base prête"
