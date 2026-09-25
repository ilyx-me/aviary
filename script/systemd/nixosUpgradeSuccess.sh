#!/bin/sh

coreutils_path=$1

booted="$("$coreutils_path"/bin/readlink /run/booted-system/{initrd,kernel,kernel-modules})"
built="$("$coreutils_path"/bin/readlink /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"

if [ "''${booted}" = "''${built}" ]; then
    echo -n "nixos-upgrade-reboot" > /run/nixos-upgrade/status
else
    echo -n "nixos-upgrade-success" > /run/nixos-upgrade/status
fi
