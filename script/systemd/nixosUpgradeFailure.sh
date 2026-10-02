#!/bin/sh

upgrade_status=$(cat "/run/nixos-upgrade/status" 2>/dev/null || echo -n "")

if [[ "$upgrade_status" == "nixos-upgrade-skip" ]]; then
    exit 0
fi

if [[ "$upgrade_status" == "nixos-upgrade-network" ]]; then
    exit 0
fi

echo -n "nixos-upgrade-failure" > /run/nixos-upgrade/status
