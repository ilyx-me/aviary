# Check initrd debug on tty9
machine.wait_for_unit("multi-user.target")
machine.succeed("echo -n password | cryptsetup luksFormat -q --iter-time=1 /dev/vdb -")
machine.succeed("bootctl set-default nixos-generation-1-specialisation-boot-luks.conf")
machine.succeed("sync")
machine.crash()
machine.start()
machine.wait_for_text("[Pp]assphrase for")
machine.send_key("ctrl-alt-f9")
machine.wait_for_text("sh-")

# Verify SSH Decryption
machine.send_chars("mkdir -p ~/.ssh && chmod 700 ~/.ssh && ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' && cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && ssh -o StrictHostKeyChecking=accept-new -i ~/.ssh/id_ed25519 -p 2222 root@127.0.0.1\n")

machine.wait_for_text("[Pp]assphrase for")
machine.send_chars("password\n")
machine.wait_for_unit("multi-user.target")
