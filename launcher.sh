#!/bin/bash
set -euo pipefail

# ========== Fonctions de log ==========
info()    { echo -e "[INFO] $*"; }
success() { echo -e "[SUCCESS] $*"; }
warn()    { echo -e "[WARN] $*"; }
error()   { echo -e "[ERROR] $*" >&2; }

# ========== Vérification et installation de Git ==========
if ! command -v git &>/dev/null; then
    info "Git non trouvé. Installation..."
    sudo apt update
    sudo apt install -y git
    success "Git installé avec succès"
else
    info "Git déjà installé"
fi

# ========== Clonage du dépôt ==========
REPO_URL="https://github.com/LordHyperion97/omv-tools-install.git"
DEST_DIR="omv-tools-install"

if [ -d "$DEST_DIR" ]; then
    warn "Le dossier $DEST_DIR existe déjà. Suppression..."
    rm -rf "$DEST_DIR"
    success "Dossier $DEST_DIR supprimé"
fi

info "Clonage du dépôt $REPO_URL..."
git clone "$REPO_URL"
cd "$DEST_DIR"
success "Dépôt cloné et prêt"

# ========== Rendre choices.sh exécutable ==========
if [ -f "choices.sh" ]; then
    info "Rendre choices.sh exécutable..."
    chmod +x choices.sh
    success "choices.sh est maintenant exécutable"
else
    error "Le fichier choices.sh est introuvable dans $DEST_DIR"
    exit 1
fi

# ========== Exécution de choices.sh ==========
info "Exécution de choices.sh avec sudo..."
sudo ./choices.sh
