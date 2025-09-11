#!/bin/bash
set -euo pipefail

# ==================== Couleurs ====================
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ==================== Variables ====================
VENV_DIR="$HOME/onnx_env"
WORKDIR="$HOME/onnxruntime_build"
GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)

# ==================== Vérification venv ====================
if [ ! -d "$VENV_DIR" ]; then
    info "Venv non trouvé, création..."
    python3 -m venv "$VENV_DIR"
else
    info "Venv existant détecté"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip setuptools wheel

# ==================== Vérification CMake >= 3.28 ====================
CMAKE_VERSION=$(cmake --version | head -n1 | awk '{print $3}')
REQUIRED_VERSION="3.28.0"
version_ge() { printf '%s\n%s\n' "$1" "$2" | sort -C -V; }

if ! version_ge "$CMAKE_VERSION" "$REQUIRED_VERSION"; then
    info "Mise à jour de CMake (actuel: $CMAKE_VERSION)..."
    sudo apt remove -y cmake || true
    sudo apt update -qq
    sudo apt install -y wget lsb-release gpg
    CMAKE_DEB="cmake_latest_$(lsb_release -cs).deb"
    wget -qO "/tmp/$CMAKE_DEB" "https://github.com/Kitware/CMake/releases/latest/download/cmake-$(lsb_release -cs)-linux-x86_64.sh"
    sudo bash "/tmp/$CMAKE_DEB" --skip-license --prefix=/usr/local
fi
info "CMake OK (version $(cmake --version | head -n1 | awk '{print $3}'))"

# ==================== Préparation source ONNX Runtime ====================
mkdir -p "$WORKDIR"
cd "$WORKDIR"
if [ ! -d "onnxruntime" ]; then
    info "Clonage dépôt ONNX Runtime..."
    git clone --recursive https://github.com/microsoft/onnxruntime
fi
cd onnxruntime
git submodule update --init --recursive
git clean -xfd || true
git reset --hard HEAD

# ==================== Compilation ====================
BUILD_CMD="./build.sh --config Release --build_wheel --update --build --parallel --allow_running_as_root"

if echo "$GPU_VENDOR" | grep -qi "amd"; then
    info "Compilation avec ROCm"
    $BUILD_CMD --use_rocm
elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    info "Compilation avec CUDA"
    $BUILD_CMD --use_cuda
else
    info "Compilation CPU uniquement"
    $BUILD_CMD
fi

# ==================== Installation Wheel ====================
WHEEL=$(find build -name "onnxruntime-*.whl" | sort | tail -n 1)
if [ -f "$WHEEL" ]; then
    pip install --upgrade "$WHEEL"
    success "ONNX Runtime compilé et installé depuis $WHEEL"
else
    error "Wheel introuvable. Compilation échouée."
    exit 1
fi

deactivate
success "Venv + ONNX Runtime prêt dans $VENV_DIR"
