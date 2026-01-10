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
for pkg in docker-compose-plugin openmediavault-compose; do
    if ! dpkg -l | grep -qw "$pkg"; then
        apt install -y "$pkg"
    fi
done

# ================= CHEMINS =================
read -rp "Chemin des données Docker (ex: /srv/dev-disk-by-label-DATA/docker) : " DOCKER_DATA
mkdir -p "$DOCKER_DATA/faster-whisper" "$DOCKER_DATA/piper" "$DOCKER_DATA/ollama"

read -rp "IP d'écoute Ollama [127.0.0.1] : " IP_ADDR
IP_ADDR=${IP_ADDR:-127.0.0.1}

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

# ================= CHOIX RAM/VRAM =================
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
MAX_RAM_ALLOUE=$((TOTAL_RAM_GB - 2))
read -rp "RAM à allouer aux conteneurs (max ${MAX_RAM_ALLOUE} Go) : " RAM_CHOSEN
RAM_CHOSEN=${RAM_CHOSEN:-$MAX_RAM_ALLOUE}
(( RAM_CHOSEN > 0 && RAM_CHOSEN <= MAX_RAM_ALLOUE )) || error "RAM invalide"
info "RAM allouée : ${RAM_CHOSEN} Go"

if (( VRAM_TOTAL_GB > 0 )); then
    read -rp "VRAM à autoriser pour Ollama (max ${VRAM_TOTAL_GB} Go) : " VRAM_CHOSEN
    VRAM_CHOSEN=${VRAM_CHOSEN:-$VRAM_TOTAL_GB}
    (( VRAM_CHOSEN > 0 && VRAM_CHOSEN <= VRAM_TOTAL_GB )) || error "VRAM invalide"
else
    read -rp "VRAM à autoriser manuellement (Go) : " VRAM_CHOSEN
    (( VRAM_CHOSEN > 0 )) || error "VRAM invalide"
fi
info "VRAM allouée à Ollama : ${VRAM_CHOSEN} Go"

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
version: "3.9"

services:
  faster-whisper:
    image: linuxserver/faster-whisper:latest
    container_name: faster-whisper
    restart: unless-stopped
    environment:
      - TZ=Europe/Paris
      - WHISPER_MODEL=small
      - WHISPER_DEVICE=cuda
      - WHISPER_COMPILE=1
      - NUM_THREADS=4
    volumes:
      - /opt/rocm:/opt/rocm
      - $DOCKER_DATA/faster-whisper:/data
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    deploy:
      resources:
        limits:
          memory: ${RAM_CHOSEN}g
    tmpfs:
      - /tmp:size=512m
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
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    command: ["--voice", "fr_FR-siwis-medium", "--data-dir", "/opt/models"]
    deploy:
      resources:
        limits:
          memory: ${RAM_CHOSEN}g
    tmpfs:
      - /tmp:size=256m
    ports:
      - "10200:10200"
    networks:
      - whispnet

  ollama:
    image: ollama/ollama:rocm
    container_name: ollama
    restart: unless-stopped
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    deploy:
      resources:
        limits:
          memory: ${RAM_CHOSEN}g
    tmpfs:
      - /tmp:size=512m
    volumes:
      - $DOCKER_DATA/ollama:/root/.ollama
    ports:
      - "${IP_ADDR}:11434:11434"
    networks:
      - whispnet

networks:
  whispnet:
    driver: bridge
EOF

# ================= LANCEMENT =================
info "Construction et lancement des conteneurs (swap bloqué)..."
docker compose -f "$COMPOSE_FILE" build
docker compose -f "$COMPOSE_FILE" up -d --no-deps \
  --memory ${RAM_CHOSEN}g \
  --memory-swap ${RAM_CHOSEN}g

success "Conteneurs Whisper, Piper et Ollama lancés avec tmpfs et swap bloqué."
info "Whisper HTTP API : http://localhost:10300"
info "Piper HTTP API   : http://localhost:10200"
info "Ollama HTTP API  : http://${IP_ADDR}:11434"
info "Swap bloqué et TBW SSD/HDD protégé."
