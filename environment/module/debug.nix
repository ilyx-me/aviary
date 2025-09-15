{
  config,
  lib,
  pkgs,
  ...
}: {
  config = {
    boot = {
      initrd.systemd = {
        #emergencyAccess = true; # allow unauthenticated initrd access
        packages = with pkgs; [
          coreutils
          curl
          gnugrep
          iproute2
          iputils
          traceroute
          wget
        ];
        initrdBin = with pkgs; [
          coreutils
          curl
          gnugrep
          iproute2
          iputils
          traceroute
          wget
        ];
      };

      kernelParams = [
        #"rd.systemd.unit=rescue.target" # force initrd into rescue mode
        "rd.systemd.debug_shell" # open initrd debug shell on tty9
      ];
    };

    users.users.root.hashedPassword = lib.mkForce "";
    users.users.admin.hashedPassword = lib.mkForce "";
    users.users."1000".hashedPassword = lib.mkForce "";
  };
}
