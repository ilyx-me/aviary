{
  inputs,
  pkgs,
  self,
  ...
}:

let
  inherit (builtins)
    readFile
    ;
in
{
  name = "default";

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default

      (import ./user/testA.nix {inherit inputs;})
    ];

    virtualisation.useEFIBoot = true;
    virtualisation.useBootLoader = true;
    virtualisation.useSecureBoot = true;

    system.activationScripts."genSBKeys".text = ''
      ${pkgs.sbctl}/bin/sbctl create-keys
    '';
  };

  testScript = readFile ./check/secureboot.py;
}
