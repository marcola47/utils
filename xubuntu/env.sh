#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

sudo apt update
sudo apt install -y \
    ca-certificates \
    curl \
    udev \
    xfconf \
    ufw \
    lightdm \
    util-linux-extra

for file in "$script_dir"/*.sh; do
    [[ -f "$file" ]] || continue
    sudo chmod +x "$file"
done