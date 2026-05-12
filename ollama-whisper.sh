#!/bin/bash
set -euo pipefail

# ================= LOG =================
info()    { echo "[INFO] $*"; }
success() { echo "[SUCCESS] $*"; }
warn()    { echo "[WARN] $*"; }

# ================= PRÉREQUIS =================
info "Installation Docker Compose"
apt update -y
apt install -y docker-compose-plugin

# ================= SWAP BLOQUÉ (TBW PROTECT) =================
info "Désactivation swap (protection SSD/HDD)"

swapoff -a || true
sed -i.bak '/ swap / s/^/#/' /etc/fstab || true

cat >/etc/sysctl.d/99-voice-stack.conf <<EOF
vm.swappiness=0
vm.vfs_cache_pressure=50
EOF

sysctl --system >/dev/null || true

success "Swap désactivé (TBW protégé)"

# ================= INPUT =================
read -rp "IP du serveur Docker : " HOST_IP
read -rp "Dossier Docker_DATA : " DOCKER_DATA

mkdir -p \
  "$DOCKER_DATA/whisper-rocm" \
  "$DOCKER_DATA/ollama"

# ================= RAM =================
RAM_WHISPER=6
RAM_OLLAMA=10

# ================= COMPOSE =================
COMPOSE_FILE="$DOCKER_DATA/docker-compose.yml"

cat > "$COMPOSE_FILE" <<EOF
services:

  # ================= WHISPER ROCm (PRIORITÉ VOIX) =================
  whisper-rocm:
    image: beecave/insanely-fast-whisper-rocm:main
    container_name: whisper-rocm
    restart: unless-stopped

    ipc: host
    shm_size: "8G"

    environment:
      - TZ=Europe/Paris
      - HSA_OVERRIDE_GFX_VERSION=11.0.0
      - HIP_VISIBLE_DEVICES=0
      - WHISPER_MODEL=openai/whisper-medium

    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri

    group_add:
      - video
      - render

    volumes:
      - $DOCKER_DATA/whisper-rocm:/app/models

    tmpfs:
      - /tmp:size=512m
      - /var/tmp:size=256m

    deploy:
      resources:
        limits:
          memory: ${RAM_WHISPER}g

    ports:
      - "${HOST_IP}:10300:8000"


  # ================= OLLAMA ROCm (LLM GPU) =================
  ollama:
    image: ollama/ollama:rocm
    container_name: ollama
    restart: unless-stopped

    environment:
      - OLLAMA_NUM_THREADS=4
      - HSA_OVERRIDE_GFX_VERSION=11.0.0

    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri

    volumes:
      - $DOCKER_DATA/ollama:/root/.ollama

    tmpfs:
      - /tmp:size=512m
      - /var/tmp:size=256m

    deploy:
      resources:
        limits:
          memory: ${RAM_OLLAMA}g

    ports:
      - "${HOST_IP}:11434:11434"

EOF

# ================= LANCEMENT =================
info "Démarrage stack Whisper ROCm + Ollama ROCm..."
docker compose -f "$COMPOSE_FILE" up -d

success "Stack ROCm prête"

# ================= INFOS =================
info "Whisper ROCm API : http://${HOST_IP}:10300"
info "Ollama API       : http://${HOST_IP}:11434"

warn "Architecture active : Whisper ROCm GPU + Ollama ROCm GPU"
warn "VRAM RX 7600 XT partagée dynamiquement entre Whisper et Ollama"
warn "Swap désactivé + tmpfs actif → latence minimale + TBW protégé"
