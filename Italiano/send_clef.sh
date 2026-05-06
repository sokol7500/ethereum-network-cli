# Colori principali
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
# Colori aggiuntivi (256 colori)
BRIGHT_BLUE="\e[94m"
NC="\e[0m"
BRIGHT_YELLOW="\e[93m"
CYAN="\e[36m"
BRIGHT_BLUE="\e[94m"
# Toni dorati brillanti
# Toni massimamente brillanti (tutti 226-229 massimali)
GOLD_226='\033[38;5;226m'  # Giallo brillante puro
GOLD_227='\033[38;5;227m'  # Giallo con sfumatura
GOLD_228='\033[38;5;228m'  # Giallo chiaro
GOLD_221='\033[38;5;221m'  # Dorato
GOLD_220='\033[38;5;220m'  # Oro classico
BRIGHT_GOLD='\033[38;5;226m'  # Giallo/oro più brillante
LIGHT_GREEN='\033[1;32m'        # Verde chiaro
PURPLE='\033[0;35m'             # Viola
GOLD='\033[38;5;220m'           # Oro autentico
LIGHT_GOLD='\033[38;5;228m'     # Oro chiaro
SOFT_GOLD='\033[38;5;223m'      # Oro morbido
PALE_GOLD='\033[38;5;230m'      # Oro pallido
DARK_WHITE='\033[38;5;250m'     # Bianco scuro (grigiastro)
LIGHT_ORANGE='\033[38;5;214m'   # Arancione chiaro
PINK='\033[38;5;205m'           # Rosa
PURPLE_LIGHT='\033[38;5;135m'   # Viola chiaro
LIGHT_CYAN='\033[1;36m'      # Ciano chiaro

#!/bin/bash
# Imposta la locale inglese per numeri corretti
export LC_NUMERIC="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Impostazioni
FROM="0xdD91aF12e4464e7412Fd1084460f407e7f9b0fd1"
TO="0xA351D597540b27eD5327425D29d1526c17C3F026"
CLEF="http://localhost:8550"
RPC="https://1rpc.io/eth"

echo -e ${GREEN} "💸 Invio ETH" ${NC}
echo "========================================"

# Funzione pulizia numeri
clean_number() {
    echo "$1" | tr -d ',' | sed 's/[^0-9.]//g'
}

# Funzione formattazione ETH come sul sito (SEMPRE 8 decimali)
format_eth_fixed() {
    local num=$(clean_number "$1")
    if [ -z "$num" ] || [ "$num" = "0" ]; then
        echo "0.00000000"
    else
        # SEMPRE 8 decimali
        LANG=C printf "%0.8f" "$num" 2>/dev/null
    fi
}

# Funzione calcolo commissione in ETH
calculate_fee() {
    local gas_gwei=$(clean_number "$1")
    if [[ ! "$gas_gwei" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$gas_gwei" ]; then
        echo "0"
        return
    fi

    # Calcolo preciso
    echo "scale=12; $gas_gwei * 21000 / 1000000000" | bc 2>/dev/null
}

# Funzione per ottenere prezzi gas precisi da Etherscan (LOGICA CORRETTA)
get_gas_prices() {
    # Ottieni pagina HTML gastracker
    echo "🌐 Ricevo dati aggiornati da Etherscan..." >&2
    local html=$(curl -s --max-time 10 "https://etherscan.io/gastracker" 2>/dev/null)

    if [ -z "$html" ]; then
        echo "❌ Impossibile caricare la pagina" >&2
        echo "0.064 0.071 0.078"
        return 1
    fi

    local low_gas="" avg_gas="" high_gas=""

    # Metodo 1: Cerchiamo tutti i valori nel formato "X.XXX gwei"
    local all_gwei_values=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+[[:space:]]*gwei' | head -10)

    echo "🔍 Valori Gwei trovati: $all_gwei_values" >&2

    # Estrai numeri e ordina crescenti
    local number_list=$(echo "$all_gwei_values" | grep -o '[0-9]\+\.[0-9]\+' | sort -n | uniq)

    # Converti in array
    local numbers=()
    while read -r num; do
        numbers+=("$num")
    done <<< "$number_list"

    local count=${#numbers[@]}

    echo "🔍 Trovati $count valori unici: ${numbers[*]}" >&2

    if [ $count -ge 3 ]; then
        # Se ci sono 3+ valori, prendiamo primo, medio e ultimo
        low_gas="${numbers[0]}"

        # Valore medio (mediana)
        local mid_index=$(( (count - 1) / 2 ))
        avg_gas="${numbers[$mid_index]}"

        # Valore più alto
        high_gas="${numbers[-1]}"

        echo "✅ Uso valori ordinati: Low=$low_gas, Mid=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 2 ]; then
        # Se ci sono 2 valori
        low_gas="${numbers[0]}"
        high_gas="${numbers[1]}"
        avg_gas=$(echo "scale=3; (${numbers[0]} + ${numbers[1]}) / 2" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 2 valori: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 1 ]; then
        # Se c'è solo 1 valore
        low_gas="${numbers[0]}"
        avg_gas="${numbers[0]}"
        high_gas=$(echo "scale=3; ${numbers[0]} * 1.1" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 1 valore: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    fi

    # Metodo 2: Cerchiamo nelle schede specifiche Low/Average/High
    if [ -z "$low_gas" ] || [ -z "$avg_gas" ] || [ -z "$high_gas" ]; then
        # Cerca blocchi con schede
        local card_section=$(echo "$html" | grep -o 'card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Low\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Average\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*High' -A 20 | head -200)

        if [ -n "$card_section" ]; then
            # Estrai prezzi dalle schede
            low_gas=$(echo "$card_section" | grep -A 10 'Low' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            avg_gas=$(echo "$card_section" | grep -A 10 'Average' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            high_gas=$(echo "$card_section" | grep -A 10 'High' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        fi
    fi

    # Pulisci valori
    low_gas=$(clean_number "$low_gas")
    avg_gas=$(clean_number "$avg_gas")
    high_gas=$(clean_number "$high_gas")

    echo "🔍 Dopo parsing: Low='$low_gas', Avg='$avg_gas', High='$high_gas'" >&2

    # Se valori non trovati o non validi, usa valori predefiniti
    if [[ ! "$low_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$low_gas" ]; then
        low_gas="0.064"
        echo "⚠️  Low non trovato, uso: $low_gas" >&2
    fi

    if [[ ! "$avg_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$avg_gas" ]; then
        avg_gas="0.071"
        echo "⚠️  Avg non trovato, uso: $avg_gas" >&2
    fi

    if [[ ! "$high_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$high_gas" ]; then
        high_gas="0.078"
        echo "⚠️  High non trovato, uso: $high_gas" >&2
    fi

    # GARANTIAMO CHE Low ≤ Avg ≤ High
    # Creiamo array e ordiniamo
    local sorted=($low_gas $avg_gas $high_gas)

    # Usiamo bc per confronto numerico
    local low_num=$(echo "$low_gas" | bc -l 2>/dev/null || echo "0")
    local avg_num=$(echo "$avg_gas" | bc -l 2>/dev/null || echo "0")
    local high_num=$(echo "$high_gas" | bc -l 2>/dev/null || echo "0")

    # Ordiniamo valori
    if [ $(echo "$low_num > $avg_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$low_gas"
        low_gas="$avg_gas"
        avg_gas="$temp"
        echo "🔄 Ordine corretto: Low e Avg scambiati" >&2
    fi

    if [ $(echo "$avg_num > $high_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$avg_gas"
        avg_gas="$high_gas"
        high_gas="$temp"
        echo "🔄 Ordine corretto: Avg e High scambiati" >&2
    fi

    # Assicuriamoci che high sia realmente maggiore di avg
    if [ $(echo "$high_gas <= $avg_gas" | bc -l 2>/dev/null) -eq 1 ]; then
        high_gas=$(echo "scale=3; $avg_gas * 1.1" | bc 2>/dev/null || echo "0.078")
        echo "🔄 High aumentato: $high_gas" >&2
    fi

    # Formatta a 3 decimali
    low_gas=$(printf "%.3f" "$low_gas" 2>/dev/null || echo "$low_gas")
    avg_gas=$(printf "%.3f" "$avg_gas" 2>/dev/null || echo "$avg_gas")
    high_gas=$(printf "%.3f" "$high_gas" 2>/dev/null || echo "$high_gas")

    # Rimuovi zeri superflui
    low_gas=$(echo "$low_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.064/')
    avg_gas=$(echo "$avg_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.071/')
    high_gas=$(echo "$high_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.078/')

    echo "✅ Valori finali: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    echo "$low_gas $avg_gas $high_gas"
    return 0
}

# Funzione selezione commissione con auto-aggiornamento
select_gas_price() {
    local choice=""
    local update_count=0
    local start_time=$(date '+%H:%M:%S')

    # Output iniziale intestazione
    clear
    echo -e ${GREEN} "💸 Invio ETH" ${NC}
    echo "========================================"
    echo "⛽ SELEZIONE COMMISSIONE "
    echo "========================================"
    echo -e "${BLUE} "🕒 Ora inizio: $start_time"${NC}"
    echo -e "${CYAN}🌐 Fonte: Etherscan Gas Tracker${NC}"

    echo ""

    while true; do
        # Aggiorna ora
        local current_time=$(date '+%H:%M:%S')

        # Ottieni prezzi
        local prices=$(get_gas_prices 2>/dev/null)
        local current_low=$(echo "$prices" | awk '{print $1}')
        local current_avg=$(echo "$prices" | awk '{print $2}')
        local current_high=$(echo "$prices" | awk '{print $3}')

        # Calcola commissioni
        local current_low_fee=$(calculate_fee "$current_low")
        local current_avg_fee=$(calculate_fee "$current_avg")
        local current_high_fee=$(calculate_fee "$current_high")

        # Formatta COME SUL SITO (8 decimali)
        local current_low_formatted=$(format_eth_fixed "$current_low_fee")
        local current_avg_formatted=$(format_eth_fixed "$current_avg_fee")
        local current_high_formatted=$(format_eth_fixed "$current_high_fee")

        # Sposta cursore su di 8 righe
        tput cup 7 0

        # Pulisci e aggiorna righe
        tput el
        echo -e "${DARK_WHITE}🕒 Ora attuale: $current_time${NC}"
        tput el
        echo -e "${YELLOW}🔄 Aggiornamenti: $((++update_count))${NC}"
        tput el
        echo ""
        tput el
        printf "${LIGHT_GREEN}   1. 🐢 Bassa       - %s Gwei ≈ %s ETH${NC}\n" "$current_low" "$current_low_formatted" 
        tput el
        printf "${GREEN}   2. 🚶 Media       - %s Gwei ≈ %s ETH${NC}\n" "$current_avg" "$current_avg_formatted"
        tput el
        printf "${RED}   3. 🏎  Alta        - %s Gwei ≈ %s ETH${NC}\n" "$current_high" "$current_high_formatted"
        tput el
        echo -e "${GOLD}   4. ✏  Inserisci manualmente${NC}"
        tput el
        echo -e "${RED}   q. ❌ Esci${NC}"
        tput el

        # Attendiamo input con timeout 1 secondo
        if read -t 1 -n 1 choice 2>/dev/null; then
            echo ""
            case $choice in
                1)
                    GAS_PRICE_GWEI="$current_low"
                    GAS_FEE_ETH="$current_low_fee"
                    GAS_FEE_FORMATTED="$current_low_formatted"
                   echo -e "${LIGHT_GREEN}✅ Commissione Bassa selezionata:${NC} ${GOLD}$current_low Gwei${NC} ≈ ${CYAN}$current_low_formatted ETH${NC}"
                   break
                    ;;
                2)
                    GAS_PRICE_GWEI="$current_avg"
                    GAS_FEE_ETH="$current_avg_fee"
                    GAS_FEE_FORMATTED="$current_avg_formatted"
                    echo -e "${GREEN}✅ Commissione Media selezionata:${NC} ${GOLD}$current_avg Gwei${NC} ≈ ${CYAN}$current_avg_formatted ETH${NC}"  
                    break
                    ;;
                3)
                    GAS_PRICE_GWEI="$current_high"
                    GAS_FEE_ETH="$current_high_fee"
                    GAS_FEE_FORMATTED="$current_high_formatted"
                    echo -e "${RED}✅ Commissione Alta selezionata:${NC} ${GOLD}$current_high Gwei${NC} ≈ ${CYAN}$current_high_formatted ETH${NC}"
                    break
                    ;;
                4)
                    echo ""
                    echo "💡 Prezzi attuali:"
                    printf "   🐢 Bassa:      %s Gwei ≈ %s ETH\n" "$current_low" "$current_low_formatted"
                    printf "   🚶 Media:      %s Gwei ≈ %s ETH\n" "$current_avg" "$current_avg_formatted"
                    printf "   🏎  Alta:       %s Gwei ≈ %s ETH\n" "$current_high" "$current_high_formatted"
                    echo ""

                    while true; do
                        read -p "Inserisci gas price in Gwei: " manual_gas
                        manual_gas=$(clean_number "$manual_gas")

                        if [[ "$manual_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            GAS_PRICE_GWEI="$manual_gas"
                            GAS_FEE_ETH=$(calculate_fee "$manual_gas")
                            GAS_FEE_FORMATTED=$(format_eth_fixed "$GAS_FEE_ETH")
                            echo "✅ Gas price impostato: $manual_gas Gwei ≈ $GAS_FEE_FORMATTED ETH"
                            break 2
                        else
                            echo "❌ Formato non valido. Esempio: 0.064 o 1.50"
                        fi
                    done
                    ;;
                q)
                    echo "Uscita..."
                    exit 0
                    ;;
            esac
        fi
    done
}

# Funzione selezione importo invio
select_amount() {
    local choice=""

    echo ""
    echo -e "${SOFT_GOLD}💰 SELEZIONE IMPORTO INVIO${NC}"
    echo "========================================"
    echo -e "${GREEN}Disponibile:${NC} ${BRIGHT_GOLD}$MAX_SEND_ETH_FORMATTED${NC} ${PURPLE}ETH${NC}"
    echo -e "${RED}Commissione:${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}" 
    echo -e "${YELLOW}Massimo:${NC}     ${LIGHT_GREEN}$MAX_SEND_ETH_FORMATTED ETH${NC}"

    echo ""
  while true; do
    echo -e "${CYAN}Scegli l'importo:${NC}"
    echo -e "${LIGHT_GREEN}   1. 📤 Invia importo totale ${NC} ${GOLD}(massimo)${NC}"
    echo -e "${LIGHT_ORANGE}   2. ✏  Inserisci importo manualmente${NC}"
    read -p "$(echo -e "${YELLOW}La tua scelta (1-2): ${NC}")" choice

    case $choice in
            1)
                SEND_WEI="$MAX_SEND_WEI"
                SEND_ETH="$MAX_SEND_ETH"
                SEND_ETH_FORMATTED="$MAX_SEND_ETH_FORMATTED"
                echo "✅ Invio importo totale selezionato: $SEND_ETH_FORMATTED ETH"
                break
                ;;
            2)
                while true; do
                    read -p "Inserisci importo da inviare in ETH: " amount_eth
                    amount_eth=$(clean_number "$amount_eth")

                    if [[ ! "$amount_eth" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "❌ Formato non valido. Esempio: 0.001 o 0.5"
                        continue
                    fi

                    # Converti in Wei
                    local amount_wei=$(echo "$amount_eth * 1000000000000000000" | bc 2>/dev/null)

                    if [ -z "$amount_wei" ] || [ "$amount_wei" = "0" ]; then
                        echo "❌ Importo troppo piccolo"
                        continue
                    fi

                    if [ $(echo "$amount_wei > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Fondi insufficienti!"
                        continue
                    fi

                    local total_needed=$(echo "$amount_wei + $GAS_FEE_WEI" | bc)
                    if [ $(echo "$total_needed > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Non abbastanza per la commissione!"
                        continue
                    fi

                    SEND_WEI="$amount_wei"
                    SEND_ETH="$amount_eth"
                    SEND_ETH_FORMATTED=$(format_eth_fixed "$amount_eth")
                    echo "✅ Importo impostato: $SEND_ETH_FORMATTED ETH"
                    break
                done
                break
                ;;
            *)
                echo "❌ Scelta non valida"
                ;;
        esac
    done
}

# === SCRIPT PRINCIPALE ===

# 1. Ottieni saldo mittente
echo "📊 Ottengo saldo..."
BALANCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$FROM\",\"latest\"],\"id\":1}")

if [ $? -ne 0 ] || [ -z "$BALANCE_RESP" ]; then
    echo "❌ Errore nel recupero del saldo"
    exit 1
fi

BALANCE_HEX=$(echo "$BALANCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BALANCE_HEX" ]; then
    echo "❌ Impossibile ottenere il saldo"
    exit 1
fi

# Conversione hex in decimale
BALANCE_WEI=$(echo "ibase=16; $(echo ${BALANCE_HEX#0x} | tr '[:lower:]' '[:upper:]')" | bc)
BALANCE_ETH=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
BALANCE_ETH_FORMATTED=$(format_eth_fixed "$BALANCE_ETH")

echo -e "${LIGHT_CYAN}✅ Saldo:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
# 2. Selezione commissione con auto-aggiornamento
select_gas_price

# 3. Converti Gwei in Wei
GAS_PRICE_WEI=$(echo "$GAS_PRICE_GWEI * 1000000000" | bc 2>/dev/null)
GAS_PRICE_WEI_INT=$(echo "scale=0; $GAS_PRICE_WEI / 1" | bc)
GAS_PRICE_HEX=$(printf "0x%x" "$GAS_PRICE_WEI_INT" 2>/dev/null)

GAS_LIMIT=21000
GAS_FEE_WEI=$(echo "$GAS_PRICE_WEI * $GAS_LIMIT" | bc 2>/dev/null)

echo ""
echo -e "${GAS}💰 Commissione transazione:${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}"

# 4. Calcola massimo inviabile
MAX_SEND_WEI=$(echo "$BALANCE_WEI - $GAS_FEE_WEI" | bc)
MAX_SEND_ETH=$(echo "scale=18; $MAX_SEND_WEI / 1000000000000000000" | bc)
MAX_SEND_ETH_FORMATTED=$(format_eth_fixed "$MAX_SEND_ETH")

# Verifica con bc
if [ $(echo "$MAX_SEND_WEI <= 0" | bc) -eq 1 ]; then
    echo ""
    echo "❌ ERRORE: Saldo troppo piccolo anche per pagare la commissione!"
    exit 1
fi

# 5. Selezione importo invio
select_amount

# Conversione in ETH
SEND_ETH=$(echo "scale=18; $SEND_WEI / 1000000000000000000" | bc)
SEND_WEI_INT=$(echo "scale=0; $SEND_WEI / 1" | bc)
SEND_HEX=$(printf "0x%x" "$SEND_WEI_INT")
echo -e "   ${LIGHT_CYAN}Saldo:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
echo -e "${YELLOW}📈 CALCOLO:${NC}"
REMAINING_ETH=$(echo "$BALANCE_ETH - $SEND_ETH - $GAS_FEE_ETH" | bc)
REMAINING_FORMATTED=$(format_eth_fixed "$REMAINING_ETH")
echo -e "   ${LIGHT_GREEN}Invio:${NC}        ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Commissione:${NC}  ${GAS}$GAS_FEE_FORMATTED ETH${NC}"
echo -e "   ${PURPLE}Resto:${NC}        ${WHITE}$REMAINING_FORMATTED ETH${NC}"

# 6. Ottieni nonce
echo ""
echo -e "${CYAN}🔢 Ottengo nonce...${NC}"
NONCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$FROM\",\"pending\"],\"id\":1}")

NONCE_HEX=$(echo "$NONCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo -e "${WHITE}✅ Nonce:${NC} ${PURPLE}$NONCE_HEX${NC}"

# 7. Conferma
echo ""
echo -e "${YELLOW}📋 CONFERMA:${NC}"
echo -e "   ${CYAN}Da:${NC}${YELLOW}$FROM${NC}"
echo -e "   ${CYAN}A:${NC} ${MAGENTA}$TO${NC}"
echo -e "   ${LIGHT_GREEN}Invio:${NC} ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Commissione:${NC} ${GAS}$GAS_FEE_FORMATTED ETH${NC} ${WHITE}(Gas:${NC} ${PURPLE}$GAS_PRICE_GWEI Gwei${NC}${WHITE})${NC}"
echo ""

read -p "$(echo -e "${YELLOW}Confermare l'invio? (y/n): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Annullato"
    exit 0
fi

# 8. Crea transazione
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
echo -e "${BRIGHT_BLUE}📝 Invio a Clef per la firma...${NC}"

# 9. Firma
SIGN_RESP=$(curl -s "$CLEF" \
  -H "Content-Type: application/json" \
  -d "$TX_JSON")

RAW_TX=$(echo "$SIGN_RESP" | grep -o '"raw":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RAW_TX" ]; then
    echo "❌ Errore di firma"
    echo "$SIGN_RESP" | jq .
    exit 1
fi

echo "✅ Transazione firmata!"

# 10. Invia
echo ""
echo -e "${CYAN}🚀 Invio alla rete...${NC}"
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
    echo -e "${BRIGHT_GREEN}🎉 SUCCESSO! Transazione inviata!${NC}"
    echo -e "🔗 Hash: ${BRIGHT_YELLOW}$TX_HASH${NC}"
    echo -e "${CYAN}🌐 Explorer: ${BRIGHT_BLUE}https://etherscan.io/tx/$TX_HASH${NC}"

else
    echo "❌ Errore invio:"
    echo "$RESULT" | jq .

    echo "$RAW_TX" > raw_tx_$(date +%s).txt
    echo "💾 Transazione raw salvata"
fi
