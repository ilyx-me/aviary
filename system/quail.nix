{
  inputs,
  ...
}:

{

  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd
  ];

  config = {

    networking.hostName = "quail";
    system.stateVersion = "25.11";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary = {
      drive.primary = "/dev/disk/by-id/wwn-0x500080d911304b53";
      virtualDisplay = "HDMI-A-3";
    };

    boot = {
      kernelModules = [ "kvm-intel" ];
      initrd.availableKernelModules = [
        "ahci"
	"e1000e"
	"iwlmvm"
	"iwlwifi"
        "sd_mod"
	"sr_mod"
	"usbhid"
        "usb_storage"
        "xhci_pci"
      ];
    };

    hardware.bluetooth.enable = true;
  };
}
