#!/bin/bash
set -euo pipefail

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

# ==================== GPU & CPU ====================
GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)
CORES=$(nproc)
info "GPU détecté : $GPU_VENDOR"
info "Nombre de coeurs CPU : $CORES"

# ==================== Venv ====================
VENV_DIR="$HOME/onnx_env"
if [ ! -d "$VENV_DIR" ]; then
    info "Création du venv..."
    python3 -m venv "$VENV_DIR"
    success "Venv créé dans $VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip setuptools wheel packaging numpy ninja

# ==================== Vérification CMake ====================
CMAKE_REQUIRED=3.28
CMAKE_CURRENT=$(cmake --version | head -n1 | awk '{print $3}')
version_ge() { printf '%s\n%s\n' "$2" "$1" | sort -V -C; }
if ! version_ge "$CMAKE_CURRENT" "$CMAKE_REQUIRED"; then
    info "Mise à jour de CMake..."
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    CMAKE_VER=3.31.0
    wget -q https://github.com/Kitware/CMake/releases/download/v$CMAKE_VER/cmake-$CMAKE_VER-linux-x86_64.sh
    chmod +x cmake-$CMAKE_VER-linux-x86_64.sh
    ./cmake-$CMAKE_VER-linux-x86_64.sh --skip-license --prefix=/usr/local
    hash -r
    success "CMake mis à jour vers $CMAKE_VER"
    cd -
fi

# ==================== Build Dir ====================
WORKDIR="$HOME/onnxruntime_build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ==================== Clone ONNX Runtime ====================
if [ ! -d "onnxruntime" ]; then
    info "Clonage du dépôt ONNX Runtime..."
    git clone --recursive https://github.com/microsoft/onnxruntime
fi
cd onnxruntime
git submodule update --init --recursive
git clean -xfd || true
git reset --hard HEAD

BUILD_DIR="$WORKDIR/build"
mkdir -p "$BUILD_DIR/cpu" "$BUILD_DIR/gpu"

# ==================== Compilation CPU ====================
info "Lancement compilation CPU..."
python3 tools/ci_build/build.py \
    --update \
    --build \
    --build_dir "$BUILD_DIR/cpu" \
    --config Release \
    --parallel $CORES \
    --skip_tests \
    --allow_running_as_root &
CPU_PID=$!

# ==================== Compilation GPU ====================
GPU_PID=""
if echo "$GPU_VENDOR" | grep -qi "amd"; then
    info "Compilation GPU AMD ROCm..."
    python3 tools/ci_build/build.py \
        --update \
        --build \
        --build_dir "$BUILD_DIR/gpu" \
        --config Release \
        --parallel $CORES \
        --skip_tests \
        --use_rocm \
        --allow_running_as_root &
    GPU_PID=$!
elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    info "Compilation GPU NVIDIA CUDA..."
    python3 tools/ci_build/build.py \
        --update \
        --build \
        --build_dir "$BUILD_DIR/gpu" \
        --config Release \
        --parallel $CORES \
        --skip_tests \
        --use_cuda \
        --allow_running_as_root &
    GPU_PID=$!
else
    warn "Aucun GPU compatible détecté, compilation CPU seule."
fi

# ==================== Attente des compilations ====================
wait $CPU_PID
success "Compilation CPU terminée."
if [ -n "${GPU_PID}" ]; then
    wait $GPU_PID
    success "Compilation GPU terminée."
fi

# ==================== Installation Python ====================
info "Installation du wheel Python..."
CPU_WHEEL=$(find "$BUILD_DIR/cpu" -name "onnxruntime-*.whl" | sort | tail -n 1)
GPU_WHEEL=$(find "$BUILD_DIR/gpu" -name "onnxruntime-*.whl" | sort | tail -n 1)
if [ -f "$GPU_WHEEL" ]; then
    pip install --upgrade "$GPU_WHEEL"
elif [ -f "$CPU_WHEEL" ]; then
    pip install --upgrade "$CPU_WHEEL"
else
    error "Wheel introuvable, compilation échouée."
    exit 1
fi

deactivate
success "Compilation terminée. Venv désactivé."
