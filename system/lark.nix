{

  config = {

    networking.hostName = "lark";
    system.stateVersion = "26.05";

    nixpkgs.hostPlatform = "aarch64-linux";

    aviary.drive.primary = "/dev/disk/by-id/wwn-0x603d0d13988e4be6bda8c3b699d08de9";

    boot.initrd.availableKernelModules = [
      "usbhid"
      "virtio_net"
      "virtio_pci"
      "virtio_scsi"
      "xhci_pci"
    ];

    services.cloud-init.enable = true;
  };
}
