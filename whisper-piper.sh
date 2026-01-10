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
if ! dpkg -l | grep -qw docker-compose-plugin; then
    apt install -y docker-compose-plugin
fi

# ================= CHEMINS =================
read -rp "Chemin des données Docker (ex: /srv/dev-disk-by-label-DATA/docker) : " DOCKER_DATA
mkdir -p "$DOCKER_DATA/faster-whisper"
mkdir -p "$DOCKER_DATA/piper"

# ================= DÉTECTION ROCm =================
ROCM_OK=0
if command -v rocm-smi >/dev/null 2>&1; then
    ROCM_OK=1
    info "ROCm détecté"
else
    error "ROCm non trouvé. Assure-toi que les drivers AMD sont installés."
fi

# ================= RÉGLAGES GPU =================
# Autoriser l'accès direct aux devices nécessaires
DEVICES=(
    "/dev/kfd:/dev/kfd"
    "/dev/dri:/dev/dri"
)

# ================= RESSOURCES =================
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
MAX_RAM_ALLOUE=$((TOTAL_RAM_GB - 2))
read -rp "RAM à allouer aux conteneurs (max ${MAX_RAM_ALLOUE} Go) : " RAM_CHOSEN
RAM_CHOSEN=${RAM_CHOSEN:-$MAX_RAM_ALLOUE}
(( RAM_CHOSEN > 0 && RAM_CHOSEN <= MAX_RAM_ALLOUE )) || error "RAM invalide"
info "RAM allouée : ${RAM_CHOSEN} Go"

# ================= DOCKER-COMPOSE OPTIMISÉ =================
COMPOSE_FILE="$DOCKER_DATA/docker-compose.yml"

cat > "$COMPOSE_FILE" <<EOF

services:
  faster-whisper:
    image: linuxserver/faster-whisper:latest
    container_name: faster-whisper
    restart: unless-stopped
    environment:
      - TZ=Europe/Paris
      - WHISPER_MODEL=small
      - WHISPER_DEVICE=cuda   # Pour ROCm AMD via compatibilité CUDA
      - WHISPER_COMPILE=1     # Optimisation compilation GPU à la première exécution
      - NUM_THREADS=4         # Multithreading CPU pour pré/post-processing
    volumes:
      - /opt/rocm:/opt/rocm
      - $DOCKER_DATA/faster-whisper:/data
    devices:
      - "${DEVICES[0]}"
      - "${DEVICES[1]}"
    deploy:
      resources:
        limits:
          memory: ${RAM_CHOSEN}g
    ports:
      - "10300:10300"
    networks:
      - whispnet

  piper:
    image: rhasspy/wyoming-piper:latest
    container_name: piper
    restart: unless-stopped
    environment:
      - TZ=Europe/Paris
    volumes:
      - $DOCKER_DATA/piper:/opt/models
    devices:
      - "${DEVICES[0]}"
      - "${DEVICES[1]}"
    command: ["--voice", "fr_FR-siwis-medium", "--data-dir", "/opt/models"]
    deploy:
      resources:
        limits:
          memory: ${RAM_CHOSEN}g
    ports:
      - "10200:10200"
    networks:
      - whispnet

networks:
  whispnet:
    driver: bridge
EOF

# ================= LANCEMENT =================
info "Construction et lancement des conteneurs..."
docker compose -f "$COMPOSE_FILE" build
docker compose -f "$COMPOSE_FILE" up -d

success "Conteneurs faster-whisper et piper lancés et optimisés pour ROCm !"
info "Faster-Whisper HTTP API : http://localhost:10300"
info "Piper HTTP API : http://localhost:10200"

