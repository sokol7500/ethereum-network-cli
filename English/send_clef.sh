#!/bin/bash
# Set English locale for correct numbers
export LC_NUMERIC="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Colors
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
# Additional colors (256 colors)
BRIGHT_BLUE="\e[94m"
BRIGHT_YELLOW="\e[93m"
# Bright gold shades
GOLD_226='\033[38;5;226m'  # Pure bright yellow
GOLD_227='\033[38;5;227m'  # Yellow with tint
GOLD_228='\033[38;5;228m'  # Light yellow
GOLD_221='\033[38;5;221m'  # Golden
GOLD_220='\033[38;5;220m'  # Classic gold
BRIGHT_GOLD='\033[38;5;226m'  # Brightest yellow/gold
GOLD='\033[38;5;220m'           # Real gold
LIGHT_GOLD='\033[38;5;228m'     # Light gold
SOFT_GOLD='\033[38;5;223m'      # Soft gold
PALE_GOLD='\033[38;5;230m'      # Pale gold
DARK_WHITE='\033[38;5;250m'     # Dark white (grayish)
LIGHT_ORANGE='\033[38;5;214m'   # Light orange
PINK='\033[38;5;205m'           # Pink
PURPLE_LIGHT='\033[38;5;135m'   # Light purple

# Settings
FROM="0xdD91aF12e4464e7412Fd1084460f407e7f9b0fd1"
TO="0xA351D597540b27eD5327425D29d1526c17C3F026"
CLEF="http://localhost:8550"
RPC="https://1rpc.io/eth"

echo -e "${GREEN}💸 Sending ETH${NC}"
echo "========================================"

# Number cleaning function
clean_number() {
    echo "$1" | tr -d ',' | sed 's/[^0-9.]//g'
}

# ETH formatting function like on website (ALWAYS 8 decimals)
format_eth_fixed() {
    local num=$(clean_number "$1")
    if [ -z "$num" ] || [ "$num" = "0" ]; then
        echo "0.00000000"
    else
        # ALWAYS 8 decimal places
        LANG=C printf "%0.8f" "$num" 2>/dev/null
    fi
}

# Function to calculate fee in ETH
calculate_fee() {
    local gas_gwei=$(clean_number "$1")
    if [[ ! "$gas_gwei" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$gas_gwei" ]; then
        echo "0"
        return
    fi

    # Exact calculation
    echo "scale=12; $gas_gwei * 21000 / 1000000000" | bc 2>/dev/null
}

# Function to get accurate gas prices from Etherscan (FIXED LOGIC)
get_gas_prices() {
    # Get gastracker HTML page
    echo "🌐 Getting current data from Etherscan..." >&2
    local html=$(curl -s --max-time 10 "https://etherscan.io/gastracker" 2>/dev/null)

    if [ -z "$html" ]; then
        echo "❌ Failed to load page" >&2
        echo "0.064 0.071 0.078"
        return 1
    fi

    local low_gas="" avg_gas="" high_gas=""

    # Method 1: Find all values in format "X.XXX gwei"
    local all_gwei_values=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+[[:space:]]*gwei' | head -10)

    echo "🔍 Gwei values found: $all_gwei_values" >&2

    # Extract numbers and sort ascending
    local number_list=$(echo "$all_gwei_values" | grep -o '[0-9]\+\.[0-9]\+' | sort -n | uniq)

    # Convert to array
    local numbers=()
    while read -r num; do
        numbers+=("$num")
    done <<< "$number_list"

    local count=${#numbers[@]}

    echo "🔍 Found $count unique values: ${numbers[*]}" >&2

    if [ $count -ge 3 ]; then
        # If 3+ values, take first, middle and last
        low_gas="${numbers[0]}"

        # Middle value (median)
        local mid_index=$(( (count - 1) / 2 ))
        avg_gas="${numbers[$mid_index]}"

        # Highest value
        high_gas="${numbers[-1]}"

        echo "✅ Using sorted values: Low=$low_gas, Mid=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 2 ]; then
        # If 2 values
        low_gas="${numbers[0]}"
        high_gas="${numbers[1]}"
        avg_gas=$(echo "scale=3; (${numbers[0]} + ${numbers[1]}) / 2" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 2 values: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    elif [ $count -eq 1 ]; then
        # If only 1 value
        low_gas="${numbers[0]}"
        avg_gas="${numbers[0]}"
        high_gas=$(echo "scale=3; ${numbers[0]} * 1.1" | bc 2>/dev/null || echo "${numbers[0]}")

        echo "✅ 1 value: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    fi

    # Method 2: Look in specific Low/Average/High cards
    if [ -z "$low_gas" ] || [ -z "$avg_gas" ] || [ -z "$high_gas" ]; then
        # Look for card blocks
        local card_section=$(echo "$html" | grep -o 'card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Low\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*Average\|card h-100[^>]*>[^<]*<div class="card-body"[^>]*>[^<]*<h3[^>]*>[^<]*High' -A 20 | head -200)

        if [ -n "$card_section" ]; then
            # Extract prices from cards
            low_gas=$(echo "$card_section" | grep -A 10 'Low' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            avg_gas=$(echo "$card_section" | grep -A 10 'Average' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            high_gas=$(echo "$card_section" | grep -A 10 'High' | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        fi
    fi

    # Clean values
    low_gas=$(clean_number "$low_gas")
    avg_gas=$(clean_number "$avg_gas")
    high_gas=$(clean_number "$high_gas")

    echo "🔍 After parsing: Low='$low_gas', Avg='$avg_gas', High='$high_gas'" >&2

    # If values not found or invalid, use default values
    if [[ ! "$low_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$low_gas" ]; then
        low_gas="0.064"
        echo "⚠️  Low not found, using: $low_gas" >&2
    fi

    if [[ ! "$avg_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$avg_gas" ]; then
        avg_gas="0.071"
        echo "⚠️  Avg not found, using: $avg_gas" >&2
    fi

    if [[ ! "$high_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ -z "$high_gas" ]; then
        high_gas="0.078"
        echo "⚠️  High not found, using: $high_gas" >&2
    fi

    # GUARANTEE THAT Low ≤ Avg ≤ High
    # Create array and sort
    local sorted=($low_gas $avg_gas $high_gas)

    # Use bc for numeric comparison
    local low_num=$(echo "$low_gas" | bc -l 2>/dev/null || echo "0")
    local avg_num=$(echo "$avg_gas" | bc -l 2>/dev/null || echo "0")
    local high_num=$(echo "$high_gas" | bc -l 2>/dev/null || echo "0")

    # Sort values
    if [ $(echo "$low_num > $avg_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$low_gas"
        low_gas="$avg_gas"
        avg_gas="$temp"
        echo "🔄 Order fixed: Low and Avg swapped" >&2
    fi

    if [ $(echo "$avg_num > $high_num" | bc -l 2>/dev/null) -eq 1 ]; then
        local temp="$avg_gas"
        avg_gas="$high_gas"
        high_gas="$temp"
        echo "🔄 Order fixed: Avg and High swapped" >&2
    fi

    # Make sure high is really greater than avg
    if [ $(echo "$high_gas <= $avg_gas" | bc -l 2>/dev/null) -eq 1 ]; then
        high_gas=$(echo "scale=3; $avg_gas * 1.1" | bc 2>/dev/null || echo "0.078")
        echo "🔄 High increased: $high_gas" >&2
    fi

    # Format to 3 decimals
    low_gas=$(printf "%.3f" "$low_gas" 2>/dev/null || echo "$low_gas")
    avg_gas=$(printf "%.3f" "$avg_gas" 2>/dev/null || echo "$avg_gas")
    high_gas=$(printf "%.3f" "$high_gas" 2>/dev/null || echo "$high_gas")

    # Remove trailing zeros
    low_gas=$(echo "$low_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.064/')
    avg_gas=$(echo "$avg_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.071/')
    high_gas=$(echo "$high_gas" | sed 's/\.0*$//; s/\.$//; s/^$/0.078/')

    echo "✅ Final values: Low=$low_gas, Avg=$avg_gas, High=$high_gas" >&2
    echo "$low_gas $avg_gas $high_gas"
    return 0
}

# Function for fee selection with auto-update
select_gas_price() {
    local choice=""
    local update_count=0
    local start_time=$(date '+%H:%M:%S')

    # Initial header display
    clear
    echo -e "${GREEN}💸 Sending ETH${NC}"
    echo "========================================"
    echo -e "${YELLOW}⛽ FEE SELECTION${NC}"
    echo "========================================"
    echo -e "${BLUE} 🕒 Start time: $start_time${NC}"
    echo -e "${CYAN}🌐 Source: Etherscan Gas Tracker${NC}"
    echo ""

    while true; do
        # Update time
        local current_time=$(date '+%H:%M:%S')

        # Get prices
        local prices=$(get_gas_prices 2>/dev/null)
        local current_low=$(echo "$prices" | awk '{print $1}')
        local current_avg=$(echo "$prices" | awk '{print $2}')
        local current_high=$(echo "$prices" | awk '{print $3}')

        # Calculate fees
        local current_low_fee=$(calculate_fee "$current_low")
        local current_avg_fee=$(calculate_fee "$current_avg")
        local current_high_fee=$(calculate_fee "$current_high")

        # Format LIKE ON WEBSITE (8 decimals)
        local current_low_formatted=$(format_eth_fixed "$current_low_fee")
        local current_avg_formatted=$(format_eth_fixed "$current_avg_fee")
        local current_high_formatted=$(format_eth_fixed "$current_high_fee")

        # Move cursor up 8 lines
        tput cup 8 0

        # Clear and update lines
        tput el
        echo -e "${DARK_WHITE}🕒 Current time: $current_time${NC}"
        tput el
        echo -e "${YELLOW}🔄 Updates: $((++update_count))${NC}"
        tput el
        echo ""
        tput el
               printf "${LIGHT_GREEN}   1. 🐢 Low\t\t- %s Gwei ≈ %s ETH${NC}\n" "$current_low" "$current_low_formatted"
tput el
printf "${GREEN}   2. 🚶 Average\t- %s Gwei ≈ %s ETH${NC}\n" "$current_avg" "$current_avg_formatted"
tput el
printf "${RED}   3. 🏎  High\t\t- %s Gwei ≈ %s ETH${NC}\n" "$current_high" "$current_high_formatted"
        tput el
        echo -e "${GOLD}   4. ✏  Enter manually${NC}"
        tput el
        echo -e "${RED}   q. ❌ Exit${NC}"
        tput el

        # Wait for input with 1 second timeout
        if read -t 1 -n 1 choice 2>/dev/null; then
            echo ""
            case $choice in
                1)
                    GAS_PRICE_GWEI="$current_low"
                    GAS_FEE_ETH="$current_low_fee"
                    GAS_FEE_FORMATTED="$current_low_formatted"
                    echo -e "${LIGHT_GREEN}✅ Low fee selected:${NC} ${GOLD}$current_low Gwei${NC} ≈ ${CYAN}$current_low_formatted ETH${NC}"
                    break
                    ;;
                2)
                    GAS_PRICE_GWEI="$current_avg"
                    GAS_FEE_ETH="$current_avg_fee"
                    GAS_FEE_FORMATTED="$current_avg_formatted"
                    echo -e "${GREEN}✅ Average fee selected:${NC} ${GOLD}$current_avg Gwei${NC} ≈ ${CYAN}$current_avg_formatted ETH${NC}"  
                    break
                    ;;
                3)
                    GAS_PRICE_GWEI="$current_high"
                    GAS_FEE_ETH="$current_high_fee"
                    GAS_FEE_FORMATTED="$current_high_formatted"
                    echo -e "${RED}✅ High fee selected:${NC} ${GOLD}$current_high Gwei${NC} ≈ ${CYAN}$current_high_formatted ETH${NC}"
                    break
                    ;;
                4)
                    echo ""
                    echo "💡 Current prices:"
                    printf "   🐢 Low:       %s Gwei ≈ %s ETH\n" "$current_low" "$current_low_formatted"
                    printf "   🚶 Average:    %s Gwei ≈ %s ETH\n" "$current_avg" "$current_avg_formatted"
                    printf "   🏎  High:      %s Gwei ≈ %s ETH\n" "$current_high" "$current_high_formatted"
                    echo ""

                    while true; do
                        read -p "Enter gas price in Gwei: " manual_gas
                        manual_gas=$(clean_number "$manual_gas")

                        if [[ "$manual_gas" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            GAS_PRICE_GWEI="$manual_gas"
                            GAS_FEE_ETH=$(calculate_fee "$manual_gas")
                            GAS_FEE_FORMATTED=$(format_eth_fixed "$GAS_FEE_ETH")
                            echo "✅ Gas price set: $manual_gas Gwei ≈ $GAS_FEE_FORMATTED ETH"
                            break 2
                        else
                            echo "❌ Invalid format. Example: 0.064 or 1.50"
                        fi
                    done
                    ;;
                q)
                    echo "Exit..."
                    exit 0
                    ;;
            esac
        fi
    done
}

# Function for selecting amount to send
select_amount() {
    local choice=""

    echo ""
    echo -e "${SOFT_GOLD}💰 AMOUNT SELECTION${NC}"
    echo "========================================"
    echo -e "${GREEN}Available:${NC}   ${BRIGHT_GOLD}$MAX_SEND_ETH_FORMATTED${NC} ${PURPLE}ETH${NC}"
    echo -e "${RED}Fee:${NC}         ${GOLD}$GAS_FEE_FORMATTED ETH${NC}" 
    echo -e "${YELLOW}Maximum:${NC}     ${LIGHT_GREEN}$MAX_SEND_ETH_FORMATTED ETH${NC}"
    echo ""

    while true; do
        echo -e "${CYAN}Select amount:${NC}"
        echo -e "${LIGHT_GREEN}   1. 📤 Send full amount ${NC} ${GOLD}(maximum)${NC}"
        echo -e "${LIGHT_ORANGE}   2. ✏  Enter amount manually${NC}"
        read -p "$(echo -e "${YELLOW}Your choice (1-2): ${NC}")" choice

        case $choice in
            1)
                SEND_WEI="$MAX_SEND_WEI"
                SEND_ETH="$MAX_SEND_ETH"
                SEND_ETH_FORMATTED="$MAX_SEND_ETH_FORMATTED"
                echo "✅ Full amount selected: $SEND_ETH_FORMATTED ETH"
                break
                ;;
            2)
                while true; do
                    read -p "Enter amount to send in ETH: " amount_eth
                    amount_eth=$(clean_number "$amount_eth")

                    if [[ ! "$amount_eth" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "❌ Invalid format. Example: 0.001 or 0.5"
                        continue
                    fi

                    # Convert to Wei
                    local amount_wei=$(echo "$amount_eth * 1000000000000000000" | bc 2>/dev/null)

                    if [ -z "$amount_wei" ] || [ "$amount_wei" = "0" ]; then
                        echo "❌ Amount too small"
                        continue
                    fi

                    if [ $(echo "$amount_wei > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Insufficient funds!"
                        continue
                    fi

                    local total_needed=$(echo "$amount_wei + $GAS_FEE_WEI" | bc)
                    if [ $(echo "$total_needed > $BALANCE_WEI" | bc) -eq 1 ]; then
                        echo "❌ Not enough for fee!"
                        continue
                    fi

                    SEND_WEI="$amount_wei"
                    SEND_ETH="$amount_eth"
                    SEND_ETH_FORMATTED=$(format_eth_fixed "$amount_eth")
                    echo "✅ Amount set: $SEND_ETH_FORMATTED ETH"
                    break
                done
                break
                ;;
            *)
                echo "❌ Invalid choice"
                ;;
        esac
    done
}
# === MAIN SCRIPT ===

# 1. Get sender balance
echo "📊 Getting balance..."
BALANCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$FROM\",\"latest\"],\"id\":1}")

if [ $? -ne 0 ] || [ -z "$BALANCE_RESP" ]; then
    echo "❌ Error getting balance"
    exit 1
fi

BALANCE_HEX=$(echo "$BALANCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BALANCE_HEX" ]; then
    echo "❌ Failed to get balance"
    exit 1
fi

# Convert hex to decimal
BALANCE_WEI=$(echo "ibase=16; $(echo ${BALANCE_HEX#0x} | tr '[:lower:]' '[:upper:]')" | bc)
BALANCE_ETH=$(echo "scale=18; $BALANCE_WEI / 1000000000000000000" | bc)
BALANCE_ETH_FORMATTED=$(format_eth_fixed "$BALANCE_ETH")

echo -e "${LIGHT_CYAN}✅ Balance:${NC} ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"

# 2. Fee selection with auto-update
select_gas_price

# 3. Convert Gwei to Wei
GAS_PRICE_WEI=$(echo "$GAS_PRICE_GWEI * 1000000000" | bc 2>/dev/null)
GAS_PRICE_WEI_INT=$(echo "scale=0; $GAS_PRICE_WEI / 1" | bc)
GAS_PRICE_HEX=$(printf "0x%x" "$GAS_PRICE_WEI_INT" 2>/dev/null)

GAS_LIMIT=21000
GAS_FEE_WEI=$(echo "$GAS_PRICE_WEI * $GAS_LIMIT" | bc 2>/dev/null)

echo ""
echo -e "${GAS}💰 Transaction fee:${NC} ${GOLD}$GAS_FEE_FORMATTED ETH${NC}"

# 4. Calculate maximum to send
MAX_SEND_WEI=$(echo "$BALANCE_WEI - $GAS_FEE_WEI" | bc)
MAX_SEND_ETH=$(echo "scale=18; $MAX_SEND_WEI / 1000000000000000000" | bc)
MAX_SEND_ETH_FORMATTED=$(format_eth_fixed "$MAX_SEND_ETH")

# Check via bc
if [ $(echo "$MAX_SEND_WEI <= 0" | bc) -eq 1 ]; then
    echo ""
    echo "❌ ERROR: Balance too small even for fee payment!"
    exit 1
fi

# 5. Select amount to send
select_amount

# Convert to ETH
SEND_ETH=$(echo "scale=18; $SEND_WEI / 1000000000000000000" | bc)
SEND_WEI_INT=$(echo "scale=0; $SEND_WEI / 1" | bc)
SEND_HEX=$(printf "0x%x" "$SEND_WEI_INT")

echo -e "   ${LIGHT_CYAN}Balance:${NC}    ${GOLD}$BALANCE_ETH_FORMATTED ETH${NC}"
echo -e "${YELLOW}📈 CALCULATION:${NC}"
REMAINING_ETH=$(echo "$BALANCE_ETH - $SEND_ETH - $GAS_FEE_ETH" | bc)
REMAINING_FORMATTED=$(format_eth_fixed "$REMAINING_ETH")
echo -e "   ${LIGHT_GREEN}Sending:${NC}    - ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Fee:${NC}        - ${GAS}$GAS_FEE_FORMATTED ETH${NC}"
echo -e "   ${PURPLE}Remaining:${NC}   = ${WHITE}$REMAINING_FORMATTED ETH${NC}"
# 6. Get nonce
echo ""
echo -e "${CYAN}🔢 Getting nonce...${NC}"
NONCE_RESP=$(curl -s "$RPC" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionCount\",\"params\":[\"$FROM\",\"pending\"],\"id\":1}")

NONCE_HEX=$(echo "$NONCE_RESP" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo -e "${WHITE}✅ Nonce:${NC} ${PURPLE}$NONCE_HEX${NC}"

# 7. Confirmation
echo ""
echo -e "${YELLOW}📋 CONFIRMATION:${NC}"
echo -e "   ${CYAN}From:${NC}        ${YELLOW}$FROM${NC}"
echo -e "   ${CYAN}To:${NC}          ${MAGENTA}$TO${NC}"
echo -e "   ${LIGHT_GREEN}Sending:${NC}    ${GOLD}$SEND_ETH_FORMATTED ETH${NC}"
echo -e "   ${RED}Fee:${NC}        ${GAS}$GAS_FEE_FORMATTED ETH${NC} ${WHITE}(Gas:${NC} ${PURPLE}$GAS_PRICE_GWEI Gwei${NC}${WHITE})${NC}"
echo ""

read -p "$(echo -e "${YELLOW}Confirm sending? (y/n): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 0
fi

# 8. Create transaction
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
echo -e "${BRIGHT_BLUE}📝 Sending to Clef for signature...${NC}"

# 9. Sign
SIGN_RESP=$(curl -s "$CLEF" \
  -H "Content-Type: application/json" \
  -d "$TX_JSON")

RAW_TX=$(echo "$SIGN_RESP" | grep -o '"raw":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RAW_TX" ]; then
    echo "❌ Signature error"
    echo "$SIGN_RESP" | jq .
    exit 1
fi

echo "✅ Transaction signed!"

# 10. Send
echo ""
echo -e "${CYAN}🚀 Sending to network...${NC}"
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
    echo -e "${BRIGHT_GREEN}🎉 SUCCESS! Transaction sent!${NC}"
    echo -e "🔗 Hash: ${BRIGHT_YELLOW}$TX_HASH${NC}"
    echo -e "${CYAN}🌐 Explorer: ${BRIGHT_BLUE}https://etherscan.io/tx/$TX_HASH${NC}"
else
    echo "❌ Send error:"
    echo "$RESULT" | jq .
    echo "$RAW_TX" > raw_tx_$(date +%s).txt
    echo "💾 Raw transaction saved"
fi
