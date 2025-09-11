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

# ==================== Détection GPU ====================
GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)
info "GPU détecté : $GPU_VENDOR"

# ==================== Venv ====================
VENV_DIR="$HOME/onnx_env"
if [ ! -d "$VENV_DIR" ]; then
    info "Création du venv"
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# ==================== Packages Python ====================
info "Installation / mise à jour des packages Python nécessaires"
pip install --upgrade pip setuptools wheel packaging numpy

# ==================== Dépendances systèmes ====================
info "Installation dépendances systèmes"
sudo apt update -qq
sudo apt install -y -qq build-essential cmake git ninja-build ccache python3-dev protobuf-compiler libprotobuf-dev wget lsb-release gpg || true

# Vérification version CMake >= 3.28
CMAKE_VER=$(cmake --version | head -n1 | awk '{print $3}')
REQUIRED_VER="3.28.0"
if printf '%s\n%s\n' "$REQUIRED_VER" "$CMAKE_VER" | sort -V | head -n1 | grep -q "$REQUIRED_VER"; then
    info "CMake version $CMAKE_VER ok"
else
    warn "CMake version $CMAKE_VER insuffisante, installation mise à jour"
    # Installation CMake récente
    wget -q https://github.com/Kitware/CMake/releases/download/v3.28.5/cmake-3.28.5-linux-x86_64.sh -O /tmp/cmake.sh
    sudo bash /tmp/cmake.sh --skip-license --prefix=/usr/local
fi

# ==================== Source ONNX Runtime ====================
WORKDIR="$HOME/onnxruntime_build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -d "onnxruntime" ]; then
    info "Clonage dépôt ONNX Runtime"
    git clone --recursive https://github.com/microsoft/onnxruntime
fi
cd onnxruntime
git submodule update --init --recursive
git clean -xfd || true
git reset --hard HEAD

# ==================== Compilation ====================
info "Début compilation ONNX Runtime"
BUILD_CMD="./build.sh --config Release --build_wheel --update --build --parallel --allow_running_as_root"

if echo "$GPU_VENDOR" | grep -qi "amd"; then
    info "Build ROCm"
    BUILD_CMD+=" --use_rocm"
elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    info "Build CUDA"
    BUILD_CMD+=" --use_cuda"
else
    info "Build CPU uniquement"
fi

# Exécution
info "Exécution : $BUILD_CMD"
$BUILD_CMD

# ==================== Installation wheel ====================
WHEEL=$(find build -name "onnxruntime-*.whl" | sort | tail -n 1)
if [ -f "$WHEEL" ]; then
    info "Installation du wheel $WHEEL"
    pip install --upgrade "$WHEEL"
    success "ONNX Runtime compilé et installé dans $VENV_DIR"
else
    error "Wheel introuvable après compilation"
    exit 1
fi

deactivate
success "Venv + ONNX Runtime prêt à l'emploi"
