{
  inputs,
  lib,
  self,
  pkgs,
  ...
}:

let
  inherit (builtins)
    readFile
    ;

in
{

  name = "update";

  nodes.machine = { ... }: {
    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default
      ../service/update.nix
      (import ./user/testA.nix { inherit inputs; })
    ];

    virtualisation = {
      emptyDiskImages = [ 8192 ];
      mountHostNixStore = true;
      writableStoreUseTmpfs = false;
      useEFIBoot = true;
      useBootLoader = true;
      memorySize = 4096;
    };

    boot = {
      lanzaboote.enable = lib.mkVMOverride false;
      loader.systemd-boot.enable = lib.mkVMOverride true;
      initrd = {
        systemd.services."systemd-cryptsetup-early".unitConfig.BindsTo = lib.mkVMOverride [
          "dev-vdb.device"
        ];
      };
    };

    environment.systemPackages = with pkgs; [ cryptsetup ];

    specialisation."boot-luks".configuration = {

      virtualisation = {
        rootDevice = "/dev/mapper/cryptroot";
        fileSystems."/".autoFormat = true;
      };

      boot.initrd = {

        luks.devices = lib.mkVMOverride {
          cryptroot = {
            device = "/dev/vdb";
            crypttabExtraOpts = [ "tpm2-device=auto" ];
          };
        };
      };
    };

    #services.comin.hostname = lib.mkVMOverride "deploy-test";

    sops.secrets."test-a-ssh-root" = {
      mode = "0400";
      owner = "root";
      group = "root";
      path = "/root/.ssh/id_ed25519";
    };

    #systemd.services.comin.environment.GIT_SSH_COMMAND = "${pkgs.openssh}/bin/ssh -i /run/secrets.d/1/test-a-ssh-root";
  };

  testScript = readFile ./check/update.py;
}
