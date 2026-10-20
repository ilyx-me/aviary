machine.wait_for_unit("default.target")
machine.succeed("ls /run/secrets/test-a-ssh")
machine.succeed("ls /run/secrets/test-a-ts")
