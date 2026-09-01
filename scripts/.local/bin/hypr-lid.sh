#!/bin/bash
# Called by acpid on every lid open/close event. Disables the internal panel
# (eDP-1) when the lid closes while an external monitor is connected, so
# Hyprland stops treating it as part of the active layout ("clamshell mode").
# Re-enables it on lid open. If no external monitor is connected, this is a
# no-op and systemd-logind's normal suspend-on-lid-close behavior applies.

set -euo pipefail

USER_NAME="thoughts"
USER_ID="$(id -u "$USER_NAME")"
export XDG_RUNTIME_DIR="/run/user/${USER_ID}"
export HYPRLAND_INSTANCE_SIGNATURE
HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR}/hypr" 2>/dev/null | head -n1)"

[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || exit 0

run_as_user() {
    runuser -u "$USER_NAME" -- env \
        XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE" \
        "$@"
}

LID_STATE="$(awk '{print $2}' /proc/acpi/button/lid/*/state 2>/dev/null | head -n1)"

if [ "$LID_STATE" = "closed" ]; then
    if run_as_user hyprctl monitors -j | grep -q '"name": "DP-1"'; then
        run_as_user hyprctl eval 'hl.monitor({output = "eDP-1", disabled = true})'
    fi
else
    run_as_user hyprctl eval 'hl.monitor({output = "eDP-1", mode = "preferred", position = "auto", scale = 0.95, disabled = false})'
fi
