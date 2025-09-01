#!/bin/bash
set -euo pipefail

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

choice=1
TIMEOUT=10
echo -n "Votre choix (défaut 1) dans $TIMEOUT secondes : "

# Lire l'entrée utilisateur en arrière-plan
read_choice=""
(
    read -r read_choice
) &
READ_PID=$!

# Spinner avec compte à rebours
spinner="/-\|"
i=0
for ((sec=TIMEOUT; sec>0; sec--)); do
    if ! kill -0 "$READ_PID" 2>/dev/null; then
        break
    fi
    printf "\r%s %2ds " "${spinner:i++%${#spinner}:1}" "$sec"
    sleep 0.2
done
echo ""

# Si timeout atteint, tuer le read
if kill -0 "$READ_PID" 2>/dev/null; then
    kill "$READ_PID" 2>/dev/null
    echo "[INFO] Timeout atteint. Valeur par défaut choisie : 1"
else
    [[ -n "$read_choice" ]] && choice="$read_choice"
fi

# Fonction pour lancer un script et afficher le résumé
run_script() {
    local script="$1"
    local name="$2"
    echo "===== Lancement $name ====="

    # Exécution en temps réel
    while IFS= read -r line; do
        echo "$line"
    done < <("$script" 2>&1)

    # Extraction du résumé si présent
    OUTPUT=$("$script" 2>&1 || true)
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
