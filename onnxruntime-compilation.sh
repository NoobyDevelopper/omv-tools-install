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
WHEEL_BACKUP="$HOME/onnxruntime_wheels_backup"

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
        warn "Gestionnaire de paquets non reconnu, installer git, cmake, ninja, python-dev..."
    fi
    success "Pré-requis système installés"
    finish_task "System Prereqs" done
}

install_pip_if_missing(){
    if ! command -v pip3 &>/dev/null; then
        info "Installation de pip..."
        mkdir -p "$TMP_DIR"
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
        info "Nettoyage des fichiers lock Git..."
        find .git -name "*.lock" -type f -exec rm -f {} +
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
    local LOG_FILE="$TMP_DIR/${BUILD_DIR}.log"

    mkdir -p "$BUILD_DIR"
    source "$VENV_DIR/bin/activate"
    info "Compilation $(basename $BUILD_DIR) [$BACKEND]..."
    : > "$LOG_FILE"

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
        --cmake_extra_defines "$CMAKE_DEFINES" 2>&1 | tee "$LOG_FILE"

    deactivate
    success "Build $(basename $BUILD_DIR) terminé"
    finish_task "Build $(basename $BUILD_DIR)" done
}

install_wheel(){
    local VENV_DIR=$1
    local BUILD_DIR=$2
    local WHEEL_DIR="$BUILD_DIR/Release/dist"
    source "$VENV_DIR/bin/activate"

    if [ -d "$WHEEL_DIR" ]; then
        WHEEL=$(find "$WHEEL_DIR" -name "onnxruntime-*.whl" | sort | tail -n 1)
        if [ -f "$WHEEL" ]; then
            info "Installation de la wheel : $WHEEL"
            pip install --upgrade "$WHEEL"
            python -c "import onnxruntime as ort; print('Version:', ort.__version__, 'Providers:', ort.get_available_providers())"
            success "ONNX Runtime installé dans $VENV_DIR"
            finish_task "Wheel $(basename $BUILD_DIR)" done
            return
        fi
    fi
    warn "Wheel non trouvée dans $WHEEL_DIR"
    finish_task "Wheel $(basename $BUILD_DIR)" warn
}

install_wheels_from_backup(){
    mkdir -p "$WHEEL_BACKUP"
    FOUND=0
    for WHEEL in "$WHEEL_BACKUP"/onnxruntime-*.whl; do
        if [ -f "$WHEEL" ]; then
            FOUND=1
            TARGET_VENV="$CPU_VENV"
            source "$TARGET_VENV/bin/activate"
            info "Installation de la wheel existante depuis le backup : $WHEEL"
            pip install --upgrade "$WHEEL"
            python -c "import onnxruntime as ort; print('Version:', ort.__version__, 'Providers:', ort.get_available_providers())"
            deactivate
            finish_task "Wheel $(basename $WHEEL)" done
        fi
    done
    if [ "$FOUND" -eq 1 ]; then
        success "Toutes les wheels du backup installées dans les venv."
        exit 0
    else
        info "Aucune wheel trouvée dans le backup, compilation nécessaire."
    fi
}

backup_wheels_and_cleanup(){
    mkdir -p "$WHEEL_BACKUP"
    for BUILD_DIR in "$REPO/build_cpu" "$REPO/build_gpu"; do
        WHEEL_DIR="$BUILD_DIR/Release/dist"
        if [ -d "$WHEEL_DIR" ]; then
            cp "$WHEEL_DIR"/*.whl "$WHEEL_BACKUP"/ 2>/dev/null || true
        fi
    done
    success "Toutes les wheels copiées dans $WHEEL_BACKUP"
    rm -rf "$REPO/build_cpu" "$REPO/build_gpu"
    success "Dossiers de build supprimés pour libérer de l'espace"
}

# ==================== Exécution ====================
mkdir -p "$TMP_DIR"

install_system_prereqs
install_pip_if_missing
prepare_venv "$CPU_VENV"
prepare_venv "$GPU_VENV"

install_wheels_from_backup  # <-- tentative d'installation depuis backup

clone_or_update_repo
cd "$REPO"

GPU_BACKEND=$(detect_gpu)

# Build CPU puis GPU séquentiellement
build_onnxruntime "$CPU_VENV" "build_cpu" "cpu"
[ "$GPU_BACKEND" != "cpu" ] && build_onnxruntime "$GPU_VENV" "build_gpu" "$GPU_BACKEND"

# Installation des wheels dans les venv
install_wheel "$CPU_VENV" "$REPO/build_cpu"
[ "$GPU_BACKEND" != "cpu" ] && install_wheel "$GPU_VENV" "$REPO/build_gpu"

# Backup des wheels et nettoyage des builds
backup_wheels_and_cleanup

rm -rf "$TMP_DIR"
show_checklist
success "ONNX Runtime CPU et GPU prêts et wheels sauvegardées ! ✅"
