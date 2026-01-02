# Check initrd debug on tty9
machine.start()
machine.wait_for_unit("initrd.target")
machine.send_key("ctrl-alt-f9")
machine.wait_for_text("sh-")
machine.send_chars("whoami\n")
machine.wait_for_text("root")
