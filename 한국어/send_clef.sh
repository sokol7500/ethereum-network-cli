# 기본 색상
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
# 추가 색상 (256색)
BRIGHT_BLUE="\e[94m"
NC="\e[0m"
BRIGHT_YELLOW="\e[93m"
CYAN="\e[36m"
BRIGHT_BLUE="\e[94m"
# 밝은 금색 계열
# 최대 밝기 계열 (모두 226-229 최대)
GOLD_226='\033[38;5;226m'  # 순수 밝은 노란색
GOLD_227='\033[38;5;227m'  # 색조가 있는 노란색
GOLD_228='\033[38;5;228m'  # 밝은 노란색
GOLD_221='\033[38;5;221m'  # 황금색
GOLD_220='\033[38;5;220m'  # 클래식 골드
BRIGHT_GOLD='\033[38;5;226m'  # 가장 밝은 노란색/금색
LIGHT_GREEN='\033[1;32m'        # 밝은 녹색
PURPLE='\033[0;35m'             # 보라색
GOLD='\033[38;5;220m'           # 진짜 금색
LIGHT_GOLD='\033[38;5;228m'     # 밝은 금색
SOFT_GOLD='\033[38;5;223m'      # 부드러운 금색
PALE_GOLD='\033[38;5;230m'      # 옅은 금색
DARK_WHITE='\033[38;5;250m'     # 진한 흰색 (회색빛)
LIGHT_ORANGE='\033[38;5;214m'   # 밝은 주황색
PINK='\033[38;5;205m'           # 분홍색
PURPLE_LIGHT='\033[38;5;135m'   # 밝은 보라색
LIGHT_CYAN='\033[1;36m'      # 밝은 청록색

#!/bin/bash
# 올바른 숫자 표시를 위한 영어 로케일 설정
export LC_NUMERIC="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# 설정
FROM="0xdD91aF12e4464e7412Fd1084460f407e7f9b0fd1"
TO="0xA351D597540b27eD5327425D29d1526c17C3F026"
CLEF="http://localhost:8550"
RPC="https://1rpc.io/eth"

echo -e ${GREEN} "💸 ETH 보내기" ${NC}
echo "========================================"

# 숫자 정리 함수
clean_number() {
    echo "$1" | tr -d ',' | sed 's/[^0-9.]//g'
}

# ETH 형식화 함수 (항상 8자리)
format_eth_fixed() {
    local num=$(clean_number "$1")
    if [ -z "$num" ] || [ "$num" = "0" ]; then
        echo "0.00000000"
    else
        # 항상 소수점 8자리
        LANG=C printf "%0.8f" "$num" 2>/dev/null
    fi
}

# ETH 수수료 계산 함수
calculate_fee() {
    local gas_gwei=$(clean_number "$1")
    if [[ ! "$gas_gwei" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$gas_gwei" ]; then
        echo "0"
        return
    fi

    # 정확한 계산
    echo "scale=12; $gas_gwei * 21000 / 1000000000" | bc 2>/dev/null
}

# Etherscan에서 정확한 가스 가격 가져오기 함수 (수정된 로직)
get_gas_prices() {
    # gastracker HTML 페이지 가져오기
    echo "🌐 Etherscan에서 실시간 데이터 가져오는 중..." >&2
    local html=$(curl -s --max-time 10 "https://etherscan.io/gastracker" 2>/dev/null)

    if [ -z "$html" ]; then
        echo "❌ 페이지를 불러올 수 없음" >&2
        echo "0.064 0.071 0.078"
        return 1
    fi

    local low_gas="" avg_gas="" high_gas=""

    # 방법 1: "X.XXX gwei" 형식의 모든 값 찾기
    local all_gwei_values=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+[[:space:]]*gwei' | head -10)

    echo "🔍 발견된 Gwei 값: $all_gwei_values" >&2

    # 숫자 추출 및 오름차순 정렬
    local number_list=$(echo "$all_gwei_values" | grep -o '[0-9]\+\.[0-9]\+' | sort -n | uniq)

    # 배열로 변환
    local numbers=()
    while read -r num; do
        numbers+=("$num")
    done <<< "$number_list"

    local count=${#numbers[@]}

    echo "🔍 $count개의 고유 값 발견: ${numbers[*]}" >&2

    if [ $count -ge 3 ]; then
        # 3개 이상의 값이 있으면 첫 번째, 중간, 마지막 값 사용
        low_gas="${numbers[0]}"

        # 중간 값 (중앙값)
        local mid_index=$(( (count - 1) / 2 ))
        avg_gas="${numbers[$mid_index]}"

        # 가장 높은 값
        high_gas="${numbers[-1]}"

        echo "✅ 정렬된 값 사용: Low=$low_gas, Mid=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 2 ]; then
        # 2개 값
        low_gas="${numbers[0]}"
        high_gas="${numbers[1]}"
        avg_gas=$(echo "scale=3; (${numbers[0]} + ${numbers[1]}) / 2" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 2개 값: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 1 ]; then
        # 1개 값만 있는 경우
        low_gas="${numbers[0]}"
        avg_gas="${numbers[0]}"
        high_gas=$(echo "scale=3; ${numbers[0]} * 1.1" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 1개 값: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    fi

    # 방법 2: Low/Average/High 카드에서 찾기
    if [ -z "$low_gas" ] || [ -z "$avg_gas" ] || [ -z "$high_gas" ]; then
        # 카드가 있는 블록 찾기
        local card_section=$(echo "$html" | grep -o 'card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Low\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Average\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*High' -A 20 | head -200)

        if [ -n "$card_section" ]; then
            # 카드에서 가격 추출
            low_gas=$(echo "$card_section" | grep -A 10 'Low' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            avg_gas=$(echo "$card_section" | grep -A 10 'Average' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            high_gas=$(echo "$card_section" | grep -A 10 'High' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        fi
    fi

    # 값 정리
    low_gas=$(clean_number "$low_gas")
    avg_gas=$(clean_number "$avg_gas")
    high_gas=$(clean_number "$high_gas")

    echo "🔍 파싱 후: Low='$low_gas', Avg='$avg_gas', High='$high_gas'" >&2

    # 값을 찾을 수 없거나 유효하지 않은 경우 기본값 사용
    if [[ ! "$low_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$low_gas" ]; then
        low_gas="0.064"
        echo "⚠️  Low를 찾을 수 없음, 기본값 사용: $low_gas" >&2
    fi

    if [[ ! "$avg_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$avg_gas" ]; then
        avg_gas="0.071"
        echo "⚠️  Avg를 찾을 수 없음, 기본값 사용: $avg_gas" >&2
    fi

    if [[ ! "$high_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$high_gas" ]; then
        high_gas="0.078"
        echo "⚠️  High를 찾을 수 없음, 기본값 사용: $high_gas" >&2
    fi

    # Low ≤ Avg ≤ High 보장
    # 배열 생성 및 정렬
    local sorted=($low_gas $avg_gas $high_gas)

    # bc를 사용한 숫자 비교
    local low_num=$(echo "$low_gas" | bc -l 2>/dev/null || echo "0")
    local avg_num=$(echo "$avg_gas" | bc -l 2>/dev/null || echo "0")
    local high_num=$(echo "$high_gas" | bc -l 2>/dev/null || echo "0")

    # 값 정렬
    if [ $(echo "$low_num > $avg_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$low_gas"
        low_gas="$avg_gas"
        avg_gas="$temp"
        echo "🔄 순서 수정: Low와 Avg가 바뀜" >&2
    fi

    if [ $(echo "$avg_num > $high_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$avg_gas"
        avg_gas="$high_gas"
        high_gas="$temp"
        echo "🔄 순서 수정: Avg와 High가 바뀜" >&2
    fi

    # high가 실제로 avg보다 큰지 확인
    if [ $(echo "$high_gas <= $avg_gas" | bc -l 2>/dev/null) -eq 1 ]; then
        high_gas=$(echo "scale=3; $avg_gas * 1.1" | bc 2>/dev/null || echo "0.078")
        echo "🔄 High 증가됨: $high_gas" >&2
    fi

    # 3자리로 형식화
    low_gas=$(printf "%.3f" "$low_gas" 2>/dev/null || echo "$low_gas")
    avg_gas=$(printf "%.3f" "$avg_gas" 2>/dev/null || echo "$avg_gas")
    high_gas=$(printf "%.3f" "$high_gas" 2>/dev/null || echo "$high_gas")

    # 불필요한 0 제거
    low_gas=$(echo "$low_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.064/')
    avg_gas=$(echo "$avg_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.071/')
    high_gas=$(echo "$high_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.078/')

    echo "✅ 최종 값: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    echo "$low_gas $avg_gas $high_gas"
    return 0
}

# 자동 업데이트 수수료 선택 함수
select_gas_price() {
    local choice=""
    local update_count=0
    local start_time=$(date '+%H:%M:%S')

    # 초기 헤더 출력
    clear
    echo -e ${GREEN} "💸 ETH 보내기" ${NC}
    echo "========================================"
    echo "⛽ 수수료 선택"
    echo "========================================"
    echo -e "${BLUE} 🕒 시작 시간: $start_time${NC}"
    echo -e "${CYAN}🌐 출처: Etherscan Gas Tracker${NC}"

    echo ""

    while true; do
        # 시간 업데이트
        local current_time=$(date '+%H:%M:%S')

        # 가격 가져오기
        local prices=$(get_gas_prices 2>/dev/null)
        local current_low=$(echo "$prices" | awk '{print $1}')
        local current_avg=$(echo "$prices" | awk '{print $2}')
        local current_high=$(echo "$prices" | awk '{print $3}')

        # 수수료 계산
        local current_low_fee=$(calculate_fee "$current_low")
        local current_avg_fee=$(calculate_fee "$current_avg")
        local current_high_fee=$(calculate_fee "$current_high")

        # 웹사이트 스타일로 형식화 (8자리)
        local current_low_formatted=$(format_eth_fixed "$current_low_fee")
        local current_avg_formatted=$(format_eth_fixed "$current_avg_fee")
        local current_high_formatted=$(format_eth_fixed "$current_high_fee")

        # 커서를 8줄 위로 이동
        tput cup 7 0

        # 줄 지우고 업데이트
        tput el
        echo -e "${DARK_WHITE}🕒 현재 시간: $current_time${NC}"
        tput el
        echo -e "${YELLOW}🔄 업데이트 횟수: $((++update_count))${NC}"
        tput el
        echo ""
        tput el
        printf "${LIGHT_GREEN}   1. 🐢 낮음     - %s Gwei ≈ %s ETH${NC}\n" "$current_low" "$current_low_formatted" 
        tput el
        printf "${GREEN}   2. 🚶 중간     - %s Gwei ≈ %s ETH${NC}\n" "$current_avg" "$current_avg_formatted"
        tput el
        printf "${RED}   3. 🏎  높음     - %s Gwei ≈ %s ETH${NC}\n" "$current_high" "$current_high_formatted"
        tput el
        echo -e "${GOLD}   4. ✏  직접 입력${NC}"
        tput el
        echo -e "${RED}   q. ❌ 종료${NC}"
        tput el

        # 1초 타임아웃으로 입력 대기
        if read -t 1 -n 1 choice 2>/dev/null; then
            echo ""
            case $choice in
                1)
                    GAS_PRICE_GWEI="$current_low"
                    GAS_FEE_ETH="$current_low_fee"
                    GAS_FEE_FORMATTED="$current_low_formatted"
                   echo -e "${LIGHT_GREEN}✅ 낮은 수수료 선택됨:${NC} ${GOLD}$current_low Gwei${NC} ≈ ${CYAN}$current_low_formatted ETH${NC}"
                   break
                    ;;
                2)
                    GAS_PRICE_GWEI="$current_avg"
                    GAS_FEE_ETH="$current_avg_fee"
                    GAS_FEE_FORMATTED="$current_avg_formatted"
                    echo -e "${GREEN}✅ 중간 수수료 선택됨:${NC} ${GOLD}$current_avg Gwei${NC} ≈ ${CYAN}$current_avg_formatted ETH${NC}"  
                    break
                    ;;
                3)
                    GAS_PRICE_GWEI="$current_high"
                    GAS_FEE_ETH="$current_high_fee"
                    GAS_FEE_FORMATTED="$current_high_formatted"
                    echo -e "${RED}✅ 높은 수수료 선택됨:${NC} ${GOLD}$current_high Gwei${NC} ≈ ${CYAN}$current_high_formatted ETH${NC}"
                    break
                    ;;
                4)
                    echo ""
                    echo "💡 현재 가격:"
                    printf "   🐢 낮음:     %s Gwei ≈ %s ETH\n" "$current_low" "$current_low_formatted"
                    printf "   🚶 중간:    %s Gwei ≈ %s ETH\n" "$current_avg" "$current_avg_formatted"
                    printf "   🏎  높음:    %s Gwei ≈ %s ETH\n" "$current_high" "$current_high_formatted"
                    echo ""

                    while true; do
                        read -p "Gwei 단위로 gas price 입력: " manual_gas
                        manual_gas=$(clean_number "$manual_gas")

                        if [[ "$manual_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            GAS_PRICE_GWEI="$manual_gas"
                            GAS_FEE_ETH=$(calculate_fee "$manual_gas")
                            GAS_FEE_FORMATTED=$(format_eth_fixed "$GAS_FEE_ETH")
                            echo "✅ gas price 설정됨: $manual_gas Gwei ≈ $GAS_FEE_FORMATTED ETH"
                            break 2
                        else
                            echo "❌ 잘못된 형식. 예시: 0.064 또는 1.50"
                        fi
                    done
                    ;;
                q)
                    echo "종료 중..."
                    exit 0
                    ;;
            esac
        fi
    done
}

# 보낼 금액 선택 함수
select_amount() {
    local choice=""

    echo ""
    echo -e "${SOFT_GOLD}💰 보낼 금액 선택${NC}"
    echo "========================================"
    echo -e "${GREEN}사용 가능:${NC}   ${BRIGHT_GOLD}$MAX_SEND_ETH_FORMATTED${NC} ${PURPLE}ETH${NC}"
    echo -e "${RED}수수료:${NC}      ${GOLD}$GAS_FEE_FORMATTED ETH${NC}" 
    echo -e "${YELLOW}최대:${NC}        ${LIGHT_GREEN}$MAX_SEND_ETH_FORMATTED ETH${NC}"

    echo ""
  while true; do
    echo -e "${CYAN}금액 선택:${NC}"
    echo -e "${LIGHT_GREEN}   1. 📤 전체 금액 보내기 ${NC} ${GOLD}(최대)${NC}"
    echo -e "${LIGHT_ORANGE}   2. ✏  수동 입력${NC}"
    read -p "$(echo -e "${YELLOW}선택 (1-2): ${NC}")" choice

    case $choice in
            1)
                SEND_WEI="$MAX_SEND_WEI"
                SEND_ETH="$MAX_SEND_ETH"
                SEND_ETH_FORMATTED="$MAX_SEND_ETH_FORMATTED"
                echo "✅ 전체 금액 보내기 선택됨: $SEND_ETH_FORMATTED ETH"
                break
                ;;
            2)
                while true; do
                    read -p "보낼 ETH 금액 입력: " amount_eth
                    amount_eth=$(clean_number "$amount_eth")

                    if [[ ! "$amount_eth" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "❌ 잘못된 형식. 예시: 0.001 또는 0.5"
                        continue
                    fi

                    # Wei로 변환
                    local amount_wei=$(echo "$amount_eth * 1000000000000000000" | bc 2>/dev/null)

                    if [ -z "$amount_wei" ] || [ "$amount_wei" = "0" ]; then
                        echo "❌ 금액이 너무 작음"
                        continue
                    fi

                    if [ $(echo "$amount_wei > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ 잔액 부족!"
                        continue
                    fi

                    local total_needed=$(echo "$amount_wei + $GAS_FEE_WEI" | bc)
                    if [ $(echo "$total_needed > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ 수수료를 지불할 잔액이 부족함!"
                        continue
                    fi

                    SEND_WEI="$amount_wei"
                    SEND_ETH="$amount_eth"
                    SEND_ETH_FORMATTED=$(format_eth_fixed "$amount_eth")
                    echo "✅ 금액 설정됨: $SEND_ETH_FORMATTED ETH"
                    break
                done
                break
                ;;
            *)
                echo "❌ 잘못된 선택"
                ;;
        esac
    done
}

# === 메인 스크립트 ===

# 1. 발신자 잔액 가져오기
echo "📊 잔액 가져오는 중..."
BALANCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$FROM\",\"latest\"],\"id\":1}")

if [ $? -ne 0 ] || [ -z "$BALANCE_RESP" ]; then
    echo "❌ 잔액 조회 오류"
    exit 1
fi

BALANCE_HEX=$(echo "$BALANCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BALANCE_HEX" ]; then
    echo "❌ 잔액을 가져올 수 없음"
    exit 1
fi

# 16진수를 10진수로 변환
BALANCE_WEI=$(echo "ibase=16; $(echo ${BALANCE_HEX#0x} | tr '[:lower:]' '[:upper:]')" | bc)
BALANCE_ETH=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
BALANCE_ETH_FORMATTED=$(format_eth_fixed "$BALANCE_ETH")

echo -e "${LIGHT_CYAN}✅ 잔액:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
# 2. 자동 업데이트 수수료 선택
select_gas_price

# 3. Gwei를 Wei로 변환
GAS_PRICE_WEI=$(echo "$GAS_PRICE_GWEI * 1000000000" | bc 2>/dev/null)
GAS_PRICE_WEI_INT=$(echo "scale=0; $GAS_PRICE_WEI / 1" | bc)
GAS_PRICE_HEX=$(printf "0x%x" "$GAS_PRICE_WEI_INT" 2>/dev/null)

GAS_LIMIT=21000
GAS_FEE_WEI=$(echo "$GAS_PRICE_WEI * $GAS_LIMIT" | bc 2>/dev/null)

echo ""
echo -e "${GAS}💰 트랜잭션 수수료:${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}"

# 4. 보낼 최대 금액 계산
MAX_SEND_WEI=$(echo "$BALANCE_WEI - $GAS_FEE_WEI" | bc)
MAX_SEND_ETH=$(echo "scale=18; $MAX_SEND_WEI / 1000000000000000000" | bc)
MAX_SEND_ETH_FORMATTED=$(format_eth_fixed "$MAX_SEND_ETH")

# bc를 통한 확인
if [ $(echo "$MAX_SEND_WEI <= 0" | bc) -eq 1 ]; then
    echo ""
    echo "❌ 오류: 수수료를 지불할 잔액이 너무 적음!"
    exit 1
fi

# 5. 보낼 금액 선택
select_amount

# ETH로 변환
SEND_ETH=$(echo "scale=18; $SEND_WEI / 1000000000000000000" | bc)
SEND_WEI_INT=$(echo "scale=0; $SEND_WEI / 1" | bc)
SEND_HEX=$(printf "0x%x" "$SEND_WEI_INT")
echo -e "   ${LIGHT_CYAN}잔액:${NC}  ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
echo -e "${YELLOW}📈 계산:${NC}"
REMAINING_ETH=$(echo "$BALANCE_ETH - $SEND_ETH - $GAS_FEE_ETH" | bc)
REMAINING_FORMATTED=$(format_eth_fixed "$REMAINING_ETH")
echo -e "   ${LIGHT_GREEN}보내기:${NC}      ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}수수료:${NC}      ${GAS}$GAS_FEE_FORMATTED ETH${NC}"
echo -e "   ${PURPLE}남은 금액:${NC}   ${WHITE}$REMAINING_FORMATTED ETH${NC}"

# 6. nonce 가져오기
echo ""
echo -e "${CYAN}🔢 nonce 가져오는 중...${NC}"
NONCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$FROM\",\"pending\"],\"id\":1}")

NONCE_HEX=$(echo "$NONCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo -e "${WHITE}✅ Nonce:${NC} ${PURPLE}$NONCE_HEX${NC}"

# 7. 확인
echo ""
echo -e "${YELLOW}📋 확인:${NC}"
echo -e "   ${CYAN}보내는 사람 - ETH:${NC} ${YELLOW}$FROM${NC}"
echo -e "   ${CYAN}받는 사람:  - ETH:${NC} ${MAGENTA}$TO${NC}"
echo -e "   ${LIGHT_GREEN}보내는 금액:${NC} ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}수수료:${NC} ${GAS}$GAS_FEE_FORMATTED ETH${NC} ${WHITE}(Gas:${NC} ${PURPLE}$GAS_PRICE_GWEI Gwei${NC}${WHITE})${NC}"
echo ""

read -p "$(echo -e "${YELLOW}보내기를 확인하시겠습니까? (y/n): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 취소됨"
    exit 0
fi

# 8. 트랜잭션 생성
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
echo -e "${BRIGHT_BLUE}📝 서명을 위해 Clef로 전송 중...${NC}"

# 9. 서명
SIGN_RESP=$(curl -s "$CLEF" \
  -H "Content-Type: application/json" \
  -d "$TX_JSON")

RAW_TX=$(echo "$SIGN_RESP" | grep -o '"raw":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RAW_TX" ]; then
    echo "❌ 서명 오류"
    echo "$SIGN_RESP" | jq .
    exit 1
fi

echo "✅ 트랜잭션 서명됨!"

# 10. 전송
echo ""
echo -e "${CYAN}🚀 네트워크로 전송 중...${NC}"
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
    echo -e "${BRIGHT_GREEN}🎉 성공! 트랜잭션이 전송되었습니다!${NC}"
    echo -e "🔗 해시: ${BRIGHT_YELLOW}$TX_HASH${NC}"
    echo -e "${CYAN}🌐 익스플로러: ${BRIGHT_BLUE}https://etherscan.io/tx/$TX_HASH${NC}"

else
    echo "❌ 전송 오류:"
    echo "$RESULT" | jq .

    echo "$RAW_TX" > raw_tx_$(date +%s).txt
    echo "💾 원시 트랜잭션이 저장됨"
fi
