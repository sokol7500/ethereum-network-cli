# 主要颜色
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
# 额外颜色 (256色)
BRIGHT_BLUE="\e[94m"
NC="\e[0m"
BRIGHT_YELLOW="\e[93m"
CYAN="\e[36m"
BRIGHT_BLUE="\e[94m"
# 亮金色调
# 最亮的色调 (所有226-229最大)
GOLD_226='\033[38;5;226m'  # 纯亮黄色
GOLD_227='\033[38;5;227m'  # 带色调的黄色
GOLD_228='\033[38;5;228m'  # 浅黄色
GOLD_221='\033[38;5;221m'  # 金色
GOLD_220='\033[38;5;220m'  # 经典金色
BRIGHT_GOLD='\033[38;5;226m'  # 最亮的黄色/金色
LIGHT_GREEN='\033[1;32m'        # 浅绿色
PURPLE='\033[0;35m'             # 紫色
GOLD='\033[38;5;220m'           # 纯金色
LIGHT_GOLD='\033[38;5;228m'     # 浅金色
SOFT_GOLD='\033[38;5;223m'      # 柔和金色
PALE_GOLD='\033[38;5;230m'      # 淡金色
DARK_WHITE='\033[38;5;250m'     # 深白色（灰白色）
LIGHT_ORANGE='\033[38;5;214m'   # 浅橙色
PINK='\033[38;5;205m'           # 粉色
PURPLE_LIGHT='\033[38;5;135m'   # 浅紫色
LIGHT_CYAN='\033[1;36m'      # 浅青色

#!/bin/bash
# 设置英文语言环境以正确显示数字
export LC_NUMERIC="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# 设置
FROM="0xdD91aF12e4464e7412Fd1084460f407e7f9b0fd1"
TO="0xA351D597540b27eD5327425D29d1526c17C3F026"
CLEF="http://localhost:8550"
RPC="https://1rpc.io/eth"

echo -e ${GREEN} "💸 发送ETH" ${NC}
echo "========================================"

# 数字清理函数
clean_number() {
    echo "$1" | tr -d ',' | sed 's/[^0-9.]//g'
}

# 格式化ETH（固定8位小数）
format_eth_fixed() {
    local num=$(clean_number "$1")
    if [ -z "$num" ] || [ "$num" = "0" ]; then
        echo "0.00000000"
    else
        # 始终显示8位小数
        LANG=C printf "%0.8f" "$num" 2>/dev/null
    fi
}

# 计算ETH手续费
calculate_fee() {
    local gas_gwei=$(clean_number "$1")
    if [[ ! "$gas_gwei" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$gas_gwei" ]; then
        echo "0"
        return
    fi

    # 精确计算
    echo "scale=12; $gas_gwei * 21000 / 1000000000" | bc 2>/dev/null
}

# 从Etherscan获取精确Gas价格（修正逻辑）
get_gas_prices() {
    # 获取gastracker页面
    echo "🌐 正在从Etherscan获取实时数据..." >&2
    local html=$(curl -s --max-time 10 "https://etherscan.io/gastracker" 2>/dev/null)

    if [ -z "$html" ]; then
        echo "❌ 无法加载页面" >&2
        echo "0.064 0.071 0.078"
        return 1
    fi

    local low_gas="" avg_gas="" high_gas=""

    # 方法1：查找所有"X.XXX gwei"格式的值
    local all_gwei_values=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+[[:space:]]*gwei' | head -10)

    echo "🔍 找到的Gwei值：$all_gwei_values" >&2

    # 提取数字并按升序排序
    local number_list=$(echo "$all_gwei_values" | grep -o '[0-9]\+\.[0-9]\+' | sort -n | uniq)

    # 转换为数组
    local numbers=()
    while read -r num; do
        numbers+=("$num")
    done <<< "$number_list"

    local count=${#numbers[@]}

    echo "🔍 找到 $count 个唯一值：${numbers[*]}" >&2

    if [ $count -ge 3 ]; then
        # 如果有3+个值，取第一个、中间和最后一个
        low_gas="${numbers[0]}"

        # 中位值
        local mid_index=$(( (count - 1) / 2 ))
        avg_gas="${numbers[$mid_index]}"

        # 最高值
        high_gas="${numbers[-1]}"

        echo "✅ 使用排序后的值：Low=$low_gas, Mid=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 2 ]; then
        # 如果有2个值
        low_gas="${numbers[0]}"
        high_gas="${numbers[1]}"
        avg_gas=$(echo "scale=3; (${numbers[0]} + ${numbers[1]}) / 2" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 2个值：Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 1 ]; then
        # 如果只有1个值
        low_gas="${numbers[0]}"
        avg_gas="${numbers[0]}"
        high_gas=$(echo "scale=3; ${numbers[0]} * 1.1" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 1个值：Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    fi

    # 方法2：在Low/Average/High卡片中查找
    if [ -z "$low_gas" ] || [ -z "$avg_gas" ] || [ -z "$high_gas" ]; then
        # 查找包含卡片的区块
        local card_section=$(echo "$html" | grep -o 'card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Low\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Average\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*High' -A 20 | head -200)

        if [ -n "$card_section" ]; then
            # 从卡片中提取价格
            low_gas=$(echo "$card_section" | grep -A 10 'Low' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            avg_gas=$(echo "$card_section" | grep -A 10 'Average' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            high_gas=$(echo "$card_section" | grep -A 10 'High' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        fi
    fi

    # 清理值
    low_gas=$(clean_number "$low_gas")
    avg_gas=$(clean_number "$avg_gas")
    high_gas=$(clean_number "$high_gas")

    echo "🔍 解析后：Low='$low_gas', Avg='$avg_gas', High='$high_gas'" >&2

    # 如果值未找到或无效，使用默认值
    if [[ ! "$low_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$low_gas" ]; then
        low_gas="0.064"
        echo "⚠️  未找到Low，使用：$low_gas" >&2
    fi

    if [[ ! "$avg_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$avg_gas" ]; then
        avg_gas="0.071"
        echo "⚠️  未找到Avg，使用：$avg_gas" >&2
    fi

    if [[ ! "$high_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$high_gas" ]; then
        high_gas="0.078"
        echo "⚠️  未找到High，使用：$high_gas" >&2
    fi

    # 确保 Low ≤ Avg ≤ High
    # 创建数组并排序
    local sorted=($low_gas $avg_gas $high_gas)

    # 使用bc进行数值比较
    local low_num=$(echo "$low_gas" | bc -l 2>/dev/null || echo "0")
    local avg_num=$(echo "$avg_gas" | bc -l 2>/dev/null || echo "0")
    local high_num=$(echo "$high_gas" | bc -l 2>/dev/null || echo "0")

    # 排序值
    if [ $(echo "$low_num > $avg_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$low_gas"
        low_gas="$avg_gas"
        avg_gas="$temp"
        echo "🔄 调整顺序：Low和Avg交换" >&2
    fi

    if [ $(echo "$avg_num > $high_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$avg_gas"
        avg_gas="$high_gas"
        high_gas="$temp"
        echo "🔄 调整顺序：Avg和High交换" >&2
    fi

    # 确保high确实大于avg
    if [ $(echo "$high_gas <= $avg_gas" | bc -l 2>/dev/null) -eq 1 ]; then
        high_gas=$(echo "scale=3; $avg_gas * 1.1" | bc 2>/dev/null || echo "0.078")
        echo "🔄 High已增加：$high_gas" >&2
    fi

    # 格式化为3位小数
    low_gas=$(printf "%.3f" "$low_gas" 2>/dev/null || echo "$low_gas")
    avg_gas=$(printf "%.3f" "$avg_gas" 2>/dev/null || echo "$avg_gas")
    high_gas=$(printf "%.3f" "$high_gas" 2>/dev/null || echo "$high_gas")

    # 删除多余零
    low_gas=$(echo "$low_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.064/')
    avg_gas=$(echo "$avg_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.071/')
    high_gas=$(echo "$high_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.078/')

    echo "✅ 最终值：Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    echo "$low_gas $avg_gas $high_gas"
    return 0
}

# 带自动更新的Gas选择函数
select_gas_price() {
    local choice=""
    local update_count=0
    local start_time=$(date '+%H:%M:%S')

    # 初始标题显示
    clear
    echo -e ${GREEN} "💸 发送ETH" ${NC}
    echo "========================================"
    echo "⛽ 选择Gas费用"
    echo "========================================"
    echo -e "${BLUE} 🕒 开始时间：$start_time${NC}"
    echo -e "${CYAN}🌐 来源：Etherscan Gas Tracker${NC}"

    echo ""

    while true; do
        # 更新时间
        local current_time=$(date '+%H:%M:%S')

        # 获取价格
        local prices=$(get_gas_prices 2>/dev/null)
        local current_low=$(echo "$prices" | awk '{print $1}')
        local current_avg=$(echo "$prices" | awk '{print $2}')
        local current_high=$(echo "$prices" | awk '{print $3}')

        # 计算手续费
        local current_low_fee=$(calculate_fee "$current_low")
        local current_avg_fee=$(calculate_fee "$current_avg")
        local current_high_fee=$(calculate_fee "$current_high")

        # 格式化为网站样式（8位小数）
        local current_low_formatted=$(format_eth_fixed "$current_low_fee")
        local current_avg_formatted=$(format_eth_fixed "$current_avg_fee")
        local current_high_formatted=$(format_eth_fixed "$current_high_fee")

        # 将光标上移8行
        tput cup 7 0

        # 清除并更新行
        tput el
        echo -e "${DARK_WHITE}🕒 当前时间：$current_time${NC}"
        tput el
        echo -e "${YELLOW}🔄 更新次数：$((++update_count))${NC}"
        tput el
        echo ""
        tput el
        printf "${LIGHT_GREEN}   1. 🐢 低费用      - %s Gwei ≈ %s ETH${NC}\n" "$current_low" "$current_low_formatted" 
        tput el
        printf "${GREEN}   2. 🚶 中等费用    - %s Gwei ≈ %s ETH${NC}\n" "$current_avg" "$current_avg_formatted"
        tput el
        printf "${RED}   3. 🏎  高费用      - %s Gwei ≈ %s ETH${NC}\n" "$current_high" "$current_high_formatted"
        tput el
        echo -e "${GOLD}   4. ✏  手动输入${NC}"
        tput el
        echo -e "${RED}   q. ❌ 退出${NC}"
        tput el

        # 等待输入，超时1秒
        if read -t 1 -n 1 choice 2>/dev/null; then
            echo ""
            case $choice in
                1)
                    GAS_PRICE_GWEI="$current_low"
                    GAS_FEE_ETH="$current_low_fee"
                    GAS_FEE_FORMATTED="$current_low_formatted"
                   echo -e "${LIGHT_GREEN}✅ 已选择低费用：${NC} ${GOLD}$current_low Gwei${NC} ≈ ${CYAN}$current_low_formatted ETH${NC}"
                   break
                    ;;
                2)
                    GAS_PRICE_GWEI="$current_avg"
                    GAS_FEE_ETH="$current_avg_fee"
                    GAS_FEE_FORMATTED="$current_avg_formatted"
                    echo -e "${GREEN}✅ 已选择中等费用：${NC} ${GOLD}$current_avg Gwei${NC} ≈ ${CYAN}$current_avg_formatted ETH${NC}"  
                    break
                    ;;
                3)
                    GAS_PRICE_GWEI="$current_high"
                    GAS_FEE_ETH="$current_high_fee"
                    GAS_FEE_FORMATTED="$current_high_formatted"
                    echo -e "${RED}✅ 已选择高费用：${NC} ${GOLD}$current_high Gwei${NC} ≈ ${CYAN}$current_high_formatted ETH${NC}"
                    break
                    ;;
                4)
                    echo ""
                    echo "💡 当前价格："
                    printf "   🐢 低：     %s Gwei ≈ %s ETH\n" "$current_low" "$current_low_formatted"
                    printf "   🚶 中等：    %s Gwei ≈ %s ETH\n" "$current_avg" "$current_avg_formatted"
                    printf "   🏎  高：    %s Gwei ≈ %s ETH\n" "$current_high" "$current_high_formatted"
                    echo ""

                    while true; do
                        read -p "请输入Gas价格（Gwei）：" manual_gas
                        manual_gas=$(clean_number "$manual_gas")

                        if [[ "$manual_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            GAS_PRICE_GWEI="$manual_gas"
                            GAS_FEE_ETH=$(calculate_fee "$manual_gas")
                            GAS_FEE_FORMATTED=$(format_eth_fixed "$GAS_FEE_ETH")
                            echo "✅ 已设置Gas价格：$manual_gas Gwei ≈ $GAS_FEE_FORMATTED ETH"
                            break 2
                        else
                            echo "❌ 格式错误。示例：0.064 或 1.50"
                        fi
                    done
                    ;;
                q)
                    echo "退出..."
                    exit 0
                    ;;
            esac
        fi
    done
}

# 选择发送金额函数
select_amount() {
    local choice=""

    echo ""
    echo -e "${SOFT_GOLD}💰 选择发送金额${NC}"
    echo "========================================"
    echo -e "${GREEN}可用余额：${NC}   ${BRIGHT_GOLD}$MAX_SEND_ETH_FORMATTED${NC} ${PURPLE}ETH${NC}"
    echo -e "${RED}手续费：${NC}     ${GOLD}$GAS_FEE_FORMATTED ETH${NC}" 
    echo -e "${YELLOW}最大可发送：${NC} ${LIGHT_GREEN}$MAX_SEND_ETH_FORMATTED ETH${NC}"

    echo ""
  while true; do
    echo -e "${CYAN}选择金额：${NC}"
    echo -e "${LIGHT_GREEN}   1. 📤 发送全部金额 ${NC} ${GOLD}(最大)${NC}"
    echo -e "${LIGHT_ORANGE}   2. ✏  手动输入金额${NC}"
    read -p "$(echo -e "${YELLOW}请选择 (1-2)：${NC}")" choice

    case $choice in
            1)
                SEND_WEI="$MAX_SEND_WEI"
                SEND_ETH="$MAX_SEND_ETH"
                SEND_ETH_FORMATTED="$MAX_SEND_ETH_FORMATTED"
                echo "✅ 已选择发送全部金额：$SEND_ETH_FORMATTED ETH"
                break
                ;;
            2)
                while true; do
                    read -p "请输入要发送的ETH金额：" amount_eth
                    amount_eth=$(clean_number "$amount_eth")

                    if [[ ! "$amount_eth" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "❌ 格式错误。示例：0.001 或 0.5"
                        continue
                    fi

                    # 转换为Wei
                    local amount_wei=$(echo "$amount_eth * 1000000000000000000" | bc 2>/dev/null)

                    if [ -z "$amount_wei" ] || [ "$amount_wei" = "0" ]; then
                        echo "❌ 金额太小"
                        continue
                    fi

                    if [ $(echo "$amount_wei > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ 余额不足！"
                        continue
                    fi

                    local total_needed=$(echo "$amount_wei + $GAS_FEE_WEI" | bc)
                    if [ $(echo "$total_needed > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ 余额不足以支付手续费！"
                        continue
                    fi

                    SEND_WEI="$amount_wei"
                    SEND_ETH="$amount_eth"
                    SEND_ETH_FORMATTED=$(format_eth_fixed "$amount_eth")
                    echo "✅ 金额已设置：$SEND_ETH_FORMATTED ETH"
                    break
                done
                break
                ;;
            *)
                echo "❌ 无效选择"
                ;;
        esac
    done
}

# === 主脚本 ===

# 1. 获取发送方余额
echo "📊 获取余额..."
BALANCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$FROM\",\"latest\"],\"id\":1}")

if [ $? -ne 0 ] || [ -z "$BALANCE_RESP" ]; then
    echo "❌ 获取余额失败"
    exit 1
fi

BALANCE_HEX=$(echo "$BALANCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BALANCE_HEX" ]; then
    echo "❌ 无法获取余额"
    exit 1
fi

# 十六进制转十进制
BALANCE_WEI=$(echo "ibase=16; $(echo ${BALANCE_HEX#0x} | tr '[:lower:]' '[:upper:]')" | bc)
BALANCE_ETH=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
BALANCE_ETH_FORMATTED=$(format_eth_fixed "$BALANCE_ETH")

echo -e "${LIGHT_CYAN}✅ 余额：${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
# 2. 带自动更新的Gas选择
select_gas_price

# 3. Gwei转换为Wei
GAS_PRICE_WEI=$(echo "$GAS_PRICE_GWEI * 1000000000" | bc 2>/dev/null)
GAS_PRICE_WEI_INT=$(echo "scale=0; $GAS_PRICE_WEI / 1" | bc)
GAS_PRICE_HEX=$(printf "0x%x" "$GAS_PRICE_WEI_INT" 2>/dev/null)

GAS_LIMIT=21000
GAS_FEE_WEI=$(echo "$GAS_PRICE_WEI * $GAS_LIMIT" | bc 2>/dev/null)

echo ""
echo -e "${GAS}💰 交易手续费：${NC}${GOLD}$GAS_FEE_FORMATTED ETH${NC}"

# 4. 计算最大可发送金额
MAX_SEND_WEI=$(echo "$BALANCE_WEI - $GAS_FEE_WEI" | bc)
MAX_SEND_ETH=$(echo "scale=18; $MAX_SEND_WEI / 1000000000000000000" | bc)
MAX_SEND_ETH_FORMATTED=$(format_eth_fixed "$MAX_SEND_ETH")

# 通过bc检查
if [ $(echo "$MAX_SEND_WEI <= 0" | bc) -eq 1 ]; then
    echo ""
    echo "❌ 错误：余额不足以支付手续费！"
    exit 1
fi

# 5. 选择发送金额
select_amount

# 转换为ETH
SEND_ETH=$(echo "scale=18; $SEND_WEI / 1000000000000000000" | bc)
SEND_WEI_INT=$(echo "scale=0; $SEND_WEI / 1" | bc)
SEND_HEX=$(printf "0x%x" "$SEND_WEI_INT")
echo -e "   ${LIGHT_CYAN}余额：${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
echo -e "${YELLOW}📈 计算：${NC}"
REMAINING_ETH=$(echo "$BALANCE_ETH - $SEND_ETH - $GAS_FEE_ETH" | bc)
REMAINING_FORMATTED=$(format_eth_fixed "$REMAINING_ETH")
echo -e "   ${LIGHT_GREEN}发送：${NC}   ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}手续费：${NC} ${GAS}$GAS_FEE_FORMATTED ETH${NC}"
echo -e "   ${PURPLE}剩余：${NC}   ${WHITE}$REMAINING_FORMATTED ETH${NC}"

# 6. 获取nonce
echo ""
echo -e "${CYAN}🔢 获取nonce...${NC}"
NONCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$FROM\",\"pending\"],\"id\":1}")

NONCE_HEX=$(echo "$NONCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo -e "${WHITE}✅ Nonce：${NC}${PURPLE}$NONCE_HEX${NC}"

# 7. 确认
echo ""
echo -e "${YELLOW}📋 确认信息：${NC}"
echo -e "   ${CYAN}发送方 - ETH：${NC}${YELLOW}$FROM${NC}"
echo -e "   ${CYAN}接收方 - ETH：${NC}${MAGENTA}$TO${NC}"
echo -e "   ${LIGHT_GREEN}发送金额：${NC} ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}手续费：${NC}   ${GAS}$GAS_FEE_FORMATTED ETH${NC} ${WHITE}(Gas：${NC} ${PURPLE}$GAS_PRICE_GWEI Gwei${NC}${WHITE})${NC}"
echo ""

read -p "$(echo -e "${YELLOW}确认发送？(y/n)：${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 已取消"
    exit 0
fi

# 8. 创建交易
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
echo -e "${BRIGHT_BLUE}📝 发送到Clef进行签名...${NC}"

# 9. 签名
SIGN_RESP=$(curl -s "$CLEF" \
  -H "Content-Type: application/json" \
  -d "$TX_JSON")

RAW_TX=$(echo "$SIGN_RESP" | grep -o '"raw":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RAW_TX" ]; then
    echo "❌ 签名失败"
    echo "$SIGN_RESP" | jq .
    exit 1
fi

echo "✅ 交易已签名！"

# 10. 发送
echo ""
echo -e "${CYAN}🚀 发送到网络...${NC}"
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
    echo -e "${BRIGHT_GREEN}🎉 成功！交易已发送！${NC}"
    echo -e "🔗 哈希：${BRIGHT_YELLOW}$TX_HASH${NC}"
    echo -e "${CYAN}🌐 浏览器：${BRIGHT_BLUE}https://etherscan.io/tx/$TX_HASH${NC}"

else
    echo "❌ 发送失败："
    echo "$RESULT" | jq .

    echo "$RAW_TX" > raw_tx_$(date +%s).txt
    echo "💾 原始交易已保存"
fi
