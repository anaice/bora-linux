#!/bin/bash

# ============================================================
#  install-arch.sh — Interactive setup for Arch Linux (Garuda / CachyOS / KDE)
#  Usage: sudo ./install-arch.sh [-v|--verbose]
#  Everything via pacman + yay + Flatpak
# ============================================================

# ==========================================
# 0. CONFIG, COLORS AND OUTPUT
# ==========================================
# Paleta: mint / lavender / peach / rose / dimmed
VERDE='\033[38;5;115m'
AZUL='\033[38;5;111m'
AMARELO='\033[38;5;222m'
VERMELHO='\033[38;5;210m'
CINZA='\033[38;5;245m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="/tmp/install-bora-$(date +%Y%m%d-%H%M%S).log"
touch "$LOG_FILE"
VERBOSE=false

# Quick lang load for --help (before gum)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SYS_LANG="${LANG:-en_US.UTF-8}"
_QUICK_LANG="en"
[[ "$_SYS_LANG" == pt_BR* ]] && _QUICK_LANG="pt-br"
source "$_SCRIPT_DIR/lang/${_QUICK_LANG}.sh"

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=true ;;
        --lang=*) _QUICK_LANG="${arg#--lang=}"; source "$_SCRIPT_DIR/lang/${_QUICK_LANG}.sh" 2>/dev/null ;;
        -h|--help)
            echo "$L_USAGE"
            echo "  $L_USAGE_VERBOSE"
            echo "  $L_USAGE_HELP"
            echo "  --lang=LANG   pt-br | en"
            exit 0 ;;
    esac
done

# --- Check root ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}$L_ERR_ROOT${NC}"
    exit 1
fi

# --- Identify real user ---
USUARIO_REAL="${SUDO_USER:-}"
if [ -z "$USUARIO_REAL" ]; then
    echo -e "${VERMELHO}$L_ERR_SUDO${NC}"
    exit 1
fi
HOME_USUARIO=$(getent passwd "$USUARIO_REAL" | cut -d: -f6)

# --- Temporary NOPASSWD for yay (AUR builds run as user but need sudo internally) ---
SUDOERS_TMP="/etc/sudoers.d/bora-linux-tmp"
echo "$USUARIO_REAL ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_TMP"
chmod 440 "$SUDOERS_TMP"
cleanup_sudoers() { rm -f "$SUDOERS_TMP"; }
trap cleanup_sudoers EXIT INT TERM

# --- Install yay if needed ---
if ! command -v yay &>/dev/null; then
    pacman -S --noconfirm --needed git base-devel
    YAY_TMP="/tmp/yay-build"
    rm -rf "$YAY_TMP"
    sudo -u "$USUARIO_REAL" git clone https://aur.archlinux.org/yay-bin.git "$YAY_TMP"
    cd "$YAY_TMP" && sudo -u "$USUARIO_REAL" makepkg -si --noconfirm
    cd / && rm -rf "$YAY_TMP"
fi

# --- Install gum if needed ---
if ! command -v gum &>/dev/null; then
    pacman -S --noconfirm gum 2>/dev/null || sudo -u "$USUARIO_REAL" yay -S --noconfirm gum
fi

# --- Gum theme (matching script palette) ---
export GUM_CHOOSE_CURSOR_FOREGROUND="111"
export GUM_CHOOSE_SELECTED_FOREGROUND="115"
export GUM_CHOOSE_HEADER_FOREGROUND="255"
export GUM_CHOOSE_CURSOR="❯ "
export GUM_CHOOSE_UNSELECTED_PREFIX="  ○ "
export GUM_CHOOSE_SELECTED_PREFIX="  ◉ "
export GUM_CONFIRM_SELECTED_FOREGROUND="0"
export GUM_CONFIRM_SELECTED_BACKGROUND="111"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="245"
export GUM_INPUT_CURSOR_FOREGROUND="111"
export GUM_INPUT_PROMPT_FOREGROUND="111"
export GUM_INPUT_HEADER_FOREGROUND="255"
export GUM_FILTER_INDICATOR_FOREGROUND="111"
export GUM_FILTER_MATCH_FOREGROUND="115"
export GUM_FILTER_HEADER_FOREGROUND="255"

# --- Language (auto-detect or --lang=xx) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lang/${_QUICK_LANG}.sh"

# ==========================================
# OUTPUT SYSTEM (spinner + log)
# ==========================================

# run_cmd "description" "shell command"
# Runs command with spinner. Press 'v' to toggle verbose in real time.
# Output always goes to LOG_FILE. In verbose, also shows in terminal via tail -f.
run_cmd() {
    local desc="$1"
    shift
    local cmd="$*"

    echo "=== [$desc] ===" >> "$LOG_FILE"
    bash -c "$cmd" >> "$LOG_FILE" 2>&1 </dev/null &
    local pid=$!
    local i=0
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local tail_pid=""

    # If already in verbose, start showing output
    if $VERBOSE; then
        printf "  ${AZUL}▸${NC} %s ${CINZA}[$L_V_EXPAND]${NC}\n" "$desc"
        tail -f -n 0 "$LOG_FILE" 2>/dev/null &
        tail_pid=$!
    fi

    while kill -0 "$pid" 2>/dev/null; do
        # Detect 'v' key (read -t replaces sleep)
        if read -rsn1 -t 0.1 key < /dev/tty 2>/dev/null; then
            if [[ "$key" == "v" || "$key" == "V" ]]; then
                if [ -z "$tail_pid" ]; then
                    # Expand: show live output
                    VERBOSE=true
                    printf "\r\033[K  ${AZUL}▸${NC} %s ${CINZA}[$L_V_EXPAND]${NC}\n" "$desc"
                    tail -f -n 0 "$LOG_FILE" 2>/dev/null &
                    tail_pid=$!
                else
                    # Collapse: back to spinner
                    VERBOSE=false
                    kill "$tail_pid" 2>/dev/null
                    wait "$tail_pid" 2>/dev/null
                    tail_pid=""
                fi
            fi
        fi

        # Spinner only appears in compact mode
        if [ -z "$tail_pid" ]; then
            printf "\r  ${AZUL}%s${NC} %s" "${spin:$i:1}" "$desc"
            i=$(( (i + 1) % ${#spin} ))
        fi
    done

    # Clean up tail if still running
    if [ -n "$tail_pid" ]; then
        sleep 0.2
        kill "$tail_pid" 2>/dev/null
        wait "$tail_pid" 2>/dev/null
    fi

    wait "$pid"
    local rc=$?

    if [ $rc -eq 0 ]; then
        printf "\r  ${VERDE}✓${NC} %s\033[K\n" "$desc"
    else
        printf "\r  ${VERMELHO}✗${NC} %s\033[K\n" "$desc"
        local last_err
        last_err=$(grep -iE 'erro|error|fail|fatal|unable|cannot' "$LOG_FILE" | tail -1 | head -c 120)
        [ -n "$last_err" ] && printf "    ${CINZA}↳ %s${NC}\n" "$last_err"
    fi

    return $rc
}

# Shortcut: run_cmd that doesn't fail the script (for optional commands)
try_cmd() {
    run_cmd "$@" || true
}

# Section headers
section() {
    echo ""
    echo -e "${BOLD}${VERDE}━━━ $1 ━━━${NC}"
}

log_ok()   { printf "  ${VERDE}✓${NC} %s\n" "$1"; }
log_warn() { printf "  ${AMARELO}!${NC} %s\n" "$1"; }
log_skip() { printf "  ${CINZA}–${NC} %s\n" "$1"; }

# ==========================================
# 1. INTERACTIVE MENUS (GUM)
# ==========================================

is_selected() {
    local item="$1"
    for s in "${SELECIONADOS[@]:-}"; do
        [[ "$s" == "$item" ]] && return 0
    done
    return 1
}

# checklist "title" "desc" height width list_height "key" "label" ON/OFF ...
# Uses gum choose --no-limit for multi-select.
# Height/width params kept for signature compatibility but ignored by gum.
checklist() {
    local title="$1" desc="$2" h="$3" w="$4" lh="$5"
    shift 5
    local items=("$@")

    # Build display lines and track pre-selected items
    local display_lines=()
    local selected_items=()
    local i=0
    while [ $i -lt ${#items[@]} ]; do
        local key="${items[$i]}"
        local label="${items[$((i+1))]}"
        local state="${items[$((i+2))]}"
        display_lines+=("$key  $label")
        [[ "$state" == "ON" ]] && selected_items+=("$key  $label")
        i=$((i + 3))
    done

    # Build gum args with --selected for each pre-selected item
    local gum_args=(--no-limit --header="  $title — $desc" --height=50)
    for sel in "${selected_items[@]}"; do
        gum_args+=(--selected="$sel")
    done

    # Run gum choose
    echo ""
    local RESULT
    RESULT=$(printf '%s\n' "${display_lines[@]}" | gum choose "${gum_args[@]}") || return 1

    [ -z "$RESULT" ] && return 1

    # Extract just the keys (first field of each line)
    echo "$RESULT" | awk '{print $1}' | tr '\n' ' '
}

menu_principal() {
    local ETAPAS
    echo ""
    ETAPAS=$(gum choose --no-limit --height=50 \
        --header="  $L_MAIN_DESC" \
        --selected="pacman  $L_STEP_PACMAN","flatpak  $L_STEP_FLATPAK","fonts  $L_STEP_FONTS","scripts  $L_STEP_SCRIPTS","mise  $L_STEP_MISE","lazyvim  $L_STEP_LAZYVIM","starship  $L_STEP_STARSHIP","zsh  $L_STEP_ZSH","ajustes  $L_STEP_TWEAKS" \
        "cleanup  $L_STEP_CLEANUP" \
        "upgrade  $L_STEP_UPGRADE" \
        "pacman  $L_STEP_PACMAN" \
        "flatpak  $L_STEP_FLATPAK" \
        "fonts  $L_STEP_FONTS" \
        "scripts  $L_STEP_SCRIPTS" \
        "mise  $L_STEP_MISE" \
        "lazyvim  $L_STEP_LAZYVIM" \
        "starship  $L_STEP_STARSHIP" \
        "zsh  $L_STEP_ZSH" \
        "themes  $L_STEP_THEMES" \
        "gdrive  $L_STEP_GDRIVE" \
        "keyboard  $L_STEP_KEYBOARD" \
        "ajustes  $L_STEP_TWEAKS") || { log_warn "$L_CANCELLED"; exit 0; }

    [ -z "$ETAPAS" ] && { log_warn "$L_CANCELLED"; exit 0; }
    readarray -t SELECIONADOS <<< "$(echo "$ETAPAS" | awk '{print $1}')"
}

menu_pacman() {
    checklist "$L_PACMAN_TITLE" "$L_PACMAN_DESC" 38 78 28 \
        "gnupg"                  "$L_APT_gpg"              ON \
        "curl"                   "$L_APT_curl"             ON \
        "wget"                   "$L_APT_wget"             ON \
        "zsh"                    "$L_APT_zsh"              ON \
        "bat"                    "$L_APT_bat"              ON \
        "fd"                     "$L_APT_fd_find"          ON \
        "fzf"                    "$L_APT_fzf"              ON \
        "eza"                    "$L_APT_eza"              ON \
        "btop"                   "$L_APT_btop"             ON \
        "meld"                   "$L_APT_meld"             ON \
        "vlc"                    "$L_APT_vlc"              ON \
        "audacity"               "$L_APT_audacity"         ON \
        "mypaint"                "$L_APT_mypaint"          ON \
        "mangohud"               "$L_APT_mangohud"         OFF \
        "brave-bin"              "$L_APT_brave_browser"    ON \
        "google-chrome"          "$L_APT_google_chrome"    ON \
        "1password"              "$L_APT_1password"        ON \
        "anydesk-bin"            "$L_APT_anydesk"          OFF \
        "zoom"                   "$L_APT_zoom"             OFF \
        "docker"                 "$L_APT_docker_ce"        ON \
        "docker-buildx"          "$L_APT_docker_buildx"    ON \
        "docker-compose"         "$L_APT_docker_compose"   ON \
        "mise"                   "$L_APT_mise"             ON \
        "neovim"                 "$L_APT_neovim"           ON \
        "ripgrep"                "$L_APT_ripgrep"          ON \
        "flameshot"              "$L_FLATPAK_flameshot"    ON \
        "copyq"                  "$L_APT_copyq"            ON \
        "wl-clipboard"           "$L_APT_wl_clipboard"     ON \
        "micro"                  "$L_FLATPAK_micro"        ON \
        "tldr"                   "$L_APT_tldr"             ON \
        "xcb-util-cursor"        "$L_APT_libxcb"           ON \
        "lazygit"                "$L_SCRIPTS_lazygit"      ON \
        "lazydocker"             "$L_SCRIPTS_lazydocker"   ON \
        "calibre"                "$L_SCRIPTS_calibre"      ON \
        "starship"               "$L_SCRIPTS_starship"     ON \
        "tabby-bin"              "$L_SCRIPTS_tabby"        ON \
        "cursor-bin"             "$L_SCRIPTS_cursor"       ON \
        "pencil-bin"             "$L_SCRIPTS_pencil"       ON \
        "aws-cli-v2"             "$L_SCRIPTS_awscli"       ON
}

menu_flatpak() {
    checklist "$L_FLATPAK_TITLE" "$L_FLATPAK_DESC" 30 78 20 \
        "com.visualstudio.code"          "$L_FLATPAK_vscode"      ON \
        "rest.insomnia.Insomnia"         "$L_FLATPAK_insomnia"    ON \
        "com.getpostman.Postman"         "$L_FLATPAK_postman"     ON \
        "com.jgraph.drawio.desktop"      "$L_FLATPAK_drawio"      ON \
        "com.usebottles.bottles"         "$L_FLATPAK_bottles"     ON \
        "dev.aunetx.deezer"              "$L_FLATPAK_deezer"      ON \
        "com.discordapp.Discord"         "$L_FLATPAK_discord"     ON \
        "org.localsend.localsend_app"    "$L_FLATPAK_localsend"   ON \
        "it.mijorus.smile"               "$L_FLATPAK_smile"       ON \
        "io.github.Qalculate"            "$L_FLATPAK_qalculate"   ON \
        "org.flameshot.Flameshot"         "$L_FLATPAK_flameshot"   OFF \
        "io.github.zyedidia.micro"       "$L_FLATPAK_micro"       OFF \
        "io.dbeaver.DBeaverCommunity"    "$L_FLATPAK_dbeaver"     ON \
        "com.rtosta.zapzap"              "$L_FLATPAK_zapzap"      ON
}

menu_scripts() {
    checklist "$L_SCRIPTS_TITLE" "$L_SCRIPTS_DESC" 22 78 10 \
        "jetbrains-toolbox" "$L_SCRIPTS_jetbrains"   ON \
        "claude"            "$L_SCRIPTS_claude"       ON \
        "zed"               "$L_SCRIPTS_zed"          ON
}

menu_linguagens() {
    checklist "$L_MISE_TITLE" "$L_MISE_DESC" 22 78 10 \
        "java"     "$L_MISE_java"      ON \
        "ruby"     "$L_MISE_ruby"      ON \
        "flutter"  "$L_MISE_flutter"   ON \
        "python"   "$L_MISE_python"    OFF \
        "go"       "$L_MISE_go"        OFF \
        "rust"     "$L_MISE_rust"      OFF \
        "clojure"  "$L_MISE_clojure"   OFF \
        "elixir"   "$L_MISE_elixir"    OFF
}

menu_cleanup() {
    checklist "$L_CLEANUP_TITLE" "$L_CLEANUP_DESC" 22 78 10 \
        "flatpak-old"    "$L_CLEANUP_FLATPAK"        ON \
        "pacman-cache"   "$L_CLEANUP_PACMAN_CACHE"    ON \
        "orphans"        "$L_CLEANUP_ORPHANS"         ON
}

menu_themes() {
    checklist "$L_THEMES_TITLE" "$L_THEMES_DESC" 26 78 14 \
        "orchis"          "$L_THEMES_orchis"          OFF \
        "colloid"         "$L_THEMES_colloid"         OFF \
        "fluent"          "$L_THEMES_fluent"           OFF \
        "graphite"        "$L_THEMES_graphite"         OFF \
        "lavanda"         "$L_THEMES_lavanda"          OFF \
        "papirus"         "$L_THEMES_papirus"         OFF \
        "tela-icons"      "$L_THEMES_tela"            OFF \
        "colloid-icons"   "$L_THEMES_colloid_icons"   OFF \
        "bibata"          "$L_THEMES_bibata"          OFF \
        "skeuos"          "$L_THEMES_skeuos"         OFF
}

# ==========================================
# 2. CLEANUP
# ==========================================
executar_cleanup() {
    section "$L_CLEANUP_TITLE"

    local CLEANUP_OPTS
    CLEANUP_OPTS=$(menu_cleanup) || { log_skip "$L_CLEANUP_CANCELLED"; return 0; }
    cleanup_selected() { echo "$CLEANUP_OPTS" | grep -qw "$1"; }

    # Flatpak unused runtimes
    if cleanup_selected "flatpak-old" && command -v flatpak &>/dev/null; then
        try_cmd "$L_CLEANUP_FLATPAK_UNUSED" \
            "flatpak uninstall --unused -y 2>/dev/null"
    fi

    # Pacman cache
    if cleanup_selected "pacman-cache"; then
        run_cmd "$L_CLEANUP_PACMAN_CLEAN" \
            "pacman -Sc --noconfirm" || true
    fi

    # Orphan packages
    if cleanup_selected "orphans"; then
        local ORPHANS
        ORPHANS=$(pacman -Qtdq 2>/dev/null || true)
        if [ -n "$ORPHANS" ]; then
            run_cmd "$L_CLEANUP_ORPHANS_RUN" \
                "pacman -Rns --noconfirm $ORPHANS" || true
        else
            log_ok "$L_CLEANUP_NO_ORPHANS"
        fi
    fi
}

# ==========================================
# 3. SYSTEM UPDATE
# ==========================================
atualizar_sistema() {
    section "$L_UPGRADE_SECTION"

    if ! command -v reflector &>/dev/null; then
        run_cmd "$L_UPGRADE_REFLECTOR_INSTALL" "pacman -S --noconfirm reflector"
    fi

    if command -v reflector &>/dev/null; then
        run_cmd "$L_UPGRADE_MIRRORS" \
            "reflector --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist"
    fi

    run_cmd "$L_UPGRADE_UPGRADE" "pacman -Syu --noconfirm"
}

# ==========================================
# 4. PACMAN PACKAGES
# ==========================================
instalar_pacman() {
    section "$L_PACMAN_SECTION"

    local PACOTES
    PACOTES=$(menu_pacman) || { log_skip "$L_PACMAN_NONE"; return 0; }

    # Separate official and AUR packages
    local AUR_PKGS="brave-bin google-chrome 1password anydesk-bin zoom mise tabby-bin cursor-bin pencil-bin aws-cli-v2"
    local FALHAS=()

    for pacote in $PACOTES; do
        if pacman -Q "$pacote" &>/dev/null; then
            log_ok "$pacote ($L_ALREADY_INSTALLED)"
        elif [[ "$pacote" == "pencil-bin" ]]; then
            run_cmd "$L_INSTALLING $pacote (AUR)" \
                "mkdir -p /tmp/bora-curl && echo 'insecure' > /tmp/bora-curl/.curlrc && sudo -u $USUARIO_REAL env CURL_HOME=/tmp/bora-curl yay -S --noconfirm $pacote; rm -rf /tmp/bora-curl" || FALHAS+=("$pacote")
        elif echo "$AUR_PKGS" | grep -qw "$pacote"; then
            run_cmd "$L_INSTALLING $pacote (AUR)" \
                "sudo -u $USUARIO_REAL yay -S --noconfirm $pacote" || FALHAS+=("$pacote")
        else
            run_cmd "$L_INSTALLING $pacote" \
                "pacman -S --noconfirm $pacote" || FALHAS+=("$pacote")
        fi
    done

    if [ ${#FALHAS[@]} -gt 0 ]; then
        log_warn "$L_FAILURES: ${FALHAS[*]}"
    fi
}

# ==========================================
# 5. FLATPAK PACKAGES
# ==========================================
instalar_flatpak() {
    section "$L_FLATPAK_SECTION"

    if ! command -v flatpak &>/dev/null; then
        run_cmd "$L_INSTALLING flatpak" "pacman -S --noconfirm flatpak"
        if ! command -v flatpak &>/dev/null; then
            log_warn "$L_FLATPAK_NOT_INSTALLED"
            return 1
        fi
    fi

    run_cmd "$L_FLATPAK_REMOTE" \
        "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"

    if ! flatpak remotes 2>/dev/null | grep -q flathub; then
        log_warn "$L_FLATPAK_REMOTE_FAIL"
        return 1
    fi

    local FLATPAKS
    FLATPAKS=$(menu_flatpak) || { log_skip "$L_FLATPAK_NONE"; return 0; }

    for flatpak_pkg in $FLATPAKS; do
        run_cmd "$L_INSTALLING $flatpak_pkg" "flatpak install flathub -y $flatpak_pkg" || true
    done
}

# ==========================================
# 7. NERD FONTS
# ==========================================
instalar_nerd_fonts() {
    section "$L_FONTS_SECTION"

    local FONT_DIR="$HOME_USUARIO/.local/share/fonts"
    mkdir -p "$FONT_DIR"

    run_cmd "$L_FONTS_DOWNLOAD" \
        "wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip -O /tmp/font.zip"

    run_cmd "$L_FONTS_EXTRACT" \
        "unzip -o /tmp/font.zip -d $FONT_DIR && rm -f /tmp/font.zip && find $FONT_DIR -name '*Windows*' -delete 2>/dev/null; true"

    chown -R "$USUARIO_REAL:$USUARIO_REAL" "$FONT_DIR"

    run_cmd "$L_FONTS_CACHE" "fc-cache -f"
}

# ==========================================
# 8. EXTERNAL SCRIPTS
# ==========================================
instalar_scripts_externos() {
    section "$L_SCRIPTS_SECTION"

    local SCRIPTS
    SCRIPTS=$(menu_scripts) || { log_skip "$L_SCRIPTS_NONE"; return 0; }

    for item in $SCRIPTS; do
        case "$item" in
            jetbrains-toolbox)
                # Check if already installed
                local TB_INSTALL_DIR="$HOME_USUARIO/.local/share/JetBrains/Toolbox/app"
                if [ -d "$TB_INSTALL_DIR" ] && [ -x "$TB_INSTALL_DIR/bin/jetbrains-toolbox" ]; then
                    log_ok "$L_TB_ALREADY"
                else
                    local TB_URL TB_TAR TB_EXTRACT_DIR
                    TB_TAR="/tmp/jetbrains-toolbox.tar.gz"

                    # 1. Discover latest version URL
                    TB_URL=$(curl -s "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
                        | sed 's/.*"linux":{[^}]*"link":"//;s/".*//')

                    if [ -z "$TB_URL" ]; then
                        log_warn "$L_TB_NO_URL"
                        return 0
                    fi

                    # 2. Download
                    run_cmd "$L_TB_DOWNLOAD" "wget -q '$TB_URL' -O '$TB_TAR'" || return 0

                    # 3. Extract
                    TB_EXTRACT_DIR=$(tar -tzf "$TB_TAR" | head -1 | cut -d'/' -f1)
                    tar -xzf "$TB_TAR" -C /tmp

                    if [ ! -x "/tmp/$TB_EXTRACT_DIR/bin/jetbrains-toolbox" ]; then
                        log_warn "$L_TB_NO_BIN"
                        rm -f "$TB_TAR"
                        return 0
                    fi

                    # 4. Copy the full bundle to ~/.local/share/JetBrains/Toolbox/app
                    mkdir -p "$TB_INSTALL_DIR"
                    cp -r /tmp/"$TB_EXTRACT_DIR"/* "$TB_INSTALL_DIR/"
                    chown -R "$USUARIO_REAL:$USUARIO_REAL" "$HOME_USUARIO/.local/share/JetBrains"

                    # 5. Create symlink in ~/.local/bin
                    local USER_BIN="$HOME_USUARIO/.local/bin"
                    mkdir -p "$USER_BIN"
                    ln -sf "$TB_INSTALL_DIR/bin/jetbrains-toolbox" "$USER_BIN/jetbrains-toolbox"
                    chown -h "$USUARIO_REAL:$USUARIO_REAL" "$USER_BIN/jetbrains-toolbox"

                    # 6. Create .desktop for launcher
                    local DESKTOP_FILE="$HOME_USUARIO/.local/share/applications/jetbrains-toolbox.desktop"
                    cat <<DTEOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Exec=$TB_INSTALL_DIR/bin/jetbrains-toolbox
Icon=$TB_INSTALL_DIR/bin/toolbox-tray-color.png
Categories=Development;IDE;
Comment=$L_TB_COMMENT
StartupNotify=true
DTEOF
                    chown "$USUARIO_REAL:$USUARIO_REAL" "$DESKTOP_FILE"

                    # 7. Execute as user for initialization
                    sudo -u "$USUARIO_REAL" bash -c "DISPLAY=$DISPLAY XAUTHORITY=${XAUTHORITY:-$HOME_USUARIO/.Xauthority} $TB_INSTALL_DIR/bin/jetbrains-toolbox" &>/dev/null &

                    # 8. Clean tmp
                    rm -rf "/tmp/$TB_EXTRACT_DIR" "$TB_TAR"

                    log_ok "$L_TB_DONE"
                fi
                ;;
            claude)
                run_cmd "$L_INSTALLING Claude Code" \
                    "sudo -u $USUARIO_REAL bash -c 'curl -fsSL https://claude.ai/install.sh | bash'" || true
                ;;
            zed)
                run_cmd "$L_INSTALLING Zed Editor" \
                    "sudo -u $USUARIO_REAL bash -c 'curl -f https://zed.dev/install.sh | sh'" || true
                ;;
        esac
    done
}

# ==========================================
# 9. LANGUAGES VIA MISE
# ==========================================
configurar_mise_linguagens() {
    section "$L_MISE_SECTION"

    if ! command -v mise &>/dev/null; then
        log_warn "$L_MISE_NOT_INSTALLED"
        return 1
    fi

    local LANGS
    LANGS=$(menu_linguagens) || { log_skip "$L_MISE_NONE"; return 0; }

    for lang in $LANGS; do
        case "$lang" in
            java)
                run_cmd "$L_INSTALLING Java" "sudo -u $USUARIO_REAL mise use --global java" || true
                ;;
            ruby)
                run_cmd "$L_MISE_RUBY_DEPS" "pacman -S --noconfirm libyaml openssl" || true
                run_cmd "$L_INSTALLING Ruby" "sudo -u $USUARIO_REAL mise use --global ruby" || true
                ;;
            flutter)
                try_cmd "Plugin Flutter" "sudo -u $USUARIO_REAL mise plugin install flutter https://github.com/nyuyuyu/asdf-flutter.git 2>/dev/null"
                run_cmd "$L_INSTALLING Flutter" "sudo -u $USUARIO_REAL mise use --global flutter" || true
                ;;
            clojure)
                try_cmd "Plugin Clojure" "sudo -u $USUARIO_REAL mise plugin install clojure https://github.com/asdf-community/asdf-clojure.git 2>/dev/null"
                run_cmd "$L_INSTALLING Clojure" "sudo -u $USUARIO_REAL mise use --global clojure" || true
                ;;
            python)
                run_cmd "$L_INSTALLING Python" "sudo -u $USUARIO_REAL mise use --global python" || true
                ;;
            go)
                run_cmd "$L_INSTALLING Go" "sudo -u $USUARIO_REAL mise use --global go" || true
                ;;
            rust)
                run_cmd "$L_INSTALLING Rust" "sudo -u $USUARIO_REAL mise use --global rust" || true
                ;;
            elixir)
                run_cmd "$L_MISE_ERLANG_DEPS" "pacman -S --noconfirm autoconf openssl ncurses" || true
                run_cmd "$L_INSTALLING Erlang + Elixir" "sudo -u $USUARIO_REAL mise use --global erlang elixir" || true
                ;;
        esac
    done
}

# ==========================================
# 10. LAZYVIM
# ==========================================
configurar_lazyvim() {
    section "$L_LAZYVIM_SECTION"

    local CONFIG_DIR="$HOME_USUARIO/.config/nvim"

    if [ -d "$CONFIG_DIR" ]; then
        local BACKUP_NAME="$CONFIG_DIR.bak.$(date +%s)"
        log_warn "$L_LAZYVIM_BACKUP: $BACKUP_NAME"
        mv "$CONFIG_DIR" "$BACKUP_NAME"
    fi

    run_cmd "$L_LAZYVIM_CLONE" \
        "sudo -u $USUARIO_REAL git clone https://github.com/LazyVim/starter $CONFIG_DIR"
}

# ==========================================
# 11. STARSHIP
# ==========================================
configurar_starship() {
    section "$L_STARSHIP_SECTION"

    if ! command -v starship &>/dev/null; then
        log_warn "Starship not installed — select it in the pacman step"
        return 1
    fi

    local CONFIG_DIR="$HOME_USUARIO/.config"
    mkdir -p "$CONFIG_DIR"

    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local PRESETS_DIR="$SCRIPT_DIR/configs/starship"

    # Preset selection
    echo ""
    local PRESET
    PRESET=$(gum choose --header="  $L_STARSHIP_PRESET_DESC" \
        "bora                $L_STARSHIP_P_bora" \
        "pastel-powerline    $L_STARSHIP_P_pastel" \
        "tokyo-night         $L_STARSHIP_P_tokyo" \
        "gruvbox-rainbow     $L_STARSHIP_P_gruvbox" \
        "catppuccin-powerline $L_STARSHIP_P_catppuccin" \
        | awk '{print $1}') || PRESET="bora"

    [ -z "$PRESET" ] && PRESET="bora"

    local STARSHIP_SRC="$PRESETS_DIR/${PRESET}.toml"

    if [ -f "$STARSHIP_SRC" ]; then
        cp "$STARSHIP_SRC" "$CONFIG_DIR/starship.toml"
        log_ok "$L_STARSHIP_DONE ($PRESET)"
    else
        log_warn "$L_STARSHIP_FALLBACK"
        cat <<'EOF' > "$CONFIG_DIR/starship.toml"
format = "$directory$git_branch$git_status$character"
[character]
success_symbol = "[❯](bold cyan)"
error_symbol = "[✗](bold red)"
EOF
    fi

    chown -R "$USUARIO_REAL:$USUARIO_REAL" "$CONFIG_DIR"
    log_warn "$L_STARSHIP_FONT_HINT"
}

# ==========================================
# 12. ZSH FULL SETUP
# ==========================================
configurar_zsh_completo() {
    section "$L_ZSH_SECTION"

    # Zoxide
    if ! command -v zoxide &>/dev/null; then
        run_cmd "$L_ZSH_ZOXIDE" "pacman -S --noconfirm zoxide" || true
    else
        log_ok "$L_ZSH_ZOXIDE_ALREADY"
    fi

    # ZSH Plugins
    local plugins=(
        "https://github.com/zsh-users/zsh-history-substring-search.git .zsh-history-substring-search"
        "https://github.com/zsh-users/zsh-autosuggestions.git .zsh-autosuggestions"
        "https://github.com/zsh-users/zsh-syntax-highlighting.git .zsh-syntax-highlighting"
    )

    for entry in "${plugins[@]}"; do
        local url="${entry%% *}"
        local dir="${entry##* }"
        local dest="$HOME_USUARIO/$dir"
        if [ -d "$dest" ]; then
            log_ok "Plugin $dir ($L_ZSH_PLUGIN_EXISTS)"
        else
            run_cmd "Plugin $dir" "sudo -u $USUARIO_REAL git clone --depth 1 $url $dest" || true
        fi
    done

    local ARQUIVO_ZSHRC="$HOME_USUARIO/.zshrc"
    [ -f "$ARQUIVO_ZSHRC" ] && mv "$ARQUIVO_ZSHRC" "$ARQUIVO_ZSHRC.old"

    cat <<'EOF' > "$ARQUIVO_ZSHRC"
# History Control
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt EXTENDED_HISTORY
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS

HISTORY_IGNORE="(ls|cd|pwd|clear|c|exit|history|* --help)"
HISTFILE=~/.zsh_history
HISTSIZE=32768
SAVEHIST=32768

# Emacs Keybinding
bindkey -e
LESS_TERMCAP_md="$(tput bold 2> /dev/null; tput setaf 2 2> /dev/null)"
LESS_TERMCAP_me="$(tput sgr0 2> /dev/null)"

# The following lines were added by compinstall
zstyle :compinstall filename '~/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

# Path Changes
export PATH="$HOME/.local/bin:$PATH"

### Functions ----------------------------------------------
compress() { tar -czf "${1%/}.tar.gz" "${1%/}"; }
open() { xdg-open "$@" >/dev/null 2>&1 & }
git_current_branch() {
  local ref
  ref=$(git symbolic-ref --quiet HEAD 2>/dev/null) || ref=$(git rev-parse --short HEAD 2>/dev/null) || return 1
  echo ${ref#refs/heads/}
}

### END Functions ------------------------------------------

### Aliases ------------------------------------------------
if command -v eza &> /dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

if command -v zoxide &> /dev/null; then
  alias cd="zd"
  zd() {
    if [ $# -eq 0 ]; then builtin cd ~ && return; elif [ -d "$1" ]; then builtin cd "$1"; else z "$@" && printf "\U000F17A9 " && pwd || echo "Error: Directory not found"; fi
  }
fi

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
alias d='docker'
alias r='rails'
alias lg='lazygit'
alias ld='lazydocker'
n() { if [ "$#" -eq 0 ]; then nvim .; else nvim "$@"; fi; }

# Git
alias g='git'
alias gb='git branch'
alias gs='git status'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'
alias gpsup='git push --set-upstream origin $(git_current_branch)'

# Misc
alias c='clear'
alias decompress="tar -xzf"
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
alias cat="bat"

# Detect package manager and define universal aliases
if (( $+commands[pacman] )); then
    alias remove='sudo pacman -Rsn'; alias install='sudo pacman -S'; alias upgrade='sudo pacman -Syu'; alias fixpacman="sudo rm /var/lib/pacman/db.lck"
elif (( $+commands[apt] )); then
    alias remove='sudo apt remove'; alias install='sudo apt install'; alias upgrade='sudo apt update && sudo apt upgrade'
elif (( $+commands[dnf] )); then
    alias remove='sudo dnf remove'; alias install='sudo dnf install'; alias upgrade='sudo dnf upgrade'
fi

# Flatpak aliases (suppress Qt/Gtk warnings)
command -v flatpak &>/dev/null && {
  alias insomnia="flatpak run rest.insomnia.Insomnia 2>/dev/null"
  alias postman="flatpak run com.getpostman.Postman 2>/dev/null"
  alias drawio="flatpak run com.jgraph.drawio.desktop 2>/dev/null"
  alias bottles="flatpak run com.usebottles.bottles 2>/dev/null"
  alias deezer="flatpak run dev.aunetx.deezer 2>/dev/null"
  alias discord="flatpak run com.discordapp.Discord 2>/dev/null"
  alias localsend="flatpak run org.localsend.localsend_app 2>/dev/null"
  alias smile="flatpak run it.mijorus.smile 2>/dev/null"
  alias qalculate="flatpak run io.github.Qalculate 2>/dev/null"
  alias dbeaver="flatpak run io.dbeaver.DBeaverCommunity 2>/dev/null"
  alias zapzap="flatpak run com.rtosta.zapzap 2>/dev/null"
  alias code="flatpak run com.visualstudio.code 2>/dev/null"
}

alias zconfig='code ~/.zshrc'
alias zconf='code ~/.zshrc'
alias zreload='source ~/.zshrc'

### END Aliases ---------------------------------------------

### Plugins
[ -f ~/.zsh-autosuggestions/zsh-autosuggestions.zsh ] && source ~/.zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f ~/.zsh-history-substring-search/zsh-history-substring-search.zsh ] && source ~/.zsh-history-substring-search/zsh-history-substring-search.zsh

### Keybinds in Terminal
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey "^[[1;5C" forward-word       # Ctrl + Seta Direita
bindkey "^[[1;5D" backward-word      # Ctrl + Seta Esquerda
bindkey "^[[1;3D" beginning-of-line  # Alt + Seta Esquerda
bindkey "^[[1;3C" end-of-line        # Alt + Seta Direita
bindkey "^D" kill-word               # Ctrl+D - Delete Word

# Delimitadores de palavra: / e . não estão, então Ctrl+left para em pontos e /
WORDCHARS='*?_-[]~=&;!#$%^(){}<>'

### Init
if command -v mise &> /dev/null; then eval "$(mise activate zsh)"; fi
if command -v starship &> /dev/null; then eval "$(starship init zsh)"; fi
if command -v zoxide &> /dev/null; then eval "$(zoxide init zsh)"; fi
if command -v fzf &> /dev/null; then
  [ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
  [ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
fi
EOF

    chown "$USUARIO_REAL:$USUARIO_REAL" "$ARQUIVO_ZSHRC"
    chmod 644 "$ARQUIVO_ZSHRC"
    log_ok "$L_ZSH_DONE"
}

# ==========================================
# 13. THEMES (GTK + ICONS + CURSORS)
# ==========================================
instalar_themes() {
    section "$L_THEMES_SECTION"

    local THEMES
    THEMES=$(menu_themes) || { log_skip "$L_THEMES_NONE"; return 0; }

    local THEME_DIR="$HOME_USUARIO/.themes"
    local ICON_DIR="$HOME_USUARIO/.local/share/icons"
    mkdir -p "$THEME_DIR" "$ICON_DIR"

    # Dependencias para compilar temas GTK
    if ! command -v sassc &>/dev/null; then
        run_cmd "$L_INSTALLING sassc ($L_THEMES_DEP)" \
            "pacman -S --noconfirm sassc" || true
    fi

    for item in $THEMES; do
        case "$item" in
            orchis)
                if [ -d "$THEME_DIR/Orchis" ] || [ -d "$THEME_DIR/Orchis-Dark" ]; then
                    log_ok "Orchis ($L_ALREADY_INSTALLED)"
                else
                    run_cmd "$L_INSTALLING Orchis GTK Theme" \
                        "rm -rf /tmp/orchis-theme && git clone --depth 1 https://github.com/vinceliuice/Orchis-theme.git /tmp/orchis-theme && cd /tmp/orchis-theme && bash install.sh -d $THEME_DIR; rm -rf /tmp/orchis-theme" || true
                fi
                ;;
            colloid)
                if [ -d "$THEME_DIR/Colloid" ] || [ -d "$THEME_DIR/Colloid-Dark" ]; then
                    log_ok "Colloid ($L_ALREADY_INSTALLED)"
                else
                    run_cmd "$L_INSTALLING Colloid GTK Theme" \
                        "rm -rf /tmp/colloid-theme && git clone --depth 1 https://github.com/vinceliuice/Colloid-gtk-theme.git /tmp/colloid-theme && cd /tmp/colloid-theme && bash install.sh -d $THEME_DIR; rm -rf /tmp/colloid-theme" || true
                fi
                ;;
            fluent)
                if [ -d "$THEME_DIR/Fluent" ] || [ -d "$THEME_DIR/Fluent-Dark" ]; then
                    log_ok "Fluent ($L_ALREADY_INSTALLED)"
                else
                    run_cmd "$L_INSTALLING Fluent GTK Theme" \
                        "rm -rf /tmp/fluent-theme && git clone --depth 1 https://github.com/vinceliuice/Fluent-gtk-theme.git /tmp/fluent-theme && cd /tmp/fluent-theme && bash install.sh -d $THEME_DIR; rm -rf /tmp/fluent-theme" || true
                fi
                ;;
            graphite)
                if [ -d "$THEME_DIR/Graphite" ] || [ -d "$THEME_DIR/Graphite-Dark" ]; then
                    log_ok "Graphite ($L_ALREADY_INSTALLED)"
                else
                    run_cmd "$L_INSTALLING Graphite GTK Theme" \
                        "rm -rf /tmp/graphite-theme && git clone --depth 1 https://github.com/vinceliuice/Graphite-gtk-theme.git /tmp/graphite-theme && cd /tmp/graphite-theme && bash install.sh -d $THEME_DIR; rm -rf /tmp/graphite-theme" || true
                fi
                ;;
            lavanda)
                if [ -d "$THEME_DIR/Lavanda" ] || [ -d "$THEME_DIR/Lavanda-Dark" ]; then
                    log_ok "Lavanda ($L_ALREADY_INSTALLED)"
                else
                    run_cmd "$L_INSTALLING Lavanda GTK Theme" \
                        "rm -rf /tmp/lavanda-theme && git clone --depth 1 https://github.com/vinceliuice/Lavanda-gtk-theme.git /tmp/lavanda-theme && cd /tmp/lavanda-theme && bash install.sh -d $THEME_DIR; rm -rf /tmp/lavanda-theme" || true
                fi
                ;;
            papirus)
                if [ -d "$ICON_DIR/Papirus" ]; then
                    log_ok "Papirus Icons ($L_ALREADY_INSTALLED)"
                else
                    run_cmd "$L_INSTALLING Papirus Icons" \
                        "wget -qO- https://git.io/papirus-icon-theme-install | DESTDIR=$ICON_DIR sh" || true
                fi
                ;;
            tela-icons)
                if [ -d "$ICON_DIR/Tela" ]; then
                    log_ok "Tela Icons ($L_ALREADY_INSTALLED)"
                else
                    run_cmd "$L_INSTALLING Tela Icons" \
                        "rm -rf /tmp/tela-icons && git clone --depth 1 https://github.com/vinceliuice/Tela-icon-theme.git /tmp/tela-icons && cd /tmp/tela-icons && bash install.sh -d $ICON_DIR; rm -rf /tmp/tela-icons" || true
                fi
                ;;
            colloid-icons)
                if [ -d "$ICON_DIR/Colloid" ]; then
                    log_ok "Colloid Icons ($L_ALREADY_INSTALLED)"
                else
                    run_cmd "$L_INSTALLING Colloid Icons" \
                        "rm -rf /tmp/colloid-icons && git clone --depth 1 https://github.com/vinceliuice/Colloid-icon-theme.git /tmp/colloid-icons && cd /tmp/colloid-icons && bash install.sh -d $ICON_DIR; rm -rf /tmp/colloid-icons" || true
                fi
                ;;
            bibata)
                if [ -d "$ICON_DIR/Bibata-Modern-Classic" ]; then
                    log_ok "Bibata Cursors ($L_ALREADY_INSTALLED)"
                else
                    local BIBATA_URL
                    BIBATA_URL=$(curl -s https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest | grep -oP '"browser_download_url": "\K[^"]*Bibata-Modern-Classic\.tar\.xz' | head -1)
                    if [ -n "$BIBATA_URL" ]; then
                        run_cmd "$L_INSTALLING Bibata Cursors" \
                            "wget -q '$BIBATA_URL' -O /tmp/bibata.tar.xz && tar -xf /tmp/bibata.tar.xz -C $ICON_DIR && rm -f /tmp/bibata.tar.xz" || true
                    else
                        log_warn "$L_THEMES_BIBATA_FAIL"
                    fi
                fi
                ;;
            skeuos)
                if ls "$THEME_DIR"/Skeuos-* &>/dev/null; then
                    log_ok "Skeuos ($L_ALREADY_INSTALLED)"
                else
                    run_cmd "$L_INSTALLING Skeuos GTK Theme" \
                        "rm -rf /tmp/skeuos-gtk && git clone --depth 1 https://github.com/daniruiz/skeuos-gtk.git /tmp/skeuos-gtk && cp -r /tmp/skeuos-gtk/themes/Skeuos-Blue-Dark $THEME_DIR/ && cp -r /tmp/skeuos-gtk/themes/Skeuos-Blue-Light $THEME_DIR/ && cp -r /tmp/skeuos-gtk/themes/Skeuos-Grey-Dark $THEME_DIR/ && cp -r /tmp/skeuos-gtk/themes/Skeuos-Black-Light $THEME_DIR/; rm -rf /tmp/skeuos-gtk" || true
                fi
                ;;
        esac
    done

    chown -R "$USUARIO_REAL:$USUARIO_REAL" "$THEME_DIR" "$ICON_DIR"
    log_ok "$L_THEMES_DONE"
    log_warn "$L_THEMES_APPLY_HINT"
}

# ==========================================
# 14. GOOGLE DRIVE (RCLONE BISYNC)
# ==========================================
configurar_google_drive() {
    section "$L_GDRIVE_SECTION"

    local GDRIVE_ACTION
    GDRIVE_ACTION=$(gum choose --no-limit \
        --header="$L_GDRIVE_TITLE — $L_GDRIVE_DESC" \
        --selected="instalar  $L_GDRIVE_INSTALL" \
        "instalar  $L_GDRIVE_INSTALL" \
        "nova-conta  $L_GDRIVE_NEW" \
        "editar-pastas  $L_GDRIVE_EDIT" \
        "remover-conta  $L_GDRIVE_REMOVE" | awk '{print $1}' | tr '\n' ' ') || { log_skip "$L_GDRIVE_CANCELLED"; return 0; }
    [ -z "$GDRIVE_ACTION" ] && { log_skip "$L_GDRIVE_CANCELLED"; return 0; }

    # --- Install rclone + systemd timer ---
    if echo "$GDRIVE_ACTION" | grep -q "instalar"; then
        if ! command -v rclone &>/dev/null; then
            run_cmd "$L_GDRIVE_RCLONE_INSTALL" "curl https://rclone.org/install.sh | bash" || true
        else
            log_ok "$L_GDRIVE_RCLONE_ALREADY"
        fi

        # Create base directory
        local GDRIVE_DIR="$HOME_USUARIO/GoogleDrive"
        mkdir -p "$GDRIVE_DIR"
        chown "$USUARIO_REAL:$USUARIO_REAL" "$GDRIVE_DIR"
        log_ok "$L_GDRIVE_DIR_CREATED: $GDRIVE_DIR"

        # Sync script that synchronizes all "drive" type remotes
        local SYNC_SCRIPT="$HOME_USUARIO/.local/bin/gdrive-sync.sh"
        mkdir -p "$(dirname "$SYNC_SCRIPT")"

        cat <<'SYNCEOF' > "$SYNC_SCRIPT"
#!/bin/bash
# gdrive-sync.sh — Sincroniza todas as contas Google Drive configuradas no rclone
# Config de pastas: ~/.config/rclone/gdrive-folders-<remote>.conf
# Se o arquivo não existir ou estiver vazio, sincroniza TUDO.
# Se existir, sincroniza apenas as pastas listadas (uma por linha).

LOG="$HOME/.local/share/gdrive-sync.log"
GDRIVE_DIR="$HOME/GoogleDrive"
CONFIG_DIR="$HOME/.config/rclone"

echo "=== $(date) ===" >> "$LOG"

sync_remote() {
    local remote_name="$1"
    local remote_path="$2"
    local sync_dir="$3"
    local label="$4"

    mkdir -p "$sync_dir"
    echo "[SYNC] $label → $sync_dir" >> "$LOG"

    local init_flag="$CONFIG_DIR/bisync_${remote_name}_$(echo "$remote_path" | tr '/' '_').initialized"

    if [ ! -f "$init_flag" ]; then
        rclone bisync "${remote_name}:${remote_path}" "$sync_dir" --resync --verbose >> "$LOG" 2>&1
        if [ $? -eq 0 ]; then
            touch "$init_flag"
            echo "[OK] $label inicializado" >> "$LOG"
        else
            echo "[ERRO] $label falhou no --resync" >> "$LOG"
        fi
    else
        rclone bisync "${remote_name}:${remote_path}" "$sync_dir" --verbose >> "$LOG" 2>&1
    fi
}

for remote in $(rclone listremotes 2>/dev/null); do
    remote_name="${remote%:}"
    remote_type=$(rclone config show "$remote_name" 2>/dev/null | grep "^type" | awk '{print $3}')

    [ "$remote_type" = "drive" ] || continue

    local_base="$GDRIVE_DIR/$remote_name"
    folders_conf="$CONFIG_DIR/gdrive-folders-${remote_name}.conf"

    if [ -f "$folders_conf" ] && [ -s "$folders_conf" ]; then
        # Modo seletivo: synca apenas as pastas listadas
        while IFS= read -r folder || [ -n "$folder" ]; do
            [ -z "$folder" ] && continue
            [[ "$folder" == \#* ]] && continue
            folder="${folder%/}"
            sync_remote "$remote_name" "$folder" "$local_base/$folder" "$remote_name:$folder"
        done < "$folders_conf"
    else
        # Modo completo: synca tudo
        sync_remote "$remote_name" "" "$local_base" "$remote_name"
    fi
done

echo "=== Fim $(date) ===" >> "$LOG"
SYNCEOF

        chmod +x "$SYNC_SCRIPT"
        chown "$USUARIO_REAL:$USUARIO_REAL" "$SYNC_SCRIPT"
        log_ok "$L_GDRIVE_SYNC_CREATED: $SYNC_SCRIPT"

        # Systemd user timer (runs as user, not root)
        local SYSTEMD_DIR="$HOME_USUARIO/.config/systemd/user"
        mkdir -p "$SYSTEMD_DIR"

        cat <<EOF > "$SYSTEMD_DIR/gdrive-sync.service"
[Unit]
Description=Google Drive bisync via rclone

[Service]
Type=oneshot
ExecStart=%h/.local/bin/gdrive-sync.sh

[Install]
WantedBy=default.target
EOF

        cat <<EOF > "$SYSTEMD_DIR/gdrive-sync.timer"
[Unit]
Description=Sync Google Drive a cada 15 minutos

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF

        chown -R "$USUARIO_REAL:$USUARIO_REAL" "$SYSTEMD_DIR"

        # Enable timer as user
        sudo -u "$USUARIO_REAL" bash -c "systemctl --user daemon-reload && systemctl --user enable gdrive-sync.timer && systemctl --user start gdrive-sync.timer" 2>/dev/null || \
            log_warn "$L_GDRIVE_TIMER_WARN"

        log_ok "$L_GDRIVE_TIMER_DONE"
    fi

    # --- Configure new account ---
    if echo "$GDRIVE_ACTION" | grep -q "nova-conta"; then
        if ! command -v rclone &>/dev/null; then
            log_warn "$L_GDRIVE_RCLONE_MISSING"
            return 1
        fi

        local NOME_CONTA
        NOME_CONTA=$(gum input --header="$L_GDRIVE_NEW_TITLE" --placeholder="$L_GDRIVE_NEW_DESC") || { log_skip "$L_GDRIVE_NEW_CANCELLED"; return 0; }

        if [ -z "$NOME_CONTA" ]; then
            log_warn "$L_GDRIVE_NEW_EMPTY"
            return 0
        fi

        echo ""
        echo -e "  ${AZUL}▸${NC} $L_GDRIVE_OPENING ${BOLD}$NOME_CONTA${NC}..."
        echo -e "  ${CINZA}  $L_GDRIVE_FOLLOW $NOME_CONTA → type: drive → ...${NC}"
        echo ""

        # rclone config is interactive — needs to run in terminal as user
        sudo -u "$USUARIO_REAL" rclone config

        # Check if remote was created
        if sudo -u "$USUARIO_REAL" rclone listremotes 2>/dev/null | grep -q "^${NOME_CONTA}:"; then
            local SYNC_DIR="$HOME_USUARIO/GoogleDrive/$NOME_CONTA"
            mkdir -p "$SYNC_DIR"
            chown "$USUARIO_REAL:$USUARIO_REAL" "$SYNC_DIR"
            log_ok "'$NOME_CONTA' $L_GDRIVE_CONFIGURED → $SYNC_DIR"

            # Ask if they want to sync everything or specific folders
            local SYNC_MODE
            SYNC_MODE=$(gum choose --header="$L_GDRIVE_SYNC_MODE_TITLE — $NOME_CONTA: $L_GDRIVE_SYNC_MODE_DESC" \
                "tudo  $L_GDRIVE_SYNC_ALL" \
                "pastas  $L_GDRIVE_SYNC_FOLDERS" | awk '{print $1}') || SYNC_MODE="tudo"

            local FOLDERS_CONF="$HOME_USUARIO/.config/rclone/gdrive-folders-${NOME_CONTA}.conf"
            mkdir -p "$(dirname "$FOLDERS_CONF")"

            if [ "$SYNC_MODE" = "pastas" ]; then
                echo ""
                echo -e "  ${AZUL}▸${NC} $L_GDRIVE_AVAILABLE ${BOLD}$NOME_CONTA${NC}:"
                echo ""
                sudo -u "$USUARIO_REAL" rclone lsd "${NOME_CONTA}:" 2>/dev/null | awk '{print "    " $NF}'
                echo ""

                local PASTAS_INPUT
                PASTAS_INPUT=$(gum input --header="$L_GDRIVE_FOLDERS_TITLE — $NOME_CONTA" --placeholder="$L_GDRIVE_INPUT_DESC") || PASTAS_INPUT=""

                if [ -n "$PASTAS_INPUT" ]; then
                    # Convert commas to lines
                    echo "# Pastas para sync de $NOME_CONTA" > "$FOLDERS_CONF"
                    echo "# Uma pasta por linha. Comente com # para desativar." >> "$FOLDERS_CONF"
                    echo "# Remova este arquivo para syncar tudo." >> "$FOLDERS_CONF"
                    echo "$PASTAS_INPUT" | tr ',' '\n' | sed 's/^ *//;s/ *$//' >> "$FOLDERS_CONF"
                    chown "$USUARIO_REAL:$USUARIO_REAL" "$FOLDERS_CONF"
                    log_ok "$L_GDRIVE_SELECTIVE_DONE: $(echo "$PASTAS_INPUT" | tr ',' ', ')"
                    log_warn "$L_GDRIVE_EDIT_HINT: $FOLDERS_CONF"
                else
                    log_warn "$L_GDRIVE_NO_FOLDERS"
                    rm -f "$FOLDERS_CONF"
                fi
            else
                # Remove folder config if exists (sync all)
                rm -f "$FOLDERS_CONF"
                log_ok "$L_GDRIVE_FULL_DONE"
            fi

            log_warn "$L_GDRIVE_FIRST_SYNC"
        else
            log_warn "'$NOME_CONTA' $L_GDRIVE_NOT_FOUND"
        fi
    fi

    # --- Edit sync folders ---
    if echo "$GDRIVE_ACTION" | grep -q "editar-pastas"; then
        if ! command -v rclone &>/dev/null; then
            log_warn "$L_GDRIVE_RCLONE_MISSING2"
            return 1
        fi

        # List available accounts
        local REMOTES
        REMOTES=$(sudo -u "$USUARIO_REAL" rclone listremotes 2>/dev/null | while read -r r; do
            rname="${r%:}"
            rtype=$(sudo -u "$USUARIO_REAL" rclone config show "$rname" 2>/dev/null | grep "^type" | awk '{print $3}')
            [ "$rtype" = "drive" ] && echo "$rname"
        done)

        if [ -z "$REMOTES" ]; then
            log_warn "$L_GDRIVE_NO_ACCOUNTS"
        else
            # Menu to select which account to edit
            local REMOTE_LINES=()
            for rname in $REMOTES; do
                local conf_file="$HOME_USUARIO/.config/rclone/gdrive-folders-${rname}.conf"
                local status="$L_GDRIVE_ALL"
                [ -f "$conf_file" ] && [ -s "$conf_file" ] && status="$L_GDRIVE_SELECTIVE"
                REMOTE_LINES+=("$rname  [$status]")
            done

            local EDIT_CONTA
            EDIT_CONTA=$(printf '%s\n' "${REMOTE_LINES[@]}" | gum choose --header="$L_GDRIVE_EDIT_TITLE — $L_GDRIVE_EDIT_DESC" | awk '{print $1}') || return 0

            if [ -n "$EDIT_CONTA" ]; then
                local FOLDERS_CONF="$HOME_USUARIO/.config/rclone/gdrive-folders-${EDIT_CONTA}.conf"

                # Fetch Drive folders
                echo ""
                echo -e "  ${AZUL}▸${NC} $L_GDRIVE_LOADING ${BOLD}$EDIT_CONTA${NC}..."
                local DRIVE_FOLDERS
                DRIVE_FOLDERS=$(sudo -u "$USUARIO_REAL" rclone lsd "${EDIT_CONTA}:" 2>/dev/null | awk '{print $NF}')

                if [ -z "$DRIVE_FOLDERS" ]; then
                    log_warn "$L_GDRIVE_CANT_LIST"
                    return 0
                fi

                # Build folder list with pre-selected items
                local FOLDER_LINES=()
                local PRESELECTED=()
                for folder in $DRIVE_FOLDERS; do
                    FOLDER_LINES+=("$folder")
                    if [ -f "$FOLDERS_CONF" ] && grep -qx "$folder" "$FOLDERS_CONF" 2>/dev/null; then
                        PRESELECTED+=("$folder")
                    elif [ ! -f "$FOLDERS_CONF" ] || [ ! -s "$FOLDERS_CONF" ]; then
                        # If no conf (sync all), check all
                        PRESELECTED+=("$folder")
                    fi
                done

                local selected_arg=""
                if [ ${#PRESELECTED[@]} -gt 0 ]; then
                    local IFS=","
                    selected_arg="--selected=${PRESELECTED[*]}"
                fi

                local SELECTED_FOLDERS
                SELECTED_FOLDERS=$(printf '%s\n' "${FOLDER_LINES[@]}" | gum choose --no-limit \
                    --header="$L_GDRIVE_FOLDERS_TITLE — $EDIT_CONTA: $L_GDRIVE_EDIT_FOLDERS_DESC" \
                    --height=50 $selected_arg | tr '\n' ' ') || return 0
                SELECTED_FOLDERS=$(echo "$SELECTED_FOLDERS" | xargs)

                # Count total folders and selected folders
                local TOTAL_FOLDERS
                TOTAL_FOLDERS=$(echo "$DRIVE_FOLDERS" | wc -w)
                local SELECTED_COUNT
                SELECTED_COUNT=$(echo "$SELECTED_FOLDERS" | wc -w)

                if [ -z "$SELECTED_FOLDERS" ] || [ "$SELECTED_COUNT" -eq "$TOTAL_FOLDERS" ]; then
                    # None or all = sync everything
                    rm -f "$FOLDERS_CONF"
                    log_ok "$EDIT_CONTA: $L_GDRIVE_FULL_DONE"
                else
                    # Save selected folders
                    echo "# Pastas para sync de $EDIT_CONTA" > "$FOLDERS_CONF"
                    echo "# Editado em $(date +%Y-%m-%d). Remova o arquivo para syncar tudo." >> "$FOLDERS_CONF"
                    for f in $SELECTED_FOLDERS; do
                        echo "$f" >> "$FOLDERS_CONF"
                    done
                    chown "$USUARIO_REAL:$USUARIO_REAL" "$FOLDERS_CONF"
                    log_ok "$EDIT_CONTA: $L_GDRIVE_SELECTIVE_DONE → $SELECTED_FOLDERS"
                fi

                # Remove initialization flag to force resync
                rm -f "$HOME_USUARIO/.config/rclone/bisync_${EDIT_CONTA}"_*.initialized
                log_warn "$L_GDRIVE_RESYNC"
            fi
        fi
    fi

    # --- Remove account ---
    if echo "$GDRIVE_ACTION" | grep -q "remover-conta"; then
        if ! command -v rclone &>/dev/null; then
            log_warn "$L_GDRIVE_RCLONE_MISSING2"
            return 1
        fi

        local REMOTES
        REMOTES=$(sudo -u "$USUARIO_REAL" rclone listremotes 2>/dev/null | while read -r r; do
            rname="${r%:}"
            rtype=$(sudo -u "$USUARIO_REAL" rclone config show "$rname" 2>/dev/null | grep "^type" | awk '{print $3}')
            [ "$rtype" = "drive" ] && echo "$rname"
        done)

        if [ -z "$REMOTES" ]; then
            log_warn "$L_GDRIVE_NO_ACCOUNTS"
        else
            local REMOVE_LINES=()
            for rname in $REMOTES; do
                REMOVE_LINES+=("$rname")
            done

            local DEL_CONTA
            DEL_CONTA=$(printf '%s\n' "${REMOVE_LINES[@]}" | gum choose --header="$L_GDRIVE_REMOVE_TITLE — $L_GDRIVE_REMOVE_DESC") || return 0

            if [ -n "$DEL_CONTA" ]; then
                local CONFIRM_MSG
                CONFIRM_MSG=$(printf "$L_GDRIVE_CONFIRM_DESC" "$DEL_CONTA" "$DEL_CONTA")
                if gum confirm "$CONFIRM_MSG"; then

                    sudo -u "$USUARIO_REAL" rclone config delete "$DEL_CONTA" 2>/dev/null
                    rm -f "$HOME_USUARIO/.config/rclone/gdrive-folders-${DEL_CONTA}.conf"
                    rm -f "$HOME_USUARIO/.config/rclone/bisync_${DEL_CONTA}"_*.initialized
                    log_ok "'$DEL_CONTA' $L_GDRIVE_REMOVED"
                    log_warn "$L_GDRIVE_FILES_KEPT"
                else
                    log_skip "$L_GDRIVE_REMOVE_CANCELLED"
                fi
            fi
        fi
    fi
}

# ==========================================
# 15. KEYBOARD FIX (US Intl cedilla via uim)
# ==========================================
configurar_teclado() {
    section "$L_KEYBOARD_SECTION"

    # Install uim (AUR on Arch)
    run_cmd "$L_KEYBOARD_UIM" "sudo -u $USUARIO_REAL yay -S --noconfirm uim"

    # Set input method modules in ~/.profile
    local PROFILE="$HOME_USUARIO/.profile"
    if ! grep -q 'GTK_IM_MODULE="uim"' "$PROFILE" 2>/dev/null; then
        printf '\nexport GTK_IM_MODULE="uim"\nexport QT_IM_MODULE="uim"\n' >> "$PROFILE"
        chown "$USUARIO_REAL:$USUARIO_REAL" "$PROFILE"
        log_ok "$L_KEYBOARD_PROFILE"
    fi

    # Copy XCompose (based on lucasfais/xcompose-pt-BR_US)
    local XCOMPOSE="$HOME_USUARIO/.XCompose"
    cp "$SCRIPT_DIR/configs/keyboard/XCompose" "$XCOMPOSE"
    chown "$USUARIO_REAL:$USUARIO_REAL" "$XCOMPOSE"
    log_ok "$L_KEYBOARD_XCOMPOSE"
}

# ==========================================
# 16. CLEANUP AND FINAL TWEAKS
# ==========================================
limpeza_e_ajustes() {
    section "$L_TWEAKS_SECTION"

    # AnyDesk autostart
    if systemctl is-active anydesk.service &>/dev/null; then
        try_cmd "$L_TWEAKS_ANYDESK" \
            "systemctl stop anydesk.service && systemctl disable anydesk.service"
    fi

    # Docker group
    usermod -aG docker "$USUARIO_REAL" 2>/dev/null && \
        log_ok "$USUARIO_REAL $L_TWEAKS_DOCKER" || true

    # Default ZSH
    local CAMINHO_ZSH
    CAMINHO_ZSH=$(which zsh 2>/dev/null || true)
    if [ -n "$CAMINHO_ZSH" ]; then
        chsh -s "$CAMINHO_ZSH" "$USUARIO_REAL" 2>/dev/null
        log_ok "$L_TWEAKS_ZSH"
    else
        log_warn "$L_TWEAKS_ZSH_NOT_FOUND"
    fi

    # PATH
    local PROFILE="$HOME_USUARIO/.profile"
    if ! grep -q '.local/bin' "$PROFILE" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE"
        chown "$USUARIO_REAL:$USUARIO_REAL" "$PROFILE"
        log_ok "$L_TWEAKS_PATH"
    fi

    # KRunner centered
    sudo -u "$USUARIO_REAL" kwriteconfig6 --file krunnerrc --group General --key FreeFloating true
    sudo -u "$USUARIO_REAL" kquitapp6 krunner 2>/dev/null; sudo -u "$USUARIO_REAL" kstart krunner 2>/dev/null &
    log_ok "$L_TWEAKS_KRUNNER"

    # Autostart apps
    local AUTOSTART_DIR="$HOME_USUARIO/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"

    # Flameshot
    cat > "$AUTOSTART_DIR/flameshot.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Flameshot
Exec=flameshot
X-GNOME-Autostart-enabled=true
EOF

    # 1Password
    if command -v 1password &>/dev/null; then
        cat > "$AUTOSTART_DIR/1password.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=1Password
Exec=1password --silent
X-GNOME-Autostart-enabled=true
EOF
    fi

    # JetBrains Toolbox
    if [ -f "$HOME_USUARIO/.local/bin/jetbrains-toolbox" ]; then
        cat > "$AUTOSTART_DIR/jetbrains-toolbox.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Exec=jetbrains-toolbox --minimize
X-GNOME-Autostart-enabled=true
EOF
    fi

    chown -R "$USUARIO_REAL:$USUARIO_REAL" "$AUTOSTART_DIR"
    log_ok "$L_TWEAKS_AUTOSTART"

    # KDE Plasma presets (disabled — TODO: use kwriteconfig6 for safe merge)
    log_skip "$L_TWEAKS_KDE_SKIP"
}

# ==========================================
# MAIN EXECUTION
# ==========================================
main() {
    clear
    echo ""
    echo -e "${BOLD}${VERDE}  bora-linux (Arch)${NC} — ${CINZA}$USUARIO_REAL${NC}"
    echo -e "  ${CINZA}Log: $LOG_FILE${NC}"
    echo -e "  ${CINZA}$L_PRESS_V${NC}"

    menu_principal

    is_selected "cleanup"  && executar_cleanup
    is_selected "upgrade"  && atualizar_sistema
    is_selected "pacman"   && instalar_pacman
    is_selected "flatpak"  && instalar_flatpak
    is_selected "fonts"    && instalar_nerd_fonts
    is_selected "scripts"  && instalar_scripts_externos
    is_selected "mise"     && configurar_mise_linguagens
    is_selected "lazyvim"  && configurar_lazyvim
    is_selected "starship" && configurar_starship
    is_selected "zsh"      && configurar_zsh_completo
    is_selected "themes"   && instalar_themes
    is_selected "gdrive"   && configurar_google_drive
    is_selected "keyboard" && configurar_teclado
    is_selected "ajustes"  && limpeza_e_ajustes

    echo ""
    echo -e "${BOLD}${VERDE}  $L_FINISHED${NC}"
    echo -e "  ${CINZA}$L_LOG_FULL: $LOG_FILE${NC}"
    echo -e "  ${AMARELO}  $L_REBOOT${NC}"
    echo ""
}

main
