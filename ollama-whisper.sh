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

# ================= GPU GROUP AUTO =================
info "Détection groupes GPU"

VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

success "video=$VIDEO_GID | render=$RENDER_GID"

# ================= INPUT =================
read -rp "IP Docker host : " HOST_IP
read -rp "Docker DATA path : " DOCKER_DATA

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

  # ================= WHISPER WYOMING ROCm =================
  wyoming-whisper:
    image: pigeekcom/wyoming-faster-whisper-rocm:rocm7.0-strix
    container_name: wyoming-whisper
    restart: unless-stopped

    ports:
      - "${HOST_IP}:10300:10300"

    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri

    group_add:
      - "${VIDEO_GID}"
      - "${RENDER_GID}"

    environment:
      - WYOMING_MODEL=medium
      - WYOMING_COMPUTE_TYPE=int8
      - NUM_THREADS=6
      - TZ=Europe/Paris

    volumes:
      - $DOCKER_DATA/whisper-rocm:/data

    tmpfs:
      - /tmp:size=512m

    ipc: host


  # ================= OLLAMA ROCm =================
  ollama:
    image: ollama/ollama:rocm
    container_name: ollama
    restart: unless-stopped

    environment:
      - OLLAMA_NUM_THREADS=4
      - HIP_VISIBLE_DEVICES=0

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

# ================= START =================
info "Démarrage stack voix + IA ROCm..."
docker compose -f "$COMPOSE_FILE" up -d

success "Stack prête"

# ================= INFOS =================
info "Whisper WYOMING : http://${HOST_IP}:10300"
info "Ollama API      : http://${HOST_IP}:11434"

warn "RX 7600 XT ROCm actif"
warn "NUM_THREADS=6 Whisper optimisé voix"
warn "HAOS sur autre machine → architecture propre"
