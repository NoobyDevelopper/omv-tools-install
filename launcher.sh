#!/bin/bash
set -euo pipefail

# ========================================
# Script : launcher.sh
# Titre  : Menu OMV + Docker avec résumé final
# ========================================

SCRIPT1="./omv-config-base.sh"
SCRIPT2="./docker-ollama-base.sh"

# Vérification des scripts
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

# Lecture avec timeout de 10s et valeur par défaut
choice=1
if ! read -t 10 -rp "Votre choix (défaut 1) : " choice_input; then
    echo "[INFO] Timeout atteint. Valeur par défaut choisie : 1"
else
    # Si l'utilisateur tape quelque chose, on l'utilise
    [[ -n "$choice_input" ]] && choice="$choice_input"
fi

# Fonction pour lancer un script et afficher le résumé
run_script() {
    local script="$1"
    local name="$2"
    echo "===== Lancement $name ====="

    # Exécution du script dans un sous-shell en temps réel (streaming)
    # Pour éviter le blocage et capturer la sortie ligne par ligne
    while IFS= read -r line; do
        echo "$line"
    done < <("$script" 2>&1)

    # Extraction du résumé si présent
    if "$script" --help >/dev/null 2>&1; then
        OUTPUT=$("$script" 2>&1 || true)
        if echo "$OUTPUT" | grep -q "==================== Résumé"; then
            echo "===== Résumé $name ====="
            echo "$OUTPUT" | awk '/==================== Résumé/,/====================================================================/'
            echo "=============================="
        fi
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
