#!/bin/bash
set -euo pipefail

# ================= LOG =================
info()    { echo "[INFO] $*"; }
success() { echo "[SUCCESS] $*"; }
warn()    { echo "[WARN] $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

# ================= PRÉREQUIS =================
info "Vérification Docker Compose"
apt update -y
for pkg in docker-compose-plugin; do
    if ! dpkg -l | grep -qw "$pkg"; then
        apt install -y "$pkg"
    fi
done

# ================= SWAP BLOQUÉ (TBW PROTECT) =================
info "Désactivation swap pour protection SSD/HDD (TBW)"

swapoff -a || true

if grep -q " swap " /etc/fstab; then
    sed -i.bak '/ swap / s/^/#/' /etc/fstab
fi

sysctl -w vm.swappiness=0 || true

cat >/etc/sysctl.d/99-no-swap.conf <<EOF
vm.swappiness=0
vm.vfs_cache_pressure=50
EOF

sysctl --system >/dev/null || true

success "Swap désactivé → TBW SSD/HDD protégé"

# ================= DEMANDE IP NAS =================
read -rp "IP de l'hôte NAS (ex: 10.0.0.7) : " HOST_IP

# ================= CHEMINS =================
read -rp "Chemin données Docker : " DOCKER_DATA
mkdir -p "$DOCKER_DATA/faster-whisper" "$DOCKER_DATA/ollama"

# ================= RAM =================
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
RAM_OLLAMA=10
RAM_WHISPER=6

# ================= DOCKER LOG =================
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "5m",
    "max-file": "1"
  }
}
EOF
systemctl restart docker

# ================= COMPOSE =================
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
info "Lancement des conteneurs..."
docker compose -f "$COMPOSE_FILE" up -d

success "Stack ROCm lancée (Whisper + Ollama)"
warn "Swap bloqué + tmpfs actif → TBW SSD/HDD protégé"

info "Whisper API : http://${HOST_IP}:10300"
info "Ollama API  : http://${HOST_IP}:11434"
