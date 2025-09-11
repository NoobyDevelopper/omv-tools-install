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
SCRIPT1="omv-config-base.sh"
SCRIPT2="docker-ollama-base.sh"

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

# ==================== Vérification exécutable ====================
check_exec() {
    local script=$1
    if [ ! -x "$script" ]; then
        echo -e "${YELLOW}Rendre $script exécutable...${NC}"
        chmod +x "$script"
    fi
}

# ==================== Exécution d'un script ====================
run_script() {
    local script=$1
    echo -e "${CYAN}=== Exécution de $script ===${NC}"
    check_exec "$script"
    if ./"$script"; then
        mark_done "$script"
        echo -e "${GREEN}$script terminé ✅${NC}\n"
    else
        mark_fail "$script"
        echo -e "${RED}$script échoué ❌${NC}\n"
    fi
}

# ==================== Fonctions parties ====================
partie1() { run_script "$SCRIPT1"; }
partie2() { run_script "$SCRIPT2"; }
partie1_2() { partie1; partie2; }

# ==================== Menu ====================
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
    read -t 1 -n 1 input || true
    if [[ -n "$input" ]]; then
        CHOIX=$input
        break
    fi
done
printf "\n"
CHOIX=${CHOIX:-1}

# ==================== Execution selon choix ====================
case $CHOIX in
    1) partie1 ;;
    2) partie2 ;;
    3) partie1_2 ;;
    *) echo -e "${RED}Option invalide, exécution Partie 1 par défaut${NC}"; partie1 ;;
esac

# ==================== Affichage checklist finale ====================
show_checklist
echo -e "${CYAN}Tous les scripts terminés! 👋${NC}"
