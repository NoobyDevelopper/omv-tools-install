#!/bin/bash
set -euo pipefail

clear

# ==================== Couleurs ====================
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ==================== Détection GPU ====================
GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)
info "GPU détecté : $GPU_VENDOR"

# ==================== Dépendances ====================
info "Installation dépendances build"
sudo apt update -qq
sudo apt install -y -qq \
    git python3 python3-pip python3-venv python3-setuptools python3-wheel \
    build-essential cmake protobuf-compiler libprotobuf-dev \
    python3-dev ninja-build ccache

pip install --upgrade pip
pip install --upgrade numpy sympy packaging

# ==================== Source code ====================
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
if echo "$GPU_VENDOR" | grep -qi "amd"; then
    info "Build avec ROCm"
    ./build.sh --config Release --build_wheel --update --build --parallel --use_rocm
elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    info "Build avec CUDA"
    ./build.sh --config Release --build_wheel --update --build --parallel --use_cuda
else
    info "Build en mode CPU"
    ./build.sh --config Release --build_wheel --update --build --parallel
fi

# ==================== Installation ====================
WHEEL=$(find build -name "onnxruntime-*.whl" | sort | tail -n 1)

if [ -f "$WHEEL" ]; then
    pip install --upgrade "$WHEEL"
    success "ONNX Runtime compilé et installé depuis $WHEEL"
else
    error "Wheel introuvable. Compilation échouée."
    exit 1
fi
