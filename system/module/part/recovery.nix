{
  ...
}:

{

  config = {

    disko.devices = {
      nodev."/" = {
        fsType = "tmpfs";
        mountOptions = [
          "defaults"
          "mode=755"
          "size=4G"
        ];
      };
    };
  };
}
