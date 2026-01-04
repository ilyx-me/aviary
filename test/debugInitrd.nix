{
  ...
}:

let
  inherit (builtins)
    readFile
  ;

in {

  name = "debugInitrd";
  enableOCR = true;

  nodes.machine = { ... }: {
    imports = [
      ../environment/module/debug.nix
    ];

    testing.initrdBackdoor = true;

    boot.initrd.systemd.enable = true;

    users.groups."admins" = {};
    users.users."999".group = "admins";
    users.users."999".isSystemUser = true;
    users.users."1000".isNormalUser = true;
  };

  testScript = readFile ./check/debugInitrd.py;
}
