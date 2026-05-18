#!/bin/sh

config=""
drive=""
luks=""
age=""

setAge() {

    while true; do
	echo ""
        read -s -p "Enter age private key for ${config}: " input

	echo -en "$input" | age-keygen -y > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
	    echo ""
	    echo -e "\033[31mAge key invalid\033[0m"
	    continue
        fi

	echo ""
        echo -e "\033[32mAge key valid\033[0m"
	age="$input"
	return 0
    done
}

setLuks() {

    while true; do
	echo ""
        read -s -p "Enter luks recovery password for ${config}: " input

        if [[ -z "$input" ]]; then
	    echo ""
	    echo -e "\033[31mLuks recovery password cannot be empty\033[0m"
	    continue
        fi

	echo ""
	echo -e "\033[32mLuks recovery password valid\033[0m"
	luks="$input"
	return 0
    done
}

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
            echo -e "\033[32mDeploying config ${config}\033[0m"
            return 0
        fi

        echo -e "\033[31mInvalid choice\033[0m"

    done
}


#setTarget() {
#
#    while true; do
#
#        echo -e -n "\nHostname of deploy target [ localhost ] "
#        read input
#
#        if [[ "$input" == "" ]]; then
#            input="localhost"
#        fi
#
#	if [[ "$input" != "localhost" ]]; then
#	    ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 root@$input exit
#
#            if [[ $? -ne 0 ]]; then
#                echo -e "\033[31mCouldn't connect to target ${input}\033[0m"
#            else
#                echo -e "\033[32mConnected to target ${input}\033[0m"
#            fi
#        else
#	    echo -e "\033[31mOk\033[0m"
#	fi
#
#        target=$input
#        return 0
#
#    done
#}

setDriveRemovable() {

    if [[ "$config" != "egg" ]]; then
        echo -e "\033[33mConfig is $config, make sure to set drive declaritively\033[0m"
        return 0
    fi

    while true; do

        echo ""
	lsblk -o HOTPLUG,TYPE,NAME,SIZE,VENDOR,MODEL | \
          awk '$1 == "1" && $2 == "disk" {print $3,$4,$5,$6}' | nl -w 2 -s ') '
        echo -e " A) Show non-removable devices..."
        echo -e -n "\nDevice to deploy on [ 1..A ] "
        read input

        if [[ "$input" =~ ^[0-9]+$ ]]; then
	    drive=$(lsblk -o HOTPLUG,TYPE,NAME | \
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
		drive=$(lsblk -o HOTPLUG,TYPE,NAME | \
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
        #echo -e "Target: ${target}"

        if [[ "$config" == "egg" ]]; then
            echo -e "Drive:  ${drive}"
        fi

        echo -e -n "\nProceed with installation? [ y/N ] "
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

setConfig
setLuks
setAge
setDriveRemovable
confirmation

mkdir -p /tmp/aviaryInstall

touch /tmp/aviaryInstall/age_host_key
chmod 0600 /tmp/aviaryInstall/age_host_key
echo -n "${age}" > /tmp/aviaryInstall/age_host_key

touch /tmp/aviaryInstall/luks-password-recovery
chmod 0600 /tmp/aviaryInstall/luks-password-recovery
echo -n "${luks}" > /tmp/aviaryInstall/luks-password-recovery

if [[ "$config" == "egg" ]]; then
    randStr=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
    echo -n "egg-${randStr}" > /tmp/aviaryInstall/egg-drive-name

    disko-install --flake .\#${config} --extra-files /tmp/aviaryInstall/age_host_key /persist/var/keys/age_host_key --disk primary "${drive}"
else
    disko-install --flake .\#${config} --extra-files /tmp/aviaryInstall/age_host_key /persist/var/keys/age_host_key
fi

diExit=$?

rm -rf /tmp/aviaryInstall

if [[ $diExit -ne 0 ]]; then
    echo -e "\n\033[31mDeployment with disko-install failed\033[0m"
    exit 1
fi

echo -e "\n\033[32mDeployment with disko-install successful\033[0m"
exit 0
