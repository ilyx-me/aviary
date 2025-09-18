{
  lib,
  self',
  ...
}:
let

  inherit (builtins)
    readFile
    ;

  inherit (lib)
    recursiveUpdate
    ;

  config = self'.checks.debugInitrd.nodes.machine;
  default = (import ../system/module/part/default.nix { inherit config lib; }).config;
  recovery = (import ../system/module/part/recovery.nix { }).config;
  diskoConfig = recursiveUpdate default recovery;
in
{
  name = "debugInitrd";
  enableOCR = true;

  disko-config = diskoConfig;

  extraInstallerConfig = {
    systemd.tmpfiles.settings."10-luks-pwd"."/luks-password-recovery".f.argument = "password";
  };

  extraSystemConfig = {
    imports = [
      ../environment/module/debug.nix
    ];

    boot.initrd.systemd.enable = true;

    users.groups.admin = {};
    users.users.admin.group = "admin";
    users.users.admin.isSystemUser = true;
    users.users."1000".group = "users";
    users.users."1000".isNormalUser = true;
    users.users."1000".name = "user";
  };

  bootCommands = readFile ./check/debugInitrd.py;
}
