#!/bin/bash

# СОХРАНЯЕМ СИСТЕМНУЮ ЛОКАЛЬ ДО ПЕРЕОПРЕДЕЛЕНИЯ
SYSTEM_LANG="$LANG"

# Установка UTF-8 для корректного отображения эмодзи
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# =============================================================================
# 🎨 ЛОГОТИП ETHEREUM
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;95m'
GOLD='\033[38;5;220m'
NC='\033[0m'

CHECK="✅"
CROSS="❌"
WARN="⚠️"

print_colored_blocks() {
    printf "\033[48;5;99m   \033[0m"
    printf "\033[48;5;214m   \033[0m"
    printf "\033[48;5;33m   \033[0m"
    printf "\033[48;5;46m   \033[0m"
    printf "\033[48;5;99m   \033[0m"
}

print_gradient_line_with_blocks() {
    local length=$1
    local start_color=$2
    local end_color=$3
    print_colored_blocks
    for ((i=0; i<length; i++)); do
        color=$((start_color + (end_color - start_color) * i / length))
        printf "\033[48;5;%dm \033[0m" "$color"
    done
    print_colored_blocks
    echo ""
}

# =============================================================================
# 🎨 ФУНКЦИИ ПЕРЕВОДОВ
# =============================================================================

declare -A TRANSLATIONS

load_translations() {
    local lang_code="$1"
    local locale_file=""
    
    for candidate in "locales/${lang_code}.txt" "${lang_code}.txt" "locales/en.txt" "en.txt"; do
        if [ -f "$candidate" ]; then
            locale_file="$candidate"
            break
        fi
    done
    
    if [ -z "$locale_file" ]; then
        TRANSLATIONS=()
        return 1
    fi
    
    TRANSLATIONS=()
    while IFS='=' read -r key value; do
        if [ -n "$key" ] && [ "${key:0:1}" != "#" ]; then
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            TRANSLATIONS["$key"]="$value"
        fi
    done < "$locale_file"
    return 0
}

get_text() {
    local key="$1"
    if [ -n "${TRANSLATIONS[$key]}" ]; then
        echo "${TRANSLATIONS[$key]}"
    else
        echo "$key"
    fi
}

# =============================================================================
# 🎨 ОПРЕДЕЛЕНИЕ ЯЗЫКА
# =============================================================================

detect_lang_code() {
    local system_lang="${1:-$LANG}"
    [ -z "$system_lang" ] && system_lang="$LANG"
    echo "$system_lang" | cut -d'_' -f1 | cut -d'.' -f1 | tr '[:upper:]' '[:lower:]'
}

# =============================================================================
# 🎨 ФУНКЦИЯ ВЫБОРА РЕЖИМА ДОСТУПА
# =============================================================================

select_access_mode() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}              🔐 $(get_text "access_mode_title")${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}$(get_text "select_access_mode")${NC}"
    echo ""
    echo -e " ${CYAN}1)${NC} 🔓 ${GREEN}$(get_text "without_password")${NC} - $(get_text "without_password_desc")"
    echo ""
    echo -e " ${CYAN}2)${NC} 🔐 ${YELLOW}$(get_text "with_password")${NC} - $(get_text "with_password_desc")"
    echo ""
    echo -n "$(get_text "your_choice") (1-2): "
    read access_choice
    echo ""

    case $access_choice in
        1)
            ACCESS_MODE="nopasswd"
            echo -e "${GREEN}${CHECK} $(get_text "selected_without_password")${NC}"
            ;;
        2|"")
            ACCESS_MODE="withpasswd"
            echo -e "${GREEN}${CHECK} $(get_text "selected_with_password")${NC}"
            ;;
        *)
            ACCESS_MODE="withpasswd"
            echo -e "${YELLOW}${WARN} $(get_text "invalid_choice_default")${NC}"
            ;;
    esac
    echo ""
}

# =============================================================================
# 🎨 ОСНОВНАЯ ЧАСТЬ
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
mkdir -p locales

# =============================================================================
# 1. ОПРЕДЕЛЯЕМ ЯЗЫК СИСТЕМЫ
# =============================================================================

DETECTED_CODE=$(detect_lang_code "$SYSTEM_LANG")

# Флаги
declare -A LANG_FLAGS
LANG_FLAGS=(
    ["ru"]="🇷🇺" ["en"]="🇺🇸" ["es"]="🇪🇸" ["fr"]="🇫🇷" ["it"]="🇮🇹"
    ["pt"]="🇵🇹" ["de"]="🇩🇪" ["ja"]="🇯🇵" ["zh"]="🇨🇳" ["ko"]="🇰🇷"
)

# Соответствие: код → имя папки
declare -A LANG_FOLDER
LANG_FOLDER=(
    ["ru"]="Русский"   ["en"]="English"   ["es"]="Español"
    ["fr"]="Français"  ["it"]="Italiano"  ["pt"]="Português"
    ["de"]="Deutsch"   ["ja"]="日本語"     ["zh"]="中文"
    ["ko"]="한국어"
)

# Порядок для перебора
LANG_ORDER=(ru en es fr it pt de ja zh ko)

# Собираем список ТОЛЬКО из СУЩЕСТВУЮЩИХ ПАПОК
declare -a LANG_LIST
LANG_COUNT=0

for code in "${LANG_ORDER[@]}"; do
    folder="${LANG_FOLDER[$code]}"
    [ -z "$folder" ] && continue
    [ ! -d "$folder" ] && continue
    
    LANG_COUNT=$((LANG_COUNT + 1))
    
    # Читаем отображаемое имя из файла переводов
    display_name=""
    for loc in "locales/${code}.txt" "${code}.txt"; do
        if [ -f "$loc" ]; then
            display_name=$(grep -m1 '^lang_name=' "$loc" 2>/dev/null | cut -d= -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "$display_name" ] && break
        fi
    done
    [ -z "$display_name" ] && display_name="$folder"
    
    LANG_LIST+=("${LANG_COUNT}:${code}:${display_name}:${LANG_FLAGS[$code]:-🌐}:${folder}")
done

if [ $LANG_COUNT -eq 0 ]; then
    echo "Error: No language folders found!"
    exit 1
fi

# Находим системный язык
DETECTED_NAME=""
DETECTED_FOLDER=""
for item in "${LANG_LIST[@]}"; do
    code=$(echo "$item" | cut -d: -f2)
    name=$(echo "$item" | cut -d: -f3)
    folder=$(echo "$item" | cut -d: -f5)
    if [ "$code" = "$DETECTED_CODE" ]; then
        DETECTED_NAME="$name"
        DETECTED_FOLDER="$folder"
        break
    fi
done

if [ -z "$DETECTED_NAME" ]; then
    first="${LANG_LIST[0]}"
    DETECTED_CODE=$(echo "$first" | cut -d: -f2)
    DETECTED_NAME=$(echo "$first" | cut -d: -f3)
    DETECTED_FOLDER=$(echo "$first" | cut -d: -f5)
fi

# =============================================================================
# 2. ЗАГРУЖАЕМ ПЕРЕВОДЫ
# =============================================================================
load_translations "$DETECTED_CODE"

# =============================================================================
# 3. МЕНЮ ВЫБОРА ЯЗЫКА
# =============================================================================

clear
echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo ""
print_gradient_line_with_blocks 60 27 63
print_gradient_line_with_blocks 60 35 71
print_gradient_line_with_blocks 60 43 79
print_gradient_line_with_blocks 60 51 87

print_colored_blocks
printf "          \033[1;37m🪙  ETHEREUM CRYPTO WALLET  🪙\033[0m          "
print_colored_blocks
echo ""

print_gradient_line_with_blocks 60 51 87
print_gradient_line_with_blocks 60 43 79
print_gradient_line_with_blocks 60 35 71
print_gradient_line_with_blocks 60 27 63

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GOLD}                    🔗 Go Ethereum CLI Installer 🔗${NC}"
echo ""

echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}$(get_text "select_lang")${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📌 $(get_text "system_lang"): ${CYAN}$SYSTEM_LANG${NC}"
echo ""

echo -e "${GREEN}🔍 $(get_text "auto_detected"): ${CYAN}$DETECTED_NAME${NC}"
echo -e "${YELLOW}$(get_text "press_enter") $DETECTED_NAME, $(get_text "or_select_number"):${NC}"
echo ""

for item in "${LANG_LIST[@]}"; do
    num=$(echo "$item" | cut -d: -f1)
    name=$(echo "$item" | cut -d: -f3)
    flag=$(echo "$item" | cut -d: -f4)
    echo -e " ${CYAN}$num)${NC} $flag $name"
done
echo ""

echo -n "$(get_text "your_choice") (Enter = $DETECTED_NAME, 1-$LANG_COUNT): "
read lang_choice
echo ""

# Определяем выбранный язык
SELECTED_CODE=""
SELECTED_NAME=""
SELECTED_FOLDER=""

if [ -z "$lang_choice" ]; then
    SELECTED_CODE="$DETECTED_CODE"
    SELECTED_NAME="$DETECTED_NAME"
    SELECTED_FOLDER="$DETECTED_FOLDER"
else
    for item in "${LANG_LIST[@]}"; do
        num=$(echo "$item" | cut -d: -f1)
        code=$(echo "$item" | cut -d: -f2)
        name=$(echo "$item" | cut -d: -f3)
        folder=$(echo "$item" | cut -d: -f5)
        if [ "$lang_choice" = "$num" ]; then
            SELECTED_CODE="$code"
            SELECTED_NAME="$name"
            SELECTED_FOLDER="$folder"
            break
        fi
    done
    if [ -z "$SELECTED_CODE" ]; then
        SELECTED_CODE="$DETECTED_CODE"
        SELECTED_NAME="$DETECTED_NAME"
        SELECTED_FOLDER="$DETECTED_FOLDER"
    fi
fi

echo -e "${GREEN}[INFO] $(get_text "selected_lang"): $SELECTED_NAME${NC}"
echo ""

# ВСЕГДА перезагружаем переводы
load_translations "$SELECTED_CODE"

# Проверяем ПАПКУ (используем SELECTED_FOLDER)
if [ ! -d "$SELECTED_FOLDER" ]; then
    echo -e "${RED}[ERROR] $(get_text "folder_not_found"): '$SELECTED_FOLDER'${NC}"
    echo -e "${YELLOW}Доступные папки:${NC}"
    ls -d */ 2>/dev/null || echo "  (нет папок)"
    exit 1
fi

# =============================================================================
# 4. ВЫБОР РЕЖИМА ДОСТУПА
# =============================================================================

select_access_mode

# =============================================================================
# 5. ПЕРЕРИСОВЫВАЕМ ЛОГОТИП
# =============================================================================

clear
echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo ""
print_gradient_line_with_blocks 60 27 63
print_gradient_line_with_blocks 60 35 71
print_gradient_line_with_blocks 60 43 79
print_gradient_line_with_blocks 60 51 87

print_colored_blocks
printf "          \033[1;37m🪙  ETHEREUM CRYPTO WALLET  🪙\033[0m          "
print_colored_blocks
echo ""

print_gradient_line_with_blocks 60 51 87
print_gradient_line_with_blocks 60 43 79
print_gradient_line_with_blocks 60 35 71
print_gradient_line_with_blocks 60 27 63

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GOLD}                    🔗 Go Ethereum CLI Installer 🔗${NC}"
echo -e "${CYAN}                   $(get_text "subtitle")${NC}"
echo ""

# =============================================================================
# 6. ВЫБОР ОС
# =============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}$(get_text "select_os")${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e " ${CYAN}1)${NC} $(get_text "arch")"
echo -e " ${CYAN}2)${NC} $(get_text "ubuntu")"
echo -e " ${CYAN}3)${NC} $(get_text "gentoo")"
echo -e " ${CYAN}4)${NC} $(get_text "auto_detect_os")"
echo ""
echo -n "$(get_text "your_choice") (1-4): "
read distro_choice
echo ""

case $distro_choice in
    1) DISTRO="arch" ;;
    2) DISTRO="ubuntu" ;;
    3) DISTRO="gentoo" ;;
    4)
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                arch|manjaro) DISTRO="arch" ;;
                gentoo) DISTRO="gentoo" ;;
                *) DISTRO="ubuntu" ;;
            esac
        else
            DISTRO="ubuntu"
        fi
        echo -e "${GREEN}[INFO]${NC} $(get_text "auto_detect_os"): $DISTRO"
        ;;
    *) DISTRO="ubuntu" ;;
esac
echo -e "${GREEN}[INFO]${NC} $(get_text "selected"): $DISTRO"
echo ""

# =============================================================================
# 7. ЗАПРОС ПАРОЛЯ
# =============================================================================

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    $(get_text "password_required")${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}$(get_text "password_request")${NC}"
echo ""

if ! sudo -v 2>/dev/null; then
    echo -e "${RED}${CROSS} $(get_text "wrong_password")${NC}"
    exit 1
fi

echo -e "${GREEN}${CHECK} $(get_text "auth_success")${NC}"
sleep 1
echo ""

# =============================================================================
# 8. НАСТРОЙКА SUDO
# =============================================================================

if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER=$(logname 2>/dev/null || echo "$USER")
fi

if [ "$ACCESS_MODE" = "nopasswd" ] && [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    echo -e "${BLUE}[STEP]${NC} $(get_text "setup_sudo_nopasswd")..."
    
    SUDOERS_RULES=(
        "$REAL_USER ALL=(ALL) NOPASSWD: /usr/local/bin/go-ethereum-cli"
        "$REAL_USER ALL=(ALL) NOPASSWD: /usr/local/bin/crypto_wallet/main.sh"
    )
    
    TEMP_SUDOERS=$(mktemp)
    sudo cat /etc/sudoers > "$TEMP_SUDOERS"
    
    ADDED=0
    for rule in "${SUDOERS_RULES[@]}"; do
        if ! grep -qF "$rule" "$TEMP_SUDOERS" 2>/dev/null; then
            echo "$rule" >> "$TEMP_SUDOERS"
            ADDED=1
            echo -e "  ${GREEN}✓${NC} $(get_text "rule_added"): $rule"
        fi
    done
    
    if [ $ADDED -eq 1 ]; then
        if sudo visudo -c -f "$TEMP_SUDOERS" 2>/dev/null; then
            sudo cp "$TEMP_SUDOERS" /etc/sudoers
        else
            echo -e "  ${YELLOW}${WARN}${NC} $(get_text "sudo_syntax_error")"
        fi
    else
        echo -e "  ${GREEN}✓${NC} $(get_text "rules_exist")"
    fi
    
    rm -f "$TEMP_SUDOERS"
    echo ""
fi

# =============================================================================
# 9. ПОИСК И ЗАПУСК УСТАНОВОЧНОГО СКРИПТА
# =============================================================================

INSTALL_SCRIPT_NAME=""
cd "$SELECTED_FOLDER"

echo -e "${BLUE}[STEP]${NC} $(get_text "looking_for_script"): $(pwd)"

case "$DISTRO" in
    arch)
        patterns=("install-package.archlinux.sh" "install-package.archlinux.bin" "install-package.archlinux" "install-package.arch.sh" "install-package.arch" "install-arch.sh")
        ;;
    gentoo)
        patterns=("install-package.gentoo.sh" "install-package.gentoo.bin" "install-package.gentoo" "install-gentoo.sh")
        ;;
    ubuntu)
        patterns=("install-package.ubuntu.sh" "install-package.ubuntu.bin" "install-package.ubuntu" "install-package.debian.sh" "install-ubuntu.sh")
        ;;
esac

for pattern in "${patterns[@]}"; do
    if [ -f "$pattern" ]; then
        INSTALL_SCRIPT_NAME="$pattern"
        echo -e "${GREEN}$(get_text "found"): $pattern${NC}"
        break
    fi
done

if [ -z "$INSTALL_SCRIPT_NAME" ]; then
    for file in install-*.sh install-*.bin install-*; do
        if [ -f "$file" ]; then
            INSTALL_SCRIPT_NAME="$file"
            echo -e "${GREEN}$(get_text "found"): $file${NC}"
            break
        fi
    done
fi

if [ -n "$INSTALL_SCRIPT_NAME" ]; then
    echo -e "${BLUE}[STEP]${NC} $(get_text "install_packages") $DISTRO..."
    chmod +x "$INSTALL_SCRIPT_NAME"
    
    if [ "$EUID" -ne 0 ]; then
        sudo bash "$INSTALL_SCRIPT_NAME"
        SCRIPT_EXIT_CODE=$?
    else
        bash "$INSTALL_SCRIPT_NAME"
        SCRIPT_EXIT_CODE=$?
    fi
    
    if [ $SCRIPT_EXIT_CODE -ne 0 ]; then
        echo -e "${YELLOW}[WARNING]${NC} $(get_text "install_error")"
    else
        echo -e "${GREEN}${CHECK}${NC} $(get_text "install_success")"
    fi
else
    echo -e "${RED}[ERROR]${NC} $(get_text "install_script_not_found")"
    ls -la
    cd "$SCRIPT_DIR"
    exit 1
fi

cd "$SCRIPT_DIR"
echo ""

# =============================================================================
# 10. КОПИРОВАНИЕ ФАЙЛОВ
# =============================================================================

TARGET_DIR="/usr/local/bin/crypto_wallet"

echo -e "${BLUE}[STEP]${NC} $(get_text "create_dir"): $TARGET_DIR"
sudo mkdir -p "$TARGET_DIR"

echo -e "${BLUE}[STEP]${NC} $(get_text "copy_files")"

FILES=(
    "add_wallet"
    "create-wallet"
    "encryption-key"
    "key-correct"
    "main"
    "rpc"
    "send"
    "send_clef"
)

for file in "${FILES[@]}"; do
    SOURCE=""
    TARGET_EXT=".sh"
    
    if [ -f "$SELECTED_FOLDER/${file}.sh" ]; then
        SOURCE="$SELECTED_FOLDER/${file}.sh"
        TARGET_EXT=".sh"
    elif [ -f "$SELECTED_FOLDER/${file}.bin" ]; then
        SOURCE="$SELECTED_FOLDER/${file}.bin"
        TARGET_EXT=".bin"
    elif [ -f "$SELECTED_FOLDER/$file" ]; then
        SOURCE="$SELECTED_FOLDER/$file"
        TARGET_EXT=".sh"
    fi
    
    if [ -n "$SOURCE" ]; then
        sudo cp "$SOURCE" "$TARGET_DIR/${file}${TARGET_EXT}"
        sudo chmod +x "$TARGET_DIR/${file}${TARGET_EXT}"
        echo -e "  ${GREEN}✓${NC} ${file}${TARGET_EXT}"
    else
        echo -e "  ${YELLOW}⚠${NC} $file — не найден"
    fi
done
echo ""

# Иконка
if [ -f "ethereum.png" ]; then
    for dir in /usr/share/icons/hicolor/128x128/apps /usr/share/pixmaps /usr/local/share/icons; do
        sudo mkdir -p "$dir"
        sudo cp "ethereum.png" "$dir/go-ethereum-cli.png"
    done
fi
echo ""

# Симлинк
sudo ln -sf "$TARGET_DIR/main.sh" "/usr/local/bin/go-ethereum-cli"
sudo chmod +x "/usr/local/bin/go-ethereum-cli" 2>/dev/null
echo ""

# Desktop
if [ "$ACCESS_MODE" = "nopasswd" ]; then
    DESKTOP_EXEC="sudo /usr/local/bin/go-ethereum-cli"
else
    DESKTOP_EXEC="pkexec /usr/local/bin/go-ethereum-cli"
fi

DESKTOP="[Desktop Entry]
Version=1.0
Type=Application
Name=Go Ethereum-cli
Comment=$(get_text "app_description")
Exec=$DESKTOP_EXEC
Icon=go-ethereum-cli
Terminal=true
Categories=Utility;Finance;System;
StartupNotify=true"

for path in /usr/share/applications /usr/local/share/applications; do
    sudo mkdir -p "$path"
    echo "$DESKTOP" | sudo tee "$path/go-ethereum-cli.desktop" > /dev/null
done

if [ -n "$SUDO_USER" ]; then
    USER_HOME="/home/$SUDO_USER"
    mkdir -p "$USER_HOME/.local/share/applications"
    echo "$DESKTOP" > "$USER_HOME/.local/share/applications/go-ethereum-cli.desktop"
fi

# PATH
if [ -n "$USER_HOME" ] && [ -f "$USER_HOME/.bashrc" ]; then
    grep -q "/usr/local/bin" "$USER_HOME/.bashrc" 2>/dev/null || echo 'export PATH=/usr/local/bin:$PATH' >> "$USER_HOME/.bashrc"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}$(get_text "install_complete")${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}$(get_text "language"):${NC} $SELECTED_NAME"
echo -e "  ${GREEN}$(get_text "os"):${NC} $DISTRO"
echo -e "  ${GREEN}$(get_text "launch"):${NC} go-ethereum-cli"
echo ""
