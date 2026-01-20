{
  inputs,
  lib,
  ...
}:

let
  inherit (builtins)
    readFile
  ;

in {

  name = "bootstrap";

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      inputs.impermanence.nixosModules.impermanence
      inputs.lanzaboote.nixosModules.lanzaboote
      ../environment/module/bootstrap.nix
    ];

    virtualisation = {
      useEFIBoot = true;
      useBootLoader = true;
    };

    boot.lanzaboote.autoEnrollKeys.autoReboot = lib.mkVMOverride false;
  };

  testScript = readFile ./check/bootstrap.py;
}
