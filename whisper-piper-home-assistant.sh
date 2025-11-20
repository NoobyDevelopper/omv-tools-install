#!/bin/bash
set -e

echo "🚀 Création des dossiers pour Docker..."
mkdir -p /docker/faster-whisper_DATA
mkdir -p /docker/piper_DATA
mkdir -p /docker/home-assistant_CONFIG

# ----------------------------
# Création du docker-compose.yml
# ----------------------------

COMPOSE_FILE="/docker/docker-compose.yml"

cat > $COMPOSE_FILE <<'EOF'
services:
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

docker compose -f $COMPOSE_FILE build
docker compose -f $COMPOSE_FILE up -d

# ----------------------------
# Attendre que Home Assistant soit prêt sur l'hôte
# ----------------------------

echo "⏳ Attente de Home Assistant (host network)..."
HA_HOST="127.0.0.1"
until curl -sf "http://$HA_HOST:8123" >/dev/null 2>&1; do
    printf "."
    sleep 5
done
echo -e "\n✅ Home Assistant est prêt !"

# ----------------------------
# Installer HACS
# ----------------------------

echo "📝 Installation de HACS dans Home Assistant..."
docker exec -it home-assistant bash -c "wget -O - https://get.hacs.xyz | bash"

# Redémarrage final
echo "🔄 Redémarrage du conteneur Home Assistant..."
docker restart home-assistant

echo "✅ Home Assistant prêt avec HACS installé !"
echo "Accès Home Assistant : http://$HA_HOST:8123"
