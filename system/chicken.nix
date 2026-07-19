{
  inputs,
  ...
}:

{

  imports = [
    inputs.hardware.nixosModules.lenovo-thinkpad-x1-6th-gen
  ];

  config = {

    networking.hostName = "chicken";
    system.stateVersion = "25.11";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary = {
      drive.primary = "/dev/disk/by-id/nvme-eui.0025385481b04ee1";
      virtualDisplay = "HDMI-A-2";
    };

    boot = {
      binfmt.emulatedSystems = [ "aarch64-linux" ];
      kernelModules = [ "kvm-intel" ];
      initrd.availableKernelModules = [
        "e1000e"
        "iwlmvm"
        "iwlwifi"
        "nvme"
        "sd_mod"
        "usb_storage"
        "xhci_pci"
      ];
    };

    hardware.bluetooth.enable = true;
  };
}
