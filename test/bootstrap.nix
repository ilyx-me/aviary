{
  inputs,
  pkgs,
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
      inputs.lanzaboote.nixosModules.lanzaboote
      ../environment/module/bootstrap.nix
    ];

    virtualisation = {
      useEFIBoot = true;
      useBootLoader = true;
    };

    system.activationScripts."genSBKeys".text = ''
      ${pkgs.sbctl}/bin/sbctl create-keys
    '';
  };

  testScript = readFile ./check/bootstrap.py;
}
