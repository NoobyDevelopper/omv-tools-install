
POUR OMV 7.4.17 intel/NVIDIA/AMDGPU tester RADEON RX 7600XT

        sudo apt update && sudo apt install -y wget unzip && \
        rm -rf omv-tools-install && \
        wget -O repo.zip https://github.com/NoobyDevelopper/omv-tools-install/archive/refs/heads/main.zip && \
        unzip repo.zip && rm repo.zip && mv omv-tools-install-main omv-tools-install && \
        cd omv-tools-install && chmod +x launcher.sh && sudo ./launcher.sh


recuper le launcher.sh  ( le launcher peut buguer donc prendre direct script omv-config-base )

pas dev fait par chatgpt je decline toute responsabilite

la sauvegarde est une vertue qui faut grandement aimé.

OMV Config Base - Script
        
Automatisation complète de la configuration de base pour OpenMediaVault avec support GPU et Python.
        
Fonctionnalités clés :
        
        Mise à jour du système (apt update/upgrade)
        
        Firmware AMD graphique
        
        Installation de wget
        
        OMV-Extras et extensions OMV (ClamAV, CTerm, DiskStats, Fail2Ban, MD, ShareRootFS)
        
        Outils Python (python3-venv, pip, setuptools, wheel)
        
        Détection automatique GPU et installation des drivers adaptés :
        
        AMD → ROCm
        
        NVIDIA → CUDA
        
        Intel → Intel GPU Tools
        
        Ajout de l’utilisateur aux groupes render et video
        
        Installation KVM (openmediavault-kvm)
        
        OMV-Compose + Docker Compose
        
        Nettoyage des paquets inutiles (apt autoremove)
        
        Création d’un venv Python avec onnxruntime, onnx et numpy
        
        Checklist finale : ✔ toutes les étapes sont terminées et prêtes à l’usage.

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
