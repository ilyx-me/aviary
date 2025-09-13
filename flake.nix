{
  description = "Aviary by ilyx";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-25.05";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # flake-parts modules go here
      imports = [ ];

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        {
          config,
          inputs',
          pkgs,
          self',
          system,
          ...
        }:
        {
          formatter = pkgs.nixfmt-tree;

          checks = {
            default = pkgs.testers.runNixOSTest (import ./test/default.nix { });
          };
        };

      flake = { };
    };
}
