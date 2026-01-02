{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkForce
    mkIf
    mkOption
    ;

  inherit (lib.types)
    bool
    ;

in {

  options.bootstrap = {

    enable = mkOption {
      type = bool;
      default = true;
      example = false;
      description = "enable bootstrap";
    };
  };

  config = mkIf config.bootstrap.enable {

    boot = {
      loader = {
        timeout = 5;
        systemd-boot = {
          enable = mkForce false;
          consoleMode = "max";
          editor = false;
        };

        #limine = {
        #  enable = true;
        #  secureBoot.enable = true;
        #};

        efi.canTouchEfiVariables = true;
      };

      lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };
    };

    #system.activationScripts."enrollSecureboot".text = ''
    #  ${pkgs.sbctl}/bin/sbctl create-keys
    #'';
  };
}
