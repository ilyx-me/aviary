{ ... }:
let
  inherit (builtins)
    readFile
    ;
in
{
  name = "debug";
  enableOCR = true;

  nodes.machine = { ... }: {
    imports = [
      ../environment/module/debug.nix
    ];

    users.groups.admin = {};
    users.users.admin.group = "admin";
    users.users.admin.isSystemUser = true;
    users.users."1000".group = "users";
    users.users."1000".isNormalUser = true;
    users.users."1000".name = "user";
  };

  testScript = readFile ./check/debug.py;
}
