{
  inputs,
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
in
{
  pkgs = pkgs;
  name = "decrypt";
  enableOCR = true;

  disko-config = diskoConfig;

  extraInstallerConfig = {
    systemd.tmpfiles.settings."10-luks-pwd"."/luks-password-recovery".f.argument = "password";
  };

  extraSystemConfig = {
    _module.args = { inherit inputs; };
    imports = [
      inputs.home-manager.nixosModules.default
      inputs.impermanence.nixosModules.impermanence
      inputs.sops-nix.nixosModules.sops
      ../environment/module/default.nix
      ../service/default.nix
      ../environment/module/debug.nix

      (import ./user/testA.nix { inherit inputs; })
    ];

    boot.initrd.availableKernelModules = [ "e1000" ];
  };

  bootCommands = readFile ./check/decrypt.py;
}
