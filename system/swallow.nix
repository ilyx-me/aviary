{

  config = {

    networking.hostName = "swallow";
    system.stateVersion = "26.05";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary.drive.primary = "/dev/disk/by-id/wwn-0x606ba5043cf547bdb8d065fc3650caf5";

    boot = {
      kernelModules = [ "kvm-amd" ];
      initrd.availableKernelModules = [
        "usbhid"
        "virtio_net"
        "virtio_pci"
        "virtio_scsi"
        "xhci_pci"
      ];
    };

    services.cloud-init.enable = true;
  };
}
