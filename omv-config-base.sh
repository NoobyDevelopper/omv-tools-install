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

TASKS_DONE=()
VENV_DIR="$HOME/onnx_env"

# ---------------- Fonction auto-update ONNX ----------------
update_onnx() {
    source "$VENV_DIR/bin/activate"
    if pip show onnxruntime &> /dev/null; then
        info "ONNX Runtime déjà installé, vérification des mises à jour..."
        pip install --upgrade onnxruntime
        TASKS_DONE+=("${LIGHT_BLUE}ONNX Runtime mis à jour ${GREEN}Fait${NC}")
    else
        info "Installation de ONNX Runtime dans le venv"
        pip install --upgrade pip setuptools wheel
        pip install onnxruntime numpy
        TASKS_DONE+=("${LIGHT_BLUE}ONNX Runtime installé ${GREEN}Fait${NC}")
    fi
    deactivate
    info "Venv désactivé après mise à jour ONNX Runtime"
}

# ---------------- Création venv si nécessaire ----------------
if [ ! -d "$VENV_DIR" ]; then
    info "Création du virtualenv Python isolé dans $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    TASKS_DONE+=("${LIGHT_BLUE}Virtualenv créé ${GREEN}Fait${NC}")
else
    TASKS_DONE+=("${LIGHT_BLUE}Virtualenv déjà présent ${GREEN}Déjà à jour${NC}")
fi

# ---------------- Détection GPU et installation pilotes ----------------
info "Détection du GPU présent"
GPU_VENDOR=""
if lspci | grep -i nvidia &> /dev/null; then
    GPU_VENDOR="NVIDIA"
elif lspci | grep -i amd | grep -i vga &> /dev/null; then
    GPU_VENDOR="AMD"
elif lspci | grep -i intel &> /dev/null; then
    GPU_VENDOR="Intel"
fi

TASKS_DONE+=("${LIGHT_BLUE}GPU détecté : $GPU_VENDOR ${GREEN}Fait${NC}")

case "$GPU_VENDOR" in
    "AMD")
        info "Installation pilotes AMD + ROCm"
        # ... ton code AMD existant ...
        ;;
    "NVIDIA")
        info "Installation pilotes NVIDIA + CUDA"
        # ... code NVIDIA ...
        ;;
    "Intel")
        info "Installation pilotes Intel GPU"
        # ... code Intel ...
        ;;
    *)
        warn "Aucun GPU compatible détecté"
        TASKS_DONE+=("${LIGHT_BLUE}Pilotes GPU non installés ${YELLOW}Skipped${NC}")
        ;;
esac

# ---------------- Mise à jour ONNX Runtime automatique ----------------
update_onnx

# ---------------- Nettoyage ----------------
info "Nettoyage packages inutiles"
sudo apt autoremove -y
TASKS_DONE+=("${LIGHT_BLUE}Packages inutiles supprimés ${GREEN}Fait${NC}")

# ---------------- Résumé des tâches ----------------
echo -e "${BLUE}====================================================================${NC}"
for task in "${TASKS_DONE[@]}"; do
    echo -e "$task"
done
echo -e "${BLUE}====================================================================${NC}"

success "Script terminé : GPU détecté, venv et ONNX Runtime prêts, auto-update activé"
