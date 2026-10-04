#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="/etc/keyd/default.conf"

echo "==> Installing keyd..."
sudo apt update
sudo apt install -y keyd

echo "==> Detecting keyd executable..."

if command -v keyd >/dev/null 2>&1; then
    KEYD_BIN="$(command -v keyd)"
elif [[ -x /usr/bin/keyd.rvaiya ]]; then
    KEYD_BIN="/usr/bin/keyd.rvaiya"
else
    echo "ERROR: keyd executable not found."
    exit 1
fi

echo "    Using: $KEYD_BIN"

echo "==> Creating keyd configuration..."

sudo mkdir -p /etc/keyd

sudo tee "$CONFIG_FILE" >/dev/null <<'EOF'
[ids]
*

[main]

# ===========================================================
# AltGr navigation / symbol layer
# ===========================================================

rightalt = layer(altgr)


[altgr]

# ===========================================================
# Navigation
#
# AltGr + J/I/K/L = Left/Up/Down/Right
# AltGr + Y/H     = PageUp/PageDown
# AltGr + U/O     = Home/End
# AltGr + Space  = Space
#
# Ctrl and Shift are preserved automatically.
# ===========================================================

j = left
i = up
k = down
l = right

y = pageup
h = pagedown

u = home
o = end

space = space


# ===========================================================
# Symbols for Brazilian (br) layout
#
# IMPORTANT:
# keyd outputs physical key positions, while XKB interprets
# those positions according to the active "br" layout.
#
# Brazilian layout:
#
#   US [ position  -> ´
#   US ] position  -> [
#   US / position  -> ;
#   ABNT2 / key    -> /
#
# Therefore:
#
#   ]       -> produces [
#   S-]     -> produces {
#   backslash -> produces ]
#   S-backslash -> produces }
#   102nd   -> NOT used here
#
# The ABNT2 slash key is exposed as "ro" by evdev/keyd.
# ===========================================================

# AltGr + , = [
comma = ]

# AltGr + . = ]
dot = backslash

# AltGr + m = /
m = ro

# AltGr + b = -
b = -

# AltGr + n = =
n = =

# AltGr + d = (
d = (

# AltGr + f = )
f = )


# ===========================================================
# AltGr + Shift
# ===========================================================

[altgr+shift]

# AltGr + Shift + , = {
comma = S-]

# AltGr + Shift + . = }
dot = S-backslash

# AltGr + Shift + m = ?
m = S-ro

# AltGr + Shift + b = _
b = S--

# AltGr + Shift + n = +
n = S-=

# AltGr + Shift + d/f
d = (
f = )
EOF

echo "==> Enabling keyd at boot..."
sudo systemctl enable keyd

echo "==> Starting keyd..."
sudo systemctl start keyd

echo "==> Reloading keyd configuration..."

if ! sudo "$KEYD_BIN" reload; then
    echo "    Direct reload failed; restarting the service instead..."
    sudo systemctl restart keyd
fi

echo
echo "==> keyd status:"
sudo systemctl --no-pager --full status keyd

echo
echo "==========================================================="
echo "keyd installation and configuration complete."
echo "Configuration: $CONFIG_FILE"
echo "Executable:    $KEYD_BIN"
echo "==========================================================="
