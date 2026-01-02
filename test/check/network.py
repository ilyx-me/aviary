machine.wait_for_unit("multi-user.target")

assert "default via" in machine.succeed("ip route show default")
assert "active" in machine.succeed("systemctl is-active sshd")
assert "active" in machine.succeed("systemctl is-active tailscaled")
