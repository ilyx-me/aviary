# Check initrd debug on tty9
machine.wait_for_text("[Pp]assphrase for")
machine.send_key("ctrl-alt-f9")
machine.wait_for_text("bash-")
machine.send_chars("whoami\n")
machine.wait_for_text("root")

# Need to get to main system or test will timeout
machine.send_key("ctrl-alt-f1")
machine.wait_for_text("[Pp]assphrase for")
machine.send_chars("password\n")
