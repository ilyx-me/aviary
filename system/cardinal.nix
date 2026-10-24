{
  config,
  inputs,
  pkgs,
  ...
}:

{

  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.hardware.nixosModules.common-pc-ssd
  ];

  config = {

    networking.hostName = "cardinal";
    system.stateVersion = "26.05";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary = {
      drive = {
        primary = "/dev/disk/by-id/nvme-eui.5cd2e41ba6540100";
        secondary = "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b4918ecea";
      };

      virtualDisplay = "HDMI-A-1";
    };

    boot = {
      kernelModules = [ "kvm-intel" ];
      kernelParams = [ "nvidia.NVreg_TemporaryFilePath=/var/tmp" ];
      initrd.availableKernelModules = [
        "ahci"
        "atlantic"
        "e1000e"
        "iwlmvm"
        "iwlwifi"
        "nvme"
        "sd_mod"
        "usbhid"
        "usb_storage"
        "xhci_pci"
      ];
    };

    hardware = {
      bluetooth.enable = true;
      nvidia = {
        open = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        powerManagement.enable = true;
      };
    };

    # a bad workaround
    # systemd-sysctl & systemd-modules-load sometimes race after initrd switches root causing
    # nvidia-uvm module to not load and leaving kernel params unset. Seems
    # nvidia specific, I can't reproduce this on other systems.
    # https://github.com/NixOS/nixpkgs/issues/290569
    systemd.services = {
      "systemd-sysctl-modules-load-restart" = {
        before = [ "multi-user.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = "yes";
          ExecStart = "${pkgs.systemd}/bin/systemctl restart systemd-modules-load systemd-sysctl";
        };
      };
    };
  };
}
