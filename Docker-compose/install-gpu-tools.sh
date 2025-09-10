#!/bin/bash
set -euo pipefail

info()    { echo -e "[INFO] $*"; }
success() { echo -e "[SUCCESS] $*"; }
warn()    { echo -e "[WARN] $*"; }
error()   { echo -e "[ERROR] $*" >&2; }

TASKS_DONE=()

info "=== Script d’installation GPU, ONNX, modèles et voix lancé ==="

# ---------------- Python et pip ----------------
if ! command -v python3 &> /dev/null; then
    error "Python3 n'est pas disponible dans ce container."
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    info "pip3 non présent, installation via ensurepip..."
    if python3 -m ensurepip --upgrade; then
        info "pip3 installé via ensurepip"
    else
        error "pip3 non disponible et ensurepip échoue"
        exit 1
    fi
fi

info "Mise à jour pip3"
python3 -m pip install --upgrade pip
TASKS_DONE+=("pip3 installé et mis à jour")

# ---------------- Nettoyage anciennes versions ----------------
python3 -m pip uninstall -y onnxruntime-rocm numpy >/dev/null 2>&1 || true

# ---------------- onnxruntime-rocm et numpy ----------------
WHEEL_DIR="/workspace/scripts/wheels"
WHEEL_FILE="$WHEEL_DIR/onnxruntime_rocm-latest.whl"
mkdir -p "$WHEEL_DIR"

info "Téléchargement du wheel onnxruntime-rocm (version stable connue)"
apt update && apt install -y wget
wget -q -O "$WHEEL_FILE" https://repo.radeon.com/rocm/manylinux/rocm-rel-6.1.3/onnxruntime_rocm-1.17.0-cp39-cp39-linux_x86_64.whl

info "Installation / mise à jour onnxruntime-rocm et numpy"
python3 -m pip install --upgrade "$WHEEL_FILE"
python3 -m pip install --upgrade numpy
TASKS_DONE+=("onnxruntime-rocm et numpy installés ou mis à jour")

# ---------------- Vérification ROCm/MIGraphX ----------------
PROVIDERS=$(python3 -c "import onnxruntime as ort; print(ort.get_available_providers())")
if [[ "$PROVIDERS" == *"MIGraphXExecutionProvider"* ]] || [[ "$PROVIDERS" == *"ROCMExecutionProvider"* ]]; then
    TASKS_DONE+=("onnxruntime ROCm/MIGraphX disponibles : $PROVIDERS")
else
    warn "onnxruntime ROCm/MIGraphX non détecté correctement : $PROVIDERS"
fi

# ---------------- Whisper modèle ----------------
MODEL_DIR="/data/models/whisper"
mkdir -p "$MODEL_DIR"
info "Téléchargement du dernier modèle Whisper small..."
wget -q -O "$MODEL_DIR/small.en.pt" https://huggingface.co/openai/whisper-small/resolve/main/small.en.pt
TASKS_DONE+=("Modèle Whisper small téléchargé dans $MODEL_DIR")

# ---------------- Piper voix ----------------
VOICE_DIR="/data/voices/piper"
mkdir -p "$VOICE_DIR"
info "Téléchargement de la dernière voix Piper fr-siwis-medium..."
wget -q -O "$VOICE_DIR/fr-siwis-medium.pth" https://github.com/rhasspy/piper-voices/releases/latest/download/fr-siwis-medium.pth
TASKS_DONE+=("Voix Piper fr-siwis-medium téléchargée dans $VOICE_DIR")

# ---------------- Résumé ----------------
echo "==================== Résumé ===================="
for task in "${TASKS_DONE[@]}"; do
    echo " - $task"
done
echo "=============================================="

success "Installation GPU, ONNX, modèles Whisper et voix Piper terminée"
