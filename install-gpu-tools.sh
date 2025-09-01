#!/bin/bash
set -euo pipefail

# ========== Fonctions de log ==========
info()    { echo -e "[INFO] $*"; }
success() { echo -e "[SUCCESS] $*"; }
warn()    { echo -e "[WARN] $*"; }
error()   { echo -e "[ERROR] $*" >&2; }

TASKS_DONE=()

info "=== Script d’installation GPU lancé dans le container ==="

# Vérification présence de Python
if ! command -v python3 &> /dev/null; then
    error "Python3 n'est pas disponible dans ce container."
    exit 1
fi

# Vérification présence de pip
if ! command -v pip3 &> /dev/null; then
    info "pip3 non présent, tentative d’installation..."
    if python3 -m ensurepip --upgrade; then
        info "pip3 installé via ensurepip"
    else
        info "ensurepip indisponible, utilisation d’apt-get"
        apt-get update && apt-get install -y python3-pip
    fi
fi

# Mise à jour pip
info "Mise à jour pip3"
python3 -m pip install --upgrade pip --break-system-packages
TASKS_DONE+=("pip3 installé et mis à jour")

# Nettoyage d'anciennes installations
if python3 -m pip show onnxruntime-rocm &>/dev/null; then
    info "Suppression ancienne version onnxruntime-rocm"
    python3 -m pip uninstall -y onnxruntime-rocm
fi
if python3 -m pip show numpy &>/dev/null; then
    info "Suppression ancienne version numpy"
    python3 -m pip uninstall -y numpy
fi

# Installation onnxruntime-rocm et numpy compatible
info "Installation onnxruntime-rocm et numpy"
python3 -m pip install --break-system-packages \
    https://repo.radeon.com/rocm/manylinux/rocm-rel-6.1.3/onnxruntime_rocm-1.17.0-cp310-cp310-linux_x86_64.whl
python3 -m pip install --break-system-packages numpy==1.26.4
TASKS_DONE+=("onnxruntime-rocm et numpy installés")

# Vérification du provider ROCm/MIGraphX
PROVIDERS=$(python3 -c "import onnxruntime as ort; print(ort.get_available_providers())")
if [[ "$PROVIDERS" == *"MIGraphXExecutionProvider"* ]] || [[ "$PROVIDERS" == *"ROCMExecutionProvider"* ]]; then
    TASKS_DONE+=("onnxruntime ROCm/MIGraphX disponibles : $PROVIDERS")
else
    warn "onnxruntime ROCm/MIGraphX non détecté correctement : $PROVIDERS"
fi

# ========== Résumé ==========
echo "==================== Résumé des tâches effectuées ===================="
for task in "${TASKS_DONE[@]}"; do
    echo " - $task"
done
echo "===================================================================="

success "Python GPU Tools installés avec onnxruntime-rocm et numpy"
