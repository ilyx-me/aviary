{
  lib,
  pkgs,
  self,
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

  config = self'.checks.bootstrap.nodes.machine;
  default = (import ../system/module/part/default.nix { inherit config lib; }).config;
  recovery = (import ../system/module/part/recovery.nix { }).config;
  diskoConfig = recursiveUpdate default recovery;
in
{
  name = "bootstrap";
  enableOCR = true;

  disko-config = diskoConfig;

  extraInstallerConfig = {
    systemd.tmpfiles.settings = {
      "10-luks-pwd"."/luks-password-recovery".f.argument = "password";
    };

    environment.systemPackages = [
      pkgs.sbctl
    ];
  };

  extraSystemConfig = {
    imports = [
      self.nixosModules.default
    ];
  };

  postDisko = readFile ./check/defaultInstall.py;
  bootCommands = readFile ./check/defaultInitrd.py;
  extraTestScript = readFile ./check/bootstrap.py;
}
