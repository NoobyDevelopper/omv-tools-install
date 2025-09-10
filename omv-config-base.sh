#!/bin/bash
set -euo pipefail

# ========== Couleurs ==========
BLUE='\033[1;34m'
LIGHT_BLUE='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

# ========== Fonctions de log ==========
info()    { echo -e "${BLUE}[INFO]${NC} ${LIGHT_BLUE}$*${NC}"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# =================== Checklist dynamique ===================
declare -A CHECKLIST

mark_done() { CHECKLIST["$1"]="✅"; }
mark_warn() { CHECKLIST["$1"]="⚠️"; }
mark_fail() { CHECKLIST["$1"]="❌"; }

show_checklist() {
    echo -e "${BLUE}==================== Checklist ====================${NC}"
    for task in "${!CHECKLIST[@]}"; do
        echo -e "${CHECKLIST[$task]} $task"
    done
    echo -e "${BLUE}==================================================${NC}"
}

# =================== Début script ===================

# ---------------- Python virtualenv ----------------
info "Vérification du virtualenv"
if [ -d ~/onnx_env ]; then
    mark_done "Virtualenv existant"
else
    python3 -m venv ~/onnx_env && mark_done "Virtualenv créé" || mark_fail "Impossible de créer le virtualenv"
fi

source ~/onnx_env/bin/activate

# Installer pip, setuptools, wheel
for pkg in pip setuptools wheel; do
    if pip show "$pkg" &> /dev/null; then
        mark_done "$pkg déjà présent"
    else
        pip install -q "$pkg" && mark_done "$pkg installé" || mark_fail "Impossible d'installer $pkg"
    fi
done

# ---------------- Détection GPU ----------------
info "Détection du GPU"
GPU_TYPE="unknown"
if lspci | grep -i amd &> /dev/null; then
    GPU_TYPE="AMD"
    mark_done "GPU AMD détecté"
elif lspci | grep -i nvidia &> /dev/null; then
    GPU_TYPE="NVIDIA"
    mark_done "GPU NVIDIA détecté"
elif lspci | grep -i intel &> /dev/null; then
    GPU_TYPE="Intel"
    mark_done "GPU Intel détecté"
else
    mark_warn "Aucun GPU détecté"
fi

# ---------------- Installation drivers GPU ----------------
case "$GPU_TYPE" in
    AMD)
        info "Installation pilotes AMD et ROCm"
        sudo apt install -y rocm && mark_done "ROCm installé" || mark_fail "ROCm échoué"
        ;;
    NVIDIA)
        info "Installation pilotes NVIDIA et CUDA"
        sudo apt install -y nvidia-driver-535 nvidia-cuda-toolkit \
            && mark_done "Pilotes NVIDIA et CUDA installés" \
            || mark_fail "Pilotes NVIDIA/ CUDA échoués"
        ;;
    Intel)
        info "Installation pilotes Intel GPU"
        sudo apt install -y intel-media-va-driver-non-free vainfo \
            && mark_done "Pilotes Intel installés" \
            || mark_fail "Pilotes Intel échoués"
        ;;
esac

# ---------------- OMV-Extras et extensions ----------------
info "Installation OMV-Extras"
if wget -qO /tmp/omv-extras-install.sh https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install; then
    bash /tmp/omv-extras-install.sh >/dev/null 2>&1 && mark_done "OMV-Extras installé"
else
    mark_fail "OMV-Extras téléchargement échoué"
fi

EXTENSIONS=(clamav cterm diskstats fail2ban md sharerootfs kvm compose)
for ext in "${EXTENSIONS[@]}"; do
    sudo apt install -y openmediavault-"$ext" &> /dev/null && mark_done "Extension $ext installée/mise à jour" || mark_fail "Extension $ext échouée"
done

# ---------------- Python ONNX Runtime ----------------
info "Installation ONNX Runtime et dépendances"
pip install -q numpy onnxruntime && mark_done "ONNX Runtime + numpy installés" || mark_fail "ONNX Runtime installation échouée"

# ---------------- Nettoyage ----------------
info "Nettoyage des packages inutiles"
sudo apt autoremove -y &> /dev/null && mark_done "Packages inutiles supprimés" || mark_warn "Aucun package à supprimer"

# ---------------- Résumé ----------------
show_checklist

# Désactivation automatique du venv
deactivate
success "Script terminé. Virtualenv désactivé."
