🧠 OMV Tools Install – Voice AI Stack (OMV 8 + ROCm 7.2.3)

---

⚡ INSTALLATION RAPIDE (OMV 8 / RX 7600 XT / ROCm)

```bash
sudo apt update && sudo apt install -y wget unzip && \
rm -rf omv-tools-install && \
wget -O repo.zip https://github.com/NoobyDevelopper/omv-tools-install/archive/refs/heads/main.zip && \
unzip repo.zip && \
rm repo.zip && \
mv omv-tools-install-main omv-tools-install && \
cd omv-tools-install && \
chmod +x launcher.sh && \
sudo ./launcher.sh
```

---

⚠️ DISCLAIMER

* Script non officiel (homelab uniquement)
* Aucune garantie
* Utilisation à vos risques

👉 Toujours faire une sauvegarde avant exécution

---

🧩 OMV 8 – FONCTIONNALITÉS

---

🧱 SYSTÈME

* Update & upgrade automatique
* Nettoyage système
* Optimisation base OMV

---

🔥 GPU AUTO SETUP (ROCm 7.2.3)

AMD (RX 7600 XT / gfx1102)

* ROCm 7.2.3 installation (latest)
* Support gfx1102
* Activation /dev/kfd + /dev/dri

NVIDIA

* CUDA fallback auto

INTEL

* Mode CPU fallback

GROUPES GPU

* render
* video

---

🐳 DOCKER / COMPOSE

* openmediavault-compose
* Docker engine intégré
* Support stacks IA :

  * Whisper
  * Ollama
  * Home Assistant

---

🐍 PYTHON STACK

* python3-venv
* pip / setuptools / wheel
* numpy base

venv global :
~/onnx_env

---

🖥️ KVM

* openmediavault-kvm
* virtualisation locale

---

🌐 WAKE-ON-LAN

* détection interface automatique
* activation via ethtool
* démarrage réseau optimisé

---

🧠 VOICE AI STACK (INTÉGRÉ)

---

🎤 WHISPER ROCm (STT)

* transcription locale GPU AMD
* faible latence voix
* compatible Home Assistant (WYOMING)

🤖 OLLAMA ROCm (LLM)

* inference GPU AMD
* modèles ministral / llama
* optimisé RX 7600 XT

---

⚡ PERFORMANCE ESTIMÉE

WHISPER

* small : 300–600 ms
* medium : 600 ms – 1.2 s
* large-v3 : 1.5 – 3 s

OLLAMA

* 15–30 tokens/sec GPU
* 0.5 – 3 s réponse

---

🔐 SÉCURITÉ & STABILITÉ

* swap OFF (TBW SSD protection)
* tmpfs RAM cache
* isolation GPU containers
* ROCm 7.2.3 stable runtime

---

🧠 ARCHITECTURE GLOBALE

Micro → HAOS (Wake Word)
→ Whisper ROCm (OMV 8)
→ Ollama ROCm (OMV 8)
→ réponse vocale / action domotique

---

🚀 RÉSULTAT FINAL

* Assistant vocal local ultra réactif
* IA locale GPU AMD (RX 7600 XT)
* Domotique Home Assistant fluide
* OMV 8 homelab production stable

---
