#!/bin/bash
set -euo pipefail

# ================= LOG =================
info()    { echo "[INFO] $*"; }
success() { echo "[SUCCESS] $*"; }
warn()    { echo "[WARN] $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

# ================= PRÉREQUIS =================
info "Vérification Docker Compose et OMV Compose"
apt update -y
for pkg in docker-compose-plugin openmediavault-compose; do
    if ! dpkg -l | grep -qw "$pkg"; then
        apt install -y "$pkg"
    fi
done

# ================= DEMANDE IP NAS =================
read -rp "IP de l'hôte NAS pour exposer les conteneurs (ex: 10.0.0.7) : " HOST_IP

# ================= CHEMINS =================
read -rp "Chemin des données Docker : " DOCKER_DATA
mkdir -p "$DOCKER_DATA/faster-whisper" "$DOCKER_DATA/piper" "$DOCKER_DATA/ollama"

# ================= DÉTECTION ROCm / VRAM =================
ROCM_OK=0
VRAM_TOTAL_GB=0
if command -v rocm-smi >/dev/null 2>&1; then
    ROCM_OK=1
    info "ROCm détecté"
    VRAM_RAW=$(rocm-smi --showmeminfo vram | grep "VRAM Total")
    VRAM_BYTES=0
    while read -r line; do
        VAL=$(echo "$line" | awk '{print $NF}')
        UNIT=$(echo "$line" | grep -oE '\(([^)]*)\)' | tr -d '()')
        case "$UNIT" in
            B) VRAM_BYTES=$((VRAM_BYTES + VAL)) ;;
            MiB) VRAM_BYTES=$((VRAM_BYTES + VAL * 1024 * 1024)) ;;
            GiB) VRAM_BYTES=$((VRAM_BYTES + VAL * 1024 * 1024 * 1024)) ;;
            *) warn "Unité VRAM inconnue : $UNIT" ;;
        esac
    done <<< "$VRAM_RAW"
    VRAM_TOTAL_GB=$((VRAM_BYTES / 1024 / 1024 / 1024))
    success "VRAM totale détectée : ${VRAM_TOTAL_GB} Go"
else
    warn "ROCm non disponible"
fi

# ================= CHOIX RAM =================
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
MAX_RAM_ALLOUE=$((TOTAL_RAM_GB - 2))
info "RAM système totale : ${TOTAL_RAM_GB} Go, max à allouer : ${MAX_RAM_ALLOUE} Go"

# Allocation fixe selon ton plan
RAM_OLLAMA=16
RAM_WHISPER=8
RAM_PIPER=3

# ================= LOGS DOCKER =================
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

# ================= COMPOSE FILE =================
COMPOSE_FILE="$DOCKER_DATA/docker-compose.yml"
cat > "$COMPOSE_FILE" <<EOF
services:
  faster-whisper:
    image: linuxserver/faster-whisper:latest
    container_name: faster-whisper
    restart: unless-stopped
    environment:
      - WHISPER_MODEL=medium
      - WHISPER_DEVICE=cuda
      - WHISPER_COMPILE=1
      - NUM_THREADS=4
    volumes:
      - /opt/rocm:/opt/rocm
      - $DOCKER_DATA/faster-whisper:/data
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    tmpfs:
      - /tmp:size=512m
    deploy:
      resources:
        limits:
          memory: ${RAM_WHISPER}g
    ports:
      - "${HOST_IP}:10300:10300"

  piper:
    image: rhasspy/wyoming-piper:latest
    container_name: piper
    restart: unless-stopped
    volumes:
      - $DOCKER_DATA/piper:/opt/models
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    command: ["--voice", "fr_FR-siwis-medium", "--data-dir", "/opt/models"]
    tmpfs:
      - /tmp:size=256m
    deploy:
      resources:
        limits:
          memory: ${RAM_PIPER}g
    ports:
      - "${HOST_IP}:10200:10200"

  ollama:
    image: ollama/ollama:rocm
    container_name: ollama
    restart: unless-stopped
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    tmpfs:
      - /tmp:size=512m
    volumes:
      - $DOCKER_DATA/ollama:/root/.ollama
    deploy:
      resources:
        limits:
          memory: ${RAM_OLLAMA}g
    ports:
      - "${HOST_IP}:11434:11434"
EOF

# ================= LANCEMENT =================
info "Construction et lancement des conteneurs..."
docker compose -f "$COMPOSE_FILE" build || true
docker compose -f "$COMPOSE_FILE" up -d

success "Whisper, Piper et Ollama lancés avec tmpfs et swap bloqué."
info "Whisper HTTP API : http://${HOST_IP}:10300"
info "Piper HTTP API   : http://${HOST_IP}:10200"
info "Ollama HTTP API  : http://${HOST_IP}:11434"
info "Swap bloqué et TBW SSD/HDD protégé."
