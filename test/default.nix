{
  inputs,
  self,
  ...
}:

let
  inherit (builtins)
    readFile
  ;

in {

  name = "default";

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default

      (import ./user/testA.nix {inherit inputs;})
    ];
  };

  testScript = readFile ./check/default.py;
}
