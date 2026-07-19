{
  lib,
  ...
}:

{

  config = {

    networking.hostName = "swallow";
    system.stateVersion = "26.05";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary.drive.primary = "/dev/disk/by-id/wwn-0x60efe417d6134dc8aaf8531a5ffdea65";

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
        "console=ttyS0"
      ];

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

    users.users."999".hashedPasswordFile = lib.mkForce null;
    users.users."1000".hashedPasswordFile = lib.mkForce null;
  };
}
