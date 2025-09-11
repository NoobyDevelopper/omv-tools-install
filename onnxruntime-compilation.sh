#!/bin/bash
set -euo pipefail

VENV_DIR="$HOME/onnx_env"
source "$VENV_DIR/bin/activate"

GPU_VENDOR=$(lspci | grep -E "VGA|3D" | grep -iE "amd|nvidia|intel" || true)
info() { echo -e "[INFO] $*"; }

WORKDIR="$HOME/onnxruntime_build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -d "onnxruntime" ]; then
    git clone --recursive https://github.com/microsoft/onnxruntime
fi
cd onnxruntime
git submodule update --init --recursive
git clean -xfd || true
git reset --hard HEAD

if echo "$GPU_VENDOR" | grep -qi "amd"; then
    ./build.sh --config Release --build_wheel --update --build --parallel --use_rocm
elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    ./build.sh --config Release --build_wheel --update --build --parallel --use_cuda
else
    ./build.sh --config Release --build_wheel --update --build --parallel
fi

WHEEL=$(find build -name "onnxruntime-*.whl" | sort | tail -n 1)
pip install --upgrade "$WHEEL"

deactivate
echo "[SUCCESS] ONNX Runtime compilé et installé dans $VENV_DIR"
