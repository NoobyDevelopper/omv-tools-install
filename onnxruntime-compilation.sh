#!/bin/bash
set -euo pipefail

# ==================== CONFIG ====================
CPU_VENV="$HOME/onnx_cpu_env"
GPU_VENV="$HOME/onnx_gpu_env"
WORKDIR="$HOME/onnxruntime_build"
REPO="$WORKDIR/onnxruntime"
NPROC=$(nproc)

log()     { echo -e "[INFO] $*"; }
success() { echo -e "[SUCCESS] $*"; }
error()   { echo -e "[ERROR] $*" >&2; }

# ==================== FUNCTIONS ====================
prepare_venv() {
    local VENV_DIR=$1
    log "Préparation du venv : $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel packaging ninja flatbuffers numpy
    deactivate
}

clone_repo() {
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

    # Retry simple pour submodules
    for i in {1..3}; do
        rm -f .git/config.lock || true
        git submodule sync --recursive && git submodule update --init --recursive && break || sleep 2
    done
}

clean_builds() {
    log "Nettoyage des anciens fichiers CMake..."
    rm -rf build_cpu build_gpu
}

build_cpu() {
    log "Compilation ONNX Runtime (CPU)..."
    source "$CPU_VENV/bin/activate"
    python tools/ci_build/build.py \
        --build_dir build_cpu --config Release --build_wheel --update --build \
        --parallel "$NPROC" --skip_tests || error "Compilation CPU échouée"
    deactivate
    success "Compilation CPU terminée"
}

build_gpu() {
    if [ -d "/opt/rocm" ] || [ -n "${ROCM_HOME:-}" ]; then
        ROCM_DIR="${ROCM_HOME:-/opt/rocm}"
        log "Compilation ONNX Runtime (ROCm GPU) avec ROCm à $ROCM_DIR..."
        export ROCM_HOME="$ROCM_DIR"
        source "$GPU_VENV/bin/activate"
        python tools/ci_build/build.py \
            --build_dir build_gpu --config Release --build_wheel --update --build \
            --parallel "$NPROC" --skip_tests --use_rocm || error "Compilation GPU échouée"
        deactivate
        success "Compilation GPU terminée"
    else
        log "ROCm non détecté. Compilation GPU ignorée."
    fi
}

install_wheel() {
    local VENV=$1
    local BUILDDIR=$2
    WHEEL=$(find "$BUILDDIR" -name "onnxruntime-*.whl" | sort | tail -n 1 || true)
    if [ -f "$WHEEL" ]; then
        source "$VENV/bin/activate"
        pip install --upgrade "$WHEEL"
        deactivate
        success "Wheel installé dans $VENV"
    else
        error "Wheel non trouvé dans $BUILDDIR"
    fi
}

# ==================== EXECUTION ====================
prepare_venv "$CPU_VENV"
prepare_venv "$GPU_VENV"

clone_repo
clean_builds

# Compilation parallèle
build_cpu & PID_CPU=$!
build_gpu & PID_GPU=$!
wait $PID_CPU || true
wait $PID_GPU || true

# Installation des wheels
install_wheel "$CPU_VENV" "$REPO/build_cpu"
if [ -d "$REPO/build_gpu" ]; then
    install_wheel "$GPU_VENV" "$REPO/build_gpu"
fi

# ==================== CHECKLIST ====================
echo -e "\n# ==================== Checklist ===================="
[ -f "$CPU_VENV/bin/python3" ] && success "ONNX Runtime CPU disponible"
[ -f "$GPU_VENV/bin/python3" ] && success "ONNX Runtime GPU (ROCm) disponible"
success "Configuration terminée !"
