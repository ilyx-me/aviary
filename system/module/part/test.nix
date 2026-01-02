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
            type = "EF00";
            size = "512M";
            name = "esp-" + host;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          persist = {
            size = "1024M";
            name = "ext4-persist-" + host;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/persist";
            };
          };
          root = {
            size = "100%";
            name = "ext4-" + host;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
