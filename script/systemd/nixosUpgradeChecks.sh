#!/bin/sh

git_path=$1
coreutils_path=$2

revision_system=$(nixos-version --configuration-revision) || {
    echo "Invalid system repository revision, updating anyway..."
}

set -o pipefail
revision_repo=$("$git_path"/bin/git ls-remote https://github.com/ilyx-me/aviary main | "$coreutils_path"/bin/cut -f1) || {
    echo "Unable to get repository revision, exiting..."
    echo -n "nixos-upgrade-network" > /run/nixos-upgrade/status
    exit 1
}

if [[ "$revision_system" == "$revision_repo" ]]; then
    echo "System revision matches repository revision, exiting..."
    echo -n "nixos-upgrade-skip" > /run/nixos-upgrade/status
    exit 1
fi

echo -n "nixos-upgrade-start" > /run/nixos-upgrade/status
