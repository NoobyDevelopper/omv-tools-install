#!/bin/bash
set -euo pipefail

# ========== Couleurs ==========
BLUE='\033[1;34m'
LIGHT_BLUE='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# ---------------- Fonctions de détection automatique ----------------
check_pkg() {
    local pkg=$1
    if dpkg -l | grep -qw "$pkg"; then
        status=$(apt list --upgradable 2>/dev/null | grep "^$pkg/" || echo "")
        if [ -z "$status" ]; then
            echo -e "${LIGHT_BLUE}$pkg ${GREEN}Déjà à jour${NC}"
            TASKS_DONE+=("${LIGHT_BLUE}$pkg ${GREEN}Déjà à jour${NC}")
        else
            sudo apt install -y "$pkg"
            echo -e "${LIGHT_BLUE}$pkg ${YELLOW}Mise à jour${NC}"
            TASKS_DONE+=("${LIGHT_BLUE}$pkg ${YELLOW}Mise à jour${NC}")
        fi
    else
        sudo apt install -y "$pkg"
        echo -e "${LIGHT_BLUE}$pkg ${GREEN}Installé${NC}"
        TASKS_DONE+=("${LIGHT_BLUE}$pkg ${GREEN}Installé${NC}")
    fi
}

# ---------------- Firmware AMD graphique ----------------
check_pkg "firmware-amd-graphics"

# ---------------- wget ----------------
check_pkg "wget"

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
    check_pkg "$ext"
done

# ---------------- Python utils ----------------
PYTHON_PKGS=(python3-venv python3-pip python3-setuptools python3-wheel)
for pkg in "${PYTHON_PKGS[@]}"; do
    check_pkg "$pkg"
done

# ---------------- Création venv ----------------
VENV_DIR="$HOME/onnx_env"
if [ -d "$VENV_DIR" ]; then
    echo -e "${LIGHT_BLUE}Venv déjà présent ${GREEN}Déjà à jour${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}Venv déjà présent ${GREEN}Déjà à jour${NC}")
else
    python3 -m venv "$VENV_DIR"
    echo -e "${LIGHT_BLUE}Venv créé dans $VENV_DIR ${GREEN}Installé${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}Venv créé dans $VENV_DIR ${GREEN}Installé${NC}")
fi

# ---------------- Activation venv et ONNX Runtime ----------------
source "$VENV_DIR/bin/activate"

if pip show onnxruntime-rocm &> /dev/null; then
    echo -e "${LIGHT_BLUE}onnxruntime-rocm ${GREEN}Déjà à jour${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}onnxruntime-rocm ${GREEN}Déjà à jour${NC}")
else
    pip install --upgrade pip setuptools wheel
    pip install onnxruntime-rocm
    echo -e "${LIGHT_BLUE}onnxruntime-rocm ${GREEN}Installé${NC}"
    TASKS_DONE+=("${LIGHT_BLUE}onnxruntime-rocm ${GREEN}Installé${NC}")
fi

# ---------------- Sortie automatique du venv ----------------
deactivate
success "Venv désactivé automatiquement"

# ---------------- Installation AMD GPU ----------------
DEB_FILE="amdgpu-install_6.4.60403-1_all.deb"
DEB_URL="https://repo.radeon.com/amdgpu-install/6.4.3/ubuntu/jammy/$DEB_FILE"
info "Téléchargement et installation du package AMD GPU"
[ -f "$DEB_FILE" ] && rm -f "$DEB_FILE"
wget -q "$DEB_URL" -O "$DEB_FILE"
sudo apt install -y -qq ./"$DEB_FILE"
TASKS_DONE+=("${LIGHT_BLUE}Package AMD GPU installé ${GREEN}Fait${NC}")

# ---------------- Groupes utilisateur ----------------
sudo usermod -a -G render,video "$LOGNAME"
TASKS_DONE+=("${LIGHT_BLUE}Utilisateur ajouté aux groupes render et video ${GREEN}Fait${NC}")

# ---------------- ROCm ----------------
check_pkg "rocm"

# ---------------- Extension KVM ----------------
check_pkg "openmediavault-kvm"

# ---------------- OMV-Compose + Docker Compose ----------------
check_pkg "openmediavault-compose"
check_pkg "docker-compose-plugin"

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

success "Script complet terminé : OMV + GPU ROCm + KVM + Docker Compose + Python venv + ONNX Runtime"
