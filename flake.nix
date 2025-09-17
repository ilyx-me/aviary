{
  description = "Aviary by ilyx";

  inputs = {
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-25.05";
    };
  };

  outputs =
    inputs@{ flake-parts, self, ... }:
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

          checks =
            let
              lib = pkgs.lib;
              eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
              makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
              diskoLib = import (inputs.disko + "/lib") { inherit lib eval-config makeTest; };
            in
            {
              bootstrap = diskoLib.testLib.makeDiskoTest (
                import ./test/bootstrap.nix {
                  inherit lib pkgs self self';
                }
              );

              debug = pkgs.testers.runNixOSTest (import ./test/debug.nix { });

              debugInitrd = diskoLib.testLib.makeDiskoTest (
                import ./test/debugInitrd.nix {
                  inherit lib self';
                }
              );

              default = pkgs.testers.runNixOSTest (import ./test/default.nix { });

              partRecovery = diskoLib.testLib.makeDiskoTest (
                import ./test/partRecovery.nix {
                  inherit lib self';
                }
              );
            };
        };

      flake = {
        nixosModules = {
          default = { ... }: {
            imports = [
              inputs.lanzaboote.nixosModules.lanzaboote
              ./environment/module/bootstrap.nix
            ];
          };
        };
      };
    };
}
