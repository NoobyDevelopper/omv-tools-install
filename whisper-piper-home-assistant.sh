#!/bin/bash

# ----------------------------
# Script Tout-en-un Docker
# ----------------------------

set -e

echo "🚀 Création des dossiers pour Docker..."
mkdir -p /docker/faster-whisper_DATA
mkdir -p /docker/piper_DATA
mkdir -p /docker/home-assistant_CONFIG

# ----------------------------
# Créer le docker-compose.yml
# ----------------------------

COMPOSE_FILE="/docker/docker-compose.yml"

echo "📝 Création du docker-compose.yml..."

cat > $COMPOSE_FILE <<'EOF'
services:

  # 🗣️ Faster-Whisper (STT)
  faster-whisper:
    image: linuxserver/faster-whisper:latest
    container_name: faster-whisper
    restart: unless-stopped
    environment:
      - TZ=Europe/Paris
      - WHISPER_MODEL=small
    volumes:
      - /opt/rocm:/opt/rocm
      - /docker/faster-whisper_DATA:/data
    devices:
      - "/dev/dri:/dev/dri"
      - "/dev/kfd:/dev/kfd"
    ports:
      - "10300:10300"
    networks:
      - whispnet

  # 🗣️ Piper (TTS)
  piper:
    image: rhasspy/wyoming-piper:latest
    container_name: piper
    restart: unless-stopped
    devices:
      - "/dev/dri:/dev/dri"
      - "/dev/kfd:/dev/kfd"
    volumes:
      - /opt/piper_models:/opt/models
    environment:
      - TZ=Europe/Paris
    ports:
      - "10200:10200"
    networks:
      - whispnet
    command: ["--voice", "fr_FR-siwis-medium", "--data-dir", "/opt/models"]

  # 🏠 Home Assistant
  home-assistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: home-assistant
    restart: unless-stopped
    network_mode: host
    environment:
      - TZ=Europe/Paris
    volumes:
      - /docker/home-assistant_CONFIG:/config

networks:
  whispnet:
    driver: bridge
EOF

# ----------------------------
# Lancer le stack Docker
# ----------------------------

echo "🚀 Lancement du stack Docker..."
docker compose -f $COMPOSE_FILE build
docker compose -f $COMPOSE_FILE up -d

echo "✅ Stack complet lancé !"
echo "Faster-Whisper : http://10.0.0.7:10300"
echo "Piper : http://10.0.0.7:10200"
echo "Home Assistant : http://10.0.0.7:8123"

# ----------------------------
# Installer HACS dans Home Assistant
# ----------------------------

echo "📝 Installation de HACS dans Home Assistant..."
docker exec -it home-assistant bash -c "wget -O - https://get.hacs.xyz | bash"

# Redémarrer le conteneur pour prendre en compte HACS
echo "🔄 Redémarrage du conteneur Home Assistant..."
docker restart home-assistant

echo "✅ Home Assistant prêt avec HACS installé !"
