
POUR OMV 7.4.17 AMDGPU tester RADEON RX 7600XT

        sudo apt update 
        sudo apt install -y wget unzip 
        rm -rf omv-tools-install 
        wget -O repo.zip https://github.com/NoobyDevelopper/omv-tools-install/archive/refs/heads/main.zip
        unzip repo.zip && rm repo.zip && mv omv-tools-install-main omv-tools-install 
        cd omv-tools-install && chmod +x launcher.sh 
        sudo ./launcher.sh


recuper le launcher.sh  ( le launcher peut buguer donc prendre direct script omv-config-base )

pas dev fait par chatgpt je decline toute responsabilite

la sauvegarde est une vertue qui faut grandement aimé.

script 1 omv-config-base

    Système déjà à jour Fait
    Firmware AMD graphique installé Fait
    wget déjà présent Fait
    OMV-Extras téléchargé Fait
    OMV-Extras installé Fait
    Extension openmediavault-clamav déjà à jour Fait
    Extension openmediavault-cterm déjà à jour Fait
    Extension openmediavault-diskstats déjà à jour Fait
    Extension openmediavault-fail2ban déjà à jour Fait
    Extension openmediavault-md déjà à jour Fait
    Extension openmediavault-sharerootfs déjà à jour Fait
    python3-setuptools déjà à jour Fait
    python3-wheel déjà à jour Fait
    Package AMD GPU installé Fait
    Utilisateur ajouté aux groupes render et video Fait
    ROCm installé Fait
    Extension openmediavault-kvm installée/mise à jour Fait
    Packages inutiles supprimés Fait
