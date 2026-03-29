#!/usr/bin/env bash
#
# Wolfix - AI Diagnostic Toolkit - Launcher Linux/macOS
# Configura l'ambiente dalla chiavetta USB e lancia Claude Code.
#

set -euo pipefail

# === AUTO-DETECT USB ROOT ===
USB_ROOT="$(cd "$(dirname "$0")" && pwd)"

# === COLORI ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
NC='\033[0m'

# === DETECT OS E ARCHITETTURA ===
OS_TYPE=$(uname -s)
ARCH=$(uname -m)

case "$OS_TYPE" in
    Linux)
        case "$ARCH" in
            x86_64)  NODE_DIR="$USB_ROOT/runtime/node-linux-x64" ;;
            aarch64) NODE_DIR="$USB_ROOT/runtime/node-linux-arm64" ;;
            *)
                echo -e "${RED}[ERROR] Unsupported architecture: $ARCH${NC}"
                exit 1
                ;;
        esac
        ;;
    Darwin)
        case "$ARCH" in
            x86_64)  NODE_DIR="$USB_ROOT/runtime/node-darwin-x64" ;;
            arm64)   NODE_DIR="$USB_ROOT/runtime/node-darwin-arm64" ;;
            *)
                echo -e "${RED}[ERROR] Unsupported architecture: $ARCH${NC}"
                exit 1
                ;;
        esac
        ;;
    *)
        echo -e "${RED}[ERROR] Unsupported OS: $OS_TYPE${NC}"
        exit 1
        ;;
esac

# === VERIFICA NODE.JS ===
# Estraiamo SEMPRE in /tmp/ per 3 motivi:
# 1. exFAT non supporta symlink (npm, npx, corepack sono symlink)
# 2. exFAT/USB montata con noexec (node non puo' essere eseguito)
# 3. Disco locale e' molto piu' veloce della USB
LOCAL_NODE_DIR="/tmp/wolfix-node-runtime"
LOCAL_NODE="$LOCAL_NODE_DIR/bin/node"

# Estrai solo se non gia' presente in /tmp/
if [ ! -f "$LOCAL_NODE" ]; then
    # Cerca il tar sulla chiavetta
    TAR_FILE=$(find "$NODE_DIR" -name "*.tar.xz" -o -name "*.tar.gz" 2>/dev/null | head -1)

    # Se il node e' gia' estratto sulla USB (setup Windows l'ha messo), copiamo solo il binario
    if [ -f "$NODE_DIR/bin/node" ] && [ -z "$TAR_FILE" ]; then
        echo -e "${YELLOW}[*] Preparazione runtime...${NC}"
        mkdir -p "$LOCAL_NODE_DIR/bin"
        cp "$NODE_DIR/bin/node" "$LOCAL_NODE"
        chmod +x "$LOCAL_NODE"
    elif [ -n "$TAR_FILE" ]; then
        # Verifica che xz sia disponibile per .tar.xz
        if [[ "$TAR_FILE" == *.tar.xz ]] && ! command -v xz &>/dev/null; then
            echo -e "${YELLOW}[*] Installazione xz-utils necessaria per estrarre Node.js...${NC}"
            if command -v apt-get &>/dev/null; then
                sudo apt-get update -qq && sudo apt-get install -y -qq xz-utils
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y -q xz
            elif command -v yum &>/dev/null; then
                sudo yum install -y -q xz
            elif command -v pacman &>/dev/null; then
                sudo pacman -S --noconfirm xz
            elif command -v apk &>/dev/null; then
                sudo apk add xz
            else
                echo -e "${RED}[ERRORE] xz-utils non installato e package manager non riconosciuto.${NC}"
                echo "Installa manualmente xz-utils e riprova."
                exit 1
            fi
        fi
        echo -e "${YELLOW}[*] Estrazione Node.js in locale...${NC}"
        mkdir -p "$LOCAL_NODE_DIR"
        tar -xf "$TAR_FILE" -C "$LOCAL_NODE_DIR" --strip-components=1
        chmod +x "$LOCAL_NODE" 2>/dev/null || true
        if [ -f "$LOCAL_NODE" ]; then
            echo -e "${GREEN}[OK] Node.js estratto.${NC}"
        else
            echo -e "${RED}[ERRORE] Estrazione fallita.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}[ERRORE] Node.js non trovato in $NODE_DIR${NC}"
        echo "Esegui setup-usb.ps1 su Windows per preparare la chiavetta."
        exit 1
    fi
else
    echo -e "${GREEN}[OK] Node.js gia' pronto in cache locale.${NC}"
fi

# Verifica che node funzioni
if ! "$LOCAL_NODE" --version &>/dev/null; then
    echo -e "${RED}[ERRORE] Node.js non funziona. Verifica la versione per questo OS/arch.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Node.js $("$LOCAL_NODE" --version) pronto.${NC}"

# === DETECT STRUTTURA CLAUDE-CODE ===
# npm su Windows installa in: prefix/claude.cmd + prefix/node_modules/
# npm su Unix installa in:    prefix/bin/claude + prefix/lib/node_modules/

CLAUDE_CODE_DIR="$USB_ROOT/claude-code"
CLAUDE_BIN=""
CLAUDE_CLI_JS=""
NODE_MODULES_DIR=""

# Cerca cli.js: prima layout Windows (node_modules/), poi Unix (lib/node_modules/)
if [ -f "$CLAUDE_CODE_DIR/node_modules/@anthropic-ai/claude-code/cli.js" ]; then
    CLAUDE_CLI_JS="$CLAUDE_CODE_DIR/node_modules/@anthropic-ai/claude-code/cli.js"
    NODE_MODULES_DIR="$CLAUDE_CODE_DIR/node_modules"
elif [ -f "$CLAUDE_CODE_DIR/lib/node_modules/@anthropic-ai/claude-code/cli.js" ]; then
    CLAUDE_CLI_JS="$CLAUDE_CODE_DIR/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    NODE_MODULES_DIR="$CLAUDE_CODE_DIR/lib/node_modules"
fi

if [ -n "$CLAUDE_CLI_JS" ]; then
    CLAUDE_BIN="/tmp/wolfix-claude-wrapper"
    cat > "$CLAUDE_BIN" << WRAPPER
#!/bin/sh
exec "$LOCAL_NODE" "$CLAUDE_CLI_JS" "\$@"
WRAPPER
    chmod +x "$CLAUDE_BIN"
    echo -e "${GREEN}[OK] Motore configurato.${NC}"
fi

# === CONFIGURA AMBIENTE ===
export PATH="/tmp:$NODE_DIR/bin:$PATH"
export NPM_CONFIG_PREFIX="$CLAUDE_CODE_DIR"
export CLAUDE_CONFIG_DIR="$USB_ROOT/config"
export NODE_PATH="${NODE_MODULES_DIR:-$CLAUDE_CODE_DIR/node_modules}"

# === VERIFICA CLAUDE CODE ===
if [ -z "$CLAUDE_BIN" ] || [ ! -f "$CLAUDE_BIN" ]; then
    echo -e "${RED}[ERRORE] Claude Code non trovato.${NC}"
    echo ""
    echo "Possibili cause:"
    echo "  - La chiavetta non è stata preparata (esegui setup-usb.ps1 su Windows)"
    echo "  - La struttura claude-code/ è incompleta"
    echo ""
    echo "Contenuto claude-code/:"
    ls -la "$CLAUDE_CODE_DIR/" 2>/dev/null || echo "  (directory non trovata)"
    exit 1
fi

# === DETECT SISTEMA ===
if [ "$OS_TYPE" = "Darwin" ]; then
    OS_NAME=$(sw_vers -productName 2>/dev/null || echo "macOS")
    OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    OS_NAME="$OS_NAME $OS_VERSION"
    KERNEL=$(uname -r)
    RAM_GB=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f", $1/1073741824}' || echo "N/A")
else
    OS_NAME=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME=" | cut -d'"' -f2 || uname -s)
    KERNEL=$(uname -r)
    RAM_GB=$(free -g 2>/dev/null | awk '/Mem:/{print $2}' || echo "N/A")
fi
HOSTNAME_VAL=$(hostname)

# === LANGUAGE ===
set_language() {
    if [ "$1" = "en" ]; then
        M1="[1] Full system diagnosis"
        M2="[2] Interactive Claude Code"
        M3="[3] Analyze log file"
        M4="[4] Guided fix (describe problem)"
        M5="[5] Collect data for offline analysis"
        M6="[6] Connect to remote server (SSH)"
        M7="[7] Network diagnosis"
        M8="[8] Security analysis"
        M9="[9] Safely eject USB"
        M0="[0] Exit"
        MSG_CHOICE="Choice: "
        MSG_LOGPATH="Log file path: "
        MSG_PROBLEM="Describe the problem: "
        MSG_SSHHOST="Host (user@ip): "
        MSG_DIAGSTART="[*] Starting full diagnosis..."
        MSG_NETSTART="[*] Starting network diagnosis..."
        MSG_SECSTART="[*] Starting security analysis..."
        MSG_COLLECTING="Collecting system data..."
        MSG_SAVED="[OK] Data saved in"
        MSG_NOTFOUND="[ERROR] File not found:"
        MSG_INVALID="Invalid choice."
        MSG_BYE="Goodbye. No traces left on the system."
        MSG_EJECT_SYNC="Flushing buffers..."
        MSG_EJECT_OK="USB safely ejected. You can remove the drive now."
        MSG_EJECT_FAIL="Could not eject the USB drive. Close all open files and try again."
        MSG_EJECT_CWD_1="Your terminal is inside the USB directory"
        MSG_EJECT_CWD_2="which prevents safe ejection."
        MSG_EJECT_CWD_3="Copy and paste this command:"
    else
        M1="[1] Diagnosi completa del sistema"
        M2="[2] Claude Code interattivo"
        M3="[3] Analizza file di log"
        M4="[4] Fix guidato (descrivi problema)"
        M5="[5] Raccogli dati per analisi offline"
        M6="[6] Connetti a server remoto (SSH)"
        M7="[7] Diagnosi rete"
        M8="[8] Analisi sicurezza"
        M9="[9] Sgancia chiavetta USB"
        M0="[0] Esci"
        MSG_CHOICE="Scelta: "
        MSG_LOGPATH="Percorso del file di log: "
        MSG_PROBLEM="Descrivi il problema: "
        MSG_SSHHOST="Host (user@ip): "
        MSG_DIAGSTART="[*] Avvio diagnosi completa..."
        MSG_NETSTART="[*] Avvio diagnosi rete..."
        MSG_SECSTART="[*] Avvio analisi sicurezza..."
        MSG_COLLECTING="Raccolta dati di sistema..."
        MSG_SAVED="[OK] Dati salvati in"
        MSG_NOTFOUND="[ERRORE] File non trovato:"
        MSG_INVALID="Scelta non valida."
        MSG_BYE="Arrivederci. Nessuna traccia lasciata sul sistema."
        MSG_EJECT_SYNC="Scaricamento buffer in corso..."
        MSG_EJECT_OK="Chiavetta USB sganciata in sicurezza. Puoi rimuoverla."
        MSG_EJECT_FAIL="Impossibile sganciare la chiavetta. Chiudi tutti i file aperti e riprova."
        MSG_EJECT_CWD_1="Il terminale e' nella directory della chiavetta"
        MSG_EJECT_CWD_2="e questo impedisce lo smontaggio."
        MSG_EJECT_CWD_3="Copia e incolla questo comando:"
    fi
}

# Default to Italian
set_language "it"

# === BANNER ===
show_banner() {
    echo ""
    echo -e "${GREEN}  ================================================${NC}"
    echo -e "${GREEN}  __        _____  _     _____ ___ __  __${NC}"
    echo -e "${GREEN}  \\\\ \\\\      / / _ \\\\| |   |  ___|_ _\\\\ \\\\/ /${NC}"
    echo -e "${GREEN}   \\\\ \\\\ /\\\\ / / | | | |   | |_   | | \\\\  / ${NC}"
    echo -e "${GREEN}    \\\\ V  V /| |_| | |___|  _|  | | /  \\\\ ${NC}"
    echo -e "${GREEN}     \\\\_/\\\\_/  \\\\___/|_____|_|   |___/_/\\\\_\\\\${NC}"
    echo ""
    echo -e "${GREEN}    >_ AI Problem Solver with Anthropic${NC}"
    echo ""
    echo -e "${DARKGRAY}    v0.2.0${NC}"
    echo -e "${GREEN}    Portable - no installation required${NC}"
    echo -e "${GREEN}  ================================================${NC}"
    echo ""
    echo -e "${GRAY}  Sistema: $OS_NAME${NC}"
    echo -e "${GRAY}  Kernel:  $KERNEL${NC}"
    echo -e "${GRAY}  RAM:     ${RAM_GB} GB${NC}"
    echo -e "${GRAY}  Host:    $HOSTNAME_VAL${NC}"
    echo ""
    echo -e "  ${CYAN}[I]${NC} Italiano  ${CYAN}[E]${NC} English"
    echo ""
    echo -n "  Language / Lingua: "
    read -r lang_choice
    if [ "$lang_choice" = "E" ] || [ "$lang_choice" = "e" ]; then
        set_language "en"
    else
        set_language "it"
    fi
    echo ""
}

# === MENU ===
show_menu() {
    echo -e "${GREEN}  +-----------------------------------------+${NC}"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M1"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M2"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M3"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M4"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M5"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M6"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M7"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M8"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M9"
    printf "${GREEN}  |  %-37s|${NC}\n" "$M0"
    echo -e "${GREEN}  +-----------------------------------------+${NC}"
}

# === FUNZIONI ===
do_diagnosi() {
    echo -e "${GREEN}${MSG_DIAGSTART}${NC}"
    if [ "$OS_TYPE" = "Darwin" ]; then
        "$CLAUDE_BIN" -p "You are a macOS diagnostic expert. This system is:
- OS: $OS_NAME
- Kernel: $KERNEL
- RAM: ${RAM_GB} GB
- Hostname: $HOSTNAME_VAL

Run a complete diagnosis:
1. Check critical services (launchctl list)
2. Check disk space (df -h, diskutil list)
3. Analyze RAM and CPU usage (vm_stat, top -l 1)
4. Check system.log and unified log for errors (last 24h)
5. Check network status (ifconfig, networksetup, DNS, routing)
6. Check pending software updates (softwareupdate -l)
7. Check Time Machine backup status
8. Check startup items and launch agents/daemons

For each problem: explain impact, propose fix, ask confirmation BEFORE applying."
    else
        "$CLAUDE_BIN" -p "Sei un esperto di diagnostica sistemi Linux. Questo sistema e':
- OS: $OS_NAME
- Kernel: $KERNEL
- RAM: ${RAM_GB} GB
- Hostname: $HOSTNAME_VAL

Esegui una diagnosi completa:
1. Controlla servizi critici (systemctl o service)
2. Verifica spazio disco (df, inodes)
3. Analizza utilizzo RAM e CPU (free, top/ps)
4. Cerca errori in syslog/journalctl (ultime 24h)
5. Verifica stato rete (ip, DNS, routing)
6. Controlla aggiornamenti pendenti
7. Verifica cron job falliti
8. Controlla mount points e fstab

Per ogni problema trovato: spiega l'impatto, proponi il fix, chiedi conferma PRIMA di eseguirlo."
    fi
}

do_analizza_log() {
    echo -n "$MSG_LOGPATH"
    read -r log_path
    if [ ! -f "$log_path" ]; then
        echo -e "${RED}${MSG_NOTFOUND} $log_path${NC}"
        return
    fi
    "$CLAUDE_BIN" -p "Analizza il file di log '$log_path'. Identifica errori, warning, pattern anomali. Fornisci un riepilogo strutturato e suggerisci soluzioni."
}

do_fix_guidato() {
    echo -n "$MSG_PROBLEM"
    read -r problema
    "$CLAUDE_BIN" -p "Sei un esperto di diagnostica e riparazione sistemi Linux.
Sistema: $OS_NAME ($KERNEL) - $HOSTNAME_VAL

Problema: $problema

1. Diagnostica con i comandi necessari
2. Identifica la causa root
3. Proponi il fix, chiedi conferma
4. Applica e verifica"
}

do_raccogli_dati() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        local script_path="$USB_ROOT/toolkit/scripts/collect-macos.sh"
    else
        local script_path="$USB_ROOT/toolkit/scripts/collect-linux.sh"
    fi
    if [ -f "$script_path" ]; then
        chmod +x "$script_path" 2>/dev/null || true
        bash "$script_path" "$USB_ROOT/toolkit/logs"
        echo -e "${GREEN}${MSG_SAVED} $USB_ROOT/toolkit/logs${NC}"
    else
        echo -e "${RED}[ERROR] Script not found: $script_path${NC}"
    fi
}

do_ssh_remoto() {
    echo -n "$MSG_SSHHOST"
    read -r ssh_host
    # Modalita interattiva invece di -p
    "$CLAUDE_BIN" "Collegati via SSH a $ssh_host. Diagnostica: OS, servizi, disco, memoria, log errori. Per ogni problema proponi fix e chiedi conferma."
}

do_diagnosi_rete() {
    echo -e "${GREEN}${MSG_NETSTART}${NC}"
    if [ "$OS_TYPE" = "Darwin" ]; then
        "$CLAUDE_BIN" -p "Complete macOS network diagnosis: interfaces (ifconfig), IP config, DNS (scutil --dns), routing (netstat -rn), listening ports (lsof -i -P), active connections, firewall (socketfilterfw), connectivity test. Identify problems and propose fixes."
    else
        "$CLAUDE_BIN" -p "Diagnosi completa rete Linux: interfacce, IP, DNS, routing, porte in ascolto (ss/netstat), connessioni attive, firewall (iptables/nftables/firewalld), test connettivita'. Identifica problemi e proponi fix."
    fi
}

do_analisi_sicurezza() {
    echo -e "${GREEN}${MSG_SECSTART}${NC}"
    if [ "$OS_TYPE" = "Darwin" ]; then
        "$CLAUDE_BIN" -p "Run a COMPLETE and AUTONOMOUS macOS security analysis without asking for confirmation. Run all checks automatically in sequence. Check: users/groups (dscl), FileVault status, Gatekeeper, SIP (csrutil), firewall, SSH config, open ports, installed profiles (profiles list), suspicious launch agents/daemons, Keychain issues, software updates, remote login, screen sharing, AirDrop settings. Do NOT ask for confirmation, do NOT stop between checks. At the end produce a structured report with severity (CRITICAL/HIGH/MEDIUM/LOW) and remediation for each issue found."
    else
        "$CLAUDE_BIN" -p "Esegui un'analisi di sicurezza COMPLETA e AUTONOMA di questo sistema Linux senza chiedere conferma. Esegui tutti i controlli in sequenza automaticamente. Controlla: utenti/gruppi, sudoers, SUID/SGID, porte aperte, servizi esposti, SSH config, fail2ban, aggiornamenti sicurezza, permessi file sensibili (/etc/shadow, /etc/passwd), crontab sospetti, processi anomali, SELinux/AppArmor, chiavi SSH autorizzate. NON chiedere conferma, NON fermarti tra un controllo e l'altro. Alla fine produci un report strutturato con severita (CRITICO/ALTO/MEDIO/BASSO) e remediation per ogni problema trovato."
    fi
}

do_sgancia_usb() {
    local mount_point device
    mount_point=$(df "$USB_ROOT" 2>/dev/null | tail -1 | awk '{print $NF}')
    device=$(df "$USB_ROOT" 2>/dev/null | tail -1 | awk '{print $1}')

    echo -e "${CYAN}${MSG_EJECT_SYNC}${NC}"
    sync

    # Pulizia file temporanei
    rm -rf /tmp/wolfix-node-runtime /tmp/wolfix-node /tmp/wolfix-claude-wrapper 2>/dev/null

    # Crea script di eject in /tmp/ (fuori dalla USB)
    local eject_script="/tmp/wolfix-eject.sh"

    cat > "$eject_script" << 'EOFHEADER'
#!/usr/bin/env bash
cd /

EJECT_OS="$1"
EJECT_DEVICE="$2"
EJECT_MOUNT="$3"
EJECT_MSG_OK="$4"
EJECT_MSG_FAIL="$5"

# Attendi che launch.sh termini
sleep 2
eject_ok=false

if [ "$EJECT_OS" = "Darwin" ]; then
    # macOS: force unmount
    if diskutil unmount force "$EJECT_MOUNT" 2>/dev/null; then
        disk_id=$(echo "$EJECT_DEVICE" | sed 's/s[0-9]*$//')
        diskutil eject "$disk_id" 2>/dev/null || true
        eject_ok=true
    fi
else
    parent_dev=$(echo "$EJECT_DEVICE" | sed 's/[0-9]*$//')

    # Chiudi tutti i processi che usano la USB (nautilus, shell, ecc.)
    fuser -km "$EJECT_MOUNT" 2>/dev/null || true
    sleep 1

    # Metodo 1: udisksctl (non richiede sudo)
    if command -v udisksctl &>/dev/null; then
        if udisksctl unmount -b "$EJECT_DEVICE" 2>/dev/null; then
            udisksctl power-off -b "$parent_dev" 2>/dev/null || true
            eject_ok=true
        fi
    fi

    # Metodo 2: gio
    if [ "$eject_ok" = "false" ] && command -v gio &>/dev/null; then
        gio mount -u "$EJECT_MOUNT" 2>/dev/null && eject_ok=true
    fi

    # Metodo 3: lazy unmount (funziona sempre)
    if [ "$eject_ok" = "false" ]; then
        sudo -n umount -l "$EJECT_MOUNT" 2>/dev/null && eject_ok=true
    fi
    if [ "$eject_ok" = "false" ]; then
        umount -l "$EJECT_MOUNT" 2>/dev/null && eject_ok=true
    fi
fi

if [ "$eject_ok" = "true" ]; then
    echo ""
    echo "$EJECT_MSG_OK"
else
    echo ""
    echo "$EJECT_MSG_FAIL"
fi

sleep 2
rm -f "$0"
EOFHEADER

    chmod +x "$eject_script"
    # Lancia in background con nohup cosi' non dipende dalla shell corrente
    nohup bash "$eject_script" "$OS_TYPE" "$device" "$mount_point" "$MSG_EJECT_OK" "$MSG_EJECT_FAIL" >/dev/null 2>&1 &
    exit 0
}

# === MAIN ===
show_banner

while true; do
    show_menu
    echo ""
    echo -n "  $MSG_CHOICE"
    read -r choice
    echo ""

    case "$choice" in
        1) do_diagnosi ;;
        2) "$CLAUDE_BIN" ;;
        3) do_analizza_log ;;
        4) do_fix_guidato ;;
        5) do_raccogli_dati ;;
        6) do_ssh_remoto ;;
        7) do_diagnosi_rete ;;
        8) do_analisi_sicurezza ;;
        9) do_sgancia_usb ;;
        0)
            echo -e "${GREEN}${MSG_BYE}${NC}"
            exit 0
            ;;
        *) echo -e "${RED}${MSG_INVALID}${NC}" ;;
    esac
    echo ""
done
