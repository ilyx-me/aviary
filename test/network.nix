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

in {

  name = "network";

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default

      (import ./user/testA.nix { inherit inputs lib; })
    ];
  };

  testScript = readFile ./check/network.py;
}
