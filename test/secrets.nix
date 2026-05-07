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

  name = "secrets";

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default

      (import ./user/testA.nix {inherit inputs lib;})
    ];
  };

  testScript = readFile ./check/secrets.py;
}
