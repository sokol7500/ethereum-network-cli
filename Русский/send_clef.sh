# Основные цвета
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
# Дополнительные цвета (256 цветов)
BRIGHT_BLUE="\e[94m"
NC="\e[0m"
BRIGHT_YELLOW="\e[93m"
CYAN="\e[36m"
BRIGHT_BLUE="\e[94m"
# Яркие золотые оттенки
# Максимально яркие оттенки (все 226-229 максимальные)
GOLD_226='\033[38;5;226m'  # Чистый ярко-желтый
GOLD_227='\033[38;5;227m'  # Желтый с оттенком
GOLD_228='\033[38;5;228m'  # Светло-желтый
GOLD_221='\033[38;5;221m'  # Золотистый
GOLD_220='\033[38;5;220m'  # Классический золотой
BRIGHT_GOLD='\033[38;5;226m'  # Самый яркий желтый/золотой
LIGHT_GREEN='\033[1;32m'        # Светло-зеленый
PURPLE='\033[0;35m'             # Фиолетовый
GOLD='\033[38;5;220m'           # Настоящий золотой
LIGHT_GOLD='\033[38;5;228m'     # Светлое золото
SOFT_GOLD='\033[38;5;223m'      # Мягкое золото
PALE_GOLD='\033[38;5;230m'      # Бледное золото
DARK_WHITE='\033[38;5;250m'     # Темно-белый (сероватый)
LIGHT_ORANGE='\033[38;5;214m'   # Светло-оранжевый
PINK='\033[38;5;205m'           # Розовый
PURPLE_LIGHT='\033[38;5;135m'   # Светло-фиолетовый
LIGHT_CYAN='\033[1;36m'      # Светло-голубой

#!/bin/bash
# Устанавливаем английскую локаль для корректных чисел
export LC_NUMERIC="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Настройки
FROM="0xA351D597540b27eD5327425D29d1526c17C3F026"
TO="0xdD91aF12e4464e7412Fd1084460f407e7f9b0fd1"
CLEF="http://localhost:8550"
RPC="https://1rpc.io/eth"

echo -e ${GREEN} "💸 Отправка ETH" ${NC}
echo "========================================"

# Функция очистки чисел
clean_number() {
    echo "$1" | tr -d ',' | sed 's/[^0-9.]//g'
}

# Функция форматирования ETH как на сайте (ВСЕГДА 8 знаков)
format_eth_fixed() {
    local num=$(clean_number "$1")
    if [ -z "$num" ] || [ "$num" = "0" ]; then
        echo "0.00000000"
    else
        # ВСЕГДА 8 знаков после запятой
        LANG=C printf "%0.8f" "$num" 2>/dev/null
    fi
}

# Функция расчета комиссии в ETH
calculate_fee() {
    local gas_gwei=$(clean_number "$1")
    if [[ ! "$gas_gwei" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$gas_gwei" ]; then
        echo "0"
        return
    fi

    # Точный расчет
    echo "scale=12; $gas_gwei * 21000 / 1000000000" | bc 2>/dev/null
}

# Функция получения точных цен газа с Etherscan (ИСПРАВЛЕННАЯ ЛОГИКА)
get_gas_prices() {
    # Получаем HTML страницу gastracker
    echo "🌐 Получаю актуальные данные с Etherscan..." >&2
    local html=$(curl -s --max-time 10 "https://etherscan.io/gastracker" 2>/dev/null)

    if [ -z "$html" ]; then
        echo "❌ Не удалось загрузить страницу" >&2
        echo "0.064 0.071 0.078"
        return 1
    fi

    local low_gas="" avg_gas="" high_gas=""

    # Метод 1: Ищем все значения в формате "X.XXX gwei"
    local all_gwei_values=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+[[:space:]]*gwei' | head -10)

    echo "🔍 Найдены значения Gwei: $all_gwei_values" >&2

    # Извлекаем числа и сортируем по возрастанию
    local number_list=$(echo "$all_gwei_values" | grep -o '[0-9]\+\.[0-9]\+' | sort -n | uniq)

    # Преобразуем в массив
    local numbers=()
    while read -r num; do
        numbers+=("$num")
    done <<< "$number_list"

    local count=${#numbers[@]}

    echo "🔍 Найдено $count уникальных значений: ${numbers[*]}" >&2

    if [ $count -ge 3 ]; then
        # Если есть 3+ значений, берем первое, среднее и последнее
        low_gas="${numbers[0]}"

        # Среднее значение (медиана)
        local mid_index=$(( (count - 1) / 2 ))
        avg_gas="${numbers[$mid_index]}"

        # Самое высокое значение
        high_gas="${numbers[-1]}"

        echo "✅ Использую отсортированные значения: Low=$low_gas, Mid=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 2 ]; then
        # Если 2 значения
        low_gas="${numbers[0]}"
        high_gas="${numbers[1]}"
        avg_gas=$(echo "scale=3; (${numbers[0]} + ${numbers[1]}) / 2" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 2 значения: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 1 ]; then
        # Если только 1 значение
        low_gas="${numbers[0]}"
        avg_gas="${numbers[0]}"
        high_gas=$(echo "scale=3; ${numbers[0]} * 1.1" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 1 значение: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    fi

    # Метод 2: Ищем в конкретных карточках Low/Average/High
    if [ -z "$low_gas" ] || [ -z "$avg_gas" ] || [ -z "$high_gas" ]; then
        # Ищем блоки с карточками
        local card_section=$(echo "$html" | grep -o 'card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Low\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Average\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*High' -A 20 | head -200)

        if [ -n "$card_section" ]; then
            # Извлекаем цены из карточек
            low_gas=$(echo "$card_section" | grep -A 10 'Low' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            avg_gas=$(echo "$card_section" | grep -A 10 'Average' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            high_gas=$(echo "$card_section" | grep -A 10 'High' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        fi
    fi

    # Очищаем значения
    low_gas=$(clean_number "$low_gas")
    avg_gas=$(clean_number "$avg_gas")
    high_gas=$(clean_number "$high_gas")

    echo "🔍 После парсинга: Low='$low_gas', Avg='$avg_gas', High='$high_gas'" >&2

    # Если значения не найдены или невалидные, используем значения по умолчанию
    if [[ ! "$low_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$low_gas" ]; then
        low_gas="0.064"
        echo "⚠️  Low не найден, использую: $low_gas" >&2
    fi

    if [[ ! "$avg_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$avg_gas" ]; then
        avg_gas="0.071"
        echo "⚠️  Avg не найден, использую: $avg_gas" >&2
    fi

    if [[ ! "$high_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$high_gas" ]; then
        high_gas="0.078"
        echo "⚠️  High не найден, использую: $high_gas" >&2
    fi

    # ГАРАНТИРУЕМ ЧТО Low ≤ Avg ≤ High
    # Создаем массив и сортируем
    local sorted=($low_gas $avg_gas $high_gas)

    # Используем bc для численного сравнения
    local low_num=$(echo "$low_gas" | bc -l 2>/dev/null || echo "0")
    local avg_num=$(echo "$avg_gas" | bc -l 2>/dev/null || echo "0")
    local high_num=$(echo "$high_gas" | bc -l 2>/dev/null || echo "0")

    # Сортируем значения
    if [ $(echo "$low_num > $avg_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$low_gas"
        low_gas="$avg_gas"
        avg_gas="$temp"
        echo "🔄 Исправлен порядок: Low и Avg поменялись местами" >&2
    fi

    if [ $(echo "$avg_num > $high_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$avg_gas"
        avg_gas="$high_gas"
        high_gas="$temp"
        echo "🔄 Исправлен порядок: Avg и High поменялись местами" >&2
    fi

    # Убеждаемся что high действительно больше avg
    if [ $(echo "$high_gas <= $avg_gas" | bc -l 2>/dev/null) -eq 1 ]; then
        high_gas=$(echo "scale=3; $avg_gas * 1.1" | bc 2>/dev/null || echo "0.078")
        echo "🔄 High увеличен: $high_gas" >&2
    fi

    # Форматируем до 3 знаков
    low_gas=$(printf "%.3f" "$low_gas" 2>/dev/null || echo "$low_gas")
    avg_gas=$(printf "%.3f" "$avg_gas" 2>/dev/null || echo "$avg_gas")
    high_gas=$(printf "%.3f" "$high_gas" 2>/dev/null || echo "$high_gas")

    # Удаляем лишние нули
    low_gas=$(echo "$low_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.064/')
    avg_gas=$(echo "$avg_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.071/')
    high_gas=$(echo "$high_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.078/')

    echo "✅ Финальные значения: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    echo "$low_gas $avg_gas $high_gas"
    return 0
}

# Функция выбора комиссии с автообновлением
select_gas_price() {
    local choice=""
    local update_count=0
    local start_time=$(date '+%H:%M:%S')

    # Первоначальный вывод заголовка
    clear
    echo -e ${GREEN} "💸 Отправка ETH" ${NC}
    echo "========================================"
    echo "⛽ ВЫБОР КОМИССИИ "
    echo "========================================"
    echo -e "${BLUE} "🕒 Время начала: $start_time"${NC}"
    echo -e "${CYAN}🌐 Источник: Etherscan Gas Tracker${NC}"

    echo ""

    while true; do
        # Обновляем время
        local current_time=$(date '+%H:%M:%S')

        # Получаем цены
        local prices=$(get_gas_prices 2>/dev/null)
        local current_low=$(echo "$prices" | awk '{print $1}')
        local current_avg=$(echo "$prices" | awk '{print $2}')
        local current_high=$(echo "$prices" | awk '{print $3}')

        # Рассчитываем комиссии
        local current_low_fee=$(calculate_fee "$current_low")
        local current_avg_fee=$(calculate_fee "$current_avg")
        local current_high_fee=$(calculate_fee "$current_high")

        # Форматируем КАК НА САЙТЕ (8 знаков)
        local current_low_formatted=$(format_eth_fixed "$current_low_fee")
        local current_avg_formatted=$(format_eth_fixed "$current_avg_fee")
        local current_high_formatted=$(format_eth_fixed "$current_high_fee")

        # Перемещаем курсор вверх на 8 строк
        tput cup 7 0

        # Очищаем и обновляем строки
        tput el
        echo -e "${DARK_WHITE}🕒 Текущее время: $current_time${NC}"
        tput el
        echo -e "${YELLOW}🔄 Обновлений: $((++update_count))${NC}"
        tput el
        echo ""
        tput el
        printf "${LIGHT_GREEN}   1. 🐢 Низкая     - %s Gwei ≈ %s ETH${NC}\n" "$current_low" "$current_low_formatted" 
        tput el
        printf "${GREEN}   2. 🚶 Средняя    - %s Gwei ≈ %s ETH${NC}\n" "$current_avg" "$current_avg_formatted"
        tput el
        printf "${RED}   3. 🏎  Высокая    - %s Gwei ≈ %s ETH${NC}\n" "$current_high" "$current_high_formatted"
        tput el
        echo -e "${GOLD}   4. ✏  Ввести вручную${NC}"
        tput el
        echo -e "${RED}   q. ❌ Выйти${NC}"
        tput el

        # Ждем ввод с таймаутом 1 секунда
        if read -t 1 -n 1 choice 2>/dev/null; then
            echo ""
            case $choice in
                1)
                    GAS_PRICE_GWEI="$current_low"
                    GAS_FEE_ETH="$current_low_fee"
                    GAS_FEE_FORMATTED="$current_low_formatted"
                   echo -e "${LIGHT_GREEN}✅ Выбрана Низкая комиссия:${NC} ${GOLD}$current_low Gwei${NC} ≈ ${CYAN}$current_low_formatted ETH${NC}"
                   break
                    ;;
                2)
                    GAS_PRICE_GWEI="$current_avg"
                    GAS_FEE_ETH="$current_avg_fee"
                    GAS_FEE_FORMATTED="$current_avg_formatted"
                    echo -e "${GREEN}✅ Выбрана Средняя комиссия:${NC} ${GOLD}$current_avg Gwei${NC} ≈ ${CYAN}$current_avg_formatted ETH${NC}"  
                    break
                    ;;
                3)
                    GAS_PRICE_GWEI="$current_high"
                    GAS_FEE_ETH="$current_high_fee"
                    GAS_FEE_FORMATTED="$current_high_formatted"
                    echo -e "${RED}✅ Выбрана Высокая комиссия:${NC} ${GOLD}$current_high Gwei${NC} ≈ ${CYAN}$current_high_formatted ETH${NC}"
                    break
                    ;;
                4)
                    echo ""
                    echo "💡 Текущие цены:"
                    printf "   🐢 Низкая:     %s Gwei ≈ %s ETH\n" "$current_low" "$current_low_formatted"
                    printf "   🚶 Средняя:    %s Gwei ≈ %s ETH\n" "$current_avg" "$current_avg_formatted"
                    printf "   🏎  Высокая:    %s Gwei ≈ %s ETH\n" "$current_high" "$current_high_formatted"
                    echo ""

                    while true; do
                        read -p "Введите gas price в Gwei: " manual_gas
                        manual_gas=$(clean_number "$manual_gas")

                        if [[ "$manual_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            GAS_PRICE_GWEI="$manual_gas"
                            GAS_FEE_ETH=$(calculate_fee "$manual_gas")
                            GAS_FEE_FORMATTED=$(format_eth_fixed "$GAS_FEE_ETH")
                            echo "✅ Установлен gas price: $manual_gas Gwei ≈ $GAS_FEE_FORMATTED ETH"
                            break 2
                        else
                            echo "❌ Неверный формат. Пример: 0.064 или 1.50"
                        fi
                    done
                    ;;
                q)
                    echo "Выход..."
                    exit 0
                    ;;
            esac
        fi
    done
}

# Функция выбора суммы отправки
select_amount() {
    local choice=""

    echo ""
    echo -e "${SOFT_GOLD}💰 ВЫБОР СУММЫ ОТПРАВКИ${NC}"
    echo "========================================"
    echo -e "${GREEN}Доступно:${NC} ${BRIGHT_GOLD}$MAX_SEND_ETH_FORMATTED${NC} ${PURPLE}ETH${NC}"
    echo -e "${RED}Комиссия:${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}" 
    echo -e "${YELLOW}Максимум:${NC} ${LIGHT_GREEN}$MAX_SEND_ETH_FORMATTED ETH${NC}"

    echo ""
  while true; do
    echo -e "${CYAN}Выберите сумму:${NC}"
    echo -e "${LIGHT_GREEN}   1. 📤 Отправить полную сумму ${NC} ${GOLD}(максимум)${NC}"
    echo -e "${LIGHT_ORANGE}   2. ✏  Ввести сумму вручную${NC}"
    read -p "$(echo -e "${YELLOW}Ваш выбор (1-2): ${NC}")" choice

    case $choice in
            1)
                SEND_WEI="$MAX_SEND_WEI"
                SEND_ETH="$MAX_SEND_ETH"
                SEND_ETH_FORMATTED="$MAX_SEND_ETH_FORMATTED"
                echo "✅ Выбрана отправка полной суммы: $SEND_ETH_FORMATTED ETH"
                break
                ;;
            2)
                while true; do
                    read -p "Введите сумму для отправки в ETH: " amount_eth
                    amount_eth=$(clean_number "$amount_eth")

                    if [[ ! "$amount_eth" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "❌ Неверный формат. Пример: 0.001 или 0.5"
                        continue
                    fi

                    # Конвертируем в Wei
                    local amount_wei=$(echo "$amount_eth * 1000000000000000000" | bc 2>/dev/null)

                    if [ -z "$amount_wei" ] || [ "$amount_wei" = "0" ]; then
                        echo "❌ Сумма слишком мала"
                        continue
                    fi

                    if [ $(echo "$amount_wei > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Недостаточно средств!"
                        continue
                    fi

                    local total_needed=$(echo "$amount_wei + $GAS_FEE_WEI" | bc)
                    if [ $(echo "$total_needed > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Не хватит на комиссию!"
                        continue
                    fi

                    SEND_WEI="$amount_wei"
                    SEND_ETH="$amount_eth"
                    SEND_ETH_FORMATTED=$(format_eth_fixed "$amount_eth")
                    echo "✅ Сумма установлена: $SEND_ETH_FORMATTED ETH"
                    break
                done
                break
                ;;
            *)
                echo "❌ Неверный выбор"
                ;;
        esac
    done
}

# === ОСНОВНОЙ СКРИПТ ===

# 1. Получить баланс отправителя
echo "📊 Получаю баланс..."
BALANCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$FROM\",\"latest\"],\"id\":1}")

if [ $? -ne 0 ] || [ -z "$BALANCE_RESP" ]; then
    echo "❌ Ошибка получения баланса"
    exit 1
fi

BALANCE_HEX=$(echo "$BALANCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BALANCE_HEX" ]; then
    echo "❌ Не удалось получить баланс"
    exit 1
fi

# Конвертация hex в decimal
BALANCE_WEI=$(echo "ibase=16; $(echo ${BALANCE_HEX#0x} | tr '[:lower:]' '[:upper:]')" | bc)
BALANCE_ETH=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
BALANCE_ETH_FORMATTED=$(format_eth_fixed "$BALANCE_ETH")

echo -e "${LIGHT_CYAN}✅ Баланс:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
# 2. Выбор комиссии с автообновлением
select_gas_price

# 3. Конвертируем Gwei в Wei
GAS_PRICE_WEI=$(echo "$GAS_PRICE_GWEI * 1000000000" | bc 2>/dev/null)
GAS_PRICE_WEI_INT=$(echo "scale=0; $GAS_PRICE_WEI / 1" | bc)
GAS_PRICE_HEX=$(printf "0x%x" "$GAS_PRICE_WEI_INT" 2>/dev/null)

GAS_LIMIT=21000
GAS_FEE_WEI=$(echo "$GAS_PRICE_WEI * $GAS_LIMIT" | bc 2>/dev/null)

echo ""
echo -e "${GAS}💰 Комиссия за транзакцию:${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}"

# 4. Рассчитать максимум для отправки
MAX_SEND_WEI=$(echo "$BALANCE_WEI - $GAS_FEE_WEI" | bc)
MAX_SEND_ETH=$(echo "scale=18; $MAX_SEND_WEI / 1000000000000000000" | bc)
MAX_SEND_ETH_FORMATTED=$(format_eth_fixed "$MAX_SEND_ETH")

# Проверка через bc
if [ $(echo "$MAX_SEND_WEI <= 0" | bc) -eq 1 ]; then
    echo ""
    echo "❌ ОШИБКА: Баланс слишком мал даже для оплаты комиссии!"
    exit 1
fi

# 5. Выбор суммы отправки
select_amount

# Конвертация в ETH
SEND_ETH=$(echo "scale=18; $SEND_WEI / 1000000000000000000" | bc)
SEND_WEI_INT=$(echo "scale=0; $SEND_WEI / 1" | bc)
SEND_HEX=$(printf "0x%x" "$SEND_WEI_INT")
echo -e "   ${LIGHT_CYAN}Баланс:${NC}    ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
echo -e "${YELLOW}📈 РАСЧЕТ:${NC}"
REMAINING_ETH=$(echo "$BALANCE_ETH - $SEND_ETH - $GAS_FEE_ETH" | bc)
REMAINING_FORMATTED=$(format_eth_fixed "$REMAINING_ETH")
echo -e "   ${LIGHT_GREEN}Отправка:${NC}  -${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Комиссия:${NC}  -${GAS}$GAS_FEE_FORMATTED ETH${NC}"
echo -e "   ${PURPLE}Остаток:${NC}   =${WHITE}$REMAINING_FORMATTED ETH${NC}"

# 6. Получить nonce
echo ""
echo -e "${CYAN}🔢 Получаю nonce...${NC}"
NONCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$FROM\",\"pending\"],\"id\":1}")

NONCE_HEX=$(echo "$NONCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo -e "${WHITE}✅ Nonce:${NC} ${PURPLE}$NONCE_HEX${NC}"

# 7. Подтверждение
echo ""
echo -e "${YELLOW}📋 ПОДТВЕРЖДЕНИЕ:${NC}"
echo -e "   ${CYAN}От:${NC}        ${YELLOW}$FROM${NC}"
echo -e "   ${CYAN}Кому:${NC}      ${MAGENTA}$TO${NC}"
echo -e "   ${LIGHT_GREEN}Отправляю:${NC} ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Комиссия:${NC}  ${GAS}$GAS_FEE_FORMATTED ETH${NC} ${WHITE}(Gas:${NC} ${PURPLE}$GAS_PRICE_GWEI Gwei${NC}${WHITE})${NC}"
echo ""

read -p "$(echo -e "${YELLOW}Подтвердить отправку? (y/n): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Отменено"
    exit 0
fi

# 8. Создать транзакцию
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
echo -e "${BRIGHT_BLUE}📝 Отправляю в Clef для подписи...${NC}"

# 9. Подписать
SIGN_RESP=$(curl -s "$CLEF" \
  -H "Content-Type: application/json" \
  -d "$TX_JSON")

RAW_TX=$(echo "$SIGN_RESP" | grep -o '"raw":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RAW_TX" ]; then
    echo "❌ Ошибка подписи"
    echo "$SIGN_RESP" | jq .
    exit 1
fi

echo "✅ Транзакция подписана!"

# 10. Отправить
echo ""
echo -e "${CYAN}🚀 Отправляю в сеть...${NC}"
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
    echo -e "${BRIGHT_GREEN}🎉 УСПЕХ! Транзакция отправлена!${NC}"
    echo -e "🔗 Hash: ${BRIGHT_YELLOW}$TX_HASH${NC}"
    echo -e "${CYAN}🌐 Explorer: ${BRIGHT_BLUE}https://etherscan.io/tx/$TX_HASH${NC}"

else
    echo "❌ Ошибка отправки:"
    echo "$RESULT" | jq .

    echo "$RAW_TX" > raw_tx_$(date +%s).txt
    echo "💾 Raw транзакция сохранена"
fi
