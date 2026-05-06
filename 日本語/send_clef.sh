# 基本色
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
# 追加色 (256色)
BRIGHT_BLUE="\e[94m"
NC="\e[0m"
BRIGHT_YELLOW="\e[93m"
CYAN="\e[36m"
BRIGHT_BLUE="\e[94m"
# 明るいゴールド系
# 最大輝度の色合い（226-229が最大）
GOLD_226='\033[38;5;226m'  # 純粋な明るい黄色
GOLD_227='\033[38;5;227m'  # ニュアンスのある黄色
GOLD_228='\033[38;5;228m'  # 明るい黄色
GOLD_221='\033[38;5;221m'  # ゴールドがかった色
GOLD_220='\033[38;5;220m'  # クラシックなゴールド
BRIGHT_GOLD='\033[38;5;226m'  # 最も明るい黄色/ゴールド
LIGHT_GREEN='\033[1;32m'        # 明るい緑
PURPLE='\033[0;35m'             # 紫
GOLD='\033[38;5;220m'           # 本物のゴールド
LIGHT_GOLD='\033[38;5;228m'     # 明るいゴールド
SOFT_GOLD='\033[38;5;223m'      # 柔らかいゴールド
PALE_GOLD='\033[38;5;230m'      # 淡いゴールド
DARK_WHITE='\033[38;5;250m'     # ダークホワイト（灰色がかった）
LIGHT_ORANGE='\033[38;5;214m'   # 明るいオレンジ
PINK='\033[38;5;205m'           # ピンク
PURPLE_LIGHT='\033[38;5;135m'   # 明るい紫
LIGHT_CYAN='\033[1;36m'      # 明るいシアン

#!/bin/bash
# 英語ロケールを設定（正しい数値のため）
export LC_NUMERIC="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# 設定
FROM="0xA351D597540b27eD5327425D29d1526c17C3F026"
TO="0xdD91aF12e4464e7412Fd1084460f407e7f9b0fd1"
CLEF="http://localhost:8550"
RPC="https://1rpc.io/eth"

echo -e ${GREEN} "💸 ETH送金" ${NC}
echo "========================================"

# 数値クレンジング関数
clean_number() {
    echo "$1" | tr -d ',' | sed 's/[^0-9.]//g'
}

# ETH書式設定関数（ウェブサイトと同様、常に8桁）
format_eth_fixed() {
    local num=$(clean_number "$1")
    if [ -z "$num" ] || [ "$num" = "0" ]; then
        echo "0.00000000"
    else
        # 常に小数点以下8桁
        LANG=C printf "%0.8f" "$num" 2>/dev/null
    fi
}

# 手数料計算関数（ETH単位）
calculate_fee() {
    local gas_gwei=$(clean_number "$1")
    if [[ ! "$gas_gwei" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$gas_gwei" ]; then
        echo "0"
        return
    fi

    # 正確な計算
    echo "scale=12; $gas_gwei * 21000 / 1000000000" | bc 2>/dev/null
}

# EtherScanから正確なガス価格を取得する関数（修正済みロジック）
get_gas_prices() {
    # gastrackerのHTMLページを取得
    echo "🌐 EtherScanから最新データを取得中..." >&2
    local html=$(curl -s --max-time 10 "https://etherscan.io/gastracker" 2>/dev/null)

    if [ -z "$html" ]; then
        echo "❌ ページの読み込みに失敗しました" >&2
        echo "0.064 0.071 0.078"
        return 1
    fi

    local low_gas="" avg_gas="" high_gas=""

    # 方法1: "X.XXX gwei"形式のすべての値を検索
    local all_gwei_values=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+[[:space:]]*gwei' | head -10)

    echo "🔍 Gwei値が見つかりました: $all_gwei_values" >&2

    # 数値を抽出し昇順にソート
    local number_list=$(echo "$all_gwei_values" | grep -o '[0-9]\+\.[0-9]\+' | sort -n | uniq)

    # 配列に変換
    local numbers=()
    while read -r num; do
        numbers+=("$num")
    done <<< "$number_list"

    local count=${#numbers[@]}

    echo "🔍 $count 個の一意な値が見つかりました: ${numbers[*]}" >&2

    if [ $count -ge 3 ]; then
        # 3つ以上の値がある場合、最初、中間、最後を取得
        low_gas="${numbers[0]}"

        # 中央値
        local mid_index=$(( (count - 1) / 2 ))
        avg_gas="${numbers[$mid_index]}"

        # 最高値
        high_gas="${numbers[-1]}"

        echo "✅ ソート済み値を使用: Low=$low_gas, Mid=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 2 ]; then
        # 2つの値の場合
        low_gas="${numbers[0]}"
        high_gas="${numbers[1]}"
        avg_gas=$(echo "scale=3; (${numbers[0]} + ${numbers[1]}) / 2" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 2つの値: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 1 ]; then
        # 1つの値のみの場合
        low_gas="${numbers[0]}"
        avg_gas="${numbers[0]}"
        high_gas=$(echo "scale=3; ${numbers[0]} * 1.1" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 1つの値: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    fi

    # 方法2: 特定のLow/Average/Highカードを検索
    if [ -z "$low_gas" ] || [ -z "$avg_gas" ] || [ -z "$high_gas" ]; then
        # カードブロックを検索
        local card_section=$(echo "$html" | grep -o 'card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Low\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Average\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*High' -A 20 | head -200)

        if [ -n "$card_section" ]; then
            # カードから価格を抽出
            low_gas=$(echo "$card_section" | grep -A 10 'Low' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            avg_gas=$(echo "$card_section" | grep -A 10 'Average' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            high_gas=$(echo "$card_section" | grep -A 10 'High' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        fi
    fi

    # 値をクレンジング
    low_gas=$(clean_number "$low_gas")
    avg_gas=$(clean_number "$avg_gas")
    high_gas=$(clean_number "$high_gas")

    echo "🔍 解析後: Low='$low_gas', Avg='$avg_gas', High='$high_gas'" >&2

    # 値が見つからないか無効な場合、デフォルト値を使用
    if [[ ! "$low_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$low_gas" ]; then
        low_gas="0.064"
        echo "⚠️  Lowが見つからないため、デフォルト値を使用: $low_gas" >&2
    fi

    if [[ ! "$avg_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$avg_gas" ]; then
        avg_gas="0.071"
        echo "⚠️  Avgが見つからないため、デフォルト値を使用: $avg_gas" >&2
    fi

    if [[ ! "$high_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$high_gas" ]; then
        high_gas="0.078"
        echo "⚠️  Highが見つからないため、デフォルト値を使用: $high_gas" >&2
    fi

    # Low ≤ Avg ≤ High を保証
    # 配列を作成してソート
    local sorted=($low_gas $avg_gas $high_gas)

    # bcを使用して数値比較
    local low_num=$(echo "$low_gas" | bc -l 2>/dev/null || echo "0")
    local avg_num=$(echo "$avg_gas" | bc -l 2>/dev/null || echo "0")
    local high_num=$(echo "$high_gas" | bc -l 2>/dev/null || echo "0")

    # 値のソート
    if [ $(echo "$low_num > $avg_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$low_gas"
        low_gas="$avg_gas"
        avg_gas="$temp"
        echo "🔄 順序修正: LowとAvgを交換しました" >&2
    fi

    if [ $(echo "$avg_num > $high_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$avg_gas"
        avg_gas="$high_gas"
        high_gas="$temp"
        echo "🔄 順序修正: AvgとHighを交換しました" >&2
    fi

    # highが実際にavgより大きいことを確認
    if [ $(echo "$high_gas <= $avg_gas" | bc -l 2>/dev/null) -eq 1 ]; then
        high_gas=$(echo "scale=3; $avg_gas * 1.1" | bc 2>/dev/null || echo "0.078")
        echo "🔄 Highを増加: $high_gas" >&2
    fi

    # 3桁にフォーマット
    low_gas=$(printf "%.3f" "$low_gas" 2>/dev/null || echo "$low_gas")
    avg_gas=$(printf "%.3f" "$avg_gas" 2>/dev/null || echo "$avg_gas")
    high_gas=$(printf "%.3f" "$high_gas" 2>/dev/null || echo "$high_gas")

    # 余分なゼロを削除
    low_gas=$(echo "$low_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.064/')
    avg_gas=$(echo "$avg_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.071/')
    high_gas=$(echo "$high_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.078/')

    echo "✅ 最終値: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    echo "$low_gas $avg_gas $high_gas"
    return 0
}

# 手数料選択関数（自動更新付き）
select_gas_price() {
    local choice=""
    local update_count=0
    local start_time=$(date '+%H:%M:%S')

    # ヘッダーの初期表示
    clear
    echo -e ${GREEN} "💸 ETH送金" ${NC}
    echo "========================================"
    echo "⛽ 手数料選択"
    echo "========================================"
    echo -e "${BLUE} "🕒 開始時間: $start_time"${NC}"
    echo -e "${CYAN}🌐 ソース: Etherscan ガストラッカー${NC}"

    echo ""

    while true; do
        # 時間更新
        local current_time=$(date '+%H:%M:%S')

        # 価格取得
        local prices=$(get_gas_prices 2>/dev/null)
        local current_low=$(echo "$prices" | awk '{print $1}')
        local current_avg=$(echo "$prices" | awk '{print $2}')
        local current_high=$(echo "$prices" | awk '{print $3}')

        # 手数料計算
        local current_low_fee=$(calculate_fee "$current_low")
        local current_avg_fee=$(calculate_fee "$current_avg")
        local current_high_fee=$(calculate_fee "$current_high")

        # ウェブサイトと同様に書式設定（8桁）
        local current_low_formatted=$(format_eth_fixed "$current_low_fee")
        local current_avg_formatted=$(format_eth_fixed "$current_avg_fee")
        local current_high_formatted=$(format_eth_fixed "$current_high_fee")

        # カーソルを8行上に移動
        tput cup 7 0

        # 行をクリアして更新
        tput el
        echo -e "${DARK_WHITE}🕒 現在時刻: $current_time${NC}"
        tput el
        echo -e "${YELLOW}🔄 更新回数: $((++update_count))${NC}"
        tput el
        echo ""
        tput el
        printf "${LIGHT_GREEN}   1. 🐢 低い     - %s Gwei ≈ %s ETH${NC}\n" "$current_low" "$current_low_formatted" 
        tput el
        printf "${GREEN}   2. 🚶 中間     - %s Gwei ≈ %s ETH${NC}\n" "$current_avg" "$current_avg_formatted"
        tput el
        printf "${RED}   3. 🏎  高い     - %s Gwei ≈ %s ETH${NC}\n" "$current_high" "$current_high_formatted"
        tput el
        echo -e "${GOLD}   4. ✏  手動入力${NC}"
        tput el
        echo -e "${RED}   q. ❌ 終了${NC}"
        tput el

        # 1秒のタイムアウトで入力を待機
        if read -t 1 -n 1 choice 2>/dev/null; then
            echo ""
            case $choice in
                1)
                    GAS_PRICE_GWEI="$current_low"
                    GAS_FEE_ETH="$current_low_fee"
                    GAS_FEE_FORMATTED="$current_low_formatted"
                   echo -e "${LIGHT_GREEN}✅ 低い手数料を選択:${NC} ${GOLD}$current_low Gwei${NC} ≈ ${CYAN}$current_low_formatted ETH${NC}"
                   break
                    ;;
                2)
                    GAS_PRICE_GWEI="$current_avg"
                    GAS_FEE_ETH="$current_avg_fee"
                    GAS_FEE_FORMATTED="$current_avg_formatted"
                    echo -e "${GREEN}✅ 中間手数料を選択:${NC} ${GOLD}$current_avg Gwei${NC} ≈ ${CYAN}$current_avg_formatted ETH${NC}"  
                    break
                    ;;
                3)
                    GAS_PRICE_GWEI="$current_high"
                    GAS_FEE_ETH="$current_high_fee"
                    GAS_FEE_FORMATTED="$current_high_formatted"
                    echo -e "${RED}✅ 高い手数料を選択:${NC} ${GOLD}$current_high Gwei${NC} ≈ ${CYAN}$current_high_formatted ETH${NC}"
                    break
                    ;;
                4)
                    echo ""
                    echo "💡 現在の価格:"
                    printf "   🐢 低い:     %s Gwei ≈ %s ETH\n" "$current_low" "$current_low_formatted"
                    printf "   🚶 中間:     %s Gwei ≈ %s ETH\n" "$current_avg" "$current_avg_formatted"
                    printf "   🏎  高い:     %s Gwei ≈ %s ETH\n" "$current_high" "$current_high_formatted"
                    echo ""

                    while true; do
                        read -p "ガス価格をGweiで入力: " manual_gas
                        manual_gas=$(clean_number "$manual_gas")

                        if [[ "$manual_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            GAS_PRICE_GWEI="$manual_gas"
                            GAS_FEE_ETH=$(calculate_fee "$manual_gas")
                            GAS_FEE_FORMATTED=$(format_eth_fixed "$GAS_FEE_ETH")
                            echo "✅ ガス価格設定: $manual_gas Gwei ≈ $GAS_FEE_FORMATTED ETH"
                            break 2
                        else
                            echo "❌ 無効な形式です。例: 0.064 または 1.50"
                        fi
                    done
                    ;;
                q)
                    echo "終了..."
                    exit 0
                    ;;
            esac
        fi
    done
}

# 送金額選択関数
select_amount() {
    local choice=""

    echo ""
    echo -e "${SOFT_GOLD}💰 送金額選択${NC}"
    echo "========================================"
    echo -e "${GREEN}利用可能:${NC} ${BRIGHT_GOLD}$MAX_SEND_ETH_FORMATTED${NC} ${PURPLE}ETH${NC}"
    echo -e "${RED}手数料:${NC}   ${GOLD}$GAS_FEE_FORMATTED ETH${NC}" 
    echo -e "${YELLOW}最大:${NC}     ${LIGHT_GREEN}$MAX_SEND_ETH_FORMATTED ETH${NC}"

    echo ""
  while true; do
    echo -e "${CYAN}金額を選択:${NC}"
    echo -e "${LIGHT_GREEN}   1. 📤 全額送金 ${NC} ${GOLD}(最大)${NC}"
    echo -e "${LIGHT_ORANGE}   2. ✏  手動入力${NC}"
    read -p "$(echo -e "${YELLOW}選択 (1-2): ${NC}")" choice

    case $choice in
            1)
                SEND_WEI="$MAX_SEND_WEI"
                SEND_ETH="$MAX_SEND_ETH"
                SEND_ETH_FORMATTED="$MAX_SEND_ETH_FORMATTED"
                echo "✅ 全額送金を選択: $SEND_ETH_FORMATTED ETH"
                break
                ;;
            2)
                while true; do
                    read -p "送金額をETHで入力: " amount_eth
                    amount_eth=$(clean_number "$amount_eth")

                    if [[ ! "$amount_eth" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "❌ 無効な形式です。例: 0.001 または 0.5"
                        continue
                    fi

                    # Weiに変換
                    local amount_wei=$(echo "$amount_eth * 1000000000000000000" | bc 2>/dev/null)

                    if [ -z "$amount_wei" ] || [ "$amount_wei" = "0" ]; then
                        echo "❌ 金額が小さすぎます"
                        continue
                    fi

                    if [ $(echo "$amount_wei > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ 残高不足！"
                        continue
                    fi

                    local total_needed=$(echo "$amount_wei + $GAS_FEE_WEI" | bc)
                    if [ $(echo "$total_needed > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ 手数料が不足します！"
                        continue
                    fi

                    SEND_WEI="$amount_wei"
                    SEND_ETH="$amount_eth"
                    SEND_ETH_FORMATTED=$(format_eth_fixed "$amount_eth")
                    echo "✅ 金額設定: $SEND_ETH_FORMATTED ETH"
                    break
                done
                break
                ;;
            *)
                echo "❌ 無効な選択"
                ;;
        esac
    done
}

# === メインスクリプト ===

# 1. 送信者の残高を取得
echo "📊 残高取得中..."
BALANCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$FROM\",\"latest\"],\"id\":1}")

if [ $? -ne 0 ] || [ -z "$BALANCE_RESP" ]; then
    echo "❌ 残高取得エラー"
    exit 1
fi

BALANCE_HEX=$(echo "$BALANCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BALANCE_HEX" ]; then
    echo "❌ 残高を取得できませんでした"
    exit 1
fi

# hexを10進数に変換
BALANCE_WEI=$(echo "ibase=16; $(echo ${BALANCE_HEX#0x} | tr '[:lower:]' '[:upper:]')" | bc)
BALANCE_ETH=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
BALANCE_ETH_FORMATTED=$(format_eth_fixed "$BALANCE_ETH")

echo -e "${LIGHT_CYAN}✅ 残高:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
# 2. 手数料選択（自動更新付き）
select_gas_price

# 3. GweiをWeiに変換
GAS_PRICE_WEI=$(echo "$GAS_PRICE_GWEI * 1000000000" | bc 2>/dev/null)
GAS_PRICE_WEI_INT=$(echo "scale=0; $GAS_PRICE_WEI / 1" | bc)
GAS_PRICE_HEX=$(printf "0x%x" "$GAS_PRICE_WEI_INT" 2>/dev/null)

GAS_LIMIT=21000
GAS_FEE_WEI=$(echo "$GAS_PRICE_WEI * $GAS_LIMIT" | bc 2>/dev/null)

echo ""
echo -e "${GAS}💰 トランザクション手数料:${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}"

# 4. 最大送金額を計算
MAX_SEND_WEI=$(echo "$BALANCE_WEI - $GAS_FEE_WEI" | bc)
MAX_SEND_ETH=$(echo "scale=18; $MAX_SEND_WEI / 1000000000000000000" | bc)
MAX_SEND_ETH_FORMATTED=$(format_eth_fixed "$MAX_SEND_ETH")

# bcで確認
if [ $(echo "$MAX_SEND_WEI <= 0" | bc) -eq 1 ]; then
    echo ""
    echo "❌ エラー: 手数料を支払うにも残高が少なすぎます！"
    exit 1
fi

# 5. 送金額選択
select_amount

# ETHに変換
SEND_ETH=$(echo "scale=18; $SEND_WEI / 1000000000000000000" | bc)
SEND_WEI_INT=$(echo "scale=0; $SEND_WEI / 1" | bc)
SEND_HEX=$(printf "0x%x" "$SEND_WEI_INT")
echo -e "   ${LIGHT_CYAN}残高:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
echo -e "${YELLOW}📈 計算:${NC}"
REMAINING_ETH=$(echo "$BALANCE_ETH - $SEND_ETH - $GAS_FEE_ETH" | bc)
REMAINING_FORMATTED=$(format_eth_fixed "$REMAINING_ETH")
echo -e "   ${LIGHT_GREEN}送金:${NC}    ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}手数料:${NC}  ${GAS}$GAS_FEE_FORMATTED ETH${NC}"
echo -e "   ${PURPLE}残り:${NC}    ${WHITE}$REMAINING_FORMATTED ETH${NC}"

# 6. nonce取得
echo ""
echo -e "${CYAN}🔢 nonce取得中...${NC}"
NONCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$FROM\",\"pending\"],\"id\":1}")

NONCE_HEX=$(echo "$NONCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo -e "${WHITE}✅ Nonce:${NC} ${PURPLE}$NONCE_HEX${NC}"

# 7. 確認
echo ""
echo -e "${YELLOW}📋 確認:${NC}"
echo -e "   ${CYAN}送信者 - ETH:${NC} ${YELLOW}$FROM${NC}"
echo -e "   ${CYAN}送信先 - ETH:${NC} ${MAGENTA}$TO${NC}"
echo -e "   ${LIGHT_GREEN}送金:${NC}   ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}手数料:${NC} ${GAS}$GAS_FEE_FORMATTED ETH${NC} ${WHITE}(Gas:${NC} ${PURPLE}$GAS_PRICE_GWEI Gwei${NC}${WHITE})${NC}"
echo ""

read -p "$(echo -e "${YELLOW}送金を確認しますか？ (y/n): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ キャンセルされました"
    exit 0
fi

# 8. トランザクション作成
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
echo -e "${BRIGHT_BLUE}📝 Clefに署名依頼を送信中...${NC}"

# 9. 署名
SIGN_RESP=$(curl -s "$CLEF" \
  -H "Content-Type: application/json" \
  -d "$TX_JSON")

RAW_TX=$(echo "$SIGN_RESP" | grep -o '"raw":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RAW_TX" ]; then
    echo "❌ 署名エラー"
    echo "$SIGN_RESP" | jq .
    exit 1
fi

echo "✅ トランザクション署名完了！"

# 10. 送信
echo ""
echo -e "${CYAN}🚀 ネットワークに送信中...${NC}"
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
    echo -e "${BRIGHT_GREEN}🎉 成功！トランザクションが送信されました！${NC}"
    echo -e "🔗 Hash: ${BRIGHT_YELLOW}$TX_HASH${NC}"
    echo -e "${CYAN}🌐 エクスプローラ: ${BRIGHT_BLUE}https://etherscan.io/tx/$TX_HASH${NC}"

else
    echo "❌ 送信エラー:"
    echo "$RESULT" | jq .

    echo "$RAW_TX" > raw_tx_$(date +%s).txt
    echo "💾 Rawトランザクションを保存しました"
fi
