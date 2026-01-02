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

in
{
  name = "decrypt";
  enableOCR = true;

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      inputs.home-manager.nixosModules.default
      inputs.impermanence.nixosModules.impermanence
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.sops-nix.nixosModules.sops
      ../environment/module/default.nix
      ../service/default.nix
      ../environment/module/debug.nix

      (import ./user/testA.nix { inherit inputs; })
    ];

    system.activationScripts."genSBKeys".text = ''
      ${pkgs.sbctl}/bin/sbctl create-keys
    '';

    virtualisation = {
      emptyDiskImages = [ 512 ];
      mountHostNixStore = true;
      efi.OVMF = pkgs.OVMFFull;
      useEFIBoot = true;
      useBootLoader = true;
    };

    boot = {
      lanzaboote.enable = lib.mkVMOverride false;
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
