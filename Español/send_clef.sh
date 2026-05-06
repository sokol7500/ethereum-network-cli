# Colores principales
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
# Colores adicionales (256 colores)
BRIGHT_BLUE="\e[94m"
BRIGHT_YELLOW="\e[93m"
# Tonos dorados brillantes
# Tonos máximamente brillantes (todos 226-229 máximos)
GOLD_226='\033[38;5;226m'  # Amarillo puro brillante
GOLD_227='\033[38;5;227m'  # Amarillo con matiz
GOLD_228='\033[38;5;228m'  # Amarillo claro
GOLD_221='\033[38;5;221m'  # Dorado
GOLD_220='\033[38;5;220m'  # Dorado clásico
BRIGHT_GOLD='\033[38;5;226m'  # Amarillo/dorado más brillante
GOLD='\033[38;5;220m'           # Dorado real
LIGHT_GOLD='\033[38;5;228m'     # Dorado claro
SOFT_GOLD='\033[38;5;223m'      # Dorado suave
PALE_GOLD='\033[38;5;230m'      # Dorado pálido
DARK_WHITE='\033[38;5;250m'     # Blanco oscuro (grisáceo)
LIGHT_ORANGE='\033[38;5;214m'   # Naranja claro
PINK='\033[38;5;205m'           # Rosa
PURPLE_LIGHT='\033[38;5;135m'   # Púrpura claro
LIGHT_CYAN='\033[1;36m'         # Cian claro

#!/bin/bash
# Establecer locale inglés para números correctos
export LC_NUMERIC="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Configuración
FROM="0xA351D597540b27eD5327425D29d1526c17C3F026"
TO="0xdD91aF12e4464e7412Fd1084460f407e7f9b0fd1"
CLEF="http://localhost:8550"
RPC="https://1rpc.io/eth"

echo -e "${GREEN}💸 Enviando ETH${NC}"
echo "========================================"

# Función para limpiar números
clean_number() {
    echo "$1" | tr -d ',' | sed 's/[^0-9.]//g'
}

# Función para formatear ETH como en el sitio web (SIEMPRE 8 decimales)
format_eth_fixed() {
    local num=$(clean_number "$1")
    if [ -z "$num" ] || [ "$num" = "0" ]; then
        echo "0.00000000"
    else
        # SIEMPRE 8 decimales
        LANG=C printf "%0.8f" "$num" 2>/dev/null
    fi
}

# Función para calcular comisión en ETH
calculate_fee() {
    local gas_gwei=$(clean_number "$1")
    if [[ ! "$gas_gwei" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$gas_gwei" ]; then
        echo "0"
        return
    fi

    # Cálculo exacto
    echo "scale=12; $gas_gwei * 21000 / 1000000000" | bc 2>/dev/null
}

# Función para obtener precios precisos de gas de Etherscan (LÓGICA CORREGIDA)
get_gas_prices() {
    # Obtener página HTML de gastracker
    echo "🌐 Obteniendo datos actuales de Etherscan..." >&2
    local html=$(curl -s --max-time 10 "https://etherscan.io/gastracker" 2>/dev/null)

    if [ -z "$html" ]; then
        echo "❌ No se pudo cargar la página" >&2
        echo "0.064 0.071 0.078"
        return 1
    fi

    local low_gas="" avg_gas="" high_gas=""

    # Método 1: Buscar todos los valores en formato "X.XXX gwei"
    local all_gwei_values=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+[[:space:]]*gwei' | head -10)

    echo "🔍 Valores Gwei encontrados: $all_gwei_values" >&2

    # Extraer números y ordenar ascendente
    local number_list=$(echo "$all_gwei_values" | grep -o '[0-9]\+\.[0-9]\+' | sort -n | uniq)

    # Convertir a array
    local numbers=()
    while read -r num; do
        numbers+=("$num")
    done <<< "$number_list"

    local count=${#numbers[@]}

    echo "🔍 Encontrados $count valores únicos: ${numbers[*]}" >&2

    if [ $count -ge 3 ]; then
        # Si hay 3+ valores, tomar primero, medio y último
        low_gas="${numbers[0]}"

        # Valor medio (mediana)
        local mid_index=$(( (count - 1) / 2 ))
        avg_gas="${numbers[$mid_index]}"

        # Valor más alto
        high_gas="${numbers[-1]}"

        echo "✅ Usando valores ordenados: Low=$low_gas, Mid=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 2 ]; then
        # Si hay 2 valores
        low_gas="${numbers[0]}"
        high_gas="${numbers[1]}"
        avg_gas=$(echo "scale=3; (${numbers[0]} + ${numbers[1]}) / 2" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 2 valores: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 1 ]; then
        # Si solo hay 1 valor
        low_gas="${numbers[0]}"
        avg_gas="${numbers[0]}"
        high_gas=$(echo "scale=3; ${numbers[0]} * 1.1" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 1 valor: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    fi

    # Método 2: Buscar en tarjetas específicas Low/Average/High
    if [ -z "$low_gas" ] || [ -z "$avg_gas" ] || [ -z "$high_gas" ]; then
        # Buscar bloques con tarjetas
        local card_section=$(echo "$html" | grep -o 'card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Low\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Average\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*High' -A 20 | head -200)

        if [ -n "$card_section" ]; then
            # Extraer precios de las tarjetas
            low_gas=$(echo "$card_section" | grep -A 10 'Low' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            avg_gas=$(echo "$card_section" | grep -A 10 'Average' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            high_gas=$(echo "$card_section" | grep -A 10 'High' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        fi
    fi

    # Limpiar valores
    low_gas=$(clean_number "$low_gas")
    avg_gas=$(clean_number "$avg_gas")
    high_gas=$(clean_number "$high_gas")

    echo "🔍 Después del análisis: Low='$low_gas', Avg='$avg_gas', High='$high_gas'" >&2

    # Si los valores no se encuentran o no son válidos, usar valores predeterminados
    if [[ ! "$low_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$low_gas" ]; then
        low_gas="0.064"
        echo "⚠️  Low no encontrado, usando: $low_gas" >&2
    fi

    if [[ ! "$avg_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$avg_gas" ]; then
        avg_gas="0.071"
        echo "⚠️  Avg no encontrado, usando: $avg_gas" >&2
    fi

    if [[ ! "$high_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$high_gas" ]; then
        high_gas="0.078"
        echo "⚠️  High no encontrado, usando: $high_gas" >&2
    fi

    # GARANTIZAR QUE Low ≤ Avg ≤ High
    # Crear array y ordenar
    local sorted=($low_gas $avg_gas $high_gas)

    # Usar bc para comparación numérica
    local low_num=$(echo "$low_gas" | bc -l 2>/dev/null || echo "0")
    local avg_num=$(echo "$avg_gas" | bc -l 2>/dev/null || echo "0")
    local high_num=$(echo "$high_gas" | bc -l 2>/dev/null || echo "0")

    # Ordenar valores
    if [ $(echo "$low_num > $avg_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$low_gas"
        low_gas="$avg_gas"
        avg_gas="$temp"
        echo "🔄 Orden corregido: Low y Avg intercambiados" >&2
    fi

    if [ $(echo "$avg_num > $high_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$avg_gas"
        avg_gas="$high_gas"
        high_gas="$temp"
        echo "🔄 Orden corregido: Avg y High intercambiados" >&2
    fi

    # Asegurar que high sea realmente mayor que avg
    if [ $(echo "$high_gas <= $avg_gas" | bc -l 2>/dev/null) -eq 1 ]; then
        high_gas=$(echo "scale=3; $avg_gas * 1.1" | bc 2>/dev/null || echo "0.078")
        echo "🔄 High aumentado: $high_gas" >&2
    fi

    # Formatear a 3 decimales
    low_gas=$(printf "%.3f" "$low_gas" 2>/dev/null || echo "$low_gas")
    avg_gas=$(printf "%.3f" "$avg_gas" 2>/dev/null || echo "$avg_gas")
    high_gas=$(printf "%.3f" "$high_gas" 2>/dev/null || echo "$high_gas")

    # Eliminar ceros sobrantes
    low_gas=$(echo "$low_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.064/')
    avg_gas=$(echo "$avg_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.071/')
    high_gas=$(echo "$high_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.078/')

    echo "✅ Valores finales: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    echo "$low_gas $avg_gas $high_gas"
    return 0
}

# Función para seleccionar comisión con auto-actualización
select_gas_price() {
    local choice=""
    local update_count=0
    local start_time=$(date '+%H:%M:%S')

    # Visualización inicial del encabezado
    clear
    echo -e "${GREEN}💸 Enviando ETH${NC}"
    echo "========================================"
    echo -e "${YELLOW}⛽ SELECCIÓN DE COMISIÓN${NC}"
    echo "========================================"
    echo -e "${BLUE} 🕒 Hora de inicio: $start_time${NC}"
    echo -e "${CYAN}🌐 Fuente: Etherscan Gas Tracker${NC}"
    echo ""

    while true; do
        # Actualizar hora
        local current_time=$(date '+%H:%M:%S')

        # Obtener precios
        local prices=$(get_gas_prices 2>/dev/null)
        local current_low=$(echo "$prices" | awk '{print $1}')
        local current_avg=$(echo "$prices" | awk '{print $2}')
        local current_high=$(echo "$prices" | awk '{print $3}')

        # Calcular comisiones
        local current_low_fee=$(calculate_fee "$current_low")
        local current_avg_fee=$(calculate_fee "$current_avg")
        local current_high_fee=$(calculate_fee "$current_high")

        # Formatear COMO EN EL SITIO WEB (8 decimales)
        local current_low_formatted=$(format_eth_fixed "$current_low_fee")
        local current_avg_formatted=$(format_eth_fixed "$current_avg_fee")
        local current_high_formatted=$(format_eth_fixed "$current_high_fee")

        # Mover cursor hacia arriba 8 líneas
        tput cup 8 0

        # Limpiar y actualizar líneas
        tput el
        echo -e "${DARK_WHITE}🕒 Hora actual: $current_time${NC}"
        tput el
        echo -e "${YELLOW}🔄 Actualizaciones: $((++update_count))${NC}"
        tput el
        echo ""
        tput el
        printf "${LIGHT_GREEN}   1. 🐢 Baja        - %s Gwei ≈ %s ETH${NC}\n" "$current_low" "$current_low_formatted"
        tput el
        printf "${GREEN}   2. 🚶 Media       - %s Gwei ≈ %s ETH${NC}\n" "$current_avg" "$current_avg_formatted"
        tput el
        printf "${RED}   3. 🏎  Alta        - %s Gwei ≈ %s ETH${NC}\n" "$current_high" "$current_high_formatted"
        tput el
        echo -e "${GOLD}   4. ✏  Ingresar manualmente${NC}"
        tput el
        echo -e "${RED}   q. ❌ Salir${NC}"
        tput el

        # Esperar entrada con tiempo de espera de 1 segundo
        if read -t 1 -n 1 choice 2>/dev/null; then
            echo ""
            case $choice in
                1)
                    GAS_PRICE_GWEI="$current_low"
                    GAS_FEE_ETH="$current_low_fee"
                    GAS_FEE_FORMATTED="$current_low_formatted"
                    echo -e "${LIGHT_GREEN}✅ Comisión baja seleccionada:${NC} ${GOLD}$current_low Gwei${NC} ≈ ${CYAN}$current_low_formatted ETH${NC}"
                    break
                    ;;
                2)
                    GAS_PRICE_GWEI="$current_avg"
                    GAS_FEE_ETH="$current_avg_fee"
                    GAS_FEE_FORMATTED="$current_avg_formatted"
                    echo -e "${GREEN}✅ Comisión media seleccionada:${NC} ${GOLD}$current_avg Gwei${NC} ≈ ${CYAN}$current_avg_formatted ETH${NC}"  
                    break
                    ;;
                3)
                    GAS_PRICE_GWEI="$current_high"
                    GAS_FEE_ETH="$current_high_fee"
                    GAS_FEE_FORMATTED="$current_high_formatted"
                    echo -e "${RED}✅ Comisión alta seleccionada:${NC} ${GOLD}$current_high Gwei${NC} ≈ ${CYAN}$current_high_formatted ETH${NC}"
                    break
                    ;;
                4)
                    echo ""
                    echo "💡 Precios actuales:"
                    printf "   🐢 Baja:        %s Gwei ≈ %s ETH\n" "$current_low" "$current_low_formatted"
                    printf "   🚶 Media:       %s Gwei ≈ %s ETH\n" "$current_avg" "$current_avg_formatted"
                    printf "   🏎  Alta:        %s Gwei ≈ %s ETH\n" "$current_high" "$current_high_formatted"
                    echo ""

                    while true; do
                        read -p "Ingrese precio de gas en Gwei: " manual_gas
                        manual_gas=$(clean_number "$manual_gas")

                        if [[ "$manual_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            GAS_PRICE_GWEI="$manual_gas"
                            GAS_FEE_ETH=$(calculate_fee "$manual_gas")
                            GAS_FEE_FORMATTED=$(format_eth_fixed "$GAS_FEE_ETH")
                            echo "✅ Precio de gas establecido: $manual_gas Gwei ≈ $GAS_FEE_FORMATTED ETH"
                            break 2
                        else
                            echo "❌ Formato inválido. Ejemplo: 0.064 o 1.50"
                        fi
                    done
                    ;;
                q)
                    echo "Saliendo..."
                    exit 0
                    ;;
            esac
        fi
    done
}

# Función para seleccionar cantidad a enviar
select_amount() {
    local choice=""

    echo ""
    echo -e "${SOFT_GOLD}💰 SELECCIÓN DE CANTIDAD${NC}"
    echo "========================================"
    echo -e "${GREEN}Disponible:${NC}   ${BRIGHT_GOLD}$MAX_SEND_ETH_FORMATTED${NC} ${PURPLE}ETH${NC}"
    echo -e "${RED}Comisión:${NC}     ${GOLD}$GAS_FEE_FORMATTED ETH${NC}" 
    echo -e "${YELLOW}Máximo:${NC}       ${LIGHT_GREEN}$MAX_SEND_ETH_FORMATTED ETH${NC}"
    echo ""

    while true; do
        echo -e "${CYAN}Seleccione cantidad:${NC}"
        echo -e "${LIGHT_GREEN}   1. 📤 Enviar cantidad completa ${NC} ${GOLD}(máximo)${NC}"
        echo -e "${LIGHT_ORANGE}   2. ✏  Ingresar cantidad manualmente${NC}"
        read -p "$(echo -e "${YELLOW}Su elección (1-2): ${NC}")" choice

        case $choice in
            1)
                SEND_WEI="$MAX_SEND_WEI"
                SEND_ETH="$MAX_SEND_ETH"
                SEND_ETH_FORMATTED="$MAX_SEND_ETH_FORMATTED"
                echo "✅ Cantidad completa seleccionada: $SEND_ETH_FORMATTED ETH"
                break
                ;;
            2)
                while true; do
                    read -p "Ingrese cantidad a enviar en ETH: " amount_eth
                    amount_eth=$(clean_number "$amount_eth")

                    if [[ ! "$amount_eth" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "❌ Formato inválido. Ejemplo: 0.001 o 0.5"
                        continue
                    fi

                    # Convertir a Wei
                    local amount_wei=$(echo "$amount_eth * 1000000000000000000" | bc 2>/dev/null)

                    if [ -z "$amount_wei" ] || [ "$amount_wei" = "0" ]; then
                        echo "❌ Cantidad demasiado pequeña"
                        continue
                    fi

                    if [ $(echo "$amount_wei > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ ¡Fondos insuficientes!"
                        continue
                    fi

                    local total_needed=$(echo "$amount_wei + $GAS_FEE_WEI" | bc)
                    if [ $(echo "$total_needed > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ ¡No alcanza para la comisión!"
                        continue
                    fi

                    SEND_WEI="$amount_wei"
                    SEND_ETH="$amount_eth"
                    SEND_ETH_FORMATTED=$(format_eth_fixed "$amount_eth")
                    echo "✅ Cantidad establecida: $SEND_ETH_FORMATTED ETH"
                    break
                done
                break
                ;;
            *)
                echo "❌ Opción inválida"
                ;;
        esac
    done
}

# === SCRIPT PRINCIPAL ===

# 1. Obtener saldo del remitente
echo "📊 Obteniendo saldo..."
BALANCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$FROM\",\"latest\"],\"id\":1}")

if [ $? -ne 0 ] || [ -z "$BALANCE_RESP" ]; then
    echo "❌ Error al obtener saldo"
    exit 1
fi

BALANCE_HEX=$(echo "$BALANCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BALANCE_HEX" ]; then
    echo "❌ No se pudo obtener el saldo"
    exit 1
fi

# Convertir hex a decimal
BALANCE_WEI=$(echo "ibase=16; $(echo ${BALANCE_HEX#0x} | tr '[:lower:]' '[:upper:]')" | bc)
BALANCE_ETH=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
BALANCE_ETH_FORMATTED=$(format_eth_fixed "$BALANCE_ETH")

echo -e "${LIGHT_CYAN}✅ Saldo:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"

# 2. Selección de comisión con auto-actualización
select_gas_price

# 3. Convertir Gwei a Wei
GAS_PRICE_WEI=$(echo "$GAS_PRICE_GWEI * 1000000000" | bc 2>/dev/null)
GAS_PRICE_WEI_INT=$(echo "scale=0; $GAS_PRICE_WEI / 1" | bc)
GAS_PRICE_HEX=$(printf "0x%x" "$GAS_PRICE_WEI_INT" 2>/dev/null)

GAS_LIMIT=21000
GAS_FEE_WEI=$(echo "$GAS_PRICE_WEI * $GAS_LIMIT" | bc 2>/dev/null)

echo ""
echo -e "${GAS}💰 Comisión de transacción:${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}"

# 4. Calcular máximo para enviar
MAX_SEND_WEI=$(echo "$BALANCE_WEI - $GAS_FEE_WEI" | bc)
MAX_SEND_ETH=$(echo "scale=18; $MAX_SEND_WEI / 1000000000000000000" | bc)
MAX_SEND_ETH_FORMATTED=$(format_eth_fixed "$MAX_SEND_ETH")

# Verificar mediante bc
if [ $(echo "$MAX_SEND_WEI <= 0" | bc) -eq 1 ]; then
    echo ""
    echo "❌ ERROR: ¡Saldo demasiado pequeño incluso para pagar la comisión!"
    exit 1
fi

# 5. Seleccionar cantidad a enviar
select_amount

# Convertir a ETH
SEND_ETH=$(echo "scale=18; $SEND_WEI / 1000000000000000000" | bc)
SEND_WEI_INT=$(echo "scale=0; $SEND_WEI / 1" | bc)
SEND_HEX=$(printf "0x%x" "$SEND_WEI_INT")

echo -e "   ${LIGHT_CYAN}Saldo:${NC}       ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
echo -e "${YELLOW}📈 CÁLCULO:${NC}"
REMAINING_ETH=$(echo "$BALANCE_ETH - $SEND_ETH - $GAS_FEE_ETH" | bc)
REMAINING_FORMATTED=$(format_eth_fixed "$REMAINING_ETH")
echo -e "   ${LIGHT_GREEN}Enviando:${NC}    - ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Comisión:${NC}    - ${GAS}$GAS_FEE_FORMATTED ETH${NC}"
echo -e "   ${PURPLE}Restante:${NC}    = ${WHITE}$REMAINING_FORMATTED ETH${NC}"

# 6. Obtener nonce
echo ""
echo -e "${CYAN}🔢 Obteniendo nonce...${NC}"
NONCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$FROM\",\"pending\"],\"id\":1}")

NONCE_HEX=$(echo "$NONCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo -e "${WHITE}✅ Nonce:${NC} ${PURPLE}$NONCE_HEX${NC}"

# 7. Confirmación
echo ""
echo -e "${YELLOW}📋 CONFIRMACIÓN:${NC}"
echo -e "   ${CYAN}De:${NC}          ${YELLOW}$FROM${NC}"
echo -e "   ${CYAN}Para:${NC}        ${MAGENTA}$TO${NC}"
echo -e "   ${LIGHT_GREEN}Enviando:${NC}    ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Comisión:${NC}    ${GAS}$GAS_FEE_FORMATTED ETH${NC} ${WHITE}(Gas:${NC} ${PURPLE}$GAS_PRICE_GWEI Gwei${NC}${WHITE})${NC}"
echo ""

read -p "$(echo -e "${YELLOW}¿Confirmar envío? (s/n): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Cancelado"
    exit 0
fi

# 8. Crear transacción
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
echo -e "${BRIGHT_BLUE}📝 Enviando a Clef para firma...${NC}"

# 9. Firmar
SIGN_RESP=$(curl -s "$CLEF" \
  -H "Content-Type: application/json" \
  -d "$TX_JSON")

RAW_TX=$(echo "$SIGN_RESP" | grep -o '"raw":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RAW_TX" ]; then
    echo "❌ Error de firma"
    echo "$SIGN_RESP" | jq .
    exit 1
fi

echo "✅ ¡Transacción firmada!"

# 10. Enviar
echo ""
echo -e "${CYAN}🚀 Enviando a la red...${NC}"
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
    echo -e "${BRIGHT_GREEN}🎉 ¡ÉXITO! ¡Transacción enviada!${NC}"
    echo -e "🔗 Hash: ${BRIGHT_YELLOW}$TX_HASH${NC}"
    echo -e "${CYAN}🌐 Explorador: ${BRIGHT_BLUE}https://etherscan.io/tx/$TX_HASH${NC}"
else
    echo "❌ Error de envío:"
    echo "$RESULT" | jq .
    echo "$RAW_TX" > raw_tx_$(date +%s).txt
    echo "💾 Transacción raw guardada"
fi
