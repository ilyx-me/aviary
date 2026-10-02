#!/bin/sh

libnotify_path=$1
inotify_tools_path=$2

status_last=""

while read file; do
    sleep 0.5

    status_current=$(cat "$file" 2>/dev/null || echo -n "")

    if [[ "$status_current" != "$status_last" ]]; then
        case "$status_current" in
            "nixos-upgrade-start")
                "$libnotify_path"/bin/notify-send -a "NixOS System" \
                  -u normal \
                  -i "nix-snowflake" \
                  "Updating System" \
                  "Downloading and installing system updates. Performance may be impaired for the duration."
                ;;
            "nixos-upgrade-success")
                "$libnotify_path"/bin/notify-send -a "NixOS System" \
                  -u normal \
                  -i "nix-snowflake" \
                  "Update Successful" \
                  "In place upgrade complete. No action required."
                ;;
            "nixos-upgrade-reboot")
                "$libnotify_path"/bin/notify-send -a "NixOS System" \
                  -u critical \
                  -i "nix-snowflake" \
                  "Reboot Required" \
                  "Please restart the system to finalize remaining changes."
                ;;
            "nixos-upgrade-failure")
                "$libnotify_path"/bin/notify-send -a "NixOS System" \
                  -u critical \
                  -i "nix-snowflake" \
                  "Update Failed" \
                  "An error occured. Please run 'journalctl -eu nixos-upgrade' for details."
                ;;
            "nixos-upgrade-network")
                "$libnotify_path"/bin/notify-send -a "NixOS System" \
                  -u normal \
                  -i "nix-snowflake" \
                  "Network Connection Failed" \
                  "Could not check for system updates. Please check the network connection."
                ;;
        esac

        status_last="$status_current"
    fi
done < <($"inotify_tools_path"/bin/inotifywait -m -e modify --format '%w%f' /run/nixos-upgrade/status)
