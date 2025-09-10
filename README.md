
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

        1️⃣ Gestion du virtualenv Python
        
        Vérifie si le répertoire ~/onnx_env existe.
        
        Si non : crée un virtualenv Python isolé à cet emplacement.
        
        Si oui : indique que le venv est déjà présent.
        
        Permet d’installer et isoler ONNX Runtime et ses dépendances (numpy, pip, setuptools, wheel) sans toucher à l’host.
        
        2️⃣ Mise à jour ou installation d’ONNX Runtime
        
        Active automatiquement le venv.
        
        Vérifie si onnxruntime est installé :
        
        Déjà installé → met à jour la version existante.
        
        Non installé → installe ONNX Runtime et numpy dans le venv.
        
        Après l’installation ou la mise à jour, le venv est désactivé automatiquement.
        
        3️⃣ Détection et gestion du GPU
        
        Détecte automatiquement le type de GPU présent via lspci :
        
        AMD → installe les pilotes AMD et ROCm.
        
        NVIDIA → installe les pilotes NVIDIA et CUDA (à compléter).
        
        Intel → installe les pilotes Intel GPU (à compléter).
        
        Enregistre le type de GPU et l’état de l’installation dans le log.
        
        4️⃣ Installation et mise à jour des dépendances systèmes
        
        Gère les paquets de base pour Python : python3-setuptools et python3-wheel.
        
        Gère les paquets nécessaires pour ROCm, AMD, NVIDIA ou Intel selon le GPU détecté.
        
        Nettoie automatiquement les paquets inutiles avec apt autoremove.
        
        5️⃣ Gestion des logs et couleurs
        
        Affiche toutes les étapes avec des couleurs codées :
        
        INFO : bleu clair
        
        SUCCESS : vert
        
        WARN : jaune
        
        ERROR : rouge
        
        Marque chaque tâche comme :
        
        Installé (Fait)
        
        Mise à jour (Fait)
        
        Déjà à jour (Déjà à jour)
        
        6️⃣ Résumé final
        
        Affiche un résumé clair de toutes les actions effectuées avec le statut de chaque tâche.
        
        Confirme que le GPU est détecté, que le venv est prêt, et que ONNX Runtime est opérationnel.
