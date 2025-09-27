#!/bin/bash
set -e

# --- Variables ---
BASE_DIR=/docker/docker_DATA
WHISPER_DATA=$BASE_DIR/whisper-data
PIPER_DATA=$BASE_DIR/piper-data
SCRIPTS_DIR=$BASE_DIR/scripts
NAS_IP=10.0.0.7
PIPER_MODEL=$PIPER_DATA/fr-fr-mls_10246-medium.onnx

# --- Créer les dossiers si absents ---
mkdir -p $WHISPER_DATA $PIPER_DATA $SCRIPTS_DIR

# --- Vérifier que le modèle Piper existe ---
if [ ! -f "$PIPER_MODEL" ]; then
    echo "Téléchargement du modèle Piper français..."
    curl -L -o "$PIPER_MODEL" \
    https://github.com/rhasspy/wyoming-piper/releases/download/v1.0.0/fr-fr-mls_10246-medium.onnx
fi

# --- Créer docker-compose.yml ---
cat > $BASE_DIR/docker-compose.yml <<EOF
version: "3.9"

services:
  whisper:
    container_name: whisper
    image: rhasspy/wyoming-whisper:latest
    command: >
      --model small
      --language fr
      --uri tcp://0.0.0.0:10300
      --data-dir /data
    volumes:
      - $WHISPER_DATA:/data
      - $SCRIPTS_DIR:/workspace/scripts
    devices:
      - /dev/kfd
      - /dev/dri
    environment:
      - TZ=Europe/Paris
    restart: unless-stopped
    ports:
      - $NAS_IP:10300:10300

  piper:
    container_name: piper
    image: rhasspy/wyoming-piper:latest
    command: >
      --piper /data/fr-fr-mls_10246-medium.onnx
      --voice fr-fr
      --data-dir /data
      --uri tcp://0.0.0.0:10200
    volumes:
      - $PIPER_DATA:/data
      - $SCRIPTS_DIR:/workspace/scripts
    devices:
      - /dev/kfd
      - /dev/dri
    environment:
      - TZ=Europe/Paris
    restart: unless-stopped
    ports:
      - $NAS_IP:10200:10200

networks:
  default:
    driver: bridge
EOF

# --- Lancer les containers ---
cd $BASE_DIR
docker compose up -d

echo "✅ Whisper et Piper sont lancés sur $NAS_IP:10300 et $NAS_IP:10200"
