{
  ...
}:

{

  config = {

    networking.hostName = "lark";
    system.stateVersion = "26.05";

    nixpkgs.hostPlatform = "aarch64-linux";

    aviary.drive.primary = "/dev/disk/by-id/wwn-0x60e788a1e0b647f19b4562a634dd790d";

    boot.kernelParams = [ "console=ttyAMA0" ];

    # Secondary Public Interface
    systemd.network.networks."05-enp1s0" = {
      address = [ "10.0.0.5/29" ];
      gateway = [ "10.0.0.1" ];
      linkConfig.MTUBytes = 9000;
      matchConfig.Name = "enp1s0";
      networkConfig.DHCP = "no";
      routes = [
        {
          Destination = "0.0.0.0/0";
          Gateway = "10.0.0.1";
          Table = "200";
        }
      ];
      routingPolicyRules = [
        {
          Priority = 100;
          Table = "200";
          From = "10.0.0.5/32";
        }
      ];
    };
  };
}
