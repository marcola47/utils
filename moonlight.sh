#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Moonlight Guide Button Handler for Xubuntu
#
# 8BitDo Ultimate 2C:
#   BTN_MODE = 316
#
# Press Xbox/Guide:
#   - Moonlight running -> bring it to the foreground
#   - Moonlight not running -> launch it
#
# If Moonlight is not installed, the script installs it via:
#   sudo snap install moonlight
# ============================================================

INSTALL_DIR="$HOME/.local/bin"
SERVICE_DIR="$HOME/.config/systemd/user"
HANDLER="$INSTALL_DIR/moonlight-guide-handler.py"
SERVICE="$SERVICE_DIR/moonlight-guide.service"

echo
echo "=========================================="
echo " Moonlight Guide Button Setup"
echo "=========================================="
echo

# ------------------------------------------------------------
# 1. Install Moonlight if necessary
# ------------------------------------------------------------

echo "[1/7] Checking for Moonlight..."

if command -v moonlight >/dev/null 2>&1; then
    MOONLIGHT_BIN="$(command -v moonlight)"
    echo "Moonlight is already installed:"
    echo "  $MOONLIGHT_BIN"
else
    echo "Moonlight was not found."
    echo
    echo "Installing Moonlight via Snap..."
    echo

    # Make sure snapd is available.
    if ! command -v snap >/dev/null 2>&1; then
        echo "snap was not found. Installing snapd..."

        sudo apt update
        sudo apt install -y snapd

        # Start/enable snapd if available.
        sudo systemctl enable --now snapd.socket 2>/dev/null || true

        # Give snapd a moment to initialize.
        sleep 2
    fi

    sudo snap install moonlight

    # Refresh PATH in case snap was just installed.
    export PATH="/snap/bin:$PATH"

    if ! command -v moonlight >/dev/null 2>&1; then
        echo
        echo "ERROR: Moonlight was installed, but the 'moonlight'"
        echo "command could not be found."
        echo
        echo "Try logging out and back in, then run this script again."
        exit 1
    fi

    MOONLIGHT_BIN="$(command -v moonlight)"

    echo
    echo "Moonlight installed successfully:"
    echo "  $MOONLIGHT_BIN"
fi

echo

# ------------------------------------------------------------
# 2. Install dependencies
# ------------------------------------------------------------

echo "[2/7] Installing dependencies..."

sudo apt update
sudo apt install -y python3-evdev xdotool

echo "Dependencies installed."
echo

# ------------------------------------------------------------
# 3. Make sure the user can read input devices
# ------------------------------------------------------------

echo "[3/7] Checking input permissions..."

if ! id -nG "$USER" | tr ' ' '\n' | grep -qx "input"; then
    echo "Adding $USER to the 'input' group..."
    sudo usermod -aG input "$USER"

    INPUT_GROUP_ADDED=1

    echo
    echo "IMPORTANT:"
    echo "Your user was added to the 'input' group."
    echo "A logout/login (or reboot) is required before this"
    echo "permission takes effect."
    echo
else
    INPUT_GROUP_ADDED=0
    echo "User is already a member of the input group."
fi

# ------------------------------------------------------------
# 4. Find the 8BitDo controller
# ------------------------------------------------------------

echo
echo "[4/7] Looking for the 8BitDo controller..."

CONTROLLER_PATH=""

for path in /dev/input/by-id/*; do
    [ -e "$path" ] || continue

    if [[ "$path" =~ [Bb]it[Dd]o|[Bb]itdo ]]; then
        if [[ "$path" == *event* ]]; then
            CONTROLLER_PATH="$path"
            break
        fi
    fi
done

if [ -z "$CONTROLLER_PATH" ]; then
    echo
    echo "ERROR: Could not automatically find the 8BitDo event device."
    echo
    echo "Available input devices:"
    ls -l /dev/input/by-id/ 2>/dev/null || true
    echo
    echo "Make sure the controller is connected and run this script again."
    exit 1
fi

echo "Found controller:"
echo "  $CONTROLLER_PATH"
echo

# ------------------------------------------------------------
# 5. Create handler
# ------------------------------------------------------------

echo "[5/7] Installing Guide button handler..."

mkdir -p "$INSTALL_DIR"
mkdir -p "$SERVICE_DIR"

cat > "$HANDLER" <<PYTHON
#!/usr/bin/env python3

import os
import subprocess
import time
import evdev
from evdev import ecodes

# 8BitDo controller event device.
CONTROLLER = "$CONTROLLER_PATH"

# Xbox / Guide / Mode button.
GUIDE_BUTTON = 316

# Moonlight executable.
MOONLIGHT_COMMAND = "$MOONLIGHT_BIN"

# Small debounce so one physical press doesn't trigger twice.
DEBOUNCE_SECONDS = 0.30


def moonlight_windows():
    """
    Find visible Moonlight X11 windows.
    """
    try:
        result = subprocess.run(
            [
                "xdotool",
                "search",
                "--onlyvisible",
                "--name",
                "Moonlight"
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        )

        return [
            line.strip()
            for line in result.stdout.splitlines()
            if line.strip()
        ]

    except Exception:
        return []


def launch_or_focus_moonlight():
    windows = moonlight_windows()

    if windows:
        # Moonlight is already running.
        # Bring its window to the foreground.
        subprocess.run(
            [
                "xdotool",
                "windowactivate",
                "--sync",
                windows[0]
            ],
            check=False,
        )

        return

    # Moonlight isn't running.
    subprocess.Popen(
        [
            "nohup",
            MOONLIGHT_COMMAND
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        start_new_session=True,
    )


def find_controller():
    if os.path.exists(CONTROLLER):
        try:
            return evdev.InputDevice(CONTROLLER)
        except Exception:
            pass

    # Fallback: look through all event devices for 8BitDo.
    for path in evdev.list_devices():
        try:
            device = evdev.InputDevice(path)

            name = device.name.lower()

            if "8bitdo" in name or "8bit do" in name:
                capabilities = device.capabilities()

                if ecodes.EV_KEY in capabilities:
                    return device

        except Exception:
            continue

    return None


def main():
    print(
        "Moonlight Guide Button handler started.",
        flush=True
    )

    last_press = 0.0

    while True:
        device = find_controller()

        if device is None:
            print(
                "8BitDo controller not found. Waiting...",
                flush=True
            )
            time.sleep(2)
            continue

        print(
            f"Listening to: {device.path} ({device.name})",
            flush=True
        )

        try:
            for event in device.read_loop():

                if event.type != ecodes.EV_KEY:
                    continue

                # Only react to button-down.
                if event.code != GUIDE_BUTTON or event.value != 1:
                    continue

                now = time.monotonic()

                if now - last_press < DEBOUNCE_SECONDS:
                    continue

                last_press = now

                print(
                    "Guide button pressed -> Moonlight",
                    flush=True
                )

                launch_or_focus_moonlight()

        except (OSError, IOError):
            # Controller was disconnected.
            try:
                device.close()
            except Exception:
                pass

            time.sleep(1)

        except Exception as e:
            print(f"Input error: {e}", flush=True)
            time.sleep(1)


if __name__ == "__main__":
    main()
PYTHON

chmod +x "$HANDLER"

echo "Handler installed at:"
echo "  $HANDLER"
echo

# ------------------------------------------------------------
# 6. Create systemd user service
# ------------------------------------------------------------

echo "[6/7] Creating user service..."

cat > "$SERVICE" <<EOF
[Unit]
Description=8BitDo Guide Button -> Moonlight
After=graphical-session.target

[Service]
Type=simple
ExecStart=$HANDLER
Restart=always
RestartSec=2

# X11 session.
Environment=DISPLAY=:0
Environment=XAUTHORITY=%h/.Xauthority

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable moonlight-guide.service

echo "Service installed."
echo

# ------------------------------------------------------------
# 7. Start it
# ------------------------------------------------------------

echo "[7/7] Starting service..."

# If the input group was newly added, the current shell still
# has the old group list. The service may therefore fail until
# the user logs in again.
if [ "$INPUT_GROUP_ADDED" -eq 1 ]; then
    echo
    echo "The input group was just added."
    echo "The service will be enabled, but you need to log out"
    echo "and back in before it can access the controller."
    echo

    systemctl --user stop moonlight-guide.service 2>/dev/null || true

    echo "=========================================="
    echo " SETUP COMPLETE"
    echo "=========================================="
    echo
    echo "Moonlight:"
    echo "  $MOONLIGHT_BIN"
    echo
    echo "Guide button handler:"
    echo "  $HANDLER"
    echo
    echo "Service:"
    echo "  moonlight-guide.service"
    echo
    echo "Now log out and back in (or reboot)."
    echo
    echo "After logging back in, the handler will start"
    echo "automatically."
    echo
    exit 0
fi

systemctl --user restart moonlight-guide.service

sleep 1

if systemctl --user is-active --quiet moonlight-guide.service; then
    echo
    echo "=========================================="
    echo " SUCCESS!"
    echo "=========================================="
    echo
    echo "Guide button handler is running."
    echo
    echo "Press the Xbox/Guide button on your"
    echo "8BitDo Ultimate 2C."
    echo
    echo "If Moonlight is running:"
    echo "  -> it will be brought to the foreground."
    echo
    echo "If Moonlight isn't running:"
    echo "  -> it will be launched."
    echo
    echo "Useful commands:"
    echo
    echo "  Check status:"
    echo "    systemctl --user status moonlight-guide.service"
    echo
    echo "  View live log:"
    echo "    journalctl --user -u moonlight-guide.service -f"
    echo
    echo "  Restart:"
    echo "    systemctl --user restart moonlight-guide.service"
    echo
    echo "  Stop:"
    echo "    systemctl --user stop moonlight-guide.service"
    echo
else
    echo
    echo "WARNING: The service did not start successfully."
    echo
    echo "Check the log with:"
    echo
    echo "  journalctl --user -u moonlight-guide.service -n 50"
    echo
fi
