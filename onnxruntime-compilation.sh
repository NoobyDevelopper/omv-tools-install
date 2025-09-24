#!/bin/bash
set -euo pipefail
clear

# ==================== Config ====================
CPU_VENV="$HOME/onnx_cpu_env"
GPU_VENV="$HOME/onnx_gpu_env"
WORKDIR="$HOME/onnxruntime_build"
REPO="$WORKDIR/onnxruntime"
NPROC=$(nproc)
TMP_DIR="/tmp/onnxruntime_tmp"

# ==================== Couleurs ====================
BLUE='\033[1;34m'; LIGHT_BLUE='\033[1;36m'; GREEN='\033[1;32m'
YELLOW='\033[1;33m'; RED='\033[1;31m'; CYAN='\033[0;36m'; NC='\033[0m'

info(){ echo -e "${BLUE}[INFO]${NC} ${LIGHT_BLUE}$*${NC}"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
error(){ echo -e "${RED}[ERROR] $*${NC}"; }

declare -A CHECKLIST
mark_done(){ CHECKLIST["$1"]="✅"; }
mark_warn(){ CHECKLIST["$1"]="⚠️"; }
mark_fail(){ CHECKLIST["$1"]="❌"; }
show_checklist(){
    echo -e "\n${CYAN}==================== Checklist ====================${NC}"
    for task in "${!CHECKLIST[@]}"; do
        echo -e "${CHECKLIST[$task]} $task"
    done
    echo -e "${CYAN}==================================================${NC}\n"
}

TASKS_TOTAL=13
TASKS_DONE_COUNT=0
finish_task(){
    local task="$1"; local status="$2"
    case "$status" in
        done) mark_done "$task";;
        warn) mark_warn "$task";;
        fail) mark_fail "$task";;
    esac
    TASKS_DONE_COUNT=$((TASKS_DONE_COUNT+1))
}

show_progress(){
    local done=$1; local total=$2; local width=40
    local percent=$(( done * 100 / total )); local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    printf "\r${BLUE}[PROGRESS]${NC} ${BLUE}|"; printf '%0.s█' $(seq 1 $filled)
    printf '%0.s ' $(seq 1 $empty); printf "| %3d%% (%d/%d)${NC}" $percent $done $total
}

# ==================== Fonctions ====================
install_system_prereqs(){
    info "Installation des prérequis système..."
    if command -v apt &>/dev/null; then
        sudo apt update
        sudo apt install -y git cmake ninja-build python3-dev build-essential wget curl lsb-release
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm git cmake ninja python python-pip base-devel wget curl
    else
        warn "Gestionnaire de paquets non reconnu, installer manuellement git, cmake, ninja, python-dev..."
    fi
    success "Pré-requis système installés"
    finish_task "System Prereqs" done
}

install_pip_if_missing(){
    if ! command -v pip3 &>/dev/null; then
        info "Installation de pip..."
        wget -q https://bootstrap.pypa.io/get-pip.py -O "$TMP_DIR/get-pip.py"
        python3 "$TMP_DIR/get-pip.py"
        rm -f "$TMP_DIR/get-pip.py"
        success "pip installé"
    else
        success "pip déjà présent"
    fi
    finish_task "pip" done
}

prepare_venv(){
    local VENV_DIR=$1
    info "Préparation du venv : $VENV_DIR"
    [ -d "$VENV_DIR" ] || python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel packaging ninja cmake flatbuffers numpy
    deactivate
    success "Venv prêt : $VENV_DIR"
    finish_task "Venv $(basename $VENV_DIR)" done
}

clone_or_update_repo(){
    mkdir -p "$WORKDIR"; cd "$WORKDIR"
    if [ ! -d "$REPO" ]; then
        info "Clonage ONNX Runtime..."
        git clone --recursive https://github.com/microsoft/onnxruntime || { finish_task "Git Repo" fail; return; }
        success "Dépôt cloné"
        finish_task "Git Repo" done
    else
        info "Mise à jour du dépôt existant..."
        cd "$REPO"
        [ -f .git/config.lock ] && rm -f .git/config.lock
        git fetch origin
        git checkout main || git checkout master || true
        git pull --ff-only || true
        git submodule sync --recursive || true
        git submodule update --init --recursive
        success "Dépôt mis à jour"
        finish_task "Git Repo" done
    fi
}

detect_gpu(){
    GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)
    if echo "$GPU_VENDOR" | grep -qi "amd"; then
        info "GPU AMD détecté (ROCm activé)"
        echo "rocm"
    elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
        info "GPU NVIDIA détecté (CUDA activé)"
        echo "cuda"
    else
        warn "Aucun GPU compatible détecté, compilation CPU uniquement"
        echo "cpu"
    fi
}

build_onnxruntime(){
    local VENV_DIR=$1
    local BUILD_DIR=$2
    local BACKEND=$3
    source "$VENV_DIR/bin/activate"
    mkdir -p "$BUILD_DIR"
    info "Compilation $(basename $BUILD_DIR) [$BACKEND]..."
    CMAKE_DEFINES="-Donnxruntime_DISABLE_WARNINGS=ON -DONNX_DISABLE_WARNINGS=ON -DCMAKE_CXX_FLAGS='-Wno-unused-parameter -Wunused-variable' -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
    [ "$BACKEND" = "rocm" ] && CMAKE_DEFINES="$CMAKE_DEFINES --use_rocm"
    [ "$BACKEND" = "cuda" ] && CMAKE_DEFINES="$CMAKE_DEFINES --use_cuda"
    ./build.sh \
        --allow_running_as_root \
        --build_dir "$BUILD_DIR" \
        --config Release \
        --build_wheel \
        --update \
        --build \
        --parallel "$NPROC" \
        --skip_tests \
        --cmake_generator Ninja \
        --cmake_extra_defines "$CMAKE_DEFINES"
    deactivate
    success "Build $(basename $BUILD_DIR) terminé"
    finish_task "Build $(basename $BUILD_DIR)" done
}

# ==================== Exécution ====================
mkdir -p "$TMP_DIR"
install_system_prereqs
install_pip_if_missing
prepare_venv "$CPU_VENV"
prepare_venv "$GPU_VENV"
clone_or_update_repo

cd "$REPO"
rm -rf build_cpu build_gpu

GPU_BACKEND=$(detect_gpu)

# Compilation parallèle
build_onnxruntime "$CPU_VENV" "build_cpu" "cpu" &
PID_CPU=$!
[ "$GPU_BACKEND" != "cpu" ] && build_onnxruntime "$GPU_VENV" "build_gpu" "$GPU_BACKEND" &
PID_GPU=$!

trap 'echo -e "\n[INFO] Annulation..."; kill $PID_CPU ${PID_GPU-} 2>/dev/null; exit 1' SIGINT

wait $PID_CPU
[ "$GPU_BACKEND" != "cpu" ] && wait $PID_GPU

# Installation wheels CPU
install_wheel "$CPU_VENV" "$REPO/build_cpu"

# Installation wheels GPU (tout-en-un)
if [ "$GPU_BACKEND" != "cpu" ]; then
    source "$GPU_VENV/bin/activate"
    WHEEL=$(find "$REPO/build_gpu" -name "onnxruntime-*.whl" | sort | tail -n 1)
    if [ -f "$WHEEL" ]; then
        info "Installation de la wheel GPU : $WHEEL"
        pip install --upgrade "$WHEEL"
        success "ONNX Runtime GPU installé dans $GPU_VENV"
    else
        warn "Wheel GPU non trouvée dans $REPO/build_gpu"
    fi
    deactivate
    finish_task "Wheel build_gpu" done
fi

rm -rf "$TMP_DIR"
show_checklist
success "ONNX Runtime CPU et GPU prêts !"
