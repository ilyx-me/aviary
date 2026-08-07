{
  config,
  pkgs,
  ...
}:

let

  inherit (builtins)
    readFile
    ;

  host = config.networking.hostName;

in

{

  config = {

    disko.devices.disk.primary.content.partitions.root.content.content =

      let

        hook = pkgs.writeShellScript "diskquota" (readFile ../../../script/diskQuota.sh);

        mapperDevice = "/dev/mapper/disk-primary-luks-btrfs-${host}";

      in
      {

        postCreateHook = "${hook} ${mapperDevice}";
      };
  };
}
