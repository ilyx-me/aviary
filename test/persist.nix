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

  name = "persist";
  enableOCR = true;

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default
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
      supportedFilesystems = [ "btrfs" ];
      initrd = {
        availableKernelModules = [ "e1000" ];
        systemd.services."systemd-cryptsetup-early".unitConfig.BindsTo = lib.mkVMOverride [ "dev-vdb.device" ];
      };
    };

    environment.systemPackages = with pkgs; [ cryptsetup ];

    specialisation."boot-luks".configuration = {

      virtualisation = {
        rootDevice = "/dev/mapper/disk-primary-luks-btrfs-test-a";
        fileSystems = {
          "/" = {
            fsType = lib.mkVMOverride "btrfs";
            options = [ "subvol=root" "compress=zstd" "noatime" ];
          };
          "/persist" = {
            fsType = "btrfs";
            device = "/dev/mapper/disk-primary-luks-btrfs-test-a";
            options = [ "subvol=persist" "compress=zstd" "noatime" ];
            neededForBoot = true;
          };
        };
      };

      boot.initrd.luks.devices = lib.mkVMOverride {
        "disk-primary-luks-btrfs-test-a" = {
          device = "/dev/vdb";
          crypttabExtraOpts = [ "tpm2-device=auto" ];
        };
      };
    };
  };

  testScript = readFile ./check/persist.py;
}
