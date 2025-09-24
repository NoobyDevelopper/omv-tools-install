#!/bin/bash
set -euo pipefail

clear

# ==================== Couleurs ====================
BLUE='\033[1;34m'
LIGHT_BLUE='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} ${LIGHT_BLUE}$*${NC}"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR] $*${NC}"; }

# ==================== Progress Bar ====================
show_progress() {
    local done=$1
    local total=$2
    local width=40
    local percent=$(( done * 100 / total ))
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    printf "\r${BLUE}[PROGRESS]${NC} ${BLUE}|"
    printf '%0.s█' $(seq 1 $filled)
    printf '%0.s ' $(seq 1 $empty)
    printf "| %3d%% (%d/%d)${NC}" $percent $done $total
}

# ==================== Checklist ====================
declare -A CHECKLIST
mark_done() { CHECKLIST["$1"]="✅"; }
mark_warn() { CHECKLIST["$1"]="⚠️"; }
mark_fail() { CHECKLIST["$1"]="❌"; }

show_checklist() {
    echo -e "\n${CYAN}==================== Checklist ====================${NC}"
    for task in "${!CHECKLIST[@]}"; do
        echo -e "${CHECKLIST[$task]} $task"
    done
    echo -e "${CYAN}==================================================${NC}\n"
}

# ==================== Étapes ====================
TASKS_TOTAL=13
TASKS_DONE_COUNT=0
finish_task() {
    local task="$1"
    local status="$2"
    case "$status" in
        done) mark_done "$task" ;;
        warn) mark_warn "$task" ;;
        fail) mark_fail "$task" ;;
    esac
    TASKS_DONE_COUNT=$((TASKS_DONE_COUNT+1))
    show_progress $TASKS_DONE_COUNT $TASKS_TOTAL
}

STEPS=(
    "Mise à jour système"
    "Firmware AMD"
    "wget"
    "OMV-Extras"
    "Extensions OMV"
    "Python utils"
    "Git"
    "GPU Drivers + ROCm"
    "Groupes utilisateur"
    "OMV-KVM"
    "OMV-Compose + Docker"
    "Nettoyage"
    "Venv"
)

TMP_DIR="/tmp/omv_temp"
mkdir -p "$TMP_DIR"

# --- Mise à jour système ---
info "Mise à jour du système"
if sudo apt update -qq && sudo apt upgrade -y -qq; then
    success "Système à jour"
    finish_task "Mise à jour système" done
else
    finish_task "Mise à jour système" fail
fi

# --- Firmware AMD ---
info "Vérification firmware AMD"
if dpkg -l | grep -qw firmware-amd-graphics; then
    success "Firmware AMD déjà présent"
    finish_task "Firmware AMD" done
else
    if sudo apt install -y -qq firmware-amd-graphics; then
        success "Firmware AMD installé"
        finish_task "Firmware AMD" done
    else
        finish_task "Firmware AMD" fail
    fi
fi

# --- wget ---
info "Vérification de wget"
if ! command -v wget &>/dev/null; then
    if sudo apt install -y -qq wget; then
        success "wget installé"
        finish_task "wget" done
    else
        finish_task "wget" fail
    fi
else
    success "wget déjà présent"
    finish_task "wget" done
fi

# --- OMV-Extras ---
info "Installation d'OMV-Extras"
OMV_EXTRAS="$TMP_DIR/omv-extras-install.sh"
if wget -qO "$OMV_EXTRAS" https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install && bash "$OMV_EXTRAS" >/dev/null 2>&1; then
    success "OMV-Extras installé"
    finish_task "OMV-Extras" done
else
    finish_task "OMV-Extras" fail
fi

# --- Extensions OMV ---
EXTENSIONS=(openmediavault-clamav openmediavault-cterm openmediavault-diskstats openmediavault-fail2ban openmediavault-md openmediavault-sharerootfs)
for ext in "${EXTENSIONS[@]}"; do
    sudo apt install -y -qq "$ext"
done
success "Extensions OMV installées"
finish_task "Extensions OMV" done

# --- Python utils ---
info "Installation Python utils"
if sudo apt install -y -qq python3-venv python3-pip python3-setuptools python3-wheel; then
    success "Python utils installés"
    finish_task "Python utils" done
else
    finish_task "Python utils" fail
fi

# --- Git ---
info "Vérification de Git"
if ! command -v git &>/dev/null; then
    if sudo apt install -y -qq git; then
        success "Git installé"
        finish_task "Git" done
    else
        finish_task "Git" fail
    fi
else
    success "Git déjà présent"
    finish_task "Git" done
fi

# --- GPU Detection + ROCm ---
info "Détection GPU"
GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)
if echo "$GPU_VENDOR" | grep -qi "amd"; then
    info "GPU AMD détecté"
    DEB_FILE="$TMP_DIR/amdgpu-install_6.4.60403-1_all.deb"
    DEB_URL="https://repo.radeon.com/amdgpu-install/6.4.3/ubuntu/jammy/amdgpu-install_6.4.60403-1_all.deb"
    wget -q "$DEB_URL" -O "$DEB_FILE"
    sudo apt install -y "$DEB_FILE"
    sudo apt update -qq
    sudo apt install -y python3-setuptools python3-wheel
    sudo usermod -a -G render,video "$LOGNAME"
    if sudo apt install -y rocm; then
        success "Pilotes AMD + ROCm installés"
        finish_task "GPU Drivers + ROCm" done
    else
        finish_task "GPU Drivers + ROCm" fail
    fi
elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    info "GPU NVIDIA détecté"
    sudo apt install -y -qq nvidia-driver nvidia-cuda-toolkit
    success "Pilotes NVIDIA + CUDA installés"
    finish_task "GPU Drivers + ROCm" done
elif echo "$GPU_VENDOR" | grep -qi "intel"; then
    info "GPU Intel détecté"
    sudo apt install -y -qq intel-gpu-tools
    success "Pilotes Intel installés"
    finish_task "GPU Drivers + ROCm" done
else
    warn "Aucun GPU pris en charge détecté"
    finish_task "GPU Drivers + ROCm" warn
fi

# --- Groupes utilisateur ---
sudo usermod -a -G render,video "$LOGNAME"
success "Utilisateur ajouté aux groupes render et video"
finish_task "Groupes utilisateur" done

# --- KVM ---
sudo apt install -y -qq openmediavault-kvm
success "KVM installé"
finish_task "OMV-KVM" done

# --- OMV-Compose + Docker ---
info "Installation OMV-Compose (inclut Docker)"
if sudo apt install -y -qq openmediavault-compose; then
    success "OMV-Compose installé (Docker inclus)"
    finish_task "OMV-Compose + Docker" done
else
    finish_task "OMV-Compose + Docker" fail
fi

# --- Nettoyage automatique ---
info "Nettoyage des fichiers temporaires et caches"
rm -rf "$TMP_DIR"
sudo apt clean
sudo apt autoremove -y
success "Nettoyage terminé"
finish_task "Nettoyage" done

# --- Venv global ---
VENV_DIR="$HOME/onnx_env"
info "Vérification du venv global"
[ -d "$VENV_DIR" ] || python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip setuptools wheel numpy
deactivate
success "Venv global prêt"
finish_task "Venv" done

# ==================== Checklist finale ====================
show_checklist
success "Configuration OMV terminée !"
