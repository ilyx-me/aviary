{
  ...
}:

{

  config = {

    networking.hostName = "swallow";
    system.stateVersion = "26.05";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary.drive.primary = "/dev/disk/by-id/wwn-0x600059fd17194a4f9b6c583e1f65a864";

    boot.kernelParams = [ "console=ttyS0" ];
  };
}
