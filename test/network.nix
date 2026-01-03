{
  inputs,
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
      inputs.home-manager.nixosModules.default
      inputs.impermanence.nixosModules.impermanence
      inputs.sops-nix.nixosModules.sops
      ../environment/module/default.nix
      ../service/default.nix

      (import ./user/testA.nix { inherit inputs; })
    ];
  };

  testScript = readFile ./check/network.py;
}
