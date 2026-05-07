{
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  inherit (builtins)
    readFile
  ;

in {

  name = "decrypt";
  enableOCR = true;

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default
      ../environment/module/debug.nix

      (import ./user/testA.nix { inherit inputs lib; })
    ];

    virtualisation = {
      emptyDiskImages = [ 512 ];
      mountHostNixStore = true;
      efi.OVMF = pkgs.OVMFFull;
      useEFIBoot = true;
      useBootLoader = true;
    };

    boot = {
      loader.systemd-boot.enable = lib.mkVMOverride true;
      initrd = {
        availableKernelModules = [ "e1000" ];
        systemd.services."systemd-cryptsetup-early".unitConfig.BindsTo = lib.mkVMOverride [ "dev-vdb.device" ];
      };
    };

    environment.systemPackages = with pkgs; [ cryptsetup ];

    specialisation."boot-luks".configuration = {

      virtualisation = {
        rootDevice = "/dev/mapper/cryptroot";
        fileSystems."/".autoFormat = true;
      };

      boot.initrd.luks.devices = lib.mkVMOverride {
        cryptroot = {
          device = "/dev/vdb";
          crypttabExtraOpts = [ "tpm2-device=auto" ];
        };
      };
    };
  };

  testScript = readFile ./check/decrypt.py;
}
