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
WHEEL_BACKUP="$HOME/onnx_wheels_backup"

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

finish_task(){
    local task="$1"; local status="$2"
    case "$status" in
        done) mark_done "$task";;
        warn) mark_warn "$task";;
        fail) mark_fail "$task";;
    esac
}

# ==================== Fonctions ====================

install_system_prereqs(){
    info "Installation des prérequis système..."
    if command -v apt &>/dev/null; then
        sudo apt update
        sudo apt install -y git cmake ninja-build python3-dev build-essential wget curl lsb-release
    else
        warn "Gestionnaire de paquets non reconnu, installer git, cmake, ninja, python-dev..."
    fi
    success "Pré-requis système installés"
    finish_task "System Prereqs" done
}

prepare_venv(){
    local VENV_DIR=$1
    info "Préparation du venv : $VENV_DIR"
    [ -d "$VENV_DIR" ] || python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel packaging ninja cmake flatbuffers "numpy<2"
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
        git fetch origin
        git checkout main || git checkout master || true
        git pull --ff-only || true
        git submodule sync --recursive
        git submodule update --init --recursive
        success "Dépôt mis à jour"
        finish_task "Git Repo" done
    fi
}

detect_gpu(){
    GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)
    if echo "$GPU_VENDOR" | grep -qi "amd"; then
        echo "rocm"
    elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
        echo "cuda"
    else
        echo "cpu"
    fi
}

build_onnxruntime(){
    local VENV_DIR=$1
    local BUILD_DIR=$2
    local BACKEND=$3
    mkdir -p "$BUILD_DIR"
    source "$VENV_DIR/bin/activate"
    info "Compilation $(basename $BUILD_DIR) [$BACKEND]..."
    CMAKE_DEFINES="-Donnxruntime_DISABLE_WARNINGS=ON -DONNX_DISABLE_WARNINGS=ON \
    -DCMAKE_CXX_FLAGS='-Wno-unused-parameter -Wunused-variable' -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
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

install_wheel(){
    local VENV_DIR=$1
    local BUILD_DIR=$2
    source "$VENV_DIR/bin/activate"
    WHEEL=$(find "$BUILD_DIR" -name "onnxruntime-*.whl" | sort | tail -n 1)
    if [ -f "$WHEEL" ]; then
        info "Installation de la wheel : $WHEEL"
        pip install --upgrade "$WHEEL"
        mkdir -p "$WHEEL_BACKUP"
        cp "$WHEEL" "$WHEEL_BACKUP/"
        success "ONNX Runtime installé dans $VENV_DIR et wheel sauvegardée"
        finish_task "Wheel $(basename $BUILD_DIR)" done
    else
        warn "Wheel non trouvée dans $BUILD_DIR"
        finish_task "Wheel $(basename $BUILD_DIR)" fail
    fi
    deactivate
}

# ==================== Exécution ====================
mkdir -p "$TMP_DIR" "$WHEEL_BACKUP"

install_system_prereqs
prepare_venv "$CPU_VENV"
prepare_venv "$GPU_VENV"
clone_or_update_repo

cd "$REPO"
rm -rf build_cpu build_gpu

GPU_BACKEND=$(detect_gpu)

# Build CPU
build_onnxruntime "$CPU_VENV" "build_cpu" "cpu"

# Build GPU si disponible
if [ "$GPU_BACKEND" != "cpu" ]; then
    build_onnxruntime "$GPU_VENV" "build_gpu" "$GPU_BACKEND"
fi

# Installation wheels
install_wheel "$CPU_VENV" "$REPO/build_cpu"
[ "$GPU_BACKEND" != "cpu" ] && install_wheel "$GPU_VENV" "$REPO/build_gpu"

rm -rf "$TMP_DIR"
show_checklist
success "ONNX Runtime CPU et GPU 1.23 prêts !"
