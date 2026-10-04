#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Run this script as your normal user, not root." >&2
    exit 1
fi

command -v xfconf-query >/dev/null 2>&1 || {
    echo "ERROR: xfconf-query was not found." >&2
    exit 1
}

set_value() {
    local channel="$1"
    local property="$2"
    local type="$3"
    local value="$4"

    if xfconf-query -c "$channel" -p "$property" >/dev/null 2>&1; then
        xfconf-query -c "$channel" -p "$property" -t "$type" -s "$value"
    else
        xfconf-query -c "$channel" -p "$property" -n -t "$type" -s "$value"
    fi
}

set_profile_without_adaptive_acceleration() {
    local property="$1"
    local args=(-a -t int -s 0 -t int -s 1 -t int -s 0)

    if ! xfconf-query -c pointers -p "$property" >/dev/null 2>&1; then
        args=(-n "${args[@]}")
    fi

    xfconf-query -c pointers -p "$property" "${args[@]}"
}

echo "==> Configuring XFCE taskbar..."

panel_channel="xfce4-panel"
panel_id="panel-1"
plugin_ids_property="/panels/${panel_id}/plugin-ids"

set_value "$panel_channel" "/panels/${panel_id}/position" string 'p=10;x=0;y=0'
set_value "$panel_channel" "/panels/${panel_id}/size" uint 24
set_value "$panel_channel" "/panels/${panel_id}/border-width" uint 8
set_value "$panel_channel" "/panels/${panel_id}/nrows" uint 1

get_plugin_ids() {
    local line

    while IFS= read -r line; do
        [[ "$line" =~ ^[0-9]+$ ]] && printf '%s\n' "$line"
    done < <(xfconf-query -c "$panel_channel" -p "$plugin_ids_property")
}

find_plugin_id() {
    local plugin_type="$1"
    local id

    while IFS= read -r id; do
        if [[ "$(xfconf-query -c "$panel_channel" -p "/plugins/plugin-${id}" 2>/dev/null || true)" == "$plugin_type" ]]; then
            printf '%s\n' "$id"
            return 0
        fi
    done < <(get_plugin_ids)

    return 1
}

ensure_plugin() {
    local plugin_type="$1"
    local plugin_id

    plugin_id="$(find_plugin_id "$plugin_type" || true)"
    if [[ -z "$plugin_id" ]]; then
        xfce4-panel "--add=${plugin_type}"
        plugin_id="$(find_plugin_id "$plugin_type" || true)"
    fi

    if [[ -z "$plugin_id" ]]; then
        echo "ERROR: Could not add XFCE panel plugin: ${plugin_type}" >&2
        exit 1
    fi

    printf '%s\n' "$plugin_id"
}

separator_id="$(ensure_plugin separator)"
showdesktop_id="$(ensure_plugin showdesktop)"
ordered_plugin_ids=()
while IFS= read -r id; do
    [[ "$id" == "$separator_id" || "$id" == "$showdesktop_id" ]] ||
        ordered_plugin_ids+=("$id")
done < <(get_plugin_ids)
ordered_plugin_ids+=("$separator_id" "$showdesktop_id")

plugin_id_args=(-a)
for id in "${ordered_plugin_ids[@]}"; do
    plugin_id_args+=(-t int -s "$id")
done
xfconf-query -c "$panel_channel" -p "$plugin_ids_property" "${plugin_id_args[@]}"

echo "==> Configuring mouse and touchpad..."

while IFS= read -r property; do
    [[ "$property" == */Properties/libinput_Accel_Profile_Enabled ]] || continue

    device="${property%/Properties/libinput_Accel_Profile_Enabled}"
    device_name="${device##*/}"

    case "$device_name" in
        *Mouse)
            set_profile_without_adaptive_acceleration "$property"
            set_value pointers "${device}/Acceleration" double 6.0
            ;;
        *Touchpad)
            set_profile_without_adaptive_acceleration "$property"
            set_value pointers "${device}/ReverseScrolling" bool true
            ;;
    esac
done < <(xfconf-query -c pointers -l)

echo "XFCE taskbar and input settings configured."