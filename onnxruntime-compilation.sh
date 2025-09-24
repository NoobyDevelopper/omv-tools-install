#!/bin/bash
set -euo pipefail

clear

# ==================== Couleurs ====================
BLUE='\033[1;34m'
LIGHT_BLUE='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} ${LIGHT_BLUE}$*${NC}"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR] $*${NC}"; }

# ==================== Progress Bar ====================
show_progress() {
    local done=$1
    local total=$2
    local width=40
    local percent=$(( done * 100 / total ))
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    printf "\r${BLUE}[PROGRESS]${NC} ${BLUE}|"
    printf '%0.s█' $(seq 1 $filled)
    printf '%0.s ' $(seq 1 $empty)
    printf "| %3d%% (%d/%d)${NC}" $percent $done $total
}

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

# ==================== Configuration ====================
CPU_VENV="$HOME/onnx_cpu_env"
GPU_VENV="$HOME/onnx_gpu_env"
WORKDIR="$HOME/onnxruntime_build"
REPO="$WORKDIR/onnxruntime"
NPROC=$(nproc)

TASKS_TOTAL=8
TASKS_DONE_COUNT=0
finish_task() {
    local task="$1"
    local status="$2"
    case "$status" in
        done) mark_done "$task" ;;
        warn) mark_warn "$task" ;;
        fail) mark_fail "$task" ;;
    esac
    TASKS_DONE_COUNT=$((TASKS_DONE_COUNT+1))
    show_progress $TASKS_DONE_COUNT $TASKS_TOTAL
}

# ==================== Fonctions ====================
prepare_venv() {
    local VENV_DIR=$1
    info "Préparation du venv : $VENV_DIR"
    [ -d "$VENV_DIR" ] || python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel packaging ninja cmake flatbuffers numpy
    deactivate
    success "Venv prêt : $VENV_DIR"
    finish_task "Venv $(basename $VENV_DIR)" done
}

clone_or_update_repo() {
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    if [ ! -d "$REPO" ]; then
        info "Clonage du dépôt ONNX Runtime..."
        git clone --recursive https://github.com/microsoft/onnxruntime || { finish_task "Git Repo" fail; return; }
        success "Dépôt cloné"
        finish_task "Git Repo" done
    else
        info "Mise à jour du dépôt existant..."
        cd "$REPO"

        # --- Nettoyage automatique des locks Git ---
        if [ -f .git/config.lock ]; then
            warn "Fichier .git/config.lock détecté, suppression..."
            rm -f .git/config.lock
        fi

        # --- Synchronisation et réinitialisation des sous-modules ---
        git submodule deinit -f . || true
        git submodule sync --recursive || true
        git submodule update --init --recursive || true

        git fetch origin
        git checkout main || git checkout master || true
        git pull --ff-only || true

        success "Dépôt mis à jour"
        finish_task "Git Repo" done
    fi
}

append_cxx_flags() {
    local FLAGS="-Wno-unused-parameter -Wunused-variable"
    if [ -n "${CMAKE_CXX_FLAGS-}" ]; then
        FLAGS="$CMAKE_CXX_FLAGS $FLAGS"
    fi
    echo "$FLAGS"
}

build_onnxruntime() {
    local VENV_DIR=$1
    local BUILD_DIR=$2
    local USE_ROCM=${3:-0}

    if [ "$USE_ROCM" -eq 1 ]; then
        info "Compilation GPU ROCm..."
    else
        info "Compilation CPU..."
    fi

    source "$VENV_DIR/bin/activate"
    ./build.sh \
        --allow_running_as_root \
        --build_dir "$BUILD_DIR" \
        --config Release \
        --build_wheel \
        --update \
        --build \
        --parallel "$NPROC" \
        --skip_tests \
        $( [ "$USE_ROCM" -eq 1 ] && echo "--use_rocm" ) \
        --cmake_generator Ninja \
        --cmake_extra_defines CMAKE_CXX_FLAGS="$(append_cxx_flags)" \
                             ONNXRUNTIME_DISABLE_WARNINGS=ON \
                             ONNX_DISABLE_WARNINGS=ON
    deactivate
    success "Compilation $(basename $BUILD_DIR) terminée"
    finish_task "Build $(basename $BUILD_DIR)" done
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
        finish_task "Wheel $(basename $BUILD_DIR)" done
    else
        error "Wheel non trouvé dans $BUILD_DIR"
        finish_task "Wheel $(basename $BUILD_DIR)" fail
    fi
}

# ==================== Exécution ====================
prepare_venv "$CPU_VENV"
prepare_venv "$GPU_VENV"

clone_or_update_repo

cd "$REPO"
rm -rf build_cpu build_gpu

build_onnxruntime "$CPU_VENV" "build_cpu" &
PID_CPU=$!
build_onnxruntime "$GPU_VENV" "build_gpu" 1 &
PID_GPU=$!

trap 'echo -e "\n[INFO] Annulation..."; kill $PID_CPU $PID_GPU 2>/dev/null; exit 1' SIGINT

wait $PID_CPU
wait $PID_GPU

install_wheel "$CPU_VENV" "$REPO/build_cpu"
install_wheel "$GPU_VENV" "$REPO/build_gpu"

# ==================== Checklist finale ====================
echo -e "\n# ==================== Checklist ===================="
[ -f "$CPU_VENV/bin/python3" ] && success "ONNX Runtime CPU disponible"
[ -f "$GPU_VENV/bin/python3" ] && success "ONNX Runtime GPU (ROCm) disponible"
show_checklist
success "Configuration ONNX Runtime terminée !"
