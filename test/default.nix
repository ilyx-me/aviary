{ ... }:
let
  inherit (builtins)
    readFile
    ;
in
{
  name = "default";

  nodes.machine = { ... }: { };

  testScript = readFile ./check/default.py;
}
