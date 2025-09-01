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

# Menu
echo "========================"
echo "   Choisissez une option"
echo "========================"
echo "1) Exécuter Partie 1 : OMV-Config-Base"
echo "2) Exécuter Partie 2 : Docker-Ollama-Base"
echo "3) Exécuter Partie 1 + Partie 2"
echo ""

TIMEOUT=10
choice=""

# Spinner pendant le choix utilisateur
spinner() {
    local i=0
    local chars="/-\|"
    while true; do
        printf "\r%s %2ds " "${chars:i++%${#chars}:1}" "$TIMEOUT"
        sleep 0.2
    done
}

spinner &
SPINNER_PID=$!

# Lire l'entrée utilisateur avec timeout
read -t $TIMEOUT -rp "Votre choix (défaut 1) : " choice_input
STATUS=$?

# Arrêter le spinner
kill "$SPINNER_PID" 2>/dev/null
wait "$SPINNER_PID" 2>/dev/null || true
echo ""

# Déterminer le choix final
if [ $STATUS -eq 0 ] && [ -n "$choice_input" ]; then
    choice="$choice_input"
else
    choice=1
    echo "[INFO] Timeout ou entrée vide. Valeur par défaut choisie : 1"
fi

# Fonction pour lancer un script avec barre de progression en fonction du nombre de lignes
run_script() {
    local script="$1"
    local name="$2"
    echo "===== Lancement $name ====="

    local width=40
    # Capture la sortie du script ligne par ligne
    local lines=0
    local total_lines=50  # Ajustable selon le script pour rendre la barre réaliste
    "$script" 2>&1 | while IFS= read -r line; do
        echo "$line"
        ((lines++))
        # Calcule pourcentage
        local percent=$(( lines * 100 / total_lines ))
        [ $percent -gt 100 ] && percent=100
        # Affiche la barre
        local done_width=$(( width * percent / 100 ))
        printf "\r[%-${width}s] %3d%%" "$(printf '#%.0s' $(seq 1 $done_width))" "$percent"
    done
    echo ""

    # Extraction du résumé si présent
    OUTPUT=$("$script" 2>&1 || true)
    if echo "$OUTPUT" | grep -q "==================== Résumé"; then
        echo "===== Résumé $name ====="
        echo "$OUTPUT" | awk '/==================== Résumé/,/====================================================================/'
        echo "=============================="
    fi
}

# Exécution selon choix
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
