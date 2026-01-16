{
  config,
  lib,
  ...
}:

let
  inherit (builtins)
    pathExists
    readFile
    ;

  inherit (lib)
    mkOption
    ;

  inherit (lib.types)
    str
    ;

  host = config.networking.hostName;
in
{
  options.aviary.drive = {

    primary = mkOption {
      type = str;
      default = host + "-drive-primary";
      example = "hostname-drive-primary";
      description = "System primary drive";
    };
  };

  config = {

    disko.devices.disk.primary = {

      device = if pathExists /tmp/egg-drive then readFile /tmp/egg-drive else config.aviary.drive.primary;

      type = "disk";
      content = {
        type = "gpt";
        partitions = {

          esp = {
            size = "4096M";
            type = "EF00";
            name = if pathExists /tmp/egg-drive-name then "esp-${readFile /tmp/egg-drive-name}" else "esp-${host}";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "defaults"
                "umask=0077"
              ];
            };
          };

          root = {
            size = "100%";
            name = if pathExists /tmp/egg-drive-name then "luks-${readFile /tmp/egg-drive-name}" else "luks-${host}";
            content = {
              type = "luks";
              name = if pathExists /tmp/egg-drive-name then "disk-primary-luks-btrfs-${readFile /tmp/egg-drive-name}" else "disk-primary-luks-btrfs-${host}";
              settings.allowDiscards = true;
              passwordFile = "/luks-password-recovery";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "nix" = {
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/nix";
                  };
                  "persist" = {
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/persist";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
