let

  sources = import ../npins;
  pkgs = import sources.nixpkgs { };

  inherit ( builtins )
    readFile
  ;

in

pkgs.testers.runNixOSTest {

  name = "default";

  nodes.machine = { ... }: { };

  testScript = readFile ./default.py;
}
