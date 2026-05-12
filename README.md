🧠 OMV Tools Install – Voice AI Stack (OMV 8 + ROCm 7.2.3)

## ⚡ Installation rapide (OMV 8 / RX 7600 XT / ROCm)


`` sudo apt update && sudo apt install -y wget unzip && \
rm -rf omv-tools-install && \
wget -O repo.zip https://github.com/NoobyDevelopper/omv-tools-install/archive/refs/heads/main.zip && \
unzip repo.zip && rm repo.zip && mv omv-tools-install-main omv-tools-install && \
cd omv-tools-install && chmod +x launcher.sh && sudo ./launcher.sh ``

⚠️ DISCLAIMER

❗ Script non officiel (homelab uniquement)
❗ Aucune garantie
❗ Utilisation à vos risques

👉 Sauvegarde obligatoire avant exécution.

🧩 OMV 8 – Fonctionnalités
🧱 Système
Update & upgrade automatique
Nettoyage système
Optimisation base OMV
🔥 GPU Auto Setup (ROCm 7.2.3)
AMD (RX 7600 XT / gfx1102)
ROCm 7.2.3 installation (latest)
Support gfx1102
Activation /dev/kfd + /dev/dri
NVIDIA
CUDA fallback auto
Intel
Mode CPU fallback
Groupes GPU
render
video
🐳 Docker / Compose
openmediavault-compose
Docker engine intégré
Support stacks IA (Whisper / Ollama / Home Assistant)
🐍 Python stack
python3-venv
pip / setuptools / wheel
numpy base
~/onnx_env
🖥️ KVM
openmediavault-kvm
virtualisation locale
🌐 Wake-on-LAN
détection interface automatique
activation via ethtool
démarrage réseau optimisé
🧠 Voice AI Stack (intégré)
🎤 Whisper ROCm (STT)
transcription locale GPU AMD
faible latence voix
compatible Home Assistant (WYOMING)
🤖 Ollama ROCm (LLM)
inference GPU AMD
modèles ministral / llama
optimisé RX 7600 XT
⚡ Performance estimée
🎤 Whisper
small : 300–600 ms
medium : 600 ms – 1.2 s
large-v3 : 1.5 – 3 s
🤖 Ollama
15–30 tokens/sec GPU
0.5 – 3 s réponse
🔐 Sécurité & stabilité
swap OFF (TBW SSD protection)
tmpfs RAM cache (réduction I/O disque)
isolation GPU containers
ROCm 7.2.3 stable runtime
🧠 Architecture globale
Micro → HAOS (Wake Word)
      → Whisper ROCm (OMV 8)
      → Ollama ROCm (OMV 8)
      → réponse vocale / action domotique
🚀 Résultat final

Stack prête pour :

🎤 Assistant vocal local ultra réactif
🧠 IA locale GPU AMD (RX 7600 XT)
🏠 Domotique Home Assistant fluide
🧱 OMV 8 homelab production stable
