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

  name = "default";

  nodes.machine = { ... }: {

    _module.args = { inherit inputs; };
    imports = [
      self.nixosModules.default
      (import ./user/testA.nix {inherit inputs;})
    ];

    system.activationScripts."genSBKeys".text = ''
      ${pkgs.sbctl}/bin/sbctl create-keys
    '';

    virtualisation = {
      emptyDiskImages = [ 512 ];
      mountHostNixStore = true;
      efi.OVMF = pkgs.OVMFFull;
      useEFIBoot = true;
      tpm.enable = true;
      useBootLoader = true;
    };

    boot = {
      lanzaboote.enable = lib.mkVMOverride false;
      loader.systemd-boot.enable = lib.mkVMOverride true;
      initrd = {
        availableKernelModules = [ "tpm_tis" ];
        systemd.services."systemd-cryptsetup-early".unitConfig.BindsTo = lib.mkVMOverride [ "dev-vdb.device" ];
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

        systemd.services."check-pcrs" = {
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          unitConfig.DefaultDependencies = "no";
          after = [ "cryptsetup.target" ];
          before = [ "sysroot.mount" ];
          requiredBy = [ "sysroot.mount" ];
          script = ''
            echo "Checking PCR 15 value"
            if [[ $(systemd-analyze pcrs 15 --json=short) != '[{"nr":15,"name":"system-identity","sha256":"0000000000000000000000000000000000000000000000000000000000000000"}]' ]] ; then
                echo "PCR 15 check failed"
                exit 1
            else
                echo "PCR 15 check succeeded"
            fi
          '';
        };
      };
    };
  };

  testScript = readFile ./check/tpm.py;
}
