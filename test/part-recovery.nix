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

  config = self'.checks.part-recovery.nodes.machine;
  default = (import ../system/module/part/default.nix { inherit config lib; }).config;
  recovery = (import ../system/module/part/recovery.nix { }).config;
  diskoConfig = recursiveUpdate default recovery;
in
{
  name = "login";
  enableOCR = true;

  disko-config = diskoConfig;

  extraInstallerConfig = {
    systemd.tmpfiles.settings."10-luks-pwd"."/luks-password-recovery".f.argument = "password";
  };

  extraSystemConfig = { };

  bootCommands = readFile ./luks-unlock.py;
  extraTestScript = readFile ./default.py;
}
