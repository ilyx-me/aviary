{
  lib,
  ...
}:

{

  config = {

    networking.hostName = "lark";
    system.stateVersion = "26.05";

    nixpkgs.hostPlatform = "aarch64-linux";

    aviary.drive.primary = "/dev/disk/by-id/wwn-0x60e788a1e0b647f19b4562a634dd790d";

    boot = {
      loader.systemd-boot = {
        enable = true;
        editor = false;
      };

      kernelParams = [
        "nvme.shutdown_timeout=10"
        "nvme_core.shutdown_timeout=10"
        "libiscsi.debug_libiscsi_eh=1"
        "crash_kexec_post_notifiers"
        "console=ttyAMA0"
      ];

      initrd.availableKernelModules = [
        "usbhid"
        "virtio_net"
        "virtio_pci"
        "virtio_scsi"
        "xhci_pci"
      ];
    };

    services.cloud-init.enable = true;

    users.users."999".hashedPasswordFile = lib.mkForce null;
    users.users."1000".hashedPasswordFile = lib.mkForce null;
  };
}
