#!/bin/bash
set -euo pipefail

# ========== Couleurs ==========
BLUE='\033[1;34m'       # bleu foncé pour [INFO]
LIGHT_BLUE='\033[1;36m' # bleu clair pour texte
GREEN='\033[1;32m'      # succès et Fait
YELLOW='\033[1;33m'     # warning
NC='\033[0m'             # No Color

# ========== Fonctions de log ==========
info()    { echo -e "${BLUE}[INFO]${NC} ${LIGHT_BLUE}$*${NC}"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "[ERROR] $*" >&2; }

# =================== OMV-Config-Base ===================
TASKS_DONE=()

# ---------------- Mise à jour système ----------------
info "Mise à jour du système"
upgrade_output=$(sudo apt upgrade -y -qq 2>&1 || true)

if echo "$upgrade_output" | grep -q "^Inst"; then
    echo "$upgrade_output" | grep "^Inst" | awk '{print $2, $3}' | while read pkg ver; do
        echo -e "${LIGHT_BLUE}$pkg $ver ${GREEN}Fait${NC}"
        TASKS_DONE+=("${LIGHT_BLUE}$pkg $ver ${GREEN}Fait${NC}")
    done
else
    echo -e "${LIGHT_BLUE}Tous les paquets sont déjà à jour ${GREEN}Fait${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}Système déjà à jour ${GREEN}Fait${NC}")
fi

# ---------------- Firmware AMD graphique ----------------
info "Vérification du firmware AMD graphique"
if dpkg -l | grep -qw firmware-amd-graphics; then
    version=$(apt list --installed firmware-amd-graphics 2>/dev/null | grep firmware-amd-graphics | awk -F'/' '{print $2}')
    echo -e "${LIGHT_BLUE}firmware-amd-graphics $version ${GREEN}Fait${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}Firmware AMD graphique mis à jour ${GREEN}Fait${NC}")
else
    sudo apt install -y -qq firmware-amd-graphics
    version=$(apt list --installed firmware-amd-graphics 2>/dev/null | grep firmware-amd-graphics | awk -F'/' '{print $2}')
    echo -e "${LIGHT_BLUE}firmware-amd-graphics $version ${GREEN}Fait${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}Firmware AMD graphique installé ${GREEN}Fait${NC}")
fi

# ---------------- wget ----------------
info "Vérification de wget"
if ! command -v wget &> /dev/null; then
    sudo apt install -y -qq wget
    version=$(apt list --installed wget 2>/dev/null | grep wget | awk -F'/' '{print $2}')
    echo -e "${LIGHT_BLUE}wget $version ${GREEN}Fait${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}wget installé ${GREEN}Fait${NC}")
else
    version=$(apt list --installed wget 2>/dev/null | grep wget | awk -F'/' '{print $2}')
    echo -e "${LIGHT_BLUE}wget $version ${GREEN}Fait${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}wget déjà présent ${GREEN}Fait${NC}")
fi

# ---------------- OMV-Extras ----------------
info "Installation d'OMV-Extras"
if wget -qO /tmp/omv-extras-install.sh https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install; then
    TASKS_DONE+=("${LIGHT_BLUE}OMV-Extras téléchargé ${GREEN}Fait${NC}")
    bash /tmp/omv-extras-install.sh >/dev/null 2>&1
    TASKS_DONE+=("${LIGHT_BLUE}OMV-Extras installé ${GREEN}Fait${NC}")
else
    warn "Erreur téléchargement OMV-Extras"
fi

# ---------------- Extensions OMV de base ----------------
EXTENSIONS=(
    openmediavault-clamav
    openmediavault-cterm
    openmediavault-diskstats
    openmediavault-fail2ban
    openmediavault-md
    openmediavault-sharerootfs
)

for ext in "${EXTENSIONS[@]}"; do
    info "Vérification de l'extension $ext"
    output=$(sudo apt install --only-upgrade -y "$ext" 2>&1)
    if echo "$output" | grep -q "est déjà la version la plus récente"; then
        version=$(echo "$output" | grep "est déjà la version la plus récente" | awk -F'[()]' '{print $2}')
        echo -e "${LIGHT_BLUE}$ext $version ${GREEN}Fait${NC}"
        TASKS_DONE+=("${LIGHT_BLUE}Extension $ext déjà à jour ${GREEN}Fait${NC}")
    else
        pkg_info=$(echo "$output" | grep "^Inst" | awk '{print $2, $3}' )
        echo -e "${LIGHT_BLUE}$pkg_info ${GREEN}Fait${NC}"
        TASKS_DONE+=("${LIGHT_BLUE}Extension $ext installée/mise à jour ${GREEN}Fait${NC}")
    fi
done

# ---------------- Installation AMD GPU ROCm ----------------
DEB_FILE="amdgpu-install_6.4.60403-1_all.deb"
DEB_URL="https://repo.radeon.com/amdgpu-install/6.4.3/ubuntu/jammy/$DEB_FILE"

info "Téléchargement et installation du package AMD GPU"
[ -f "$DEB_FILE" ] && rm -f "$DEB_FILE"
wget -q "$DEB_URL" -O "$DEB_FILE"
sudo apt install -y -qq ./"$DEB_FILE"
version=$(apt list --installed amdgpu-install 2>/dev/null | grep amdgpu-install | awk -F'/' '{print $2}')
echo -e "${LIGHT_BLUE}amdgpu-install $version ${GREEN}Fait${NC}"
TASKS_DONE+=("${LIGHT_BLUE}Package AMD GPU installé ${GREEN}Fait${NC}")

# ---------------- Python utils ----------------
for pkg in python3-setuptools python3-wheel; do
    sudo apt install -y -qq "$pkg"
    version=$(apt list --installed "$pkg" 2>/dev/null | grep "$pkg" | awk -F'/' '{print $2}')
    echo -e "${LIGHT_BLUE}$pkg $version ${GREEN}Fait${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}$pkg installé ${GREEN}Fait${NC}")
done

# ---------------- Groupes utilisateur ----------------
sudo usermod -a -G render,video "$LOGNAME"
TASKS_DONE+=("${LIGHT_BLUE}Utilisateur ajouté aux groupes render et video ${GREEN}Fait${NC}")

# ---------------- ROCm ----------------
info "Installation de ROCm via le package AMD GPU"
if ! sudo apt install -y -qq rocm-dkms rocm-dev rocm-utils; then
    warn "Installation ROCm partielle, vérifier le dépôt AMD"
fi
for pkg in rocm-dkms rocm-dev rocm-utils; do
    if dpkg -l | grep -qw "$pkg"; then
        version=$(apt list --installed "$pkg" 2>/dev/null | grep "$pkg" | awk -F'/' '{print $2}')
        echo -e "${LIGHT_BLUE}$pkg $version ${GREEN}Fait${NC}"
        TASKS_DONE+=("${LIGHT_BLUE}$pkg installé ${GREEN}Fait${NC}")
    else
        warn "$pkg non détecté après installation"
    fi
done

# ---------------- Extension KVM ----------------
info "Installation de l'extension KVM"
if ! dpkg -l | grep -qw openmediavault-kvm; then
    sudo apt install -y -qq openmediavault-kvm
fi
version=$(apt list --installed openmediavault-kvm 2>/dev/null | grep openmediavault-kvm | awk -F'/' '{print $2}')
echo -e "${LIGHT_BLUE}openmediavault-kvm $version ${GREEN}Fait${NC}"
TASKS_DONE+=("${LIGHT_BLUE}Extension openmediavault-kvm installée/mise à jour ${GREEN}Fait${NC}")

# ---------------- Nettoyage ----------------
info "Nettoyage des packages inutiles"
sudo apt autoremove -y
TASKS_DONE+=("${LIGHT_BLUE}Packages inutiles supprimés ${GREEN}Fait${NC}")

# ---------------- Résumé des tâches ----------------
echo -e "${BLUE}====================================================================${NC}"
for task in "${TASKS_DONE[@]}"; do
    echo -e "$task"
done
echo -e "${BLUE}====================================================================${NC}"

success "Partie 1 terminée : OMV-Config-Base prête avec GPU ROCm et KVM"
