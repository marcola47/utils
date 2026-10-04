#!/usr/bin/env bash

# ============================================================
# Sunshine setup for Xubuntu
#
# What this script does:
#   - Installs Sunshine from the official LizardByte repository
#   - Enables automatic LightDM login for the current user
#   - Configures the laptop to ignore lid-close events
#   - Disables XFCE automatic suspend/DPMS while plugged in
#   - Enables Sunshine as a systemd user service
#
# Run this script as your normal Xubuntu user.
# Do NOT run it as root.
# ============================================================

set -Eeuo pipefail

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[ OK ]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

# ------------------------------------------------------------
# Basic checks
# ------------------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    die "Do NOT run this script as root. Run it as your normal Xubuntu user."
fi

if ! command -v sudo >/dev/null 2>&1; then
    die "sudo is required."
fi

source /etc/os-release

info "Detected OS: ${PRETTY_NAME:-unknown}"
info "Current user: ${USER}"
info "Home directory: ${HOME}"

if [[ "${ID:-}" != "ubuntu" ]]; then
    die "This script is intended for Ubuntu/Xubuntu."
fi

# ------------------------------------------------------------
# Check for XFCE
# ------------------------------------------------------------

if [[ "${XDG_CURRENT_DESKTOP:-}" != *XFCE* ]] &&
   [[ "${XDG_CURRENT_DESKTOP:-}" != *X-XFCE* ]] &&
   [[ ! -d /usr/share/xfce4 ]]; then

    warn "This does not look like a normal XFCE/Xubuntu installation."
    warn "Continuing anyway."
fi

# ------------------------------------------------------------
# Request sudo
# ------------------------------------------------------------

info "Requesting administrator privileges..."

sudo -v

# Keep sudo alive while the script runs.
(
    while true; do
        sudo -n true
        sleep 50
        kill -0 "$$" || exit
    done
) 2>/dev/null &

SUDO_KEEPALIVE_PID=$!

cleanup() {
    kill "${SUDO_KEEPALIVE_PID:-0}" 2>/dev/null || true
}

trap cleanup EXIT

# ------------------------------------------------------------
# 1. Install prerequisites
# ------------------------------------------------------------

info "Installing required packages..."

sudo apt update

sudo apt install -y \
    curl \
    ca-certificates \
    udev \
    dbus-user-session \
    xfconf

success "Required packages installed."

# ------------------------------------------------------------
# 2. Install Sunshine
# ------------------------------------------------------------

if command -v sunshine >/dev/null 2>&1; then
    success "Sunshine is already installed."

else
    info "Adding the official LizardByte Sunshine repository..."

    curl -1sLf \
        'https://dl.cloudsmith.io/public/lizardbyte/stable/cfg/setup/bash.deb.sh' \
        | sudo -E bash

    info "Installing Sunshine..."

    sudo apt update
    sudo apt install -y sunshine

    success "Sunshine installed."
fi

SUNSHINE_BIN="$(command -v sunshine || true)"

if [[ -z "${SUNSHINE_BIN}" ]]; then
    die "Sunshine installation failed."
fi

info "Sunshine binary: ${SUNSHINE_BIN}"

# ------------------------------------------------------------
# 3. Configure LightDM automatic login
# ------------------------------------------------------------

LIGHTDM_DIR="/etc/lightdm/lightdm.conf.d"

if command -v lightdm >/dev/null 2>&1 || [[ -d /etc/lightdm ]]; then
    info "Configuring LightDM automatic login..."
    sudo mkdir -p "${LIGHTDM_DIR}"
    sudo tee "${LIGHTDM_DIR}/50-sunshine-autologin.conf" >/dev/null <<EOF
[Seat:*]
autologin-user=${USER}
autologin-user-timeout=0
EOF

    success "Automatic graphical login configured for ${USER}."
else
    warn "LightDM was not detected."
    warn "Automatic login was not configured."
fi

# ------------------------------------------------------------
# 4. Configure systemd-logind lid behavior
# ------------------------------------------------------------

info "Configuring closed-lid behavior..."
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/50-sunshine-lid.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

success "Laptop will ignore lid-close events."

# ------------------------------------------------------------
# 5. Configure XFCE power management
# ------------------------------------------------------------

info "Configuring XFCE power management..."

if ! command -v xfconf-query >/dev/null 2>&1; then
    die "xfconf-query was not found. Is XFCE/Xubuntu installed correctly?"
fi

# Disable inactivity action while on AC.
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/inactivity-on-ac \
    -n -t int -s 0 2>/dev/null || \
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/inactivity-on-ac \
    -s 0

# Disable DPMS.
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/dpms-enabled \
    -n -t bool -s false 2>/dev/null || \
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/dpms-enabled \
    -s false

# Disable display blanking while on AC.
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/blank-on-ac \
    -n -t int -s 0 2>/dev/null || \
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/blank-on-ac \
    -s 0

# Disable DPMS sleep while on AC.
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/dpms-on-ac-sleep \
    -n -t int -s 0 2>/dev/null || \
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/dpms-on-ac-sleep \
    -s 0

# Disable DPMS off while on AC.
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/dpms-on-ac-off \
    -n -t int -s 0 2>/dev/null || \
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/dpms-on-ac-off \
    -s 0

# Ignore lid action while on AC.
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/lid-action-on-ac \
    -n -t uint -s 0 2>/dev/null || \
xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/lid-action-on-ac \
    -s 0

success "XFCE automatic sleep/DPMS disabled while on AC."

# ------------------------------------------------------------
# 6. Enable Sunshine systemd user service
# ------------------------------------------------------------

info "Enabling Sunshine systemd user service..."
systemctl --user --now enable app-dev.lizardbyte.app.Sunshine
success "Sunshine systemd user service enabled and started."

# ------------------------------------------------------------
# 7. Final status
# ------------------------------------------------------------

echo
echo "============================================================"
echo " SETUP COMPLETE"
echo "============================================================"
echo

success "Sunshine installation/configuration is complete."

echo
echo "The machine is configured to:"
echo
echo "  1. Automatically log into ${USER}."
echo "  2. Start the XFCE graphical session."
echo "  3. Start Sunshine via systemd user service."
echo "  4. Ignore the laptop lid being closed."
echo "  5. Avoid automatic suspend/DPMS while on AC power."
echo
echo "============================================================"
echo

info "Sunshine service status:"
systemctl --user --no-pager --full status app-dev.lizardbyte.app.Sunshine || true

echo
warn "A reboot is recommended so the new system-wide lid/logind"
warn "configuration is fully applied."
