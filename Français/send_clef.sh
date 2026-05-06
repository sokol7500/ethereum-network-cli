# Couleurs principales
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
ORANGE='\033[0;33m'
LIGHT_GREEN='\033[1;32m'
DARK_BLUE='\033[0;34m'
GAS='\033[0;36m'
BROWN='\033[0;33m'
MAGENTA='\033[0;35m'
LIGHT_CYAN='\033[1;36m'
NC='\033[0m'
BRIGHT_GREEN="\e[92m"
# Couleurs supplémentaires (256 couleurs)
BRIGHT_BLUE="\e[94m"
NC="\e[0m"
BRIGHT_YELLOW="\e[93m"
CYAN="\e[36m"
BRIGHT_BLUE="\e[94m"
# Teintes dorées vives
# Teintes maximales vives (toutes 226-229 maximales)
GOLD_226='\033[38;5;226m'  # Jaune vif pur
GOLD_227='\033[38;5;227m'  # Jaune avec nuance
GOLD_228='\033[38;5;228m'  # Jaune clair
GOLD_221='\033[38;5;221m'  # Doré
GOLD_220='\033[38;5;220m'  # Or classique
BRIGHT_GOLD='\033[38;5;226m'  # Jaune/or le plus vif
LIGHT_GREEN='\033[1;32m'        # Vert clair
PURPLE='\033[0;35m'             # Violet
GOLD='\033[38;5;220m'           # Or véritable
LIGHT_GOLD='\033[38;5;228m'     # Or clair
SOFT_GOLD='\033[38;5;223m'      # Or doux
PALE_GOLD='\033[38;5;230m'      # Or pâle
DARK_WHITE='\033[38;5;250m'     # Blanc sombre (grisâtre)
LIGHT_ORANGE='\033[38;5;214m'   # Orange clair
PINK='\033[38;5;205m'           # Rose
PURPLE_LIGHT='\033[38;5;135m'   # Violet clair
LIGHT_CYAN='\033[1;36m'      # Cyan clair

#!/bin/bash
# Définir la locale anglaise pour des nombres corrects
export LC_NUMERIC="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Paramètres
FROM="0xA351D597540b27eD5327425D29d1526c17C3F026"
TO="0xdD91aF12e4464e7412Fd1084460f407e7f9b0fd1"
CLEF="http://localhost:8550"
RPC="https://1rpc.io/eth"

echo -e ${GREEN} "💸 Envoi d'ETH" ${NC}
echo "========================================"

# Fonction de nettoyage des nombres
clean_number() {
    echo "$1" | tr -d ',' | sed 's/[^0-9.]//g'
}

# Fonction de formatage ETH comme sur le site (TOUJOURS 8 décimales)
format_eth_fixed() {
    local num=$(clean_number "$1")
    if [ -z "$num" ] || [ "$num" = "0" ]; then
        echo "0.00000000"
    else
        # TOUJOURS 8 décimales
        LANG=C printf "%0.8f" "$num" 2>/dev/null
    fi
}

# Fonction de calcul des frais en ETH
calculate_fee() {
    local gas_gwei=$(clean_number "$1")
    if [[ ! "$gas_gwei" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$gas_gwei" ]; then
        echo "0"
        return
    fi

    # Calcul précis
    echo "scale=12; $gas_gwei * 21000 / 1000000000" | bc 2>/dev/null
}

# Fonction d'obtention des prix précis du gaz sur Etherscan (LOGIQUE CORRIGÉE)
get_gas_prices() {
    # Récupérer la page HTML du gastracker
    echo "🌐 Récupération des données actuelles d'Etherscan..." >&2
    local html=$(curl -s --max-time 10 "https://etherscan.io/gastracker" 2>/dev/null)

    if [ -z "$html" ]; then
        echo "❌ Échec du chargement de la page" >&2
        echo "0.064 0.071 0.078"
        return 1
    fi

    local low_gas="" avg_gas="" high_gas=""

    # Méthode 1 : Rechercher toutes les valeurs au format "X.XXX gwei"
    local all_gwei_values=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+[[:space:]]*gwei' | head -10)

    echo "🔍 Valeurs Gwei trouvées : $all_gwei_values" >&2

    # Extraire les nombres et trier par ordre croissant
    local number_list=$(echo "$all_gwei_values" | grep -o '[0-9]\+\.[0-9]\+' | sort -n | uniq)

    # Convertir en tableau
    local numbers=()
    while read -r num; do
        numbers+=("$num")
    done <<< "$number_list"

    local count=${#numbers[@]}

    echo "🔍 $count valeurs uniques trouvées : ${numbers[*]}" >&2

    if [ $count -ge 3 ]; then
        # S'il y a 3+ valeurs, prendre la première, la moyenne et la dernière
        low_gas="${numbers[0]}"

        # Valeur médiane
        local mid_index=$(( (count - 1) / 2 ))
        avg_gas="${numbers[$mid_index]}"

        # Valeur la plus élevée
        high_gas="${numbers[-1]}"

        echo "✅ Utilisation des valeurs triées : Low=$low_gas, Mid=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 2 ]; then
        # S'il y a 2 valeurs
        low_gas="${numbers[0]}"
        high_gas="${numbers[1]}"
        avg_gas=$(echo "scale=3; (${numbers[0]} + ${numbers[1]}) / 2" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 2 valeurs : Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 1 ]; then
        # S'il n'y a qu'une seule valeur
        low_gas="${numbers[0]}"
        avg_gas="${numbers[0]}"
        high_gas=$(echo "scale=3; ${numbers[0]} * 1.1" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 1 valeur : Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    fi

    # Méthode 2 : Rechercher dans les cartes spécifiques Low/Average/High
    if [ -z "$low_gas" ] || [ -z "$avg_gas" ] || [ -z "$high_gas" ]; then
        # Rechercher les blocs de cartes
        local card_section=$(echo "$html" | grep -o 'card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Low\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Average\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*High' -A 20 | head -200)

        if [ -n "$card_section" ]; then
            # Extraire les prix des cartes
            low_gas=$(echo "$card_section" | grep -A 10 'Low' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            avg_gas=$(echo "$card_section" | grep -A 10 'Average' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            high_gas=$(echo "$card_section" | grep -A 10 'High' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        fi
    fi

    # Nettoyer les valeurs
    low_gas=$(clean_number "$low_gas")
    avg_gas=$(clean_number "$avg_gas")
    high_gas=$(clean_number "$high_gas")

    echo "🔍 Après analyse : Low='$low_gas', Avg='$avg_gas', High='$high_gas'" >&2

    # Si les valeurs ne sont pas trouvées ou invalides, utiliser les valeurs par défaut
    if [[ ! "$low_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$low_gas" ]; then
        low_gas="0.064"
        echo "⚠️  Low non trouvé, utilisation de : $low_gas" >&2
    fi

    if [[ ! "$avg_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$avg_gas" ]; then
        avg_gas="0.071"
        echo "⚠️  Avg non trouvé, utilisation de : $avg_gas" >&2
    fi

    if [[ ! "$high_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$high_gas" ]; then
        high_gas="0.078"
        echo "⚠️  High non trouvé, utilisation de : $high_gas" >&2
    fi

    # GARANTIR QUE Low ≤ Avg ≤ High
    # Créer un tableau et trier
    local sorted=($low_gas $avg_gas $high_gas)

    # Utiliser bc pour la comparaison numérique
    local low_num=$(echo "$low_gas" | bc -l 2>/dev/null || echo "0")
    local avg_num=$(echo "$avg_gas" | bc -l 2>/dev/null || echo "0")
    local high_num=$(echo "$high_gas" | bc -l 2>/dev/null || echo "0")

    # Trier les valeurs
    if [ $(echo "$low_num > $avg_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$low_gas"
        low_gas="$avg_gas"
        avg_gas="$temp"
        echo "🔄 Ordre corrigé : Low et Avg échangés" >&2
    fi

    if [ $(echo "$avg_num > $high_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$avg_gas"
        avg_gas="$high_gas"
        high_gas="$temp"
        echo "🔄 Ordre corrigé : Avg et High échangés" >&2
    fi

    # S'assurer que high est vraiment plus grand que avg
    if [ $(echo "$high_gas <= $avg_gas" | bc -l 2>/dev/null) -eq 1 ]; then
        high_gas=$(echo "scale=3; $avg_gas * 1.1" | bc 2>/dev/null || echo "0.078")
        echo "🔄 High augmenté : $high_gas" >&2
    fi

    # Formater à 3 décimales
    low_gas=$(printf "%.3f" "$low_gas" 2>/dev/null || echo "$low_gas")
    avg_gas=$(printf "%.3f" "$avg_gas" 2>/dev/null || echo "$avg_gas")
    high_gas=$(printf "%.3f" "$high_gas" 2>/dev/null || echo "$high_gas")

    # Supprimer les zéros superflus
    low_gas=$(echo "$low_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.064/')
    avg_gas=$(echo "$avg_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.071/')
    high_gas=$(echo "$high_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.078/')

    echo "✅ Valeurs finales : Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    echo "$low_gas $avg_gas $high_gas"
    return 0
}

# Fonction de sélection des frais avec mise à jour automatique
select_gas_price() {
    local choice=""
    local update_count=0
    local start_time=$(date '+%H:%M:%S')

    # Affichage initial de l'en-tête
    clear
    echo -e ${GREEN} "💸 Envoi d'ETH" ${NC}
    echo "========================================"
    echo "⛽ SÉLECTION DES FRAIS "
    echo "========================================"
    echo -e "${BLUE} "🕒 Heure de début: $start_time"${NC}"
    echo -e "${CYAN}🌐 Source: Etherscan Gas Tracker${NC}"

    echo ""

    while true; do
        # Mettre à jour l'heure
        local current_time=$(date '+%H:%M:%S')

        # Obtenir les prix
        local prices=$(get_gas_prices 2>/dev/null)
        local current_low=$(echo "$prices" | awk '{print $1}')
        local current_avg=$(echo "$prices" | awk '{print $2}')
        local current_high=$(echo "$prices" | awk '{print $3}')

        # Calculer les frais
        local current_low_fee=$(calculate_fee "$current_low")
        local current_avg_fee=$(calculate_fee "$current_avg")
        local current_high_fee=$(calculate_fee "$current_high")

        # Formater COMME SUR LE SITE (8 décimales)
        local current_low_formatted=$(format_eth_fixed "$current_low_fee")
        local current_avg_formatted=$(format_eth_fixed "$current_avg_fee")
        local current_high_formatted=$(format_eth_fixed "$current_high_fee")

        # Déplacer le curseur de 8 lignes vers le haut
        tput cup 7 0

        # Effacer et mettre à jour les lignes
        tput el
        echo -e "${DARK_WHITE}🕒 Heure actuelle : $current_time${NC}"
        tput el
        echo -e "${YELLOW}🔄 Mises à jour : $((++update_count))${NC}"
        tput el
        echo ""
        tput el
        printf "${LIGHT_GREEN}   1. 🐢 Basse      - %s Gwei ≈ %s ETH${NC}\n" "$current_low" "$current_low_formatted" 
        tput el
        printf "${GREEN}   2. 🚶 Moyenne    - %s Gwei ≈ %s ETH${NC}\n" "$current_avg" "$current_avg_formatted"
        tput el
        printf "${RED}   3. 🏎  Haute      - %s Gwei ≈ %s ETH${NC}\n" "$current_high" "$current_high_formatted"
        tput el
        echo -e "${GOLD}   4. ✏  Saisie manuelle${NC}"
        tput el
        echo -e "${RED}   q. ❌ Quitter${NC}"
        tput el

        # Attendre la saisie avec un délai d'1 seconde
        if read -t 1 -n 1 choice 2>/dev/null; then
            echo ""
            case $choice in
                1)
                    GAS_PRICE_GWEI="$current_low"
                    GAS_FEE_ETH="$current_low_fee"
                    GAS_FEE_FORMATTED="$current_low_formatted"
                   echo -e "${LIGHT_GREEN}✅ Frais bas sélectionnés :${NC} ${GOLD}$current_low Gwei${NC} ≈ ${CYAN}$current_low_formatted ETH${NC}"
                   break
                    ;;
                2)
                    GAS_PRICE_GWEI="$current_avg"
                    GAS_FEE_ETH="$current_avg_fee"
                    GAS_FEE_FORMATTED="$current_avg_formatted"
                    echo -e "${GREEN}✅ Frais moyens sélectionnés:${NC} ${GOLD}$current_avg Gwei${NC} ≈ ${CYAN}$current_avg_formatted ETH${NC}"  
                    break
                    ;;
                3)
                    GAS_PRICE_GWEI="$current_high"
                    GAS_FEE_ETH="$current_high_fee"
                    GAS_FEE_FORMATTED="$current_high_formatted"
                    echo -e "${RED}✅ Frais élevés sélectionnés:${NC} ${GOLD}$current_high Gwei${NC} ≈ ${CYAN}$current_high_formatted ETH${NC}"
                    break
                    ;;
                4)
                    echo ""
                    echo "💡 Prix actuels :"
                    printf "   🐢 Basse :     %s Gwei ≈ %s ETH\n" "$current_low" "$current_low_formatted"
                    printf "   🚶 Moyenne :    %s Gwei ≈ %s ETH\n" "$current_avg" "$current_avg_formatted"
                    printf "   🏎  Haute :      %s Gwei ≈ %s ETH\n" "$current_high" "$current_high_formatted"
                    echo ""

                    while true; do
                        read -p "Entrez le gas price en Gwei : " manual_gas
                        manual_gas=$(clean_number "$manual_gas")

                        if [[ "$manual_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            GAS_PRICE_GWEI="$manual_gas"
                            GAS_FEE_ETH=$(calculate_fee "$manual_gas")
                            GAS_FEE_FORMATTED=$(format_eth_fixed "$GAS_FEE_ETH")
                            echo "✅ Gas price défini : $manual_gas Gwei ≈ $GAS_FEE_FORMATTED ETH"
                            break 2
                        else
                            echo "❌ Format incorrect. Exemple : 0.064 ou 1.50"
                        fi
                    done
                    ;;
                q)
                    echo "Sortie..."
                    exit 0
                    ;;
            esac
        fi
    done
}

# Fonction de sélection du montant à envoyer
select_amount() {
    local choice=""

    echo ""
    echo -e "${SOFT_GOLD}💰 SÉLECTION DU MONTANT${NC}"
    echo "========================================"
    echo -e "${GREEN}Disponible:${NC} ${BRIGHT_GOLD}$MAX_SEND_ETH_FORMATTED${NC} ${PURPLE}ETH${NC}"
    echo -e "${RED}Frais:     ${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}" 
    echo -e "${YELLOW}Maximum:   ${NC} ${LIGHT_GREEN}$MAX_SEND_ETH_FORMATTED ETH${NC}"

    echo ""
  while true; do
    echo -e "${CYAN}Choisissez le montant :${NC}"
    echo -e "${LIGHT_GREEN}   1. 📤 Envoyer le montant total ${NC} ${GOLD}(maximum)${NC}"
    echo -e "${LIGHT_ORANGE}   2. ✏  Saisie manuelle${NC}"
    read -p "$(echo -e "${YELLOW}Votre choix (1-2) : ${NC}")" choice

    case $choice in
            1)
                SEND_WEI="$MAX_SEND_WEI"
                SEND_ETH="$MAX_SEND_ETH"
                SEND_ETH_FORMATTED="$MAX_SEND_ETH_FORMATTED"
                echo "✅ Envoi du montant total sélectionné : $SEND_ETH_FORMATTED ETH"
                break
                ;;
            2)
                while true; do
                    read -p "Entrez le montant à envoyer en ETH : " amount_eth
                    amount_eth=$(clean_number "$amount_eth")

                    if [[ ! "$amount_eth" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "❌ Format incorrect. Exemple : 0.001 ou 0.5"
                        continue
                    fi

                    # Convertir en Wei
                    local amount_wei=$(echo "$amount_eth * 1000000000000000000" | bc 2>/dev/null)

                    if [ -z "$amount_wei" ] || [ "$amount_wei" = "0" ]; then
                        echo "❌ Montant trop petit"
                        continue
                    fi

                    if [ $(echo "$amount_wei > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Solde insuffisant !"
                        continue
                    fi

                    local total_needed=$(echo "$amount_wei + $GAS_FEE_WEI" | bc)
                    if [ $(echo "$total_needed > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Pas assez pour les frais !"
                        continue
                    fi

                    SEND_WEI="$amount_wei"
                    SEND_ETH="$amount_eth"
                    SEND_ETH_FORMATTED=$(format_eth_fixed "$amount_eth")
                    echo "✅ Montant défini : $SEND_ETH_FORMATTED ETH"
                    break
                done
                break
                ;;
            *)
                echo "❌ Choix invalide"
                ;;
        esac
    done
}

# === SCRIPT PRINCIPAL ===

# 1. Obtenir le solde de l'expéditeur
echo "📊 Récupération du solde..."
BALANCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$FROM\",\"latest\"],\"id\":1}")

if [ $? -ne 0 ] || [ -z "$BALANCE_RESP" ]; then
    echo "❌ Erreur lors de la récupération du solde"
    exit 1
fi

BALANCE_HEX=$(echo "$BALANCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BALANCE_HEX" ]; then
    echo "❌ Impossible de récupérer le solde"
    exit 1
fi

# Conversion hex en décimal
BALANCE_WEI=$(echo "ibase=16; $(echo ${BALANCE_HEX#0x} | tr '[:lower:]' '[:upper:]')" | bc)
BALANCE_ETH=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
BALANCE_ETH_FORMATTED=$(format_eth_fixed "$BALANCE_ETH")

echo -e "${LIGHT_CYAN}✅ Solde :${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
# 2. Sélection des frais avec mise à jour automatique
select_gas_price

# 3. Convertir Gwei en Wei
GAS_PRICE_WEI=$(echo "$GAS_PRICE_GWEI * 1000000000" | bc 2>/dev/null)
GAS_PRICE_WEI_INT=$(echo "scale=0; $GAS_PRICE_WEI / 1" | bc)
GAS_PRICE_HEX=$(printf "0x%x" "$GAS_PRICE_WEI_INT" 2>/dev/null)

GAS_LIMIT=21000
GAS_FEE_WEI=$(echo "$GAS_PRICE_WEI * $GAS_LIMIT" | bc 2>/dev/null)

echo ""
echo -e "${GAS}💰 Frais de transaction :${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}"

# 4. Calculer le maximum à envoyer
MAX_SEND_WEI=$(echo "$BALANCE_WEI - $GAS_FEE_WEI" | bc)
MAX_SEND_ETH=$(echo "scale=18; $MAX_SEND_WEI / 1000000000000000000" | bc)
MAX_SEND_ETH_FORMATTED=$(format_eth_fixed "$MAX_SEND_ETH")

# Vérification via bc
if [ $(echo "$MAX_SEND_WEI <= 0" | bc) -eq 1 ]; then
    echo ""
    echo "❌ ERREUR : Solde trop faible même pour payer les frais !"
    exit 1
fi

# 5. Sélection du montant à envoyer
select_amount

# Conversion en ETH
SEND_ETH=$(echo "scale=18; $SEND_WEI / 1000000000000000000" | bc)
SEND_WEI_INT=$(echo "scale=0; $SEND_WEI / 1" | bc)
SEND_HEX=$(printf "0x%x" "$SEND_WEI_INT")
echo -e "   ${LIGHT_CYAN}Solde:${NC}  ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
echo -e "${YELLOW}📈 CALCUL:${NC}"
REMAINING_ETH=$(echo "$BALANCE_ETH - $SEND_ETH - $GAS_FEE_ETH" | bc)
REMAINING_FORMATTED=$(format_eth_fixed "$REMAINING_ETH")
echo -e "   ${LIGHT_GREEN}Envoi:${NC}  ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Frais:${NC}  ${GAS}$GAS_FEE_FORMATTED ETH${NC}"
echo -e "   ${PURPLE}Reste:${NC}  ${WHITE}$REMAINING_FORMATTED ETH${NC}"

# 6. Obtenir le nonce
echo ""
echo -e "${CYAN}🔢 Récupération du nonce...${NC}"
NONCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$FROM\",\"pending\"],\"id\":1}")

NONCE_HEX=$(echo "$NONCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo -e "${WHITE}✅ Nonce :${NC} ${PURPLE}$NONCE_HEX${NC}"

# 7. Confirmation
echo ""
echo -e "${YELLOW}📋 CONFIRMATION :${NC}"
echo -e "   ${CYAN}De:${NC}  ${YELLOW}$FROM${NC}"
echo -e "   ${CYAN}À:${NC}   ${MAGENTA}$TO${NC}"
echo -e "   ${LIGHT_GREEN}Envoi:${NC} ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Frais:${NC} ${GAS}$GAS_FEE_FORMATTED ETH${NC} ${WHITE}(Gas :${NC} ${PURPLE}$GAS_PRICE_GWEI Gwei${NC}${WHITE})${NC}"
echo ""

read -p "$(echo -e "${YELLOW}Confirmer l'envoi ? (y/n) : ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Annulé"
    exit 0
fi

# 8. Créer la transaction
TX_JSON='{
  "jsonrpc": "2.0",
  "method": "account_signTransaction",
  "params": [{
    "from": "'$FROM'",
    "to": "'$TO'",
    "value": "'$SEND_HEX'",
    "gas": "0x5208",
    "gasPrice": "'$GAS_PRICE_HEX'",
    "nonce": "'$NONCE_HEX'",
    "chainId": "0x1"
  }],
  "id": 1
}'

echo ""
echo -e "${BRIGHT_BLUE}📝 Envoi à Clef pour signature...${NC}"

# 9. Signer
SIGN_RESP=$(curl -s "$CLEF" \
  -H "Content-Type: application/json" \
  -d "$TX_JSON")

RAW_TX=$(echo "$SIGN_RESP" | grep -o '"raw":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RAW_TX" ]; then
    echo "❌ Erreur de signature"
    echo "$SIGN_RESP" | jq .
    exit 1
fi

echo "✅ Transaction signée !"

# 10. Envoyer
echo ""
echo -e "${CYAN}🚀 Envoi vers le réseau...${NC}"
SEND_JSON='{
  "jsonrpc": "2.0",
  "method": "eth_sendRawTransaction",
  "params": ["'$RAW_TX'"],
  "id": 1
}'

RESULT=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "$SEND_JSON")

TX_HASH=$(echo "$RESULT" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TX_HASH" ]; then
    echo ""
    echo -e "${BRIGHT_GREEN}🎉 SUCCÈS! Transaction envoyée !${NC}"
    echo -e "🔗 Hash: ${BRIGHT_YELLOW}$TX_HASH${NC}"
    echo -e "${CYAN}🌐 Explorateur: ${BRIGHT_BLUE}https://etherscan.io/tx/$TX_HASH${NC}"

else
    echo "❌ Erreur d'envoi:"
    echo "$RESULT" | jq .

    echo "$RAW_TX" > raw_tx_$(date +%s).txt
    echo "💾 Transaction brute sauvegardée"
fi
