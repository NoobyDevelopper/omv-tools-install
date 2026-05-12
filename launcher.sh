#!/bin/bash
set -euo pipefail

clear

# ==================== Couleurs ====================
GREEN='\033[1;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ==================== Scripts ====================
SCRIPTS=(
    "omv-config-base.sh"
    "docker-ollama-base.sh"
    "ollama-whisper.sh"
)

# ==================== Checklist dynamique ====================
declare -A CHECKLIST
mark_done() { CHECKLIST["$1"]="✅"; }
mark_fail() { CHECKLIST["$1"]="❌"; }

show_checklist() {
    echo -e "\n${CYAN}==================== Checklist ====================${NC}"
    for task in "${!CHECKLIST[@]}"; do
        echo -e "${CHECKLIST[$task]} $task"
    done
    echo -e "${CYAN}==================================================${NC}\n"
}

# ==================== Installer dos2unix si nécessaire ====================
if ! command -v dos2unix >/dev/null 2>&1; then
    echo -e "${YELLOW}📦 dos2unix non trouvé, installation...${NC}"
    apt update
    apt install dos2unix -y
fi

# ==================== Vérification et exécution des scripts ====================
check_exec() {
    local script=$1
    if [ ! -f "$script" ]; then
        echo -e "${RED}Le script $script n'existe pas ❌${NC}"
        mark_fail "$script"
        return 1
    fi
    echo -e "${CYAN}🔄 Conversion DOS->Unix pour $script${NC}"
    dos2unix "$script"
    if [ ! -x "$script" ]; then
        echo -e "${YELLOW}Rendre $script exécutable...${NC}"
        chmod +x "$script"
    fi
}

run_script() {
    local script=$1
    check_exec "$script" || return
    echo -e "${CYAN}=== Exécution de $script ===${NC}"
    if ./"$script"; then
        mark_done "$script"
        echo -e "${GREEN}$script terminé ✅${NC}\n"
    else
        mark_fail "$script"
        echo -e "${RED}$script échoué ❌${NC}\n"
    fi
}

# ==================== Fonctions dynamiques par "partie" ====================
# Génère automatiquement les fonctions partieX
declare -A PARTIES

for i in "${!SCRIPTS[@]}"; do
    part_name=$((i+1))
    PARTIES[$part_name]="${SCRIPTS[i]}"
done

execute_partie() {
    local choix_list=("$@")
    for choix in "${choix_list[@]}"; do
        local script=${PARTIES[$choix]}
        [ -n "$script" ] && run_script "$script"
    done
}

# ==================== Menu ====================
echo -e "${YELLOW}#############################################${NC}"
echo -e "${YELLOW}# Choisir une option (défaut Partie 1 dans 20s) #${NC}"
echo -e "${YELLOW}#############################################${NC}"
echo "1) Partie 1  -> ${SCRIPTS[0]}"
echo "2) Partie 2  -> ${SCRIPTS[1]}"
echo "3) Partie 1+2 -> ${SCRIPTS[0]} + ${SCRIPTS[1]}"
echo "4) Partie 1+3 -> ${SCRIPTS[0]} + ${SCRIPTS[2]}"
echo "5) Partie 3  -> ${SCRIPTS[2]}"
echo -e "${YELLOW}#############################################${NC}"

# Timer 20s pour choix par défaut
CHOIX=""
for i in {20..1}; do
    printf "\rSélection automatique dans %2d secondes..." "$i"
    read -t 1 -n 1 input || true
    if [[ -n "$input" ]]; then
        CHOIX=$input
        break
    fi
done
printf "\n"
CHOIX=${CHOIX:-1}

read -p "Vous avez choisi l'option $CHOIX. Appuyez sur Entrée pour confirmer..." _

# ==================== Exécution selon choix ====================
case $CHOIX in
    1) execute_partie 1 ;;
    2) execute_partie 2 ;;
    3) execute_partie 1 2 ;;
    4) execute_partie 1 3 ;;
    5) execute_partie 3 ;;
    *) echo -e "${RED}Option invalide, exécution Partie 1 par défaut${NC}"; execute_partie 1 ;;
esac

# ==================== Affichage checklist finale ====================
show_checklist
echo -e "${CYAN}Tous les scripts terminés! 👋${NC}"
