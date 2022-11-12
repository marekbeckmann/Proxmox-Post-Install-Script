#!/bin/bash
# 
# This script incorporates the following:
# https://tteck.github.io/Proxmox/
# https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_11_Bullseye
# https://github.com/Weilbyte/PVEDiscordDark


shopt -s inherit_errexit nullglob
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
WARN="${DGN}⚠${CL}"
DEBIAN_FRONTEND=noninteractive
RAM_SIZE_GB=$(($(vmstat -s | grep -i "total memory" | xargs | cut -d" " -f 1) / 1024 / 1000))
IP_ADDR="$(hostname --ip-address)"
HOSTNAME="$(hostname)"
FQDN="$(hostname -f)"
OS="$(lsb_release -is)"

function getIni() {
    startsection="$1"
    endsection="$2"
    output="$(awk "/$startsection/{ f = 1; next } /$endsection/{ f = 0 } f" "${CONFIG_FILE}")"
}

function backupConfigs() {
    cp -pr --archive "$1" "$1"-COPY-"$(date +"%m-%d-%Y")" >/dev/null 2>&1
}

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_warn() {
    local msg="$1"
    echo -e "${BFR} ${WARN} ${DGN}${msg}${CL}"
}

function msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function errorhandler() {
    msg_error "$1"
    exit 1
}

function header_info {
    clear
    echo -e "${RD}
    ____ _    _____________   ____             __     ____           __        ____
   / __ \ |  / / ____/__  /  / __ \____  _____/ /_   /  _/___  _____/ /_____ _/ / /
  / /_/ / | / / __/    / /  / /_/ / __ \/ ___/ __/   / // __ \/ ___/ __/ __  / / / 
 / ____/| |/ / /___   / /  / ____/ /_/ (__  ) /_   _/ // / / (__  ) /_/ /_/ / / /  
/_/     |___/_____/  /_/  /_/    \____/____/\__/  /___/_/ /_/____/\__/\__,_/_/_/   


${CL}"
}

function yesNoDialog() {
    while true; do
        read -p "${1}" yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*) exit 0 ;;
        *) echo "Please answer yes or no." ;;
        esac
    done

}

function checkProxmox() {
    if ! command -v pveversion >/dev/null 2>&1; then
        echo -e "\n🛑  No PVE Detected, aborting...\n"
        exit 1
    else
        PVEVERSION="$(pveversion --verbose | grep pve-manager | cut -c 14- | cut -c -6)"
        msg_ok "PVE Version ${PVEVERSION} detected"
    fi
    if [ "$(pveversion | grep "pve-manager/7" | wc -l)" -ne 1 ]; then
        echo -e "\n${RD}⚠ This version of Proxmox Virtual Environment is not supported"
        echo -e "Requires PVE Version: 7.XX${CL}"
        echo -e "\nExiting..."
        exit 1
    fi
}

function helpMsg() {
    printf '%s\n' "Help for Proxmox Post Install Script:
You can use the following Options:
  [-h] => Help Dialog
  [-c] [--config-file] => Specifies path to config file
  [-s] [--settings-file] => Specifies path to settings file
More Documentation can be found on Github: https://github.com/marekbeckmann/Proxmox-Post-Install-Script"
}

function get_Params() {
    while test $# -gt 0; do
        case "$1" in
        -h | --help)
            helpMsg
            exit 0
            ;;
        -c | --config-file)
            CONFIG_FILE="$2"
            ;;
        -s | --settings-file)
            SETTINGS_FILE="$2"
            ;;
        --*)
            msg_error "Unknown option $1"
            helpMsg
            exit 1
            ;;
        -*)
            msg_error "Unknown option $1"
            helpMsg
            exit 1
            ;;
        esac
        shift
    done
}

function checkScript() {
    header_info
    get_Params "$@"
    if [[ "$EUID" = 0 ]]; then
        if [[ -z $CONFIG_FILE ]]; then
            CONFIG_FILE="config.ini"
        fi
        if [[ -z $SETTINGS_FILE ]]; then
            SETTINGS_FILE="settings.ini"
        fi
        if [[ ! -f $CONFIG_FILE ]]; then
            errorhandler "Config file not found"
        fi
        if [[ -f $SETTINGS_FILE ]]; then
            msg_ok "Settings file found, using custom settings"
            . "$SETTINGS_FILE"
        else
            msg_info "Settings file not found, using default settings"
            yesNoDialog "Do you want to continue? [Y/n]: "
            setDefaults
        fi
        if [[ -f /etc/pve-post-install/.post-install ]]; then
            errorhandler "Post-Install script already ran, aborting..."
        fi
        if [[ $(who am i) =~ \([-a-zA-Z0-9\.]+\)$ ]]; then
            msg_warn "Detected remote session"
            yesNoDialog "Continue anyway? [y/n]: "
        fi
        checkProxmox
        basicSettings
        setLimits
        cleanUp
    else
        errorhandler "You must run this script as root"
    fi
}

function setDefaults() {
    #----------------------------------------------------------#
    DISABLE_ENTERPRISE="yes"
    DISABLE_SUB_BANNER="yes"
    UPGRADE_SYSTEM="yes"
    APT_IPV4="yes"
    COMMON_UTILS="yes"
    FIX_AMD="yes"
    KERNEL_SOURCE_HEADERS="yes"
    INCREASE_LIMITS="yes"
    OPTIMISE_LOGROTATE="yes"
    OPTIMISE_JOURNALD="yes"
    POPULATE_ENTROPY="yes"
    OPTIMISE_VZDUMP="yes"
    OPTIMISE_MEMORY="yes"
    OPTIMISE_MAX_FS="yes"
    #----------------------------------------------------------#
}

function basicSettings() {
    if [[ "$DISABLE_ENTERPRISE" = "yes" ]]; then
        msg_info "Disabling Enterprise Repository"
        sed -i "s/^deb/#deb/g" /etc/apt/sources.list.d/pve-enterprise.list >/dev/null 2>&1
        msg_ok "Disabled Enterprise Repository"
    fi
    if [[ "$ENABLE_ENTERPRISE" = "yes" ]]; then
        msg_info "Enabling Enterprise Repository"
        getIni "START_ENTERPRISE_REPO" "END_ENTERPRISE_REPO"
        printf "%s" "$output" | tee -a /etc/apt/sources.list >/dev/null 2>&1
        msg_ok "Enabled Enterprise Repository"
    fi
    if [[ "$DISABLE_SUB_BANNER" = "yes" ]]; then
        msg_info "Disabling Subscription Banner"
        echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { sed -i '/data.status/{s/\!//;s/Active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" >/etc/apt/apt.conf.d/no-nag-script >/dev/null 2>&1
        apt --reinstall install proxmox-widget-toolkit &>/dev/null
        msg_ok "Disabled Subscription Banner"
    fi
    if [[ "$UPGRADE_SYSTEM" = "yes" ]]; then
        msg_info "Upgrading System (This might take a while)"
        apt-get update >/dev/null 2>&1
        apt-get -y dist-upgrade >/dev/null 2>&1
        msg_ok "Upgraded System successfully"
    fi
    if [[ "$APT_IPV4" = "yes" ]]; then
        msg_info "Setting APT to use IPv4"
        echo -e "Acquire::Languages \"none\";\\n" msg_ok "Set APT to use IPv4" >/etc/apt/apt.conf.d/99-xs-disable-translations >/dev/null 2>&1
        msg_ok "Set APT to use IPv4"
    fi
    if [[ "$COMMON_UTILS" = "yes" ]]; then
        msg_info "Installing Common Utilities (this might take a while)"
        apt-get -y update >/dev/null 2>&1
        apt-get -y install curl wget git vim htop net-tools colordiff apt-transport-https debian-archive-keyring ca-certificates zfsutils-linux proxmox-backup-restore-image build-essential dnsutils iperf software-properties-common unzip zip >/dev/null 2>&1
        msg_ok "Installed Common Utilities"
    fi
    if [[ "$FIX_AMD" = "yes" ]]; then
        msg_info "Checking for AMD CPU"
        if [ "$(grep -i -m 1 "model name" /proc/cpuinfo | grep -i "EPYC")" != "" ]; then
            msg_ok "AMD EPYC detected"
        elif [ "$(grep -i -m 1 "model name" /proc/cpuinfo | grep -i "Ryzen")" != "" ]; then
            msg_ok "AMD Ryzen detected"
        else
            msg_warn "No AMD CPU detected, skipping"
            FIX_AMD="no"
        fi
        if [ "${FIX_AMD}" == "yes" ]; then
            msg_info "Installing AMD Fixes"
            if ! grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub | grep -q "idle=nomwait"; then
                sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="idle=nomwait /g' /etc/default/grub >/dev/null 2>&1
                update-grub >/dev/null 2>&1
            fi
            echo "options kvm ignore_msrs=Y" >>/etc/modprobe.d/kvm.conf >/dev/null 2>&1
            echo "options kvm report_ignored_msrs=N" >>/etc/modprobe.d/kvm.conf >/dev/null 2>&1
            /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::='--force-confdef' install pve-kernel-5.15 >/dev/null 2>&1
            msg_ok "Installed AMD Fixes (Reboot required)"
        fi
    fi
    if [[ "$KERNEL_SOURCE_HEADERS" = "yes" ]]; then
        msg_info "Installing Kernel Source headers"
        apt-get -y install pve-headers module-assistant >/dev/null 2>&1
        msg_ok "Installed Kernel Source headers"
    fi
}

function setLimits() {
    if [[ "$INCREASE_LIMITS" = "yes" ]]; then
        msg_info "Increasing max user watches, FD limit, FD ulimit, max key limit, ulimits"
        getIni "START_XSLIMIT" "END_XSLIMIT"
        printf "%s" "$output" | tee -a /etc/sysctl.d/99-xs-maxwatches.conf >/dev/null 2>&1
        getIni "START_FD_LIMIT" "END_FD_LIMIT"
        printf "%s" "$output" | tee -a /etc/security/limits.d/99-xs-limits.conf >/dev/null 2>&1
        getIni "START_KERNEL_LIMIT" "END_KERNEL_LIMIT"
        printf "%s" "$output" | tee -a /etc/sysctl.d/99-xs-maxkeys.conf >/dev/null 2>&1
        echo "DefaultLimitNOFILE=256000" >>/etc/systemd/system.conf >/dev/null 2>&1
        echo "DefaultLimitNOFILE=256000" >>/etc/systemd/user.conf >/dev/null 2>&1
        echo 'session required pam_limits.so' >>/etc/pam.d/common-session >/dev/null 2>&1
        echo 'session required pam_limits.so' >>/etc/pam.d/runuser-l >/dev/null 2>&1
        echo "ulimit -n 256000" >>/root/.profile >/dev/null 2>&1
        msg_ok "Increased Limits"
    fi
    if [[ "$OPTIMISE_LOGROTATE" = "yes" ]]; then
        msg_info "Optimising Logrotate"
        getIni "START_LOGROTATE" "END_LOGROTATE"
        printf "%s" "$output" | tee -a /etc/logrotate.conf >/dev/null 2>&1
        systemctl restart logrotate >/dev/null 2>&1
        msg_ok "Optimised Logrotate"
    fi
    if [[ "$OPTIMISE_JOURNALD" = "yes" ]]; then
        msg_info "Optimising JournalD"
        getIni "START_JOURNALD" "END_JOURNALD"
        printf "%s" "$output" | tee -a /etc/systemd/journald.conf >/dev/null 2>&1
        systemctl restart systemd-journald >/dev/null 2>&1
        journalctl --vacuum-size=64M --vacuum-time=1d >/dev/null 2>&1
        journalctl --rotate >/dev/null 2>&1
        msg_ok "Optimised JournalD"
    fi
    if [[ "$POPULATE_ENTROPY" = "yes" ]]; then
        msg_info "Populate Entropy"
        apt -y install haveged >/dev/null 2>&1
        getIni "START_ENTROPY" "END_ENTROPY"
        printf "%s" "$output" | tee -a /etc/default/haveged >/dev/null 2>&1
        systemctl daemon-reload >/dev/null 2>&1
        systemctl enable haveged >/dev/null 2>&1
        msg_ok "Entropy populated successfully"
    fi
    if [[ "$OPTIMISE_VZDUMP" = "yes" ]]; then
        msg_info "Optimising vzdump"
        sed -i "s/#bwlimit:.*/bwlimit: 0/" /etc/vzdump.conf >/dev/null 2>&1
        sed -i "s/#ionice:.*/ionice: 5/" /etc/vzdump.conf >/dev/null 2>&1
        msg_ok "Optimised vzdump"
    fi
    if [[ "$OPTIMISE_MEMORY" = "yes" ]]; then
        msg_info "Optimising Memory"
        getIni "START_MEMORY" "END_MEMORY"
        printf "%s" "$output" | tee -a /etc/sysctl.d/99-xs-memory.conf >/dev/null 2>&1
        msg_ok "Optimised Memory"
    fi
    if [[ "$FIX_SWAP" = "yes" ]]; then
        msg_info "Fixing Swap Bug"
        getIni "START_SWAP" "END_SWAP"
        printf "%s" "$output" | tee -a /etc/sysctl.d/99-xs-swap.conf >/dev/null 2>&1
        msg_ok "Fixed Swap Bug"
    fi
    if [[ "$OPTIMISE_MAX_FS" = "yes" ]]; then
        msg_info "Optimising Max FS"
        getIni "START_MAX_FS" "END_MAX_FS"
        printf "%s" "$output" | tee -a /etc/sysctl.d/99-xs-fs.conf >/dev/null 2>&1
        msg_ok "Optimised Max FS"
    fi
    if [[ "$CUSTOM_BASHRC" = "yes" ]]; then
        msg_info "Customising Bashrc"
        getIni "START_BASHPROMPT" "END_BASHPROMPT"
        printf "%s" "$output" | tee -a /etc/profile.d/custom_bash_prompt.sh >/dev/null 2>&1
        msg_ok "Customised Bashrc"
    fi
    if [[ "$CUSTOM_ALIASE" = "yes" ]]; then
        msg_info "Customising Aliases"
        getIni "START_BASHALIAS" "END_BASHALIAS"
        printf "%s" "$output" | tee -a /etc/profile.d/custom_aliases.sh >/dev/null 2>&1
        msg_ok "Customised Aliases"
    fi
    if [[ "$INSTALL_DARKTHEME" = "yes" ]]; then
        msg_info "Installing Dark Theme"
        TEMPLATE_FILE="/usr/share/pve-manager/index.html.tpl"
        SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"
        SCRIPTPATH="${SCRIPTDIR}$(basename "${BASH_SOURCE[0]}")"
        OFFLINEDIR="${SCRIPTDIR}offline"
        OFFLINE=false
        REPO=${REPO:-"Weilbyte/PVEDiscordDark"}
        DEFAULT_TAG="master"
        TAG=${TAG:-$DEFAULT_TAG}
        BASE_URL="https://raw.githubusercontent.com/$REPO/$TAG"
        PVEVersion="$(pveversion --verbose | grep pve-manager | cut -c 14- | cut -c -6)" # Below pveversion pre-run check
        PVEVersionMajor="$(echo "$PVEVersion" | cut -d'-' -f1)"
        if test -d "$OFFLINEDIR"; then
            msg_info "Offline directory detected, entering offline mode."
            OFFLINE=true
        fi
        if [ "$OFFLINE" = false ]; then
            local SUPPORTED=$(
                curl -f -s "$BASE_URL/meta/supported" >/dev/null 2>&1
                echo $?
            )
        else
            local SUPPORTED=$(cat "$OFFLINEDIR/meta/supported" 2>/dev/null)
        fi

        if [ -z "$SUPPORTED" ]; then
            if [ "$OFFLINE" = false ]; then
                msg_warn "Could not reach supported version file ($BASE_URL/meta/supported). Skipping support check"
            else
                msg_warn"Could not find supported version file ($OFFLINEDIR/meta/supported). Skipping support check"
            fi
        else
            local SUPPORTEDARR=($(echo "$SUPPORTED" | tr ',' '\n'))
            if ! (printf '%s\n' "${SUPPORTEDARR[@]}" | grep -q -P "$PVEVersionMajor"); then
                msg_error "Cant install Dark Theme, unsupported PVE version: $PVEVersion"
                cleanUp
            fi
        fi
        backupConfigs "$TEMPLATE_FILE"
        if [ "$OFFLINE" = false ]; then
            curl -s "$BASE_URL"/PVEDiscordDark/sass/PVEDiscordDark.css >/usr/share/pve-manager/css/dd_style.css >/dev/null 2>&1
        else
            cp "$OFFLINEDIR/PVEDiscordDark/sass/PVEDiscordDark.css" /usr/share/pve-manager/css/dd_style.css >/dev/null 2>&1
        fi
        if [ "$OFFLINE" = false ]; then
            curl -s "$BASE_URL"/PVEDiscordDark/js/PVEDiscordDark.js >/usr/share/pve-manager/js/dd_patcher.js >/dev/null 2>&1
        else
            cp "$OFFLINEDIR/PVEDiscordDark/js/PVEDiscordDark.js" /usr/share/pve-manager/js/dd_patcher.js >/dev/null 2>&1
        fi
        if ! (grep -Fq "<link rel='stylesheet' type='text/css' href='/pve2/css/dd_style.css'>" $TEMPLATE_FILE); then
            echo "<link rel='stylesheet' type='text/css' href='/pve2/css/dd_style.css'>" >>$TEMPLATE_FILE
        fi
        if ! (grep -Fq "<script type='text/javascript' src='/pve2/js/dd_patcher.js'></script>" $TEMPLATE_FILE); then
            echo "<script type='text/javascript' src='/pve2/js/dd_patcher.js'></script>" >>$TEMPLATE_FILE
        fi

        if [ "$OFFLINE" = false ]; then
            local IMAGELIST=$(curl -f -s "$BASE_URL/meta/imagelist")
        else
            local IMAGELIST=$(cat "$OFFLINEDIR/meta/imagelist")
        fi
        local IMAGELISTARR=($(echo "$IMAGELIST" | tr ',' '\n'))
        ITER=0
        for image in "${IMAGELISTARR[@]}"; do
            if [ "$OFFLINE" = false ]; then
                curl -s "$BASE_URL"/PVEDiscordDark/images/"$image" >/usr/share/pve-manager/images/"$image" >/dev/null 2>&1
            else
                cp "$OFFLINEDIR/PVEDiscordDark/images/$image" /usr/share/pve-manager/images/"$image"
            fi
            ((ITER++))
        done
        msg_ok "Dark Theme installed"
    fi
}

function cleanUp() {
    unset DEBIAN_FRONTEND
    msg_info "Cleaning Up"
    update-initramfs -u -k all >/dev/null 2>&1
    update-grub >/dev/null 2>&1
    pve-efiboot-tool refresh >/dev/null 2>&1
    apt -y autoremov >/dev/null 2>&1
    apt -y autoclean >/dev/null 2>&1
    msg_ok "Everything cleaned up"
    echo -e "\n${GN} Script has finished with the post-install routine.\n
    ${RD}⚠ Please reboot your server to apply all changes.\n ${CL}"
    exit 0
}
checkScript "$@"
