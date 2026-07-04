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

    secondary = mkOption {
      type = str;
      default = "none";
      example = "/dev/vdc";
      description = "System secondary drive";
    };
  };

  config = {

    disko.devices.disk = {

      primary.content.partitions.root.content.content.subvolumes = {

        "root" = {
          mountOptions = [ "compress=zstd" "noatime" ];
          mountpoint = "/";
        };

        "swap" = {
          swap.swapfile.size = "8G";
          mountpoint = "/.swapvol";
        };
      };

      secondary = {

        device = config.aviary.drive.secondary;

        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            home = {
              size = "100%";
              name = if pathExists /tmp/aviaryInstall/egg-drive-name then "luks-${readFile /tmp/aviaryInstall/egg-drive-name}" else "luks-${host}";
              content = {
                type = "luks";
                name = if pathExists /tmp/aviaryInstall/egg-drive-name then "disk-secondary-luks-btrfs-${readFile /tmp/aviaryInstall/egg-drive-name}" else "disk-secondary-luks-btrfs-${host}";
                settings.allowDiscards = true;
                passwordFile = "/tmp/aviaryInstall/luks-password-recovery";
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "home" = {
                      mountOptions = [ "compress=zstd" "noatime" ];
                      mountpoint = "/home";
                    };
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
