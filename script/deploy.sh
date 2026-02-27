#!/bin/sh

config=""
target=""
drive=""
luksPassword=""

setConfig() {

    while true; do

        echo ""
        nix flake show --all-systems --json --impure | jq -r '.nixosConfigurations | to_entries | .[] | "\(.key)"' | nl -w 2 -s ') '
        echo -e -n "\nConfig to deploy [ 1.. ] "
        read input

        if [[ "$input" =~ ^[0-9]+$ && "$input" -gt 0 ]]; then

            config=$(nix flake show --all-systems --json --impure | \
              jq -r --arg index "$input" '.nixosConfigurations | to_entries | .[(($index | tonumber) - 1)] | .key')

        fi

        if [[ "$config" != "" && "$config" != "null" ]]; then

            if [[ -r /run/secrets/"${config}"-ssh-host ]]; then
                echo -e "\033[32mDeploying config ${config}\033[0m"
                return 0
            fi

            if [[ -e /run/secrets/"${config}"-ssh-host ]]; then
                echo -e "\033[31mUnable to read SSH host key SOPS secret for ${config}\033[0m"
                exit 1
            fi

            echo -e "\033[31mSSH host key SOPS secret not present for ${config}\033[0m"
            exit 1
        fi

        echo -e "\033[31mInvalid choice\033[0m"

    done
}


setTarget() {

    while true; do

        echo -e -n "\nHostname of deploy target [ localhost ] "
        read input

        if [[ $input == "" ]]; then
            input="localhost"
        fi

        ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 root@$input exit

        if [[ $? -ne 0 ]]; then
            echo -e "\033[31mCouldn't connect to target ${input}\033[0m"
        else
            echo -e "\033[32mConnected to target ${input}\033[0m"
            target=$input
            return 0
        fi

    done
}

setDriveRemovable() {

    if [[ "$config" != "egg" ]]; then
        echo -e "\033[33mConfig is $config, make sure to set drive declaritively\033[0m"
        return 0
    fi

    while true; do

        echo ""
        ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target \
        lsblk -o HOTPLUG,TYPE,NAME,SIZE,VENDOR,MODEL | \
        awk '$1 == "1" && $2 == "disk" {print $3,$4,$5,$6}' | nl -w 2 -s ') '
        echo -e " A) Show non-removable devices..."
        echo -e -n "\nDevice to deploy on [ 1..A ] "
        read input

        if [[ "$input" =~ ^[0-9]+$ ]]; then

            drive=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target \
              lsblk -o HOTPLUG,TYPE,NAME | \
              awk '$1 == "1" && $2 == "disk" {print $3}' | \
              awk -v inp=$input 'NR == inp {print "/dev/"$1}')

        fi

        if [[ "$input" == "A" ]]; then

            setDriveInternal
            if [[ "$drive" == "" ]]; then
                continue
            fi

        fi

        if [[ "$drive" != "" ]]; then
            echo -e "\033[32mDeploying on ${drive}\033[0m"
            return 0
        fi

        echo -e "\033[31mInvalid choice\033[0m"

    done
}

setDriveInternal() {

    while true; do

        echo ""
        ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target \
        lsblk -o HOTPLUG,TYPE,NAME,SIZE,VENDOR,MODEL,ID | \
        awk '$1 == "0" && $2 == "disk" {print $3,$4,$5,$6,$7}' | nl -w 2 -s ') '
        echo -e " \033[32mB) (RECOMMENDED)\033[0m Show removable device only..."
        echo -e "\n\033[31mWARNING: THESE DEVICES MAY CONTAIN AN OPERATING SYSTEM OR OTHER CRITICAL DATA\033[0m"
        echo -e -n "Device to deploy on [ 1..\033[32mB\033[0m ] "
        read input

        if [[ "$input" =~ ^[0-9]+$ ]]; then

            echo -e -n "\033[31mDo you know what you're doing?\033[0m [ \033[31my\033[0m/\033[32mN\033[0m ] "
            read inputConfirm

            if [[ ${inputConfirm,,} == "y" ]]; then

                drive=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target \
                  lsblk -o HOTPLUG,TYPE,NAME | \
                  awk '$1 == "0" && $2 == "disk" {print $3}' | \
                  awk -v inp=$input 'NR == inp {print "/dev/"$1}')

            else
                  return 0
            fi

        fi

        if [[ "${input,,}" == "b" ]]; then
            return 0
        fi

        if [[ "$drive" != "" ]]; then
            return 0
        fi

        echo -e "\033[31mInvalid choice\033[0m"

    done
}

confirmation() {

    while true; do

        echo -e "\nConfig: ${config}"
        echo -e "Target: ${target}"

        if [[ "$config" == "egg" ]]; then
            echo -e "Drive:  ${drive}"
        fi

        echo -e -n "\nProceed with nixos-anywhere? [ y/N ] "
        read input

        if [[ "${input,,}" == "n" || "${input,,}" == "" ]]; then
            echo -e "\033[31mUser did not confirm, terminating...\033[0m"
            cleanup
            exit 1
        fi

        if [[ "${input,,}" == "y" ]]; then
            echo -e "\033[32mUser confirmed, proceeding...\033[0m\n"
            return 0
        fi

        echo -e "\033[31mInvalid choice\033[0m"

    done
}

cleanup() {

    if [[ -e "/tmp/egg-drive" ]]; then
        rm -f /tmp/egg-drive
    fi

    if [[ -e "/tmp/egg-drive-name" ]]; then
        rm -f /tmp/egg-drive-name
    fi

    if [[ -e "/tmp/aviary-extra-files" ]]; then
        rm -rf /tmp/aviary-extra-files
    fi
}

setConfig
setTarget
setDriveRemovable
confirmation

mkdir -p /tmp/aviary-extra-files/persist/etc/ssh
cp /run/secrets/"${config}"-ssh-host /tmp/aviary-extra-files/persist/etc/ssh/ssh_host_ed25519_key
chmod 0400 /tmp/aviary-extra-files/persist/etc/ssh/ssh_host_ed25519_key

mkdir -p /tmp/aviary-extra-files/etc/ssh
cp /run/secrets/"${config}"-ssh-host /tmp/aviary-extra-files/etc/ssh/ssh_host_ed25519_key
chmod 0400 /tmp/aviary-extra-files/etc/ssh/ssh_host_ed25519_key

luksPasswordRecovery=$(cat /run/secrets/"$config"-luks)
ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target "printf '%s' '$luksPasswordRecovery' > /luks-password-recovery"

ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target "mkdir -p /mnt"

sbctl create-keys --disable-landlock -e /tmp/aviary-extra-files/var/lib/sbctl/keys -d /tmp/aviary-extra-files/var/lib/sbctl/GUID
mkdir -p /tmp/aviary-extra-files/persist/var/lib
cp -r /tmp/aviary-extra-files/var/lib/sbctl /tmp/aviary-extra-files/persist/var/lib

if [[ "$config" == "egg" ]]; then
    echo -n ${drive} | tee /tmp/egg-drive >/dev/null
    rand_str=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
    echo -n "egg-${rand_str}" > /tmp/egg-drive-name
fi

if [[ "$target" == "localhost" ]]; then
    nixos-anywhere -f .\#$config --option pure-eval false --extra-files /tmp/aviary-extra-files --phases disko,install root@$target
    naExit=$?

    ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target "rm /luks-password-recovery"
    ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target "umount /mnt/boot /mnt/nix /mnt/persist /mnt"
    ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target "dmsetup remove /dev/mapper/disk-primary-luks-btrfs-$(cat /tmp/egg-drive-name)"
else
    nixos-anywhere -f .\#$config --option pure-eval false --extra-files /tmp/aviary-extra-files --phases disko,install,reboot root@$target
    naExit=$?

    if [[ $naExit -ne 0 ]]; then
        ssh -o BatchMode=yes -o ConnectTimeout=5 root@$target "rm /luks-password-recovery"
    fi
fi

cleanup

if [[ $naExit -ne 0 ]]; then
    echo -e "\n\033[31mDeployment with nixos-anywhere failed\033[0m"
    exit 1
fi

echo -e "\n\033[32mDeployment with nixos-anywhere successful\033[0m"
exit 0
