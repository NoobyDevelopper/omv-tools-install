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
read -rp "IP du server (Docker) : " HOST_IP
read -rp "Dossier Docker_DATA : " DOCKER_DATA

mkdir -p "$DOCKER_DATA/faster-whisper" "$DOCKER_DATA/ollama"

# ================= RAM =================
RAM_WHISPER=6
RAM_OLLAMA=10

# ================= COMPOSE =================
COMPOSE_FILE="$DOCKER_DATA/docker-compose.yml"

cat > "$COMPOSE_FILE" <<EOF
services:

  # ================= WHISPER (PRIORITÉ VOIX) =================
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
      - CT2_FORCE_FP16=1
      - WHISPER_COMPUTE_TYPE=float16

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


  # ================= OLLAMA (LLM GPU SECONDAIRE) =================
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
info "Démarrage stack VOIX + IA ROCm..."
docker compose -f "$COMPOSE_FILE" up -d

success "Stack prête"

# ================= INFOS =================
info "Whisper API : http://${HOST_IP}:10300"
info "Ollama API  : http://${HOST_IP}:11434"

warn "Architecture active : VOIX prioritaire (Whisper GPU) + LLM secondaire (Ollama ROCm)"
warn "Swap désactivé + tmpfs actif → latence disque minimale + TBW protégé"
