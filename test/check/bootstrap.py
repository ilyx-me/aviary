machine.wait_for_unit("default.target")
assert "Product: lanzastub" in machine.succeed("bootctl -q --no-pager")
