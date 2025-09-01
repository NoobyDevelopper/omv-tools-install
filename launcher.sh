#!/bin/bash
# launcher.sh - Menu stylé avec bordures et noms de scripts

# Couleurs
GREEN='\033[1;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Scripts à exécuter
SCRIPT1="omv-config-base.sh"
SCRIPT2="docker-ollama-base.sh"

# Vérifier et rendre exécutable
check_exec() {
    local script=$1
    if [ ! -x "$script" ]; then
        echo -e "${YELLOW}Rendre $script exécutable...${NC}"
        chmod +x "$script"
    fi
}

# Initialiser la barre fixe
init_progress_bar() {
    BAR_WIDTH=$(( $(tput cols) - 10 ))  # espace pour "[| ] 100%"
    echo -e "\n"  # espace avant barre
    PROGRESS_ROW=$(tput lines)
}

# Mettre à jour la barre
update_progress_bar() {
    local percent=$1
    local info="$2"
    local filled=$((BAR_WIDTH * percent / 100))
    local empty=$((BAR_WIDTH - filled))
    local bar=$(printf "%${filled}s" "" | tr ' ' '#')
    local space=$(printf "%${empty}s" "")
    # info au-dessus
    tput sc
    tput cup $((PROGRESS_ROW-2)) 0
    printf "%-$(tput cols)s" "$info"
    # barre fixe
    tput cup $((PROGRESS_ROW-1)) 0
    printf "[|${GREEN}%s${NC}%s] %3d%%" "$bar" "$space" "$percent"
    tput rc
}

# Exécuter script avec barre et info dynamique
run_script() {
    local script=$1
    echo -e "${CYAN}=== Exécution de $script ===${NC}"
    check_exec "$script"
    init_progress_bar
    ./"$script" &
    pid=$!

    percent=0
    while kill -0 $pid 2>/dev/null; do
        percent=$((percent + 2))
        [ $percent -gt 100 ] && percent=100
        update_progress_bar $percent "Traitement de $script en cours..."
        sleep 0.3
    done
    wait $pid
    update_progress_bar 100 "$script terminé ✅"
    echo -e "\n"
}

# Partie 1
partie1() { run_script "$SCRIPT1"; }

# Partie 2
partie2() { run_script "$SCRIPT2"; }

# Partie 1 + 2
partie1_2() {
    partie1
    partie2
}

# Menu avec bordures ######### et noms des scripts
echo -e "${YELLOW}#############################################${NC}"
echo -e "${YELLOW}# Choisir une option (défaut Partie 1 dans 10s) #${NC}"
echo -e "${YELLOW}#############################################${NC}"
echo "1) Partie 1  -> $SCRIPT1"
echo "2) Partie 2  -> $SCRIPT2"
echo "3) Partie 1+2 -> $SCRIPT1 + $SCRIPT2"
echo -e "${YELLOW}#############################################${NC}"

# Timer 10s pour choix par défaut
CHOIX=""
for i in {10..1}; do
    printf "\rSélection automatique dans %2d secondes..." "$i"
    read -t 1 -n 1 input
    if [ ! -z "$input" ]; then
        CHOIX=$input
        break
    fi
done
printf "\n"
CHOIX=${CHOIX:-1}

case $CHOIX in
    1) partie1 ;;
    2) partie2 ;;
    3) partie1_2 ;;
    *) echo -e "${RED}Option invalide${NC}" ;;
esac

echo -e "${CYAN}Script terminé! 👋${NC}"
