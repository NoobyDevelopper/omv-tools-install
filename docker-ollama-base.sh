#!/bin/bash
set -euo pipefail

: '
Script : partie2.sh
Titre  : Docker-Ollama-Base
Objectif : Déployer et gérer Ollama dans Docker sur OMV avec accès GPU et données persistantes.
Description :
  1. Installation/mise à jour d’OMV-Compose.
  2. Vérification/installation du plugin Docker Compose.
  3. Définition du volume Docker pour Ollama.
  4. Fonction de gestion des conteneurs (création, mise à jour, relance automatique).
  5. Détection automatique de l’adresse IP pour exposer Ollama sur le réseau.
  6. Déploiement du conteneur Ollama avec GPU ROCm, ports, et persistance.
'

# ========== Fonctions de log ==========
info()    { echo -e "[INFO] $*"; }
success() { echo -e "[SUCCESS] $*"; }
warn()    { echo -e "[WARN] $*"; }
error()   { echo -e "[ERROR] $*" >&2; }

# ========== Docker + Ollama ==========
if dpkg -l | grep -qw openmediavault-compose; then
    info "OMV-Compose déjà installé. Mise à jour si nécessaire..."
    sudo apt install --only-upgrade -y openmediavault-compose
else
    info "OMV-Compose non installé. Installation..."
    sudo apt install -y openmediavault-compose
fi

if ! dpkg -l | grep -qw docker-compose-plugin; then
    info "Docker Compose plugin non trouvé. Installation..."
    sudo apt update && sudo apt install -y docker-compose-plugin
else
    info "Docker Compose plugin déjà installé."
fi

read -rp "Entrez le chemin du volume Docker pour Ollama (ex: /srv/dev-disk-by-label-DATA/docker) : " DOCKER_DATA
mkdir -p "$DOCKER_DATA/ollama"

update_or_restart_container() {
  local name=$1
  local image=$2
  local run_cmd=$3

  if sudo docker ps -a --format '{{.Names}}' | grep -qw "$name"; then
    info "Mise à jour du conteneur $name"
    sudo docker pull "$image"
    if sudo docker ps --format '{{.Names}}' | grep -qw "$name"; then
      sudo docker stop "$name"
    fi
    sudo docker rm "$name"
    eval "$run_cmd"
    success "Conteneur $name mis à jour et relancé"
  else
    warn "Conteneur $name non trouvé. Création..."
    eval "$run_cmd"
    success "Conteneur $name créé et lancé"
  fi
}

if [ "$(ls -A $DOCKER_DATA/ollama)" ]; then
    warn "Des fichiers existent déjà dans $DOCKER_DATA/ollama. Ils ne seront pas écrasés."
else
    info "Le répertoire $DOCKER_DATA/ollama est vide."
fi

IP_ADDR=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}')
[[ -z "$IP_ADDR" ]] && IP_ADDR="10.0.0.7"
info "IP utilisée pour Ollama : $IP_ADDR"

info "Mise à jour du conteneur Docker Ollama"
update_or_restart_container "ollama" "ollama/ollama:rocm" \
"sudo docker run -d \
  --device /dev/kfd \
  --device /dev/dri \
  --group-add video \
  -v $DOCKER_DATA/ollama:/root/.ollama \
  -p $IP_ADDR:11434:11434 \
  --name ollama --restart=always \
  ollama/ollama:rocm"

success "Partie 2 terminée : Docker + Ollama prêts"
