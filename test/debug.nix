{
  inputs,
  lib,
  self,
  ...
}:

let
  inherit (builtins)
    readFile
    ;
in
{
  name = "debug";
  enableOCR = true;

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default
      ../environment/module/debug.nix

      (import ./user/testA.nix { inherit inputs lib; })
    ];
  };

  testScript = readFile ./check/debug.py;
}
