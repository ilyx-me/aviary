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

    users.groups.admin = {};
    users.users.admin.group = "admin";
    users.users.admin.isSystemUser = true;
    users.users."1000".isNormalUser = true;
  };

  testScript = readFile ./check/debugInitrd.py;
}
