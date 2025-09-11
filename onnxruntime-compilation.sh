#!/bin/bash
set -euo pipefail

# ==================== CONFIG ====================
CPU_VENV="$HOME/onnx_cpu_env"
GPU_VENV="$HOME/onnx_gpu_env"
WORKDIR="$HOME/onnxruntime_build"
REPO="$WORKDIR/onnxruntime"
NPROC=$(nproc)

log() { echo -e "[INFO] $*"; }
success() { echo -e "[SUCCESS] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

# ==================== PREPARE VENV ====================
prepare_venv() {
    local VENV_DIR=$1
    log "Préparation du venv : $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel packaging ninja flatbuffers numpy
    deactivate
}

prepare_venv "$CPU_VENV"
prepare_venv "$GPU_VENV"

# ==================== CLONE / UPDATE REPO ====================
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -d "$REPO" ]; then
    log "Clonage du dépôt ONNX Runtime..."
    git clone --recursive https://github.com/microsoft/onnxruntime
fi

cd "$REPO"
git fetch origin
git checkout main || git checkout master || true
git pull --ff-only || true
git submodule sync --recursive
git submodule update --init --recursive

# ==================== CLEAN BUILDS ====================
log "Nettoyage des anciens fichiers CMake..."
rm -rf build_cpu build_gpu

# ==================== BUILD FUNCTIONS ====================
# Combine les flags souhaités sans écraser les existants
append_cxx_flags() {
    local FLAGS="-Wno-unused-parameter -Wunused-variable"
    if [ -n "${CMAKE_CXX_FLAGS-}" ]; then
        FLAGS="$CMAKE_CXX_FLAGS $FLAGS"
    fi
    echo "$FLAGS"
}

build_cpu() {
    log "Compilation ONNX Runtime (CPU)..."
    source "$CPU_VENV/bin/activate"
    ./build.sh \
        --allow_running_as_root \
        --build_dir build_cpu \
        --config Release \
        --build_wheel \
        --update \
        --build \
        --parallel "$NPROC" \
        --skip_tests \
        --cmake_generator Ninja \
        --cmake_extra_defines CMAKE_CXX_FLAGS="$(append_cxx_flags)" ONNXRUNTIME_DISABLE_WARNINGS=ON
    deactivate
    success "Compilation CPU terminée"
}

build_gpu() {
    log "Compilation ONNX Runtime (ROCm GPU)..."
    source "$GPU_VENV/bin/activate"
    ./build.sh \
        --allow_running_as_root \
        --build_dir build_gpu \
        --config Release \
        --build_wheel \
        --update \
        --build \
        --parallel "$NPROC" \
        --skip_tests \
        --use_rocm \
        --cmake_generator Ninja \
        --cmake_extra_defines CMAKE_CXX_FLAGS="$(append_cxx_flags)" ONNXRUNTIME_DISABLE_WARNINGS=ON
    deactivate
    success "Compilation GPU terminée"
}

# ==================== RUN BUILDS IN PARALLEL ====================
build_cpu &
PID_CPU=$!
build_gpu &
PID_GPU=$!

wait $PID_CPU
wait $PID_GPU

# ==================== INSTALL WHEELS ====================
install_wheel() {
    local VENV=$1
    local BUILDDIR=$2
    local WHEEL
    WHEEL=$(find "$BUILDDIR" -name "onnxruntime-*.whl" | sort | tail -n 1 || true)
    if [ -f "$WHEEL" ]; then
        source "$VENV/bin/activate"
        pip install --upgrade "$WHEEL"
        deactivate
        success "Wheel installé dans $VENV"
    else
        error "Wheel non trouvé dans $BUILDDIR, compilation échouée !"
    fi
}

install_wheel "$CPU_VENV" "$REPO/build_cpu"
install_wheel "$GPU_VENV" "$REPO/build_gpu"

# ==================== CHECKLIST ====================
echo -e "\n# ==================== Checklist ===================="
[ -f "$CPU_VENV/bin/python3" ] && success "ONNX Runtime CPU disponible"
[ -f "$GPU_VENV/bin/python3" ] && success "ONNX Runtime GPU (ROCm) disponible"
success "Configuration terminée !"
