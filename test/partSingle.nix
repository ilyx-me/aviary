{
  lib,
  pkgs,
  ...
}:
let

  inherit (builtins)
    readFile
    ;

  inherit (lib)
    recursiveUpdate
    ;

  config = { networking.hostName = "test-a"; };
  default = (import ../system/module/part/default.nix { inherit config lib; }).config;
  single = (import ../system/module/part/single.nix { }).config;
  diskoConfig = recursiveUpdate default single;
in
{
  pkgs = pkgs;
  name = "partSingle";
  enableOCR = true;

  disko-config = diskoConfig;

  extraInstallerConfig = {
    systemd.tmpfiles.settings."10-luks-pwd"."/luks-password-recovery".f.argument = "password";
  };

  extraSystemConfig = { };

  bootCommands = readFile ./check/defaultInitrd.py;
  extraTestScript = readFile ./check/partSingle.py;
}
