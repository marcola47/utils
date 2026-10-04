#!/usr/bin/env bash

# ============================================================
# Sunshine setup for Xubuntu
#
# What this script does:
#   - Installs Sunshine from the official LizardByte repository
#   - Configures Sunshine/uinput permissions
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
    dbus-user-session

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
# 3. Configure uinput permissions
# ------------------------------------------------------------

info "Configuring Sunshine virtual input permissions..."

sudo tee /etc/udev/rules.d/85-sunshine.rules >/dev/null <<'EOF'
KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

success "uinput permissions configured."

# ------------------------------------------------------------
# 4. Add user to input group
# ------------------------------------------------------------

if getent group input >/dev/null 2>&1; then
    info "Adding ${USER} to the input group..."
    sudo usermod -aG input "${USER}"
    success "User added to input group."
else
    warn "The 'input' group does not exist. Skipping."
fi

# ------------------------------------------------------------
# 5. Configure LightDM automatic login
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
# 6. Configure systemd-logind lid behavior
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
# 7. Configure XFCE power management
# ------------------------------------------------------------

info "Configuring XFCE power management..."

XFCE_POWER_DIR="${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml"
XFCE_POWER_FILE="${XFCE_POWER_DIR}/xfce4-power-manager.xml"

mkdir -p "${XFCE_POWER_DIR}"

if [[ -f "${XFCE_POWER_FILE}" ]]; then
    cp "${XFCE_POWER_FILE}" \
       "${XFCE_POWER_FILE}.sunshine-backup.$(date +%Y%m%d-%H%M%S)"
fi

cat > "${XFCE_POWER_FILE}" <<'EOF'
<?xml version="1.1" encoding="UTF-8" ?>

<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="inactivity-on-ac" type="int" value="0"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="dpms-on-ac-sleep" type="int" value="0"/>
    <property name="dpms-on-ac-off" type="int" value="0"/>
    <property name="lid-action-on-ac" type="uint" value="0"/>
  </property>
</channel>
EOF

success "XFCE automatic sleep/DPMS disabled."

# ------------------------------------------------------------
# 8. Enable Sunshine systemd user service
# ------------------------------------------------------------

info "Enabling Sunshine systemd user service..."

systemctl --user --now enable app-dev.lizardbyte.app.Sunshine

success "Sunshine systemd user service enabled and started."

# ------------------------------------------------------------
# 9. Final status
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
warn "A reboot is recommended so the new input-group membership and"
warn "system-wide lid/logind configuration are fully applied."
