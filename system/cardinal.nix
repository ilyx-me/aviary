{
  config,
  inputs,
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

    aviary.drive = {
      primary = "/dev/disk/by-id/nvme-eui.5cd2e41ba6540100";
      secondary = "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b4918ecea";
    };

    boot = {
      kernelModules = [ "kvm-intel" ];
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
      };
    };
  };
}
