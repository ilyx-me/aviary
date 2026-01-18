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

    networking.hostName = "chicken";
    system.stateVersion = "25.11";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary.drive.primary = "/dev/disk/by-id/nvme-eui.0025385481b04ee1";

    boot.initrd.availableKernelModules = [
      "e1000e"
      "iwlmvm"
      "iwlwifi"
      "nvme"
      "sd_mod"
      "usb_storage"
      "xhci_pci"
    ];

    boot.kernelModules = [ "kvm-intel" ];

    hardware.bluetooth.enable = true;
  };
}
