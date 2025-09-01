#!/bin/bash
set -euo pipefail

# ========== Fonctions de log ==========
info()    { echo -e "[INFO] $*"; }
success() { echo -e "[SUCCESS] $*"; }
warn()    { echo -e "[WARN] $*"; }
error()   { echo -e "[ERROR] $*" >&2; }

# ========== OMV-Config-Base ==========
TASKS_DONE=()

info "Mise à jour du système"
sudo apt update && sudo apt upgrade -y
TASKS_DONE+=("Système mis à jour")

# Firmware AMD graphique
if dpkg -l | grep -qw firmware-amd-graphics; then
    info "Firmware AMD graphique déjà installé. Mise à jour si nécessaire..."
    sudo apt install --only-upgrade -y firmware-amd-graphics
else
    info "Firmware AMD graphique non installé. Installation..."
    sudo apt install -y firmware-amd-graphics
fi
TASKS_DONE+=("Firmware AMD graphique installé/mis à jour")

# wget
if ! command -v wget &> /dev/null; then
    info "wget non trouvé. Installation..."
    sudo apt install -y wget
else
    info "wget déjà installé."
fi
TASKS_DONE+=("wget vérifié/installer")

# OMV-Extras
info "Installation d'OMV-Extras"
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | bash
TASKS_DONE+=("OMV-Extras installé")

# Extensions OMV de base
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
    TASKS_DONE+=("Extension $ext installée/mise à jour")
done

# ========== Installation AMD GPU ROCm et outils ==========
DEB_FILE="amdgpu-install_6.4.60403-1_all.deb"
DEB_URL="https://repo.radeon.com/amdgpu-install/6.4.3/ubuntu/jammy/$DEB_FILE"

info "Téléchargement et installation du package AMD GPU"

# Supprimer le fichier si déjà présent
if [[ -f "$DEB_FILE" ]]; then
    info "Fichier $DEB_FILE existant, suppression..."
    rm -f "$DEB_FILE"
fi

wget "$DEB_URL" -O "$DEB_FILE"
sudo apt install -y ./"$DEB_FILE"
sudo apt update
TASKS_DONE+=("Package AMD GPU installé")

# Python utils
sudo apt install -y python3-setuptools python3-wheel
TASKS_DONE+=("Python setuptools et wheel installés")

# Ajout de l’utilisateur aux groupes render et video
sudo usermod -a -G render,video "$LOGNAME"
TASKS_DONE+=("Utilisateur ajouté aux groupes render et video")

# ROCm installation
info "Installation de ROCm"
if apt-cache show rocm=6.4.3 &>/dev/null; then
    sudo apt install -y rocm=6.4.3
else
    warn "Version 6.4.3 de ROCm non trouvée dans les dépôts, installation de la dernière disponible"
    sudo apt install -y rocm || warn "ROCm non trouvé, vérifier le dépôt AMD"
fi
TASKS_DONE+=("ROCm installé")

# Vérification et installation des packages supplémentaires
for pkg in migraphx migraphx-dev half; do
    if ! dpkg -l | grep -qw "$pkg"; then
        sudo apt install -y "$pkg"
        TASKS_DONE+=("$pkg installé")
    else
        TASKS_DONE+=("$pkg déjà présent")
    fi
done

# pip3 installation et mise à jour
sudo apt install -y python3-pip
python3 -m pip install --upgrade pip
TASKS_DONE+=("pip3 installé et mis à jour")

# Gestion onnxruntime-rocm et numpy
if python3 -m pip show onnxruntime-rocm &>/dev/null; then
    python3 -m pip uninstall -y onnxruntime-rocm
fi
if python3 -m pip show numpy &>/dev/null; then
    python3 -m pip uninstall -y numpy
fi

python3 -m pip install https://repo.radeon.com/rocm/manylinux/rocm-rel-6.1.3/onnxruntime_rocm-1.17.0-cp310-cp310-linux_x86_64.whl
python3 -m pip install numpy==1.26.4
TASKS_DONE+=("onnxruntime-rocm et numpy installés")

# Vérification du provider ROCm/MIGraphX
PROVIDERS=$(python3 -c "import onnxruntime as ort; print(ort.get_available_providers())")
if [[ "$PROVIDERS" == *"MIGraphXExecutionProvider"* ]] && [[ "$PROVIDERS" == *"ROCMExecutionProvider"* ]]; then
    TASKS_DONE+=("onnxruntime ROCm et MIGraphX disponibles : $PROVIDERS")
else
    warn "onnxruntime ROCm/MIGraphX non détecté correctement : $PROVIDERS"
fi

# Installation de l’extension KVM
if dpkg -l | grep -qw openmediavault-kvm; then
    info "Extension openmediavault-kvm déjà installée"
else
    sudo apt install -y openmediavault-kvm
fi
TASKS_DONE+=("Extension openmediavault-kvm installée/mise à jour")

# ========== Résumé des tâches ==========
echo "==================== Résumé des tâches effectuées ===================="
for task in "${TASKS_DONE[@]}"; do
    echo " - $task"
done
echo "===================================================================="

success "Partie 1 terminée : OMV-Config-Base prête avec GPU ROCm et KVM"
