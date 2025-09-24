#!/bin/bash
set -euo pipefail

clear

# ==================== Couleurs ====================
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR] $*"; }

# ==================== Variables ====================
CPU_VENV="$HOME/onnx_cpu_env"
GPU_VENV="$HOME/onnx_gpu_env"
WORKDIR="$HOME/onnxruntime_build"
REPO="$WORKDIR/onnxruntime"
NPROC=$(nproc)

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

# ==================== Fonctions ====================
prepare_venv() {
    local VENV_DIR=$1
    info "Préparation du venv : $VENV_DIR"
    [ -d "$VENV_DIR" ] || python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel packaging ninja flatbuffers numpy cmake
    deactivate
    success "Venv prêt : $VENV_DIR"
    mark_done "Venv $(basename $VENV_DIR)"
}

clone_or_update_repo() {
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    if [ ! -d "$REPO" ]; then
        info "Clonage du dépôt ONNX Runtime..."
        git clone --recursive https://github.com/microsoft/onnxruntime
        success "Dépôt cloné"
        mark_done "Git Repo"
    else
        info "Mise à jour du dépôt existant..."
        cd "$REPO"
        git fetch origin
        git reset --hard origin/main
        git submodule update --init --recursive || true
        success "Dépôt mis à jour"
        mark_done "Git Repo"
    fi
}

build_onnxruntime() {
    local VENV_DIR=$1
    local BUILD_DIR=$2
    local USE_ROCM=${3:-0}

    source "$VENV_DIR/bin/activate"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    CMAKE_FLAGS="-DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
-DONNXRUNTIME_DISABLE_WARNINGS=ON \
-DONNX_DISABLE_WARNINGS=ON \
-DCMAKE_CXX_FLAGS='-Wno-unused-parameter -Wunused-variable'"

    info "Génération CMake pour $(basename $BUILD_DIR)..."
    cmake "$REPO" -G Ninja $CMAKE_FLAGS $( [ "$USE_ROCM" -eq 1 ] && echo "-Donnxruntime_USE_ROCM=ON" )

    info "Compilation $(basename $BUILD_DIR)..."
    ninja -j"$NPROC"
    success "Compilation $(basename $BUILD_DIR) terminée"
    mark_done "Build $(basename $BUILD_DIR)"
    deactivate
}

install_wheel() {
    local VENV_DIR=$1
    local BUILD_DIR=$2
    local WHEEL
    WHEEL=$(find "$BUILD_DIR" -name "onnxruntime-*.whl" | sort | tail -n 1 || true)
    if [ -f "$WHEEL" ]; then
        source "$VENV_DIR/bin/activate"
        pip install --upgrade "$WHEEL"
        deactivate
        success "Wheel installé dans $VENV_DIR"
        mark_done "Wheel $(basename $BUILD_DIR)"
    else
        error "Wheel non trouvé dans $BUILD_DIR"
        mark_fail "Wheel $(basename $BUILD_DIR)"
    fi
}

# ==================== Exécution ====================
prepare_venv "$CPU_VENV"
prepare_venv "$GPU_VENV"
clone_or_update_repo

rm -rf "$REPO/build_cpu" "$REPO/build_gpu"

build_onnxruntime "$CPU_VENV" "$REPO/build_cpu"
build_onnxruntime "$GPU_VENV" "$REPO/build_gpu" 1

install_wheel "$CPU_VENV" "$REPO/build_cpu"
install_wheel "$GPU_VENV" "$REPO/build_gpu"

# ==================== Checklist finale ====================
[ -f "$CPU_VENV/bin/python3" ] && success "ONNX Runtime CPU disponible"
[ -f "$GPU_VENV/bin/python3" ] && success "ONNX Runtime GPU (ROCm) disponible"
show_checklist
success "Configuration ONNX Runtime terminée !"
