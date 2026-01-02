# log into root
machine.wait_for_unit("multi-user.target")
machine.send_chars("root\n")
machine.wait_for_text("root@")
assert '"session":"1","uid":0,"user":"root"' in machine.succeed("loginctl list-sessions --json=short")

# Log into admin
machine.send_key("ctrl-alt-f2")
machine.wait_for_text("login:")
machine.send_chars("admin\n")
machine.wait_for_text("admin@")
assert '"session":"3","uid":999,"user":"admin"' in machine.succeed("loginctl list-sessions --json=short")

# Log into user
machine.send_key("ctrl-alt-f3")
machine.wait_for_text("login:")
machine.send_chars("user\n")
machine.wait_for_text("user@")
assert '"session":"4","uid":1000,"user":"user"' in machine.succeed("loginctl list-sessions --json=short")
