#!/usr/bin/env bash

# ============================================================
# Sunshine setup for Xubuntu
#
# What this script does:
#   - Installs Sunshine from the official LizardByte repository
#   - Enables automatic LightDM login for the current user
#   - Configures the laptop to ignore lid-close events
#   - Disables XFCE automatic suspend/DPMS while plugged in
#   - Configures UFW for Sunshine Internet streaming
#   - Enables Sunshine as a systemd user service
#   - Verifies all required Sunshine firewall rules
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
    xfconf \
    ufw

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
LIGHTDM_CONFIG="${LIGHTDM_DIR}/50-sunshine-autologin.conf"

if command -v lightdm >/dev/null 2>&1 || [[ -d /etc/lightdm ]]; then
    info "Configuring LightDM automatic login..."

    sudo mkdir -p "${LIGHTDM_DIR}"

    sudo tee "${LIGHTDM_CONFIG}" >/dev/null <<EOF
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
# 6. Configure UFW firewall for Sunshine
# ------------------------------------------------------------

info "Configuring UFW firewall for Sunshine..."

# Sunshine Internet-streaming ports according to the supplied
# Sunshine/Moonlight documentation.
#
# TCP:
#   47984 - Sunshine HTTPS endpoint
#   47989 - Sunshine HTTP endpoint
#   48010 - RTSP/session setup
#
# UDP:
#   47998 - Video stream
#   47999 - Control/input
#   48000 - Audio
#   48002 - Mic/auxiliary traffic
#   48010 - Additional streaming traffic

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

# ------------------------------------------------------------
# Configure IPv6 support
# ------------------------------------------------------------

# Sunshine remote access in this setup is intended to work over
# public IPv6, so UFW must also process IPv6 traffic.

if [[ ! -f /etc/default/ufw ]]; then
    die "/etc/default/ufw does not exist. UFW installation appears incomplete."
fi

if grep -q '^IPV6=' /etc/default/ufw; then
    CURRENT_IPV6="$(grep '^IPV6=' /etc/default/ufw | tail -n1 | cut -d= -f2)"

    if [[ "${CURRENT_IPV6}" != "yes" ]]; then
        info "Enabling IPv6 support in UFW..."

        sudo sed -i \
            's/^IPV6=.*/IPV6=yes/' \
            /etc/default/ufw
    else
        success "UFW IPv6 support is already enabled."
    fi
else
    info "Adding IPv6 support to UFW..."

    echo 'IPV6=yes' | sudo tee -a /etc/default/ufw >/dev/null
fi

# ------------------------------------------------------------
# UFW rule helper
# ------------------------------------------------------------

ufw_rule_exists() {
    local port="$1"
    local protocol="$2"

    # Use UFW's numbered status and look for an exact port/protocol
    # rule. This prevents repeated executions from creating
    # duplicate rules.
    sudo ufw status | grep -Eq \
        "^[[:space:]]*${port}/${protocol}[[:space:]]"
}

ufw_allow_once() {
    local port="$1"
    local protocol="$2"

    if ufw_rule_exists "${port}" "${protocol}"; then
        success "UFW rule already exists: ${port}/${protocol}"
    else
        info "Adding UFW rule: ${port}/${protocol}..."

        sudo ufw allow \
            "${port}/${protocol}" \
            comment "Sunshine ${protocol} ${port}"

        success "Added UFW rule: ${port}/${protocol}"
    fi
}

# ------------------------------------------------------------
# Add Sunshine TCP rules
# ------------------------------------------------------------

info "Checking Sunshine TCP firewall rules..."

for port in "${SUNSHINE_TCP_PORTS[@]}"; do
    ufw_allow_once "${port}" tcp
done

# ------------------------------------------------------------
# Add Sunshine UDP rules
# ------------------------------------------------------------

info "Checking Sunshine UDP firewall rules..."

for port in "${SUNSHINE_UDP_PORTS[@]}"; do
    ufw_allow_once "${port}" udp
done

# ------------------------------------------------------------
# Sunshine web interface
# ------------------------------------------------------------

# 47990/TCP is Sunshine's web interface.
#
# It is intentionally NOT opened here because the requested
# firewall configuration is for Sunshine streaming.
#
# Local access remains available at:
#
#   https://localhost:47990
#
# If remote access to the Sunshine UI is desired, it should
# preferably be restricted to a trusted source rather than
# exposed globally.

if ufw_rule_exists 47990 tcp; then
    warn "UFW currently has a 47990/tcp rule."
    warn "47990/tcp is Sunshine's web interface and is NOT required"
    warn "for the Internet streaming firewall configuration."
fi

# ------------------------------------------------------------
# Enable UFW
# ------------------------------------------------------------

if sudo ufw status | grep -q '^Status: active'; then
    success "UFW is already active."
else
    info "UFW is currently inactive."
    info "Enabling UFW..."

    sudo ufw --force enable

    success "UFW enabled."
fi

# ------------------------------------------------------------
# Reload UFW
# ------------------------------------------------------------

info "Reloading UFW..."

sudo ufw reload >/dev/null

success "UFW reloaded."

# ------------------------------------------------------------
# 6a. Verify UFW is active
# ------------------------------------------------------------

info "Verifying UFW status..."

if sudo ufw status | grep -q '^Status: active'; then
    success "UFW is active."
else
    die "UFW is not active after configuration."
fi

# ------------------------------------------------------------
# 6b. Verify IPv6 support
# ------------------------------------------------------------

info "Verifying UFW IPv6 configuration..."

UFW_IPV6="$(grep '^IPV6=' /etc/default/ufw | tail -n1 | cut -d= -f2 || true)"

if [[ "${UFW_IPV6}" == "yes" ]]; then
    success "UFW IPv6 support is enabled."
else
    die "UFW IPv6 support is not enabled."
fi

# ------------------------------------------------------------
# 6c. Verify each required Sunshine rule
# ------------------------------------------------------------

info "Verifying Sunshine TCP firewall rules..."

FIREWALL_VERIFICATION_FAILED=0

for port in "${SUNSHINE_TCP_PORTS[@]}"; do
    if ufw_rule_exists "${port}" tcp; then
        success "Verified TCP ${port}/tcp"
    else
        error "MISSING TCP ${port}/tcp"
        FIREWALL_VERIFICATION_FAILED=1
    fi
done

info "Verifying Sunshine UDP firewall rules..."

for port in "${SUNSHINE_UDP_PORTS[@]}"; do
    if ufw_rule_exists "${port}" udp; then
        success "Verified UDP ${port}/udp"
    else
        error "MISSING UDP ${port}/udp"
        FIREWALL_VERIFICATION_FAILED=1
    fi
done

if [[ "${FIREWALL_VERIFICATION_FAILED}" -ne 0 ]]; then
    die "One or more required Sunshine firewall rules are missing."
fi

success "All required Sunshine firewall rules are present."

# ------------------------------------------------------------
# 6d. Display final firewall configuration
# ------------------------------------------------------------

echo
echo "============================================================"
echo " SUNSHINE FIREWALL RULES"
echo "============================================================"
echo

sudo ufw status verbose

echo
echo "Required Sunshine TCP:"
for port in "${SUNSHINE_TCP_PORTS[@]}"; do
    echo "  - ${port}/tcp"
done

echo
echo "Required Sunshine UDP:"
for port in "${SUNSHINE_UDP_PORTS[@]}"; do
    echo "  - ${port}/udp"
done

echo

# ------------------------------------------------------------
# 7. Enable Sunshine systemd user service
# ------------------------------------------------------------

info "Enabling Sunshine systemd user service..."

systemctl --user --now enable app-dev.lizardbyte.app.Sunshine

success "Sunshine systemd user service enabled and started."

# ------------------------------------------------------------
# 8. Verify Sunshine service
# ------------------------------------------------------------

info "Verifying Sunshine systemd user service..."

if systemctl --user is-enabled --quiet app-dev.lizardbyte.app.Sunshine; then
    success "Sunshine systemd user service is enabled."
else
    die "Sunshine systemd user service is not enabled."
fi

if systemctl --user is-active --quiet app-dev.lizardbyte.app.Sunshine; then
    success "Sunshine systemd user service is running."
else
    warn "Sunshine systemd user service is not currently running."
    warn "Check with:"
    warn "  systemctl --user status app-dev.lizardbyte.app.Sunshine"
fi

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
echo "  6. Allow Sunshine Internet streaming ports through UFW."
echo "  7. Process Sunshine traffic over IPv6."
echo "  8. Verify every required Sunshine firewall rule."
echo
echo "Sunshine TCP:"
echo "  47984"
echo "  47989"
echo "  48010"
echo
echo "Sunshine UDP:"
echo "  47998"
echo "  47999"
echo "  48000"
echo "  48002"
echo "  48010"
echo
echo "Sunshine web interface:"
echo "  47990/tcp is NOT opened by this script."
echo "  Local access: https://localhost:47990"
echo
echo "============================================================"
echo

info "Sunshine service status:"
systemctl --user --no-pager --full status app-dev.lizardbyte.app.Sunshine || true

echo
warn "A reboot is recommended so the new system-wide lid/logind"
warn "configuration is fully applied."
