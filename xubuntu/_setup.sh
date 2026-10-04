#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Run setup.sh as your normal user, not root." >&2
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required." >&2
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Keep scripts in dependency order; add new setup scripts to this list.
scripts=(
    env.sh
    keyd.sh
    docker.sh
    sunshine.sh
)

for script in "${scripts[@]}"; do
    script_path="$script_dir/$script"

    if [[ ! -f "$script_path" ]]; then
        echo "ERROR: Setup script not found: $script_path" >&2
        exit 1
    fi

    echo
    echo "==> Running $script..."
    bash "$script_path"
done

echo
echo "All setup scripts completed successfully."