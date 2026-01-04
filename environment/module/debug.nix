{
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkForce
    ;

in {

  config = {

    boot = {
      initrd.systemd = {
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
        "rd.systemd.debug_shell" # open initrd debug shell on tty9
      ];
    };

    # getty login is disabled for recovery so make sure it's enabled
    services.getty = {
      loginProgram = mkForce "${pkgs.shadow}/bin/login";
      loginOptions = mkForce null;
      extraArgs = mkForce [];
    };

    users.users = {
      root.hashedPassword = mkForce "";
      "999".hashedPassword = mkForce "";
      "1000".hashedPassword = mkForce "";
    };
  };
}
