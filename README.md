
POUR OMV 7.4.17 intel/NVIDIA/AMDGPU tester RADEON RX 7600XT

        sudo apt update && sudo apt install -y wget unzip && \
        rm -rf omv-tools-install && \
        wget -O repo.zip https://github.com/NoobyDevelopper/omv-tools-install/archive/refs/heads/main.zip && \
        unzip repo.zip && rm repo.zip && mv omv-tools-install-main omv-tools-install && \
        cd omv-tools-install && chmod +x launcher.sh && sudo ./launcher.sh


recuper le launcher.sh

pas dev fait par chatgpt je decline toute responsabilite

la sauvegarde est une vertue qui faut grandement aimé.

OMV Config Base - Script
        
Automatisation complète de la configuration de base pour OpenMediaVault avec support GPU et Python.
        
Fonctionnalités clés :
# Checklist d'installation OMV et configuration GPU/venv

- [ ] **Mise à jour système**  
  - `apt update` et `apt upgrade`  
  - Vérification des paquets à jour

- [ ] **Firmware AMD**  
  - Vérification si `firmware-amd-graphics` installé  
  - Installation si absent

- [ ] **wget**  
  - Vérification de la présence de `wget`  
  - Installation si nécessaire

- [ ] **OMV-Extras**  
  - Téléchargement et installation du script OMV-Extras

- [ ] **Extensions OMV**  
  - `openmediavault-clamav`, `openmediavault-cterm`, `openmediavault-diskstats`, etc.  

- [ ] **Python utils**  
  - `python3-venv`, `python3-pip`, `python3-setuptools`, `python3-wheel`

- [ ] **Git**  
  - Vérification de Git  
  - Installation si absent

- [ ] **GPU Drivers + ROCm / CUDA / Intel**  
  - Détection GPU : AMD → ROCm, NVIDIA → CUDA, Intel → drivers Intel  
  - Installation des pilotes  
  - Ajout utilisateur aux groupes `render` et `video`

- [ ] **Groupes utilisateur**  
  - Ajouter l’utilisateur courant aux groupes `render` et `video`

- [ ] **OMV-KVM**  
  - Installation de `openmediavault-kvm`

- [ ] **OMV-Compose + Docker**  
  - Installation de `openmediavault-compose` (Docker inclus)

- [ ] **Nettoyage automatique**  
  - Suppression des fichiers temporaires et caches  
  - `apt clean` et `apt autoremove`

- [ ] **Venv global**  
  - Création du venv global `~/onnx_env`  
  - Installation de pip, setuptools, wheel, numpy

- [ ] **Wake-on-LAN automatique**  
  - Détection de l’interface principale  
  - Activation WOL avec `ethtool` si disponible

ONNX Runtime Builder ✅

Script automatisé pour compiler ONNX Runtime CPU & ROCm GPU, gérer les venv Python, filtrer les warnings et installer les wheels.

🚀 Checklist des fonctionnalités

# Checklist du script ONNX Runtime

- [ ] **Pré-requis système**  
  - Git, CMake, Ninja  
  - Python3-dev, build-essential, wget, curl

- [ ] **Création des venv**  
  - CPU venv (`$HOME/onnx_cpu_env`)  
  - GPU venv (`$HOME/onnx_gpu_env`)  
  - pip, setuptools, wheel, packaging, ninja, cmake, flatbuffers, numpy

- [ ] **Installation depuis backup**  
  - Si des wheels existent dans `~/onnxruntime_wheels_backup`  
    - Installer directement dans le CPU venv  
    - Sortie du script  

- [ ] **Clone / Update du repo ONNX Runtime**  
  - `git clone --recursive` si inexistant  
  - Sinon `git pull` + submodules update  

- [ ] **Détection GPU**  
  - AMD → ROCm  
  - NVIDIA → CUDA  
  - Aucun → CPU uniquement  

- [ ] **Compilation ONNX Runtime**  
  - Build CPU  
  - Build GPU si GPU détecté  
  - Logs et barre de progression  

- [ ] **Installation des wheels**  
  - CPU venv  
  - GPU venv (si présent)  

- [ ] **Backup et nettoyage**  
  - Copie des wheels vers `~/onnxruntime_wheels_backup`  
  - Suppression des dossiers `build_cpu` et `build_gpu`  

- [ ] ✅ **ONNX Runtime prêt**  
  - CPU et GPU installés dans les venv  
  - Wheels sauvegardées
