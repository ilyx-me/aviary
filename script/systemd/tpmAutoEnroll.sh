#!/bin/sh

systemd_path=$1
hostname=$2

if [ "$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* | tr -d ' ')" -eq 60001 ]; then
    "$systemd_path"/bin/systemd-cryptenroll /dev/disk/by-partlabel/disk-primary-luks-"$hostname" \
      --wipe-slot=tpm2 \
      --tpm2-device=auto \
      --tpm2-pcrs=7 \
      --unlock-key-file=/run/secrets/"$hostname"-luks

    if [ -e "/dev/disk/by-partlabel/disk-secondary-luks-$hostname" ]; then
        "$systemd_path"/bin/systemd-cryptenroll /dev/disk/by-partlabel/disk-secondary-luks-"$hostname" \
          --wipe-slot=tpm2 \
          --tpm2-device=auto \
          --tpm2-pcrs=7 \
          --unlock-key-file=/run/secrets/"$hostname"-luks
    fi
fi
