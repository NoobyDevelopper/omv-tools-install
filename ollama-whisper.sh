#!/bin/bash
set -euo pipefail

# ================= LOG =================
info()    { echo "[INFO] $*"; }
success() { echo "[SUCCESS] $*"; }
warn()    { echo "[WARN] $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

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
read -rp "IP hôte : " HOST_IP
read -rp "Dossier Docker : " DOCKER_DATA

mkdir -p "$DOCKER_DATA/faster-whisper" "$DOCKER_DATA/ollama"

# ================= RAM =================
RAM_OLLAMA=10
RAM_WHISPER=6

# ================= DOCKER =================
COMPOSE_FILE="$DOCKER_DATA/docker-compose.yml"

cat > "$COMPOSE_FILE" <<EOF
services:

  faster-whisper:
    image: linuxserver/faster-whisper:latest
    container_name: faster-whisper
    restart: unless-stopped

    environment:
      - WHISPER_MODEL=large-v3
      - WHISPER_DEVICE=rocm
      - WHISPER_COMPILE=1
      - NUM_THREADS=6
      - HSA_OVERRIDE_GFX_VERSION=11.0.0

    volumes:
      - /opt/rocm:/opt/rocm
      - $DOCKER_DATA/faster-whisper:/data

    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri

    tmpfs:
      - /tmp:size=512m
      - /var/tmp:size=256m

    deploy:
      resources:
        limits:
          memory: ${RAM_WHISPER}g

    ports:
      - "${HOST_IP}:10300:10300"


  ollama:
    image: ollama/ollama:rocm
    container_name: ollama
    restart: unless-stopped

    environment:
      - OLLAMA_NUM_THREADS=4
      - HSA_OVERRIDE_GFX_VERSION=11.0.0

    volumes:
      - $DOCKER_DATA/ollama:/root/.ollama

    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri

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
info "Démarrage stack voix + IA..."
docker compose -f "$COMPOSE_FILE" up -d

success "Stack prête (Whisper GPU prioritaire + Ollama ROCm)"

info "Whisper : http://${HOST_IP}:10300"
info "Ollama  : http://${HOST_IP}:11434"

warn "GPU partagé ROCm → arbitrage dynamique (pas de partition fixe VRAM)"
