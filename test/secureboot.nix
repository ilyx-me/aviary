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

  name = "secureboot";

  nodes.machine = { ... }: {

    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default
      (import ./user/testA.nix {inherit inputs;})
    ];

    virtualisation = {
      useEFIBoot = true;
      useBootLoader = true;
      useSecureBoot = true;
    };

    boot.lanzaboote.autoEnrollKeys.autoReboot = lib.mkVMOverride false;
  };

  testScript = readFile ./check/secureboot.py;
}
