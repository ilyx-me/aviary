# log into root
machine.wait_for_unit("multi-user.target")
machine.send_chars("root\n")
machine.wait_for_unit("user@0.service")
machine.succeed("last | grep tty1 | grep root")

# Log into admin
machine.send_key("ctrl-alt-f2")
machine.wait_for_text("login:")
machine.send_chars("admin\n")
machine.wait_for_unit("user@999.service")
machine.succeed("last | grep tty2 | grep admin")

# Log into 1000
machine.send_key("ctrl-alt-f3")
machine.wait_for_text("login:")
machine.send_chars("user\n")
machine.wait_for_unit("user@1000.service")
machine.succeed("last | grep tty3 | grep user")
