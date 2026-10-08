#!/usr/bin/env bash

# ============================================================
# Sunshine setup for Xubuntu
#
# Run as the normal Xubuntu user.
# Do NOT run as root.
#
# Configures:
#   - Sunshine from the official LizardByte repository
#   - LightDM automatic login
#   - XFCE autostart for Sunshine
#   - Ignore laptop lid close
#   - Disable suspend/DPMS while on AC
#   - Disable screen locking
#   - UFW IPv4/IPv6 Sunshine streaming ports
# ============================================================

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ------------------------------------------------------------
# Basic checks
# ------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    die "Run this script as your normal Xubuntu user, not root."
fi

command -v sudo >/dev/null || die "sudo is required."

source /etc/os-release

[[ "${ID:-}" == "ubuntu" ]] ||
    die "This script is intended for Ubuntu/Xubuntu."

sudo -v

info "User: ${USER}"
info "OS: ${PRETTY_NAME:-unknown}"

# ------------------------------------------------------------
# Sunshine
# ------------------------------------------------------------

if command -v sunshine >/dev/null 2>&1; then
    success "Sunshine is already installed."
else
    repo_file="/etc/apt/sources.list.d/lizardbyte-stable.list"
    keyring_file="/usr/share/keyrings/lizardbyte-stable-archive-keyring.gpg"
    trusted_key_file="/etc/apt/trusted.gpg.d/lizardbyte-stable.gpg"

    if [[ ! -s "$repo_file" || ( ! -s "$keyring_file" && ! -s "$trusted_key_file" ) ]]; then
        info "Adding the official LizardByte repository..."
        sudo rm -f "$keyring_file"

        curl -1sLf \
            'https://dl.cloudsmith.io/public/lizardbyte/stable/cfg/setup/bash.deb.sh' |
            sudo -E bash
    fi

    sudo apt update
    sudo apt install -y sunshine

    success "Sunshine installed."
fi

SUNSHINE_BIN="$(command -v sunshine)"
info "Sunshine: ${SUNSHINE_BIN}"

# ------------------------------------------------------------
# LightDM automatic login
# ------------------------------------------------------------

LIGHTDM_DIR="/etc/lightdm/lightdm.conf.d"
LIGHTDM_CONFIG="${LIGHTDM_DIR}/50-sunshine-autologin.conf"

info "Configuring LightDM automatic login..."

sudo mkdir -p "${LIGHTDM_DIR}"

sudo tee "${LIGHTDM_CONFIG}" >/dev/null <<EOF
[Seat:*]
autologin-user=${USER}
autologin-user-timeout=0
EOF

success "LightDM automatic login configured for ${USER}."

# ------------------------------------------------------------
# XFCE autostart
# ------------------------------------------------------------

AUTOSTART_DIR="${HOME}/.config/autostart"
AUTOSTART_FILE="${AUTOSTART_DIR}/sunshine.desktop"

info "Configuring XFCE Sunshine autostart..."

mkdir -p "${AUTOSTART_DIR}"

cat > "${AUTOSTART_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=Sunshine
Comment=Sunshine game streaming server
Exec=${SUNSHINE_BIN}
Terminal=false
StartupNotify=false
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
EOF

success "Sunshine will start automatically with XFCE."

# ------------------------------------------------------------
# systemd-logind lid behavior
# ------------------------------------------------------------

info "Configuring lid-close behavior..."

sudo mkdir -p /etc/systemd/logind.conf.d

sudo tee /etc/systemd/logind.conf.d/50-sunshine-lid.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

success "Laptop lid close will be ignored."

# ------------------------------------------------------------
# XFCE power management
# ------------------------------------------------------------

info "Configuring XFCE power management..."

command -v xfconf-query >/dev/null ||
    die "xfconf-query was not found."

xfconf-query -c xfce4-power-manager \
    -p /xfce4-power-manager/inactivity-on-ac \
    -n -t int -s 0

xfconf-query -c xfce4-power-manager \
    -p /xfce4-power-manager/dpms-enabled \
    -n -t bool -s false

xfconf-query -c xfce4-power-manager \
    -p /xfce4-power-manager/blank-on-ac \
    -n -t int -s 0

xfconf-query -c xfce4-power-manager \
    -p /xfce4-power-manager/dpms-on-ac-sleep \
    -n -t int -s 0

xfconf-query -c xfce4-power-manager \
    -p /xfce4-power-manager/dpms-on-ac-off \
    -n -t int -s 0

xfconf-query -c xfce4-power-manager \
    -p /xfce4-power-manager/lid-action-on-ac \
    -n -t uint -s 0

xfconf-query -c xfce4-screensaver \
    -p /lock-enabled \
    -n -t bool -s false

xfconf-query -c xfce4-power-manager \
    -p /xfce4-power-manager/lock-screen-suspend-hibernate \
    -n -t bool -s false

success "XFCE sleep/DPMS and screen locking disabled."

# ------------------------------------------------------------
# UFW
# ------------------------------------------------------------

info "Configuring UFW..."

# Enable IPv6 firewall support.
if grep -q '^IPV6=' /etc/default/ufw; then
    sudo sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
else
    echo 'IPV6=yes' | sudo tee -a /etc/default/ufw >/dev/null
fi

SUNSHINE_TCP_PORTS=(
    47984
    47989
    48010
)

SUNSHINE_UDP_PORTS=(
    47998
    47999
    48000
    48002
    48010
)

# UFW itself avoids adding duplicate rules.
for port in "${SUNSHINE_TCP_PORTS[@]}"; do
    sudo ufw allow "${port}/tcp" comment "Sunshine TCP ${port}" >/dev/null
done

for port in "${SUNSHINE_UDP_PORTS[@]}"; do
    sudo ufw allow "${port}/udp" comment "Sunshine UDP ${port}" >/dev/null
done

sudo ufw --force enable >/dev/null
sudo ufw reload >/dev/null

success "UFW configured for Sunshine."

# ------------------------------------------------------------
# Verify firewall
# ------------------------------------------------------------

info "Verifying Sunshine firewall rules..."

for port in "${SUNSHINE_TCP_PORTS[@]}"; do
    sudo ufw status | grep -Eq "${port}/tcp" ||
        die "Missing UFW rule: ${port}/tcp"
done

for port in "${SUNSHINE_UDP_PORTS[@]}"; do
    sudo ufw status | grep -Eq "${port}/udp" ||
        die "Missing UFW rule: ${port}/udp"
done

success "All Sunshine firewall rules verified."

# ------------------------------------------------------------
# Final status
# ------------------------------------------------------------

echo
echo "============================================================"
echo " SUNSHINE SETUP COMPLETE"
echo "============================================================"
echo
echo "User:       ${USER}"
echo "Sunshine:   ${SUNSHINE_BIN}"
echo "Autostart:  ${AUTOSTART_FILE}"
echo
echo "Sunshine will start automatically when XFCE logs in."
echo
echo "TCP:"
printf '  %s/tcp\n' "${SUNSHINE_TCP_PORTS[@]}"
echo
echo "UDP:"
printf '  %s/udp\n' "${SUNSHINE_UDP_PORTS[@]}"
echo
echo "Sunshine web interface:"
echo "  https://localhost:47990"
echo
echo "A reboot is recommended."
echo "============================================================"
