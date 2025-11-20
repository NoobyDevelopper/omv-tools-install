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
SCRIPT3="whisper-piper-home-assistant.sh"

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

# ==================== Vérification exécutable et conversion DOS->Unix ====================
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

# ==================== Exécution d'un script ====================
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

# ==================== Fonctions parties ====================
partie1() { run_script "$SCRIPT1"; }
partie2() { run_script "$SCRIPT2"; }
partie3() { run_script "$SCRIPT3"; }
partie1_2() { partie1; partie2; }
partie1_3() { partie1; partie3; }

# ==================== Menu ====================
echo -e "${YELLOW}#############################################${NC}"
echo -e "${YELLOW}# Choisir une option (défaut Partie 1 dans 10s) #${NC}"
echo -e "${YELLOW}#############################################${NC}"
echo "1) Partie 1  -> $SCRIPT1"
echo "2) Partie 2  -> $SCRIPT2"
echo "3) Partie 1+2 -> $SCRIPT1 + $SCRIPT2"
echo "4) Partie 1+3 -> $SCRIPT1 + $SCRIPT3"
echo "5) Partie 3  -> $SCRIPT3"
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

# Confirmation simple
read -p "Vous avez choisi l'option $CHOIX. Appuyez sur Entrée pour confirmer..." _

# ==================== Execution selon choix ====================
case $CHOIX in
    1) partie1 ;;
    2) partie2 ;;
    3) partie1_2 ;;
    4) partie1_3 ;;
    5) partie3 ;;
    *) echo -e "${RED}Option invalide, exécution Partie 1 par défaut${NC}"; partie1 ;;
esac

# ==================== Affichage checklist finale ====================
show_checklist
echo -e "${CYAN}Tous les scripts terminés! 👋${NC}"
