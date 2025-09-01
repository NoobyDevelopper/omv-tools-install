#!/bin/bash
set -euo pipefail

echo "========================"
echo "   Choisissez une option"
echo "========================"
echo "1) Exécuter Partie 1 : OMV-Config-Base"
echo "2) Exécuter Partie 2 : Docker-Ollama-Base"
echo "3) Exécuter Partie 1 + Partie 2"
echo ""

read -t 10 -rp "Votre choix (défaut 1) : " choice || choice=1

case "$choice" in
    1) bash ./partie1.sh ;;
    2) bash ./partie2.sh ;;
    3) bash ./partie1.sh && bash ./partie2.sh ;;
    *) echo "[WARN] Choix invalide, exécution Partie 1 par défaut"; bash ./partie1.sh ;;
esac

echo "==================== Fin du script ===================="
