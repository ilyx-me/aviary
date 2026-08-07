machine.wait_for_unit("multi-user.target")
machine.succeed("echo -n password | cryptsetup luksFormat -q --iter-time=1 /dev/vdb -")
machine.succeed("echo -n password | cryptsetup luksOpen -q /dev/vdb cryptroot")
machine.succeed("mkfs.btrfs /dev/mapper/cryptroot")
machine.succeed("bootctl set-default nixos-generation-1-specialisation-boot-luks.conf")
machine.succeed("sync")
machine.crash()
machine.start()
machine.wait_for_text("[Pp]assphrase for")
machine.send_key("ctrl-alt-f9")
machine.wait_for_text("sh-")

machine.send_chars("ip route show default\n")
machine.wait_for_text("default via")

machine.send_chars("systemctl status sshd --no-pager\n")
machine.wait_for_text("active")

machine.send_chars("printf '\\033c'\n")
machine.wait_for_text("sh-")

machine.send_chars("tailscale ip\n")
machine.wait_for_text("100.")
