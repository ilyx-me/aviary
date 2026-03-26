{
  description = "Aviary by ilyx";
  inputs = {
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-gnome-theme = {
      url = "github:rafaelmardojai/firefox-gnome-theme";
      flake = false;
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    hardware = {
      url = "github:nixos/nixos-hardware";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-25.11";
    };

    secrets = {
      url = "git+ssh://git@github.com/ilyx-me/aviarySecrets.git";
      flake = false;
    };

    secrets-test = {
      url = "git+ssh://git@github.com/ilyx-me/aviarySecretsTest.git";
      flake = false;
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, self, ... }:
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
          _module.args.pkgs = import self.inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;

            # Can also use per-package approach

            # config.allowUnfreePredicate = pkg:
            #   builtins.elem (lib.getName pkg) [
            #     "terraform"
            #   ];
          };

          formatter = pkgs.nixfmt-tree;

          checks =
            let
              lib = pkgs.lib;
              eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
              qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix");
              makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
              diskoLib = import (inputs.disko + "/lib") { inherit lib eval-config makeTest qemu-common; };
            in
            {
              bootstrap = pkgs.testers.runNixOSTest (
                import ./test/bootstrap.nix {
                  inherit inputs lib;
                }
              );

              debug = pkgs.testers.runNixOSTest (
                import ./test/debug.nix {
                  inherit inputs self;
                }
              );

              debugInitrd = pkgs.testers.runNixOSTest (
                import ./test/debugInitrd.nix { }
              );

              decrypt = pkgs.testers.runNixOSTest (
                import ./test/decrypt.nix {
                  inherit inputs lib pkgs self;
                }
              );

              default = pkgs.testers.runNixOSTest (
                import ./test/default.nix {
                  inherit inputs self;
                }
              );

              /*
              deploy = pkgs.testers.runNixOSTest ( #TODO FINISH
                import ./test/deploy.nix {
                  inherit inputs lib self';
                }
              );

              deployDisko = diskoLib.testLib.makeDiskoTest ( #TODO FINISH
                import ./test/deployDisko.nix {
                  inherit inputs lib pkgs self';
                }
              );
              */

              network = pkgs.testers.runNixOSTest (
                import ./test/network.nix {
                  inherit inputs self;
                }
              );

              networkInitrd = pkgs.testers.runNixOSTest (
                import ./test/networkInitrd.nix {
                  inherit inputs lib pkgs self;
                }
              );

              partRecovery = diskoLib.testLib.makeDiskoTest (
                import ./test/partRecovery.nix {
                  inherit lib pkgs;
                }
              );

              partSingle = diskoLib.testLib.makeDiskoTest (
                import ./test/partSingle.nix {
                  inherit lib pkgs;
                }
              );

              persist = pkgs.testers.runNixOSTest (
                import ./test/persist.nix {
                  inherit inputs lib pkgs self;
                }
              );

              secrets = pkgs.testers.runNixOSTest (
                import ./test/secrets.nix {
                  inherit inputs self;
                }
              );

              secureboot = pkgs.testers.runNixOSTest (
                import ./test/secureboot.nix {
                  inherit inputs lib self;
                }
              );

              tpm = pkgs.testers.runNixOSTest (
                import ./test/tpm.nix {
                  inherit inputs lib pkgs self;
                }
              );

              /*
              update = pkgs.testers.runNixOSTest ( #TODO FINISH
                import ./test/update.nix {
                  inherit inputs lib self pkgs;
                }
              );

              wifi = pkgs.testers.runNixOSTest ( #TODO FINISH
                import ./test/wifi.nix {
                  inherit inputs lib;
                }
              );
              */

            };
        };

      flake = {
        nixosModules = {
          default = { ... }: {
            #_module.args = { inherit inputs; }; # Can be used for diskoLib tests, can also be put in their extraInstallerConfig/extraSystemConfig
            imports = [
              inputs.home-manager.nixosModules.default
              inputs.impermanence.nixosModules.impermanence
              inputs.sops-nix.nixosModules.sops
              ./environment/module/default.nix
              ./service/default.nix
            ];
          };

          bootstrap = { ... }: {
            imports = [
	      self.nixosModules.default
              inputs.disko.nixosModules.default
              inputs.lanzaboote.nixosModules.lanzaboote
              ./environment/module/bootstrap.nix
            ];
          };

          recovery = { ... }: {
            imports = [
              self.nixosModules.bootstrap
              ./environment/module/recovery.nix
            ];
          };
        };

        nixosConfigurations = {
          deploy-test = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              self.nixosModules.recovery
              ./system/module/part/default.nix
              ./system/module/part/recovery.nix
              ({ ... }: {
                nixpkgs.hostPlatform = "x86_64-linux";
                networking.hostName = "test-a";
                system.nixos.variant_id = "test";
                boot.initrd.network.ssh.authorizedKeys = [ "none" ];
                sops.defaultSopsFile = "${inputs.secrets-test}/test-a.yaml";
                aviary.uID = "test-a";
              })
            ];
          };

          egg = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              self.nixosModules.recovery
              ./system/module/part/default.nix
              ./system/module/part/recovery.nix
              ./user/recovery.nix
              ({ ... }: {
                nixpkgs.hostPlatform = "x86_64-linux";
                networking.hostName = "egg";
              })
            ];
          };

          chicken = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              self.nixosModules.bootstrap
	      ./environment/module/graphical.nix
	      ./environment/module/niri.nix
              ./system/module/part/default.nix
              ./system/module/part/single.nix
              ./system/chicken.nix
              ./user/00.nix
	      ./service/update.nix
            ];
          };

          ibis = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              self.nixosModules.bootstrap
	      ./environment/module/graphical.nix
	      ./environment/module/niri.nix
	      ./environment/module/waydroid.nix
              ./system/module/part/default.nix
              ./system/module/part/single.nix
	      ./system/module/part/quota.nix
              ./system/ibis.nix
              ./user/00.nix
              ./service/update.nix
            ];
          };
        };
      };
    };
}
