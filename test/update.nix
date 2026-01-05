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

  name = "update";

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default
      ../service/update.nix
      (import ./user/testA.nix { inherit inputs; })
    ];

    services.comin.hostname = lib.mkVMOverride "deploy-test";
  };

  testScript = readFile ./check/update.py;
}
