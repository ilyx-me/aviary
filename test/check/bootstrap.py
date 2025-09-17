machine.wait_for_unit("default.target")
machine.succeed("bootctl | grep lanza")
