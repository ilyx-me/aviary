{
  config,
  lib,
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

  options.aviary = {

    bootstrap = mkOption {
      type = bool;
      default = true;
      example = false;
      description = "enable bootstrap";
    };
  };

  config = mkIf config.aviary.bootstrap {

    boot = {
      loader = {
        timeout = 5;
        systemd-boot = {
          enable = mkForce false; # Using Lanzaboote for secureboot
          editor = false; # Prevent passing Kernel parameters at boot
        };

        efi.canTouchEfiVariables = true;
      };

      lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
        autoGenerateKeys.enable = true;
        autoEnrollKeys = {
          enable = true;
          autoReboot = true;
        };
      };
    };

    environment.persistence."/persist".directories = [
      "/var/lib/sbctl"
    ];
  };
}
