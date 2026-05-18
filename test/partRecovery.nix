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
  recovery = (import ../system/module/part/recovery.nix { }).config;
  diskoConfig = recursiveUpdate default recovery;

in {

  pkgs = pkgs;
  name = "partRecovery";
  enableOCR = true;

  disko-config = diskoConfig;

  extraInstallerConfig = {
    systemd.tmpfiles.settings."10-luks-pwd"."/tmp/aviaryInstall/luks-password-recovery".f.argument = "password";

    virtualisation.emptyDiskImages = lib.mkForce [ 8192 ];
  };

  extraSystemConfig = { };

  bootCommands = readFile ./check/defaultInitrd.py;
  extraTestScript = readFile ./check/partRecovery.py;
}
