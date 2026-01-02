machine.wait_for_unit("multi-user.target")

machine.succeed("ip route show default | grep 'default via'")
machine.succeed("systemctl is-active sshd | grep 'active'")
machine.succeed("systemctl is-active tailscaled | grep 'active'")
