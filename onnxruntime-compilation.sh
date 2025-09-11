#!/bin/bash
set -euo pipefail

clear

# ==================== Couleurs ====================
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ==================== Checklist ====================
declare -A CHECKLIST
mark_done() { CHECKLIST["$1"]="✅"; }
mark_warn() { CHECKLIST["$1"]="⚠️"; }
mark_fail() { CHECKLIST["$1"]="❌"; }

show_checklist() {
    echo -e "\n${BLUE}==================== Checklist ====================${NC}"
    for task in "${!CHECKLIST[@]}"; do
        echo -e "${CHECKLIST[$task]} $task"
    done
    echo -e "${BLUE}==================================================${NC}\n"
}

# ==================== Variables ====================
VENV_DIR="$HOME/onnx_env"
WORKDIR="$HOME/onnxruntime_build"
GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)

# ==================== Venv ====================
info "Vérification du venv"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    info "Venv créé"
else
    info "Venv déjà présent"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip setuptools wheel numpy

# ==================== Build ====================
info "Préparation du répertoire de build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -d "onnxruntime" ]; then
    info "Clonage du dépôt ONNX Runtime"
    git clone --recursive https://github.com/microsoft/onnxruntime
fi

cd onnxruntime
git submodule update --init --recursive
git clean -xfd || true
git reset --hard HEAD

BUILD_CMD="./build.sh --config Release --build_wheel --update --build --parallel --allow_running_as_root"

if echo "$GPU_VENDOR" | grep -qi "amd"; then
    info "Build avec ROCm"
    $BUILD_CMD --use_rocm
elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    info "Build avec CUDA"
    $BUILD_CMD --use_cuda
else
    info "Build CPU seulement"
    $BUILD_CMD
fi

# ==================== Installation ====================
WHEEL=$(find build -name "onnxruntime-*.whl" | sort | tail -n 1)
if [ -f "$WHEEL" ]; then
    pip install --upgrade "$WHEEL"
    success "ONNX Runtime compilé et installé dans $VENV_DIR"
    mark_done "ONNX Runtime"
else
    error "Wheel introuvable. Compilation échouée."
    mark_fail "ONNX Runtime"
fi

deactivate

# ==================== Checklist finale ====================
show_checklist
success "ONNX Runtime tout-en-un terminé !"
