#!/bin/bash
set -euo pipefail

: '
Script : launcher.sh
Titre  : Menu OMV + Docker avec résumé final
Objectif : Lancer les scripts omv-config-base.sh et docker-ollama-base.sh et afficher un résumé des tâches.
'

# Noms des scripts
SCRIPT1="./omv-config-base.sh"
SCRIPT2="./docker-ollama-base.sh"

# Vérification des scripts et chmod +x
for script in "$SCRIPT1" "$SCRIPT2"; do
    if [ ! -f "$script" ]; then
        echo "[ERROR] Le script $script est manquant !"
        exit 1
    fi
    chmod +x "$script"
done

echo "========================"
echo "   Choisissez une option"
echo "========================"
echo "1) Exécuter Partie 1 : OMV-Config-Base"
echo "2) Exécuter Partie 2 : Docker-Ollama-Base"
echo "3) Exécuter Partie 1 + Partie 2"
echo ""

read -t 10 -rp "Votre choix (défaut 1) : " choice || choice=1

# Fonctions pour lancer les scripts et capturer le résumé
run_script() {
    local script="$1"
    local name="$2"
    echo "===== Lancement $name ====="
    
    # Exécution dans un sous-shell pour capturer la sortie
    OUTPUT=$("$script" 2>&1)
    echo "$OUTPUT"
    
    # Extraction des lignes de résumé si le script en contient un
    if echo "$OUTPUT" | grep -q "==================== Résumé"; then
        echo "===== Résumé $name ====="
        echo "$OUTPUT" | awk '/==================== Résumé/,/====================================================================/'
        echo "=============================="
    fi
}

case "$choice" in
    1)
        run_script "$SCRIPT1" "OMV-Config-Base"
        ;;
    2)
        run_script "$SCRIPT2" "Docker-Ollama-Base"
        ;;
    3)
        run_script "$SCRIPT1" "OMV-Config-Base"
        run_script "$SCRIPT2" "Docker-Ollama-Base"
        ;;
    *)
        echo "[WARN] Choix invalide, exécution Partie 1 par défaut"
        run_script "$SCRIPT1" "OMV-Config-Base"
        ;;
esac

echo "==================== Fin du script ===================="

