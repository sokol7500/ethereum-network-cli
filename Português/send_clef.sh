# Cores principais
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
# Cores adicionais (256 cores)
BRIGHT_BLUE="\e[94m"
NC="\e[0m"
BRIGHT_YELLOW="\e[93m"
CYAN="\e[36m"
BRIGHT_BLUE="\e[94m"
# Tons dourados brilhantes
# Tons máximos brilhantes (todos 226-229 máximos)
GOLD_226='\033[38;5;226m'  # Amarelo brilhante puro
GOLD_227='\033[38;5;227m'  # Amarelo com tom
GOLD_228='\033[38;5;228m'  # Amarelo claro
GOLD_221='\033[38;5;221m'  # Dourado
GOLD_220='\033[38;5;220m'  # Dourado clássico
BRIGHT_GOLD='\033[38;5;226m'  # Amarelo/dourado mais brilhante
LIGHT_GREEN='\033[1;32m'        # Verde claro
PURPLE='\033[0;35m'             # Roxo
GOLD='\033[38;5;220m'           # Dourado verdadeiro
LIGHT_GOLD='\033[38;5;228m'     # Dourado claro
SOFT_GOLD='\033[38;5;223m'      # Dourado suave
PALE_GOLD='\033[38;5;230m'      # Dourado pálido
DARK_WHITE='\033[38;5;250m'     # Branco escuro (acinzentado)
LIGHT_ORANGE='\033[38;5;214m'   # Laranja claro
PINK='\033[38;5;205m'           # Rosa
PURPLE_LIGHT='\033[38;5;135m'   # Roxo claro
LIGHT_CYAN='\033[1;36m'      # Ciano claro

#!/bin/bash
# Definir locale inglês para números corretos
export LC_NUMERIC="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Configurações
FROM="0xdd91af12e4464e7412fd1084460f407e7f9b0fd1"
TO="0xa351d597540b27ed5327425d29d1526c17c3f026"
CLEF="http://localhost:8550"
RPC="https://1rpc.io/eth"

echo -e ${GREEN} "💸 Enviar ETH" ${NC}
echo "========================================"

# Função para limpar números
clean_number() {
    echo "$1" | tr -d ',' | sed 's/[^0-9.]//g'
}

# Função para formatar ETH como no site (SEMPRE 8 dígitos)
format_eth_fixed() {
    local num=$(clean_number "$1")
    if [ -z "$num" ] || [ "$num" = "0" ]; then
        echo "0.00000000"
    else
        # SEMPRE 8 dígitos após a vírgula
        LANG=C printf "%0.8f" "$num" 2>/dev/null
    fi
}

# Função para calcular comissão em ETH
calculate_fee() {
    local gas_gwei=$(clean_number "$1")
    if [[ ! "$gas_gwei" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$gas_gwei" ]; then
        echo "0"
        return
    fi

    # Cálculo preciso
    echo "scale=12; $gas_gwei * 21000 / 1000000000" | bc 2>/dev/null
}

# Função para obter preços precisos de gás do Etherscan (LÓGICA CORRIGIDA)
get_gas_prices() {
    # Obter página HTML do gastracker
    echo "🌐 Obtendo dados atualizados do Etherscan..." >&2
    local html=$(curl -s --max-time 10 "https://etherscan.io/gastracker" 2>/dev/null)

    if [ -z "$html" ]; then
        echo "❌ Não foi possível carregar a página" >&2
        echo "0.064 0.071 0.078"
        return 1
    fi

    local low_gas="" avg_gas="" high_gas=""

    # Método 1: Procurar todos os valores no formato "X.XXX gwei"
    local all_gwei_values=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+[[:space:]]*gwei' | head -10)

    echo "🔍 Valores Gwei encontrados: $all_gwei_values" >&2

    # Extrair números e classificar em ordem crescente
    local number_list=$(echo "$all_gwei_values" | grep -o '[0-9]\+\.[0-9]\+' | sort -n | uniq)

    # Converter em array
    local numbers=()
    while read -r num; do
        numbers+=("$num")
    done <<< "$number_list"

    local count=${#numbers[@]}

    echo "🔍 Encontrados $count valores únicos: ${numbers[*]}" >&2

    if [ $count -ge 3 ]; then
        # Se houver 3+ valores, pegamos o primeiro, médio e último
        low_gas="${numbers[0]}"

        # Valor mediano
        local mid_index=$(( (count - 1) / 2 ))
        avg_gas="${numbers[$mid_index]}"

        # Valor mais alto
        high_gas="${numbers[-1]}"

        echo "✅ Usando valores ordenados: Low=$low_gas, Mid=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 2 ]; then
        # Se houver 2 valores
        low_gas="${numbers[0]}"
        high_gas="${numbers[1]}"
        avg_gas=$(echo "scale=3; (${numbers[0]} + ${numbers[1]}) / 2" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 2 valores: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 1 ]; then
        # Se houver apenas 1 valor
        low_gas="${numbers[0]}"
        avg_gas="${numbers[0]}"
        high_gas=$(echo "scale=3; ${numbers[0]} * 1.1" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 1 valor: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    fi

    # Método 2: Procurar nos cartões específicos Low/Average/High
    if [ -z "$low_gas" ] || [ -z "$avg_gas" ] || [ -z "$high_gas" ]; then
        # Procurar blocos com cartões
        local card_section=$(echo "$html" | grep -o 'card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Low\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Average\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*High' -A 20 | head -200)

        if [ -n "$card_section" ]; then
            # Extrair preços dos cartões
            low_gas=$(echo "$card_section" | grep -A 10 'Low' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            avg_gas=$(echo "$card_section" | grep -A 10 'Average' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            high_gas=$(echo "$card_section" | grep -A 10 'High' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        fi
    fi

    # Limpar valores
    low_gas=$(clean_number "$low_gas")
    avg_gas=$(clean_number "$avg_gas")
    high_gas=$(clean_number "$high_gas")

    echo "🔍 Após análise: Low='$low_gas', Avg='$avg_gas', High='$high_gas'" >&2

    # Se valores não encontrados ou inválidos, usar valores padrão
    if [[ ! "$low_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$low_gas" ]; then
        low_gas="0.064"
        echo "⚠️  Low não encontrado, usando: $low_gas" >&2
    fi

    if [[ ! "$avg_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$avg_gas" ]; then
        avg_gas="0.071"
        echo "⚠️  Avg não encontrado, usando: $avg_gas" >&2
    fi

    if [[ ! "$high_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$high_gas" ]; then
        high_gas="0.078"
        echo "⚠️  High não encontrado, usando: $high_gas" >&2
    fi

    # GARANTIR QUE Low ≤ Avg ≤ High
    # Criar array e ordenar
    local sorted=($low_gas $avg_gas $high_gas)

    # Usar bc para comparação numérica
    local low_num=$(echo "$low_gas" | bc -l 2>/dev/null || echo "0")
    local avg_num=$(echo "$avg_gas" | bc -l 2>/dev/null || echo "0")
    local high_num=$(echo "$high_gas" | bc -l 2>/dev/null || echo "0")

    # Ordenar valores
    if [ $(echo "$low_num > $avg_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$low_gas"
        low_gas="$avg_gas"
        avg_gas="$temp"
        echo "🔄 Ordem corrigida: Low e Avg trocados" >&2
    fi

    if [ $(echo "$avg_num > $high_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$avg_gas"
        avg_gas="$high_gas"
        high_gas="$temp"
        echo "🔄 Ordem corrigida: Avg e High trocados" >&2
    fi

    # Garantir que high seja realmente maior que avg
    if [ $(echo "$high_gas <= $avg_gas" | bc -l 2>/dev/null) -eq 1 ]; then
        high_gas=$(echo "scale=3; $avg_gas * 1.1" | bc 2>/dev/null || echo "0.078")
        echo "🔄 High aumentado: $high_gas" >&2
    fi

    # Formatar para 3 dígitos
    low_gas=$(printf "%.3f" "$low_gas" 2>/dev/null || echo "$low_gas")
    avg_gas=$(printf "%.3f" "$avg_gas" 2>/dev/null || echo "$avg_gas")
    high_gas=$(printf "%.3f" "$high_gas" 2>/dev/null || echo "$high_gas")

    # Remover zeros extras
    low_gas=$(echo "$low_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.064/')
    avg_gas=$(echo "$avg_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.071/')
    high_gas=$(echo "$high_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.078/')

    echo "✅ Valores finais: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    echo "$low_gas $avg_gas $high_gas"
    return 0
}

# Função para selecionar comissão com auto-atualização
select_gas_price() {
    local choice=""
    local update_count=0
    local start_time=$(date '+%H:%M:%S')

    # Saída inicial do cabeçalho
    clear
    echo -e ${GREEN} "💸 Enviar ETH" ${NC}
    echo "========================================"
    echo "⛽ SELEÇÃO DE COMISSÃO "
    echo "========================================"
    echo -e "${BLUE} "🕒 Hora de início: $start_time"${NC}"
    echo -e "${CYAN}🌐 Fonte: Etherscan Gas Tracker${NC}"

    echo ""

    while true; do
        # Atualizar hora
        local current_time=$(date '+%H:%M:%S')

        # Obter preços
        local prices=$(get_gas_prices 2>/dev/null)
        local current_low=$(echo "$prices" | awk '{print $1}')
        local current_avg=$(echo "$prices" | awk '{print $2}')
        local current_high=$(echo "$prices" | awk '{print $3}')

        # Calcular comissões
        local current_low_fee=$(calculate_fee "$current_low")
        local current_avg_fee=$(calculate_fee "$current_avg")
        local current_high_fee=$(calculate_fee "$current_high")

        # Formatar COMO NO SITE (8 dígitos)
        local current_low_formatted=$(format_eth_fixed "$current_low_fee")
        local current_avg_formatted=$(format_eth_fixed "$current_avg_fee")
        local current_high_formatted=$(format_eth_fixed "$current_high_fee")

        # Mover cursor para cima 8 linhas
        tput cup 7 0

        # Limpar e atualizar linhas
        tput el
        echo -e "${DARK_WHITE}🕒 Hora atual: $current_time${NC}"
        tput el
        echo -e "${YELLOW}🔄 Atualizações: $((++update_count))${NC}"
        tput el
        echo ""
        tput el
        printf "${LIGHT_GREEN}   1. 🐢 Baixa       - %s Gwei ≈ %s ETH${NC}\n" "$current_low" "$current_low_formatted" 
        tput el
        printf "${GREEN}   2. 🚶 Média       - %s Gwei ≈ %s ETH${NC}\n" "$current_avg" "$current_avg_formatted"
        tput el
        printf "${RED}   3. 🏎  Alta        - %s Gwei ≈ %s ETH${NC}\n" "$current_high" "$current_high_formatted"
        tput el
        echo -e "${GOLD}   4. ✏  Inserir manualmente${NC}"
        tput el
        echo -e "${RED}   q. ❌ Sair${NC}"
        tput el

        # Aguardar entrada com timeout de 1 segundo
        if read -t 1 -n 1 choice 2>/dev/null; then
            echo ""
            case $choice in
                1)
                    GAS_PRICE_GWEI="$current_low"
                    GAS_FEE_ETH="$current_low_fee"
                    GAS_FEE_FORMATTED="$current_low_formatted"
                   echo -e "${LIGHT_GREEN}✅ Comissão Baixa selecionada:${NC} ${GOLD}$current_low Gwei${NC} ≈ ${CYAN}$current_low_formatted ETH${NC}"
                   break
                    ;;
                2)
                    GAS_PRICE_GWEI="$current_avg"
                    GAS_FEE_ETH="$current_avg_fee"
                    GAS_FEE_FORMATTED="$current_avg_formatted"
                    echo -e "${GREEN}✅ Comissão Média selecionada:${NC} ${GOLD}$current_avg Gwei${NC} ≈ ${CYAN}$current_avg_formatted ETH${NC}"  
                    break
                    ;;
                3)
                    GAS_PRICE_GWEI="$current_high"
                    GAS_FEE_ETH="$current_high_fee"
                    GAS_FEE_FORMATTED="$current_high_formatted"
                    echo -e "${RED}✅ Comissão Alta selecionada:${NC} ${GOLD}$current_high Gwei${NC} ≈ ${CYAN}$current_high_formatted ETH${NC}"
                    break
                    ;;
                4)
                    echo ""
                    echo "💡 Preços atuais:"
                    printf "   🐢 Baixa:      %s Gwei ≈ %s ETH\n" "$current_low" "$current_low_formatted"
                    printf "   🚶 Média:      %s Gwei ≈ %s ETH\n" "$current_avg" "$current_avg_formatted"
                    printf "   🏎  Alta:       %s Gwei ≈ %s ETH\n" "$current_high" "$current_high_formatted"
                    echo ""

                    while true; do
                        read -p "Digite o gas price em Gwei: " manual_gas
                        manual_gas=$(clean_number "$manual_gas")

                        if [[ "$manual_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            GAS_PRICE_GWEI="$manual_gas"
                            GAS_FEE_ETH=$(calculate_fee "$manual_gas")
                            GAS_FEE_FORMATTED=$(format_eth_fixed "$GAS_FEE_ETH")
                            echo "✅ Gas price definido: $manual_gas Gwei ≈ $GAS_FEE_FORMATTED ETH"
                            break 2
                        else
                            echo "❌ Formato inválido. Exemplo: 0.064 ou 1.50"
                        fi
                    done
                    ;;
                q)
                    echo "Saindo..."
                    exit 0
                    ;;
            esac
        fi
    done
}

# Função para selecionar valor de envio
select_amount() {
    local choice=""

    echo ""
    echo -e "${SOFT_GOLD}💰 SELEÇÃO DE VALOR DE ENVIO${NC}"
    echo "========================================"
    echo -e "${GREEN}Disponível:${NC} ${BRIGHT_GOLD}$MAX_SEND_ETH_FORMATTED${NC} ${PURPLE}ETH${NC}"
    echo -e "${RED}Comissão:${NC}   ${GOLD}$GAS_FEE_FORMATTED ETH${NC}" 
    echo -e "${YELLOW}Máximo:${NC}     ${LIGHT_GREEN}$MAX_SEND_ETH_FORMATTED ETH${NC}"

    echo ""
  while true; do
    echo -e "${CYAN}Escolha o valor:${NC}"
    echo -e "${LIGHT_GREEN}   1. 📤 Enviar valor total ${NC} ${GOLD}(máximo)${NC}"
    echo -e "${LIGHT_ORANGE}   2. ✏  Inserir valor manualmente${NC}"
    read -p "$(echo -e "${YELLOW}Sua escolha (1-2): ${NC}")" choice

    case $choice in
            1)
                SEND_WEI="$MAX_SEND_WEI"
                SEND_ETH="$MAX_SEND_ETH"
                SEND_ETH_FORMATTED="$MAX_SEND_ETH_FORMATTED"
                echo "✅ Envio de valor total selecionado: $SEND_ETH_FORMATTED ETH"
                break
                ;;
            2)
                while true; do
                    read -p "Digite o valor para enviar em ETH: " amount_eth
                    amount_eth=$(clean_number "$amount_eth")

                    if [[ ! "$amount_eth" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "❌ Formato inválido. Exemplo: 0.001 ou 0.5"
                        continue
                    fi

                    # Converter para Wei
                    local amount_wei=$(echo "$amount_eth * 1000000000000000000" | bc 2>/dev/null)

                    if [ -z "$amount_wei" ] || [ "$amount_wei" = "0" ]; then
                        echo "❌ Valor muito pequeno"
                        continue
                    fi

                    if [ $(echo "$amount_wei > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Fundos insuficientes!"
                        continue
                    fi

                    local total_needed=$(echo "$amount_wei + $GAS_FEE_WEI" | bc)
                    if [ $(echo "$total_needed > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Não será suficiente para a comissão!"
                        continue
                    fi

                    SEND_WEI="$amount_wei"
                    SEND_ETH="$amount_eth"
                    SEND_ETH_FORMATTED=$(format_eth_fixed "$amount_eth")
                    echo "✅ Valor definido: $SEND_ETH_FORMATTED ETH"
                    break
                done
                break
                ;;
            *)
                echo "❌ Escolha inválida"
                ;;
        esac
    done
}

# === SCRIPT PRINCIPAL ===

# 1. Obter saldo do remetente
echo "📊 Obtendo saldo..."
BALANCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$FROM\",\"latest\"],\"id\":1}")

if [ $? -ne 0 ] || [ -z "$BALANCE_RESP" ]; then
    echo "❌ Erro ao obter saldo"
    exit 1
fi

BALANCE_HEX=$(echo "$BALANCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BALANCE_HEX" ]; then
    echo "❌ Não foi possível obter saldo"
    exit 1
fi

# Conversão hex para decimal
BALANCE_WEI=$(echo "ibase=16; $(echo ${BALANCE_HEX#0x} | tr '[:lower:]' '[:upper:]')" | bc)
BALANCE_ETH=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
BALANCE_ETH_FORMATTED=$(format_eth_fixed "$BALANCE_ETH")

echo -e "${LIGHT_CYAN}✅ Saldo:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
# 2. Seleção de comissão com auto-atualização
select_gas_price

# 3. Converter Gwei para Wei
GAS_PRICE_WEI=$(echo "$GAS_PRICE_GWEI * 1000000000" | bc 2>/dev/null)
GAS_PRICE_WEI_INT=$(echo "scale=0; $GAS_PRICE_WEI / 1" | bc)
GAS_PRICE_HEX=$(printf "0x%x" "$GAS_PRICE_WEI_INT" 2>/dev/null)

GAS_LIMIT=21000
GAS_FEE_WEI=$(echo "$GAS_PRICE_WEI * $GAS_LIMIT" | bc 2>/dev/null)

echo ""
echo -e "${GAS}💰 Comissão da transação:${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}"

# 4. Calcular máximo para envio
MAX_SEND_WEI=$(echo "$BALANCE_WEI - $GAS_FEE_WEI" | bc)
MAX_SEND_ETH=$(echo "scale=18; $MAX_SEND_WEI / 1000000000000000000" | bc)
MAX_SEND_ETH_FORMATTED=$(format_eth_fixed "$MAX_SEND_ETH")

# Verificação via bc
if [ $(echo "$MAX_SEND_WEI <= 0" | bc) -eq 1 ]; then
    echo ""
    echo "❌ ERRO: Saldo muito pequeno até para pagar a comissão!"
    exit 1
fi

# 5. Seleção do valor de envio
select_amount

# Conversão para ETH
SEND_ETH=$(echo "scale=18; $SEND_WEI / 1000000000000000000" | bc)
SEND_WEI_INT=$(echo "scale=0; $SEND_WEI / 1" | bc)
SEND_HEX=$(printf "0x%x" "$SEND_WEI_INT")
echo -e "   ${LIGHT_CYAN}Saldo:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
echo -e "${YELLOW}📈 CÁLCULO:${NC}"
REMAINING_ETH=$(echo "$BALANCE_ETH - $SEND_ETH - $GAS_FEE_ETH" | bc)
REMAINING_FORMATTED=$(format_eth_fixed "$REMAINING_ETH")
echo -e "   ${LIGHT_GREEN}Envio:${NC}     ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Comissão:${NC}  ${GAS}$GAS_FEE_FORMATTED ETH${NC}"
echo -e "   ${PURPLE}Restante:${NC}  ${WHITE}$REMAINING_FORMATTED ETH${NC}"

# 6. Obter nonce
echo ""
echo -e "${CYAN}🔢 Obtendo nonce...${NC}"
NONCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$FROM\",\"pending\"],\"id\":1}")

NONCE_HEX=$(echo "$NONCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo -e "${WHITE}✅ Nonce:${NC} ${PURPLE}$NONCE_HEX${NC}"

# 7. Confirmação
echo ""
echo -e "${YELLOW}📋 CONFIRMAÇÃO:${NC}"
echo -e "   ${CYAN}De:${NC}    ${YELLOW}$FROM${NC}"
echo -e "   ${CYAN}Para:${NC}  ${MAGENTA}$TO${NC}"
echo -e "   ${LIGHT_GREEN}Enviando:${NC} ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Comissão:${NC} ${GAS}$GAS_FEE_FORMATTED ETH${NC} ${WHITE}(Gas:${NC} ${PURPLE}$GAS_PRICE_GWEI Gwei${NC}${WHITE})${NC}"
echo ""

read -p "$(echo -e "${YELLOW}Confirmar envio? (s/n): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Cancelado"
    exit 0
fi

# 8. Criar transação
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
echo -e "${BRIGHT_BLUE}📝 Enviando para Clef assinar...${NC}"

# 9. Assinar
SIGN_RESP=$(curl -s "$CLEF" \
  -H "Content-Type: application/json" \
  -d "$TX_JSON")

RAW_TX=$(echo "$SIGN_RESP" | grep -o '"raw":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RAW_TX" ]; then
    echo "❌ Erro de assinatura"
    echo "$SIGN_RESP" | jq .
    exit 1
fi

echo "✅ Transação assinada!"

# 10. Enviar
echo ""
echo -e "${CYAN}🚀 Enviando para a rede...${NC}"
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
    echo -e "${BRIGHT_GREEN}🎉 SUCESSO! Transação enviada!${NC}"
    echo -e "🔗 Hash: ${BRIGHT_YELLOW}$TX_HASH${NC}"
    echo -e "${CYAN}🌐 Explorador: ${BRIGHT_BLUE}https://etherscan.io/tx/$TX_HASH${NC}"

else
    echo "❌ Erro de envio:"
    echo "$RESULT" | jq .

    echo "$RAW_TX" > raw_tx_$(date +%s).txt
    echo "💾 Transação raw salva"
fi
