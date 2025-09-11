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

# ==================== Variables ====================
VENV_DIR="$HOME/onnx_env"
WORKDIR="$HOME/onnxruntime_build"

# ==================== Venv ====================
if [ ! -d "$VENV_DIR" ]; then
    info "Création du venv : $VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip setuptools wheel numpy packaging sympy protobuf

# ==================== Détection GPU ====================
GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)
info "GPU détecté : $GPU_VENDOR"

# ==================== Dépendances ====================
info "Installation dépendances build"
sudo apt update -qq
sudo apt install -y -qq git python3-dev build-essential ninja-build ccache

# ==================== Mise à jour CMake >=3.28 ====================
CMAKE_VER=$(cmake --version | head -n1 | awk '{print $3}')
REQUIRED_VER="3.28.0"
if dpkg --compare-versions "$CMAKE_VER" lt "$REQUIRED_VER"; then
    info "Mise à jour de CMake vers 3.28+"
    sudo apt remove -y cmake || true
    wget https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-linux-x86_64.sh -O /tmp/cmake.sh
    sudo sh /tmp/cmake.sh --skip-license --prefix=/usr/local
fi
cmake --version

# ==================== Préparation sources ====================
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
BUILD_CMD="./build.sh --config Release --build_wheel --update --build --parallel --allow_running_as_root"

if echo "$GPU_VENDOR" | grep -qi "amd"; then
    info "Build avec ROCm"
    $BUILD_CMD --use_rocm
elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    info "Build avec CUDA"
    $BUILD_CMD --use_cuda
else
    info "Build CPU uniquement"
    $BUILD_CMD
fi

# ==================== Installation ====================
WHEEL=$(find build -name "onnxruntime-*.whl" | sort | tail -n 1)
if [ -f "$WHEEL" ]; then
    pip install --upgrade "$WHEEL"
    success "ONNX Runtime compilé et installé dans $VENV_DIR"
else
    error "Wheel introuvable. Compilation échouée."
    deactivate
    exit 1
fi

deactivate
