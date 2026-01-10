#!/bin/bash
set -euo pipefail

# ================= LOG =================
info()    { echo "[INFO] $*"; }
success() { echo "[SUCCESS] $*"; }
warn()    { echo "[WARN] $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

# ================= PRÉREQUIS =================
info "Vérification OMV Compose / Docker Compose plugin"
apt update -y

if ! dpkg -l | grep -qw openmediavault-compose; then
    apt install -y openmediavault-compose
fi

if ! dpkg -l | grep -qw docker-compose-plugin; then
    apt install -y docker-compose-plugin
fi

# ================= CHEMINS =================
read -rp "Chemin des données Docker (ex: /srv/dev-disk-by-label-DATA/docker) : " DOCKER_DATA
mkdir -p "$DOCKER_DATA/ollama"

read -rp "IP d'écoute Ollama [127.0.0.1] : " IP_ADDR
IP_ADDR=${IP_ADDR:-127.0.0.1}

# ================= DÉTECTION ROCm / VRAM =================
VRAM_TOTAL_GB=0
ROCM_OK=0

if command -v rocm-smi >/dev/null 2>&1 && rocm-smi >/dev/null 2>&1; then
    ROCM_OK=1
    info "ROCm détecté"

    VRAM_RAW=$(rocm-smi --showmeminfo vram | grep "VRAM Total")

    VRAM_TOTAL_BYTES=0
    while read -r line; do
        VALUE=$(echo "$line" | awk '{print $NF}')
        UNIT=$(echo "$line" | grep -oE '\(([^)]*)\)' | tr -d '()')

        case "$UNIT" in
            B)   VRAM_TOTAL_BYTES=$((VRAM_TOTAL_BYTES + VALUE)) ;;
            MiB) VRAM_TOTAL_BYTES=$((VRAM_TOTAL_BYTES + VALUE * 1024 * 1024)) ;;
            GiB) VRAM_TOTAL_BYTES=$((VRAM_TOTAL_BYTES + VALUE * 1024 * 1024 * 1024)) ;;
            *)   warn "Unité VRAM inconnue : $UNIT" ;;
        esac
    done <<< "$VRAM_RAW"

    VRAM_TOTAL_GB=$((VRAM_TOTAL_BYTES / 1024 / 1024 / 1024))
    success "VRAM totale détectée : ${VRAM_TOTAL_GB} Go"
else
    warn "ROCm non disponible"
fi

# ================= CHOIX VRAM =================
if (( VRAM_TOTAL_GB > 0 )); then
    read -rp "VRAM à autoriser à Ollama (max ${VRAM_TOTAL_GB} Go) : " VRAM_CHOSEN
    VRAM_CHOSEN=${VRAM_CHOSEN:-$VRAM_TOTAL_GB}
    (( VRAM_CHOSEN > 0 && VRAM_CHOSEN <= VRAM_TOTAL_GB )) || error "VRAM invalide"
else
    read -rp "VRAM à autoriser manuellement (Go) : " VRAM_CHOSEN
    (( VRAM_CHOSEN > 0 )) || error "VRAM invalide"
fi

info "VRAM allouée : ${VRAM_CHOSEN} Go"

# ================= DÉTECTION RAM =================
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
MAX_RAM_ALLOUE=$((TOTAL_RAM_GB - 2))
read -rp "RAM à allouer à Ollama (max ${MAX_RAM_ALLOUE} Go) : " RAM_CHOSEN
RAM_CHOSEN=${RAM_CHOSEN:-$MAX_RAM_ALLOUE}
(( RAM_CHOSEN > 0 && RAM_CHOSEN <= MAX_RAM_ALLOUE )) || error "RAM invalide"

info "RAM allouée à Ollama : ${RAM_CHOSEN} Go (swap bloqué, OS protégé)"

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

# ================= DÉPLOIEMENT OLLAMA =================
info "Déploiement Ollama (VRAM GPU + RAM ${RAM_CHOSEN} Go, swap bloqué)"

docker rm -f ollama >/dev/null 2>&1 || true

docker run -d \
  --name ollama \
  --restart unless-stopped \
  --device /dev/kfd \
  --device /dev/dri \
  --group-add video \
  --memory ${RAM_CHOSEN}g \
  --memory-swap ${RAM_CHOSEN}g \
  -v "$DOCKER_DATA/ollama:/root/.ollama" \
  -p ${IP_ADDR}:11434:11434 \
  ollama/ollama:rocm

success "Ollama opérationnel — VRAM GPU prioritaire, RAM allouée ${RAM_CHOSEN} Go, swap bloqué, TBW SSD/HDD protégé"
